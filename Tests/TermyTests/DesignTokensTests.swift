import XCTest
@testable import Termy
@testable import TermyCore

final class DesignTokensTests: XCTestCase {
    // Transcription guard: a wrong hue/lightness in the literal table is the
    // most likely error. Verify each accent's dominant channel via the
    // already-tested converter (structural, not hardcoded triples).
    func testErrorAccentIsRedDominant() {
        let p = DesignTokens.error.base.displayP3Components()
        XCTAssertGreaterThan(p.red, p.green)
        XCTAssertGreaterThan(p.red, p.blue)
    }

    func testSyncAccentIsGreenDominant() {
        let p = DesignTokens.sync.base.displayP3Components()
        XCTAssertGreaterThan(p.green, p.red)
        XCTAssertGreaterThan(p.green, p.blue)
    }

    func testHostAccentIsBlueGreenLeaning() {
        let p = DesignTokens.host.base.displayP3Components()  // cyan, h=200
        XCTAssertGreaterThan(p.blue, p.red)
        XCTAssertGreaterThan(p.green, p.red)
    }

    func testNeutralsAreNearAchromaticAndOrdered() {
        // bg0 darker than fg1; both effectively gray (low chroma).
        XCTAssertLessThan(DesignTokens.bg0.l, DesignTokens.fg1.l)
        let fg = DesignTokens.fg1.displayP3Components()
        XCTAssertEqual(fg.red, fg.green, accuracy: 0.03)
    }

    func testChipBackgroundsAreTranslucent() {
        XCTAssertLessThan(DesignTokens.ai.bg.alpha, 1.0)
        XCTAssertEqual(DesignTokens.ai.bg.alpha, 0.22, accuracy: 1e-9)
    }

    func testPrimaryAndAiAreVioletNotAmber() {   // h=295: blue & red > green
        for c in [DesignTokens.primary, DesignTokens.ai.base] {
            let p = c.displayP3Components()
            XCTAssertGreaterThan(p.blue, p.green)
            XCTAssertGreaterThan(p.red, p.green)
        }
    }

    func testAgentIsWarmAmber() {                 // h=70: red & green > blue
        let p = DesignTokens.agent.base.displayP3Components()
        XCTAssertGreaterThan(p.red, p.blue)
        XCTAssertGreaterThan(p.green, p.blue)
    }

    func testRadiiAreMonotonic() {
        let r = DesignTokens.Radius.self
        XCTAssertTrue(r.xs < r.sm && r.sm < r.md && r.md < r.lg && r.lg < r.xl && r.xl < r.xxl)
    }
}
