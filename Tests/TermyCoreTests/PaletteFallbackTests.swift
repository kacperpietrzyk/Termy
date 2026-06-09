import XCTest
@testable import TermyCore

final class PaletteFallbackTests: XCTestCase {

    // MARK: - Input passthrough

    func testInputReflectsAssociatedValue() {
        XCTAssertEqual(PaletteFallback.runInSession("ls -la").input, "ls -la")
        XCTAssertEqual(PaletteFallback.askLocalAI("why fail").input, "why fail")
        XCTAssertEqual(PaletteFallback.sshTo("box").input, "box")
        XCTAssertEqual(PaletteFallback.searchScrollback("error").input, "error")
    }

    // MARK: - Titles reflect input

    func testTitlesIncludeInputWhenPresent() {
        XCTAssertTrue(PaletteFallback.runInSession("ls").title.contains("ls"))
        XCTAssertTrue(PaletteFallback.askLocalAI("fix").title.contains("fix"))
        XCTAssertTrue(PaletteFallback.sshTo("host").title.contains("host"))
        XCTAssertTrue(PaletteFallback.searchScrollback("warn").title.contains("warn"))
    }

    func testTitlesFallBackToGenericWhenEmpty() {
        XCTAssertEqual(PaletteFallback.runInSession("").title, "Run in session")
        XCTAssertEqual(PaletteFallback.askLocalAI("").title, "Ask local AI")
        XCTAssertEqual(PaletteFallback.sshTo("").title, "SSH to a host")
        XCTAssertEqual(PaletteFallback.searchScrollback("").title, "Search scrollback")
    }

    func testStableIdsPerKind() {
        XCTAssertEqual(PaletteFallback.runInSession("a").id, PaletteFallback.runInSession("b").id)
        XCTAssertNotEqual(PaletteFallback.runInSession("a").id, PaletteFallback.askLocalAI("a").id)
    }

    // MARK: - Suggestion ordering per scope

    func testAllScopeLeadsWithRunThenAISSHSearch() {
        let prefix = PalettePrefix.parse("deploy")
        let list = PaletteFallback.suggestions(for: prefix)
        XCTAssertEqual(list, [
            .runInSession("deploy"),
            .askLocalAI("deploy"),
            .sshTo("deploy"),
            .searchScrollback("deploy")
        ])
    }

    func testCommandsScopeMatchesAllOrdering() {
        let prefix = PalettePrefix.parse(">deploy")
        let list = PaletteFallback.suggestions(for: prefix)
        XCTAssertEqual(list.first, .runInSession("deploy"))
        XCTAssertEqual(list.count, 4)
    }

    func testSessionsScopeLeadsWithSSH() {
        let prefix = PalettePrefix.parse("@prod-box")
        let list = PaletteFallback.suggestions(for: prefix)
        XCTAssertEqual(list.first, .sshTo("prod-box"))
        XCTAssertFalse(list.contains(.askLocalAI("prod-box")))
    }

    func testSettingsScopeOffersOnlyAIAndSearch() {
        let prefix = PalettePrefix.parse(":theme")
        let list = PaletteFallback.suggestions(for: prefix)
        XCTAssertEqual(list, [.askLocalAI("theme"), .searchScrollback("theme")])
    }

    func testHelpScopeOffersOnlyAIAndSearch() {
        let prefix = PalettePrefix.parse("?shortcut")
        let list = PaletteFallback.suggestions(for: prefix)
        XCTAssertEqual(list, [.askLocalAI("shortcut"), .searchScrollback("shortcut")])
    }

    func testSuggestionsSeedRemainderNotRawQuery() {
        // The sigil must be stripped before seeding the fallback input.
        let prefix = PalettePrefix.parse("@web1")
        let list = PaletteFallback.suggestions(for: prefix)
        XCTAssertEqual(list.first?.input, "web1")
    }
}
