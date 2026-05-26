import XCTest
import Foundation

/// Tests for the termy_spec zsh classifier (termy-spec-highlighter.zsh).
///
/// Shells out to /bin/zsh, sources the highlighter, calls termy_spec_classify,
/// and reads back the _TS_RESULT global array. Validates the ordered role
/// sequence for each test row (offsets are not asserted — roles only).
final class SpecHighlightClassifierTests: XCTestCase {

    /// Repo root resolved from this file's location.
    var root: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // TermyCoreTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // repo root
    }

    var highlighterPath: String {
        root.appendingPathComponent("script/shell/termy-spec-highlighter.zsh").path
    }

    var specDir: String {
        root.appendingPathComponent("vendor/specs/out").path
    }

    // MARK: - Helpers

    /// Runs termy_spec_classify for `line` and returns the ordered role list.
    private func classify(_ line: String) throws -> [String] {
        guard FileManager.default.fileExists(atPath: "/bin/zsh") else {
            throw XCTSkip("zsh not available at /bin/zsh")
        }
        guard FileManager.default.fileExists(atPath: highlighterPath) else {
            XCTFail("Highlighter not found at \(highlighterPath)")
            return []
        }

        // Escape single quotes in the line for embedding in a single-quoted zsh string.
        let escaped = line.replacingOccurrences(of: "'", with: "'\\''")

        // Driver: set TERMY_SPEC_DIR, source the highlighter, classify, print _TS_RESULT.
        // printf prints one triple per line. We extract the role (3rd field).
        let driver = """
        export TERMY_SPEC_DIR='\(specDir)'
        source '\(highlighterPath)'
        termy_spec_classify '\(escaped)'
        printf '%s\\n' "${_TS_RESULT[@]}"
        """

        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-classify-\(UUID().uuidString).zsh")
        try driver.write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = [tmp.path]
        var env = ProcessInfo.processInfo.environment
        env["TERMY_SPEC_DIR"] = specDir
        proc.environment = env

        let stdout = Pipe()
        let stderr = Pipe()
        proc.standardOutput = stdout
        proc.standardError = stderr

        try proc.run()
        proc.waitUntilExit()

        let errStr = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let outStr = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        XCTAssertEqual(proc.terminationStatus, 0, "zsh driver failed for '\(line)'. stderr: \(errStr)")

        // Parse roles: each line is "<start> <end> <role>"; extract the third field.
        let roles = outStr
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { line -> String? in
                let parts = line.split(separator: " ", maxSplits: 2)
                guard parts.count == 3 else { return nil }
                return String(parts[2])
            }
        return roles
    }

    // MARK: - Table-driven classifier tests

    func test_classifierTable() throws {
        guard FileManager.default.fileExists(atPath: "/bin/zsh") else {
            throw XCTSkip("zsh not available at /bin/zsh")
        }
        guard FileManager.default.fileExists(atPath: highlighterPath) else {
            XCTFail("Highlighter not found at \(highlighterPath) — implement script/shell/termy-spec-highlighter.zsh")
            return
        }

        let table: [(line: String, expectedRoles: [String])] = [
            // Row 1: standard subcommand + option + option-argument + option
            (
                #"git commit -m "x" --amend"#,
                ["command", "subcommand", "option", "option-argument", "option"]
            ),
            // Row 2: nested subcommand; positional args
            (
                "git remote add origin url",
                ["command", "subcommand", "subcommand", "argument", "argument"]
            ),
            // Row 3: two-pass global option (-C takes arg) before subcommand
            (
                "git -C /tmp commit",
                ["command", "option", "option-argument", "subcommand"]
            ),
            // Row 4: lenient trailing prefix — "pul" is prefix of "pull" → subcommand (NOT error)
            (
                "git pul",
                ["command", "subcommand"]
            ),
            // Row 5: completed unknown flag → error
            (
                "git --bogusflag",
                ["command", "error"]
            ),
            // Row 6: --long=val is one token → classified as single option (NOT option + option-argument)
            (
                "git commit --message=hi",
                ["command", "subcommand", "option"]
            ),
            // Row 7: bare -- ends options; all remaining tokens are arguments (including --amend)
            (
                "git -- --amend",
                ["command", "argument", "argument"]
            ),
            // Row 8: "psh" is NOT a prefix of any git subcommand → error
            (
                "git psh",
                ["command", "error"]
            ),
            // Row 9: subcommand with no nested _SUB table — positional after it is
            // an argument (regression: undefined _SUB var must stop descent so the
            // positional is not mis-classified as a trailing-prefix error).
            (
                "docker run -d nginx",
                ["command", "subcommand", "option", "argument"]
            ),
            // Row 10: completed positional after a leaf subcommand → argument
            // (regression for the same undefined-_SUB latent bug).
            (
                "git commit somefile.txt",
                ["command", "subcommand", "argument"]
            ),
            // Row 11: command on PATH but with NO bundled spec (ls) → fail-open.
            // word-0 paints as command; every remaining token is argument (NOT error)
            // because we have no grammar to validate options against (spec §6 / §7).
            (
                "ls -la /tmp",
                ["command", "argument", "argument"]
            ),
        ]

        for (line, expectedRoles) in table {
            let got = try classify(line)
            XCTAssertEqual(
                got, expectedRoles,
                "classify('\(line)') → \(got) but expected \(expectedRoles)"
            )
        }
    }
}
