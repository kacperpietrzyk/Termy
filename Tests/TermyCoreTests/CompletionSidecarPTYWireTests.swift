import XCTest
@testable import TermyCore

final class CompletionSidecarPTYWireTests: XCTestCase {
    func test_complete_basicLine() {
        let q = "__termy_complete Z2l0IHA= 5 /tmp 7\n"
        let wire = CompletionSidecar.ptyWireString(forQLine: q)
        XCTAssertNotNil(wire)
        XCTAssertEqual(wire, "\u{0015}git p\u{001B}q")
    }

    func test_complete_movesCursorLeftBeforeTrigger() {
        let q = "__termy_complete Z2l0IHA= 3 /tmp 1\n"
        let wire = CompletionSidecar.ptyWireString(forQLine: q)!
        XCTAssertEqual(wire, "\u{0015}git p\u{001B}[D\u{001B}[D\u{001B}q")
    }

    func test_complete_cursorUsesScalarsNotGraphemes() {
        // "é" as e + combining acute = 2 scalars but 1 grapheme, then "x" → 3 scalars,
        // 2 graphemes. zsh CURSOR=2 means "after é, before x". The left-move count must
        // be 3 - 2 = 1 (scalars); the old grapheme math gave 2 - 2 = 0 → wrong column.
        let buffer = "e\u{0301}x"
        let b64 = Data(buffer.utf8).base64EncodedString()
        let q = "__termy_complete \(b64) 2 /tmp 1\n"
        let wire = CompletionSidecar.ptyWireString(forQLine: q)!
        let leftMoves = wire.components(separatedBy: "\u{001B}[D").count - 1
        XCTAssertEqual(leftMoves, 1)
    }

    func test_cd_basic() {
        let q = "__termy_cd /var/log\n"
        XCTAssertEqual(
            CompletionSidecar.ptyWireString(forQLine: q),
            "__termy_cd_target=/var/log; _termy_cd\n"
        )
    }

    func test_complete_missingParts_returnsNil() {
        XCTAssertNil(CompletionSidecar.ptyWireString(forQLine: "__termy_complete ab cd\n"))
        XCTAssertNil(CompletionSidecar.ptyWireString(forQLine: "__termy_complete\n"))
    }

    func test_unknownPrefix_returnsNil() {
        XCTAssertNil(CompletionSidecar.ptyWireString(forQLine: "__random_garbage 1 2 3\n"))
        XCTAssertNil(CompletionSidecar.ptyWireString(forQLine: ""))
    }

    func test_lineWithoutTrailingNewline_stillParsed() {
        // Defensive: the transport always appends \n, but the function shouldn't crash without it.
        let q = "__termy_cd /tmp"
        XCTAssertEqual(
            CompletionSidecar.ptyWireString(forQLine: q),
            "__termy_cd_target=/tmp; _termy_cd\n"
        )
    }
}
