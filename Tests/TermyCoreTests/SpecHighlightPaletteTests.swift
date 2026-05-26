import XCTest
@testable import TermyCore

final class SpecHighlightPaletteTests: XCTestCase {
    func testEmitsZshAssocForStructureRolesOnly() {
        let block = SpecHighlightPalette.default.zshStylesBlock()
        XCTAssertTrue(block.contains("typeset -gA TERMY_SPEC_STYLES"))
        XCTAssertTrue(block.contains("TERMY_SPEC_STYLES[command]='fg=#30D158'"))
        XCTAssertTrue(block.contains("TERMY_SPEC_STYLES[subcommand]='fg=#5AC8FA'"))
        XCTAssertTrue(block.contains("TERMY_SPEC_STYLES[option]='fg=#98989D'"))
        XCTAssertTrue(block.contains("TERMY_SPEC_STYLES[error]='fg=#FF453A'"))
        XCTAssertFalse(block.contains("[argument]"))
        XCTAssertFalse(block.contains("[option-argument]"))
    }
}
