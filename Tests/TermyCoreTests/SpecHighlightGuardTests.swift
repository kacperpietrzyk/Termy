import XCTest
@testable import TermyCore

/// Task-5 structural guard (mirrors FB1SyntaxHighlightGuardTests): the vendored
/// withfig/autocomplete spec artifact must stay present, structured, and pinned;
/// the THIRDPARTY audit doc must exist; the generated .zshrc must fail-open on
/// a missing TERMY_SPEC_DIR.
final class SpecHighlightGuardTests: XCTestCase {
    /// Repo root = this file is at <root>/Tests/TermyCoreTests/SpecHighlightGuardTests.swift
    var root: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    // MARK: - Spec artifact structure

    /// The git spec file must exist and contain the top-level TS_GIT_SUB table with the
    /// core git subcommands, the nested TS_GIT_remote_SUB table, and correct takes-arg
    /// flags for commit's -m (takes-arg=1) and --amend (flag=0).
    func testConvertedSpecsPresentAndStructured() throws {
        let git = try String(
            contentsOf: root.appendingPathComponent("vendor/specs/out/spec_git.zsh"),
            encoding: .utf8)

        // Top-level subcommand table present.
        XCTAssertTrue(git.contains("TS_GIT_SUB="), "TS_GIT_SUB table must be present")

        // Core subcommands exist in TS_GIT_SUB (quoted-key format from spec converter).
        for sub in ["commit", "pull", "push", "remote"] {
            XCTAssertTrue(git.contains("[\"\(sub)\"]="), "\(sub) must appear in git spec")
        }

        // Nested TS_GIT_remote_SUB must exist (tests two-level spec depth).
        XCTAssertTrue(git.contains("TS_GIT_remote_SUB="), "nested TS_GIT_remote_SUB must exist")

        // commit's -m takes an argument (value=1) and --amend is a flag (value=0).
        XCTAssertTrue(git.contains("[\"-m\"]=1"),
                      "git commit -m must be marked takes-arg=1")
        XCTAssertTrue(git.contains("[\"--amend\"]=0"),
                      "git commit --amend must be marked flag=0")
    }

    // MARK: - PINS record

    /// vendor/specs/PINS must record the 40-character hex SHA for withfig/autocomplete.
    func testPinRecordsSha() throws {
        let pins = try String(
            contentsOf: root.appendingPathComponent("vendor/specs/PINS"),
            encoding: .utf8)
        XCTAssertTrue(pins.contains("withfig-autocomplete"),
                      "PINS must name the dependency")
        XCTAssertTrue(
            pins.range(of: #"SHA\s+[0-9a-f]{40}"#, options: .regularExpression) != nil,
            "PINS must record a 40-char hex SHA")
    }

    // MARK: - THIRDPARTY audit doc

    /// THIRDPARTY-SPECS.md must exist at the repo root (also flips `specsAudited` in
    /// package_dmg.sh).
    func testThirdpartyAuditPresent() {
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: root.appendingPathComponent("THIRDPARTY-SPECS.md").path),
            "THIRDPARTY-SPECS.md must exist at repo root")
    }

    // MARK: - Generated .zshrc fail-open guard

    /// The generated .zshrc must guard the spec-layer source on $TERMY_SPEC_DIR readability
    /// so a missing resource never blocks shell start.
    func testGeneratedZshrcFailsOpenForSpecDir() {
        let s = ShellIntegrationScript.zsh(highlightStyles: [], specStylesBlock: "")
        XCTAssertTrue(
            s.contains(#"[[ -n "$TERMY_SPEC_DIR" && -r "$TERMY_SPEC_DIR/termy-spec-highlighter.zsh" ]]"#),
            "generated .zshrc must guard spec source on TERMY_SPEC_DIR readability")
    }
}
