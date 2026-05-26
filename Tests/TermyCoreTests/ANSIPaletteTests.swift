import XCTest
@testable import TermyCore

final class ANSIPaletteTests: XCTestCase {
    func testBaseColorsBlackAndRed() {
        XCTAssertEqual(ANSIPalette.rgb(forIndex: 0), RGB8(0, 0, 0))
        XCTAssertEqual(ANSIPalette.rgb(forIndex: 1), RGB8(205, 0, 0))
    }
    func testBrightWhiteIsIndex15() {
        XCTAssertEqual(ANSIPalette.rgb(forIndex: 15), RGB8(255, 255, 255))
    }
    func testCubeStartIndex16IsBlack() {
        XCTAssertEqual(ANSIPalette.rgb(forIndex: 16), RGB8(0, 0, 0))
    }
    func testCubeWhiteIndex231() {
        XCTAssertEqual(ANSIPalette.rgb(forIndex: 231), RGB8(255, 255, 255))
    }
    func testCubeMidColor() {
        XCTAssertEqual(ANSIPalette.rgb(forIndex: 196), RGB8(255, 0, 0))
    }
    func testGrayscaleRampStartIndex232() {
        XCTAssertEqual(ANSIPalette.rgb(forIndex: 232), RGB8(8, 8, 8))
    }
    func testGrayscaleRampEndIndex255() {
        XCTAssertEqual(ANSIPalette.rgb(forIndex: 255), RGB8(238, 238, 238))
    }
    func testOutOfRangeClampsToEdges() {
        XCTAssertEqual(ANSIPalette.rgb(forIndex: -5), ANSIPalette.rgb(forIndex: 0))
        XCTAssertEqual(ANSIPalette.rgb(forIndex: 999), ANSIPalette.rgb(forIndex: 255))
    }
    func testResolveMapsRGBPassThroughAndIndexed() {
        XCTAssertEqual(ANSIPalette.resolve(.rgb(10, 20, 30)), RGB8(10, 20, 30))
        XCTAssertEqual(ANSIPalette.resolve(.indexed(1)), RGB8(205, 0, 0))
    }
}
