import XCTest
import AppKit
@testable import Termy

final class TypographyTests: XCTestCase {
    // The fallback contract: an unavailable face resolves to nil so callers
    // drop to the system font. Deterministic regardless of whether Geist is
    // registered in the test process (it is not — `swift test` has no bundle).
    func testUnavailableFaceResolvesNil() {
        XCTAssertNil(Typography.availablePostScriptName("Geist-DefinitelyNotAFace"))
    }

    func testSystemFaceAlwaysResolves() {
        XCTAssertNotNil(Typography.availablePostScriptName(".AppleSystemUIFont")
            ?? Typography.availablePostScriptName("Helvetica"))
    }
}
