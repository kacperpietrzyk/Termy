#if canImport(AppKit)
import AppKit
import XCTest
import SwiftTerm
import TermyCore
@testable import Termy

@MainActor
final class BufferSnapshotProbeTests: XCTestCase {

    private func makeView() -> TappedLocalProcessTerminalView {
        TappedLocalProcessTerminalView(frame: CGRect(x: 0, y: 0, width: 800, height: 480))
    }
    private func feed(_ view: TappedLocalProcessTerminalView, _ s: String) {
        view.dataReceived(slice: Array(s.utf8)[...])
    }

    func testReadsViewportRowAsTrimmedText() {
        let view = makeView()
        feed(view, "hello world\r\n")
        let line = BufferSnapshot.lineText(view.getTerminal(), viewportRow: 0)
        XCTAssertEqual(line, "hello world")
    }
}
#endif
