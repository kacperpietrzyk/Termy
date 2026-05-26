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
