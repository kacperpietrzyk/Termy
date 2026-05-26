import XCTest
@testable import TermyCore

final class OklchColorTests: XCTestCase {
    private let tol = 1.0 / 255.0

    // Achromatic anchors are gamut-independent and exactly computable.
    func testBlackIsZero() {
        let p = OKLCH(l: 0, c: 0, h: 0).displayP3Components()
        XCTAssertEqual(p.red, 0, accuracy: tol)
        XCTAssertEqual(p.green, 0, accuracy: tol)
        XCTAssertEqual(p.blue, 0, accuracy: tol)
        XCTAssertEqual(p.alpha, 1, accuracy: tol)
    }

    func testWhiteIsOne() {
        let p = OKLCH(l: 1, c: 0, h: 0).displayP3Components()
        XCTAssertEqual(p.red, 1, accuracy: tol)
        XCTAssertEqual(p.green, 1, accuracy: tol)
        XCTAssertEqual(p.blue, 1, accuracy: tol)
    }

    // C=0 ⇒ neutral gray = sRGB-encode(L³). For L=0.5 that is ≈0.3886, and
    // all three channels must be identical regardless of hue angle.
    func testMidGrayIsAchromatic() {
        let p = OKLCH(l: 0.5, c: 0, h: 210).displayP3Components()
        XCTAssertEqual(p.red, p.green, accuracy: 1e-6)
        XCTAssertEqual(p.green, p.blue, accuracy: 1e-6)
        XCTAssertEqual(p.red, 0.3886, accuracy: 0.002)
    }

    func testAlphaPassesThrough() {
        let p = OKLCH(l: 0.5, c: 0, h: 0, alpha: 0.4).displayP3Components()
        XCTAssertEqual(p.alpha, 0.4, accuracy: tol)
    }

    // Hue invariants catch matrix transposition / sign errors without
    // hardcoding chromatic reference triples.
    func testRedHueIsRedDominant() {
        let p = OKLCH(l: 0.72, c: 0.20, h: 25).displayP3Components()   // error red
        XCTAssertGreaterThan(p.red, p.green)
        XCTAssertGreaterThan(p.red, p.blue)
    }

    func testGreenHueIsGreenDominant() {
        let p = OKLCH(l: 0.80, c: 0.14, h: 145).displayP3Components()  // sync green
        XCTAssertGreaterThan(p.green, p.red)
        XCTAssertGreaterThan(p.green, p.blue)
    }

    func testVioletHueHasSmallestGreen() {
        let p = OKLCH(l: 0.72, c: 0.18, h: 295).displayP3Components()  // primary violet
        XCTAssertLessThan(p.green, p.red)
        XCTAssertLessThan(p.green, p.blue)
    }

    func testOutputAlwaysClampedToUnitRange() {
        for h in stride(from: 0.0, to: 360, by: 30) {
            let p = OKLCH(l: 0.7, c: 0.37, h: h).displayP3Components()
            for v in [p.red, p.green, p.blue] {
                XCTAssertGreaterThanOrEqual(v, 0)
                XCTAssertLessThanOrEqual(v, 1)
            }
        }
    }

    func testHueWrapsAt360() {
        let a = OKLCH(l: 0.72, c: 0.20, h: 0).displayP3Components()
        let b = OKLCH(l: 0.72, c: 0.20, h: 360).displayP3Components()
        XCTAssertEqual(a.red, b.red, accuracy: 1e-12)
        XCTAssertEqual(a.green, b.green, accuracy: 1e-12)
        XCTAssertEqual(a.blue, b.blue, accuracy: 1e-12)
    }

    func testEquatable() {
        XCTAssertEqual(OKLCH(l: 0.6, c: 0.1, h: 200), OKLCH(l: 0.6, c: 0.1, h: 200))
        XCTAssertNotEqual(OKLCH(l: 0.6, c: 0.1, h: 200), OKLCH(l: 0.6, c: 0.1, h: 201))
    }
}
