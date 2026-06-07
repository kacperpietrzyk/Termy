import XCTest
@testable import Termy

/// Poziom-2b: a finished, successful command block must show NO footer chrome
/// (clean like Warp); only a non-zero exit surfaces `EXIT n`, and an unfinished
/// command shows `RUNNING`.
final class BlockFooterStateTests: XCTestCase {
    func testSuccessIsClean() {
        XCTAssertEqual(BlockFooterState(exitCode: 0), .none)
    }

    func testRunningWhenNoExitYet() {
        XCTAssertEqual(BlockFooterState(exitCode: nil), .running)
    }

    func testNonZeroExitSurfacesCode() {
        XCTAssertEqual(BlockFooterState(exitCode: 1), .error(code: 1))
        XCTAssertEqual(BlockFooterState(exitCode: 130), .error(code: 130))
    }
}
