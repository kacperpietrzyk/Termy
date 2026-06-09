import XCTest
@testable import TermyCore

/// Fixture-driven tests for the fully-offline destructive-command heuristic
/// (AI-S7).
///
/// The heuristic gates the proactive auto-fix/insert path under B4 — a
/// destructive suggestion must never be run or inserted without explicit
/// confirmation — so the priority here is a *low false-negative rate* on the
/// catastrophic commands, balanced against a *low false-positive rate* on
/// everyday safe ones (alarm fatigue also defeats B4). The decision is pure and
/// synchronous; no network, no client.
final class DestructiveCommandHeuristicTests: XCTestCase {

    private typealias H = DestructiveCommandHeuristic
    private typealias Risk = DestructiveCommandHeuristic.RiskLevel

    // MARK: - Safe commands → none (low false-positive rate)

    func testSafeCommandsAreNotFlagged() {
        let safe = [
            "ls -la",
            "git status",
            "git push",
            "git pull",
            "cd ~/Projects/Termy",
            "swift build",
            "npm install",
            "cat README.md",
            "echo hello",
            "grep -r TODO .",
            "git commit -m \"fix\"",
            "git reset HEAD~1",            // soft/mixed reset, not --hard
            "git reset --soft HEAD~1",
            "rm file.txt",                 // plain rm: expected, not gated
            "find . -name '*.swift'",
            "chmod 644 file.txt",          // not recursive
            "chown me file.txt"
        ]
        for cmd in safe {
            let v = H.evaluate(cmd)
            XCTAssertEqual(v.level, .none, "should be safe: \(cmd)")
            XCTAssertFalse(v.requiresConfirmation, "should not gate: \(cmd)")
            XCTAssertNil(v.primaryReason, "no reason for safe: \(cmd)")
        }
    }

    // MARK: - rm -rf flag combinations

    func testRmRecursiveForceFlagCombos() {
        let combos = ["rm -rf build", "rm -fr build", "rm -r -f build",
                      "rm --recursive --force build", "rm -Rf build"]
        for cmd in combos {
            let v = H.evaluate(cmd)
            XCTAssertGreaterThanOrEqual(v.level, .high, "rm -rf combo should be >= high: \(cmd)")
            XCTAssertEqual(v.findings.first?.category, .recursiveDelete, cmd)
        }
    }

    func testRmRecursiveOnlyIsModerate() {
        let v = H.evaluate("rm -r ./build")
        XCTAssertEqual(v.level, .moderate)
        XCTAssertEqual(v.findings.first?.category, .recursiveDelete)
    }

    func testRmForceOnlyIsLow() {
        let v = H.evaluate("rm -f stale.lock")
        XCTAssertEqual(v.level, .low)
    }

    func testRmRfOnRootIsCritical() {
        for target in ["rm -rf /", "rm -rf /*", "rm -rf ~", "rm -rf $HOME",
                       "rm -rf /usr", "rm -rf /System"] {
            let v = H.evaluate(target)
            XCTAssertEqual(v.level, .critical, "must be catastrophic: \(target)")
        }
    }

    func testRmRfLocalPathIsHighNotCritical() {
        let v = H.evaluate("rm -rf ./node_modules")
        XCTAssertEqual(v.level, .high)
    }

    // MARK: - git destructive subcommands

    func testGitForcePush() {
        for cmd in ["git push --force", "git push -f origin main",
                    "git push origin main --force"] {
            let v = H.evaluate(cmd)
            XCTAssertEqual(v.level, .high, cmd)
            XCTAssertEqual(v.findings.first?.category, .forcePush, cmd)
        }
    }

    func testGitForceWithLeaseIsLowerThanBareForce() {
        let lease = H.evaluate("git push --force-with-lease")
        XCTAssertEqual(lease.level, .moderate)
        let bare = H.evaluate("git push --force")
        XCTAssertGreaterThan(bare.level, lease.level)
    }

    func testGitResetHard() {
        let v = H.evaluate("git reset --hard HEAD~3")
        XCTAssertEqual(v.level, .moderate)
        XCTAssertEqual(v.findings.first?.category, .hardReset)
    }

    func testGitCleanForce() {
        XCTAssertEqual(H.evaluate("git clean -fd").level, .high)
        XCTAssertEqual(H.evaluate("git clean -fdx").level, .high)
        XCTAssertEqual(H.evaluate("git clean -f").level, .moderate)
        XCTAssertEqual(H.evaluate("git clean -n").level, .none)   // dry-run
    }

    // MARK: - dd / mkfs

    func testDdToDeviceIsCritical() {
        let v = H.evaluate("dd if=image.iso of=/dev/disk2 bs=1m")
        XCTAssertEqual(v.level, .critical)
        XCTAssertEqual(v.findings.first?.category, .diskWrite)
    }

    func testDdToFileIsHigh() {
        let v = H.evaluate("dd if=/dev/zero of=out.img bs=1m count=10")
        XCTAssertEqual(v.level, .high)
    }

    func testMkfs() {
        XCTAssertEqual(H.evaluate("mkfs.ext4 /dev/sdb1").level, .critical)
        XCTAssertEqual(H.evaluate("mkfs -t ext4 /dev/sdb1").level, .critical)
    }

    // MARK: - truncate

    func testTruncateWithSizeIsModerate() {
        let v = H.evaluate("truncate -s 0 app.log")
        XCTAssertEqual(v.level, .moderate)
        XCTAssertEqual(v.findings.first?.category, .truncate)
    }

    func testTruncateWithoutSizeIsNotFlagged() {
        // truncate without -s is not a data-destroying invocation.
        let v = H.evaluate("truncate --help")
        XCTAssertEqual(v.level, .none)
    }

    // MARK: - redirect truncation (the subtle one)

    func testTruncatingRedirectToRealFileIsFlagged() {
        for cmd in ["echo x > config.json", "cat /dev/null > app.log",
                    "command 2> err.txt", "build &> output.log"] {
            let v = H.evaluate(cmd)
            XCTAssertGreaterThanOrEqual(v.level, .low, "truncating redirect: \(cmd)")
            XCTAssertTrue(v.findings.contains { $0.category == .redirectTruncate },
                          "expected redirect finding: \(cmd)")
        }
    }

    func testAppendRedirectIsNotFlagged() {
        for cmd in ["echo x >> app.log", "cat a.txt >> b.txt", "build &>> out.log"] {
            let v = H.evaluate(cmd)
            XCTAssertFalse(v.findings.contains { $0.category == .redirectTruncate },
                           "append must not be flagged: \(cmd)")
        }
    }

    func testRedirectToDevNullIsSafe() {
        for cmd in ["echo x > /dev/null", "noisy 2> /dev/null",
                    "cmd > /dev/stdout", "cmd 2> /dev/stderr"] {
            let v = H.evaluate(cmd)
            XCTAssertFalse(v.findings.contains { $0.category == .redirectTruncate },
                           "/dev sink must be safe: \(cmd)")
        }
    }

    func testDetachedRedirectOperator() {
        // Operator as its own token: ">" then "file".
        let v = H.evaluate("echo x > out.txt")
        XCTAssertTrue(v.findings.contains { $0.category == .redirectTruncate })
    }

    func testRedirectToSystemPathIsHigh() {
        let v = H.evaluate("echo x > /etc")
        XCTAssertTrue(v.findings.contains { $0.category == .redirectTruncate && $0.level == .high })
    }

    // MARK: - chmod / chown -R

    func testRecursiveChmodIsHigh() {
        let v = H.evaluate("chmod -R 777 ./public")
        XCTAssertEqual(v.level, .high)
        XCTAssertEqual(v.findings.first?.category, .recursivePermission)
    }

    func testRecursiveChmodOnRootIsCritical() {
        XCTAssertEqual(H.evaluate("chmod -R 777 /").level, .critical)
        XCTAssertEqual(H.evaluate("chown -R me /usr").level, .critical)
    }

    func testNonRecursiveChmodIsSafe() {
        XCTAssertEqual(H.evaluate("chmod 755 script.sh").level, .none)
    }

    // MARK: - sudo / env-prefix stripping + escalation

    func testSudoStripsToRealBinaryAndRaisesLevel() {
        // rm -rf ./build is high; under sudo it climbs to critical.
        let plain = H.evaluate("rm -rf ./build")
        let sudo = H.evaluate("sudo rm -rf ./build")
        XCTAssertEqual(plain.level, .high)
        XCTAssertEqual(sudo.level, .critical)
        XCTAssertTrue(sudo.primaryReason?.contains("sudo") == true)
    }

    func testEnvAssignmentPrefixStripped() {
        let v = H.evaluate("FOO=bar rm -rf ./build")
        XCTAssertEqual(v.findings.first?.category, .recursiveDelete)
        XCTAssertEqual(v.level, .high)
    }

    func testPathQualifiedBinaryIsRecognised() {
        let v = H.evaluate("/bin/rm -rf ./build")
        XCTAssertEqual(v.findings.first?.category, .recursiveDelete)
    }

    // MARK: - chained commands → max risk across segments

    func testChainedCommandsTakeMaxRisk() {
        let v = H.evaluate("git status && rm -rf / && echo done")
        XCTAssertEqual(v.level, .critical)
    }

    func testPipelineSegmentIsScanned() {
        let v = H.evaluate("cat list.txt | xargs rm -rf")
        XCTAssertGreaterThanOrEqual(v.level, .high)
    }

    func testMultipleFindingsAcrossSegments() {
        let v = H.evaluate("git reset --hard; git push --force")
        XCTAssertEqual(v.findings.count, 2)
        XCTAssertEqual(v.level, .high)   // force-push (high) > hard-reset (moderate)
        XCTAssertEqual(v.primaryReason, v.findings.first(where: { $0.level == .high })?.reason)
    }

    // MARK: - verdict shape / reasons

    func testReasonIsSpecificNotGeneric() {
        let v = H.evaluate("rm -rf build")
        let reason = v.primaryReason ?? ""
        XCTAssertTrue(reason.contains("recursively"), "reason should be specific: \(reason)")
        XCTAssertNotEqual(reason, "destructive")
    }

    func testEmptyAndWhitespaceAreSafe() {
        XCTAssertEqual(H.evaluate("").level, .none)
        XCTAssertEqual(H.evaluate("    ").level, .none)
        XCTAssertEqual(H.evaluate(";;;").level, .none)
    }

    func testRiskLevelOrdering() {
        XCTAssertLessThan(Risk.none, Risk.low)
        XCTAssertLessThan(Risk.low, Risk.moderate)
        XCTAssertLessThan(Risk.moderate, Risk.high)
        XCTAssertLessThan(Risk.high, Risk.critical)
    }
}
