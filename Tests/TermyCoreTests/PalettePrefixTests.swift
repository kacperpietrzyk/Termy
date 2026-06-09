import XCTest
@testable import TermyCore

final class PalettePrefixTests: XCTestCase {

    // MARK: - No sigil

    func testEmptyQueryIsAllScopeEmptyRemainder() {
        let prefix = PalettePrefix.parse("")
        XCTAssertEqual(prefix.scope, .all)
        XCTAssertEqual(prefix.remainder, "")
        XCTAssertFalse(prefix.isBareSigil)
    }

    func testPlainTextIsAllScopeWithWholeQuery() {
        let prefix = PalettePrefix.parse("git status")
        XCTAssertEqual(prefix.scope, .all)
        XCTAssertEqual(prefix.remainder, "git status")
    }

    func testWhitespaceIsTrimmed() {
        let prefix = PalettePrefix.parse("   git   ")
        XCTAssertEqual(prefix.scope, .all)
        XCTAssertEqual(prefix.remainder, "git")
    }

    // MARK: - Each sigil strips to remainder

    func testCommandsSigil() {
        let prefix = PalettePrefix.parse(">new terminal")
        XCTAssertEqual(prefix.scope, .commands)
        XCTAssertEqual(prefix.remainder, "new terminal")
    }

    func testSessionsSigil() {
        let prefix = PalettePrefix.parse("@prod")
        XCTAssertEqual(prefix.scope, .sessions)
        XCTAssertEqual(prefix.remainder, "prod")
    }

    func testSettingsSigil() {
        let prefix = PalettePrefix.parse(":output")
        XCTAssertEqual(prefix.scope, .settings)
        XCTAssertEqual(prefix.remainder, "output")
    }

    func testHelpSigil() {
        let prefix = PalettePrefix.parse("?")
        XCTAssertEqual(prefix.scope, .help)
        XCTAssertEqual(prefix.remainder, "")
        XCTAssertTrue(prefix.isBareSigil)
    }

    func testSigilFollowedBySpaceStillStrips() {
        let prefix = PalettePrefix.parse(">  new")
        XCTAssertEqual(prefix.scope, .commands)
        XCTAssertEqual(prefix.remainder, "new")
    }

    func testLeadingSpaceBeforeSigilStillParses() {
        let prefix = PalettePrefix.parse("  @prod")
        XCTAssertEqual(prefix.scope, .sessions)
        XCTAssertEqual(prefix.remainder, "prod")
    }

    // MARK: - Bare sigil = show all in scope (NOT fallbacks)

    func testBareCommandsSigilIsBare() {
        let prefix = PalettePrefix.parse(">")
        XCTAssertEqual(prefix.scope, .commands)
        XCTAssertEqual(prefix.remainder, "")
        XCTAssertTrue(prefix.isBareSigil)
    }

    func testBareSigilWithTrailingSpaceIsStillBare() {
        let prefix = PalettePrefix.parse("@   ")
        XCTAssertEqual(prefix.scope, .sessions)
        XCTAssertTrue(prefix.isBareSigil)
    }

    // MARK: - Unknown leading char is literal text

    func testUnknownSigilIsLiteralText() {
        let prefix = PalettePrefix.parse("#tag")
        XCTAssertEqual(prefix.scope, .all)
        XCTAssertEqual(prefix.remainder, "#tag")
        XCTAssertFalse(prefix.isBareSigil)
    }

    func testSigilNotFirstIsLiteralText() {
        // A sigil that is not the first character carries no scope.
        let prefix = PalettePrefix.parse("git >status")
        XCTAssertEqual(prefix.scope, .all)
        XCTAssertEqual(prefix.remainder, "git >status")
    }

    // MARK: - Scope membership

    func testCommandsScopeAdmitsOnlyActions() {
        let p = PalettePrefix.parse(">x")
        XCTAssertTrue(p.admits(kind: .action, actionArea: "terminal", actionID: "new-local-terminal"))
        XCTAssertFalse(p.admits(kind: .profile))
        XCTAssertFalse(p.admits(kind: .agentSession))
    }

    func testSessionsScopeAdmitsProfilesAndAgentsOnly() {
        let p = PalettePrefix.parse("@x")
        XCTAssertTrue(p.admits(kind: .profile))
        XCTAssertTrue(p.admits(kind: .agentSession))
        XCTAssertFalse(p.admits(kind: .action, actionArea: "terminal", actionID: "new-local-terminal"))
    }

    func testAllScopeAdmitsEverything() {
        let p = PalettePrefix.parse("x")
        XCTAssertTrue(p.admits(kind: .action, actionArea: "ai", actionID: "toggle-ai-panel"))
        XCTAssertTrue(p.admits(kind: .profile))
        XCTAssertTrue(p.admits(kind: .agentSession))
    }

    // MARK: - Settings scope keys off real action signals (no fabrication)

    func testSettingsScopeAdmitsSyncAndCommandCenterAreaActions() {
        let p = PalettePrefix.parse(":x")
        XCTAssertTrue(p.admits(kind: .action, actionArea: ProductArea.sync.rawValue, actionID: "save-workspace"))
        XCTAssertTrue(p.admits(kind: .action, actionArea: ProductArea.commandCenter.rawValue, actionID: "tile-editor-right"))
    }

    func testSettingsScopeAdmitsOutputModeToggleEvenInTerminalArea() {
        let p = PalettePrefix.parse(":output")
        XCTAssertTrue(p.admits(kind: .action,
                               actionArea: ProductArea.terminal.rawValue,
                               actionID: "set-terminal-output-blocks"))
    }

    func testSettingsScopeRejectsPlainTerminalAction() {
        let p = PalettePrefix.parse(":x")
        XCTAssertFalse(p.admits(kind: .action,
                                actionArea: ProductArea.terminal.rawValue,
                                actionID: "new-local-terminal"))
    }

    func testSettingsScopeRejectsNonActions() {
        let p = PalettePrefix.parse(":x")
        XCTAssertFalse(p.admits(kind: .profile))
        XCTAssertFalse(p.admits(kind: .agentSession))
    }

    func testHelpScopeAdmitsActions() {
        // The store further restricts to actions with a shortcut; the prefix
        // itself admits the action kind.
        let p = PalettePrefix.parse("?x")
        XCTAssertTrue(p.admits(kind: .action, actionArea: "ai", actionID: "toggle-ai-panel"))
        XCTAssertFalse(p.admits(kind: .profile))
    }

    // MARK: - Sigil round-trip

    func testScopeSigilRoundTrip() {
        XCTAssertNil(PalettePrefix.Scope.all.sigil)
        XCTAssertEqual(PalettePrefix.Scope.commands.sigil, ">")
        XCTAssertEqual(PalettePrefix.Scope.sessions.sigil, "@")
        XCTAssertEqual(PalettePrefix.Scope.settings.sigil, ":")
        XCTAssertEqual(PalettePrefix.Scope.help.sigil, "?")
    }
}
