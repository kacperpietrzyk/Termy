import XCTest
@testable import Termy
import TermyCore

final class DesignTokensBackgroundTests: XCTestCase {
    func testCornerBloomsMatchDesignSpec() {
        // DESIGN.md §3.4 — verbatim OKLCH literals.
        XCTAssertEqual(DesignTokens.Background.violetBloom, OKLCH(l: 0.48, c: 0.22, h: 295, alpha: 0.55))
        XCTAssertEqual(DesignTokens.Background.blueBloom,    OKLCH(l: 0.46, c: 0.20, h: 230, alpha: 0.50))
        XCTAssertEqual(DesignTokens.Background.magentaBloom, OKLCH(l: 0.42, c: 0.18, h: 325, alpha: 0.28))
        XCTAssertEqual(DesignTokens.Background.cyanBloom,    OKLCH(l: 0.44, c: 0.18, h: 200, alpha: 0.32))
    }

    func testCalmWashIsBg0At78Percent() {
        XCTAssertEqual(DesignTokens.Background.calmWash, OKLCH(l: 0.085, c: 0.012, h: 285, alpha: 0.78))
    }
}
