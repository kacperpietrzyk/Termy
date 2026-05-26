import XCTest
@testable import TermyCore

final class SyntaxHighlightStyleMapTests: XCTestCase {
    private var system: TerminalTheme {
        TerminalThemeCatalog.builtIn.theme(id: "system")!  // prompt #64D2FF, error #FF453A, fg #F2F2F2, muted #98989D
    }

    func testMapsRolesToThemeColors() {
        let lines = SyntaxHighlightStyleMap.styles(for: system)
        XCTAssertTrue(lines.contains("ZSH_HIGHLIGHT_STYLES[command]='fg=#64D2FF'"))
        XCTAssertTrue(lines.contains("ZSH_HIGHLIGHT_STYLES[builtin]='fg=#64D2FF'"))
        XCTAssertTrue(lines.contains("ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#FF453A'"))
        XCTAssertTrue(lines.contains("ZSH_HIGHLIGHT_STYLES[path]='fg=#F2F2F2,underline'"))
        XCTAssertTrue(lines.contains("ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=#F2F2F2'"))
        XCTAssertTrue(lines.contains("ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=#98989D'"))
        XCTAssertTrue(lines.contains("ZSH_HIGHLIGHT_STYLES[commandseparator]='fg=#98989D'"))
    }

    func testEveryLineIsAWellFormedAssignmentAndPure() {
        let a = SyntaxHighlightStyleMap.styles(for: system)
        let b = SyntaxHighlightStyleMap.styles(for: system)
        XCTAssertEqual(a, b, "pure: same theme -> same output")
        XCTAssertFalse(a.isEmpty)
        for line in a {
            XCTAssertTrue(line.hasPrefix("ZSH_HIGHLIGHT_STYLES["))
            XCTAssertTrue(line.contains("='fg=#"))
            XCTAssertTrue(line.hasSuffix("'"))
        }
    }

    func testCustomThemeColorsFlowThrough() {
        let custom = TerminalTheme(id: "x", name: "X", backgroundHex: "#000000",
                                   foregroundHex: "#ABCDEF", promptHex: "#112233",
                                   errorHex: "#FF0000", mutedHex: "#445566")
        let lines = SyntaxHighlightStyleMap.styles(for: custom)
        XCTAssertTrue(lines.contains("ZSH_HIGHLIGHT_STYLES[command]='fg=#112233'"))
        XCTAssertTrue(lines.contains("ZSH_HIGHLIGHT_STYLES[path]='fg=#ABCDEF,underline'"))
    }
}
