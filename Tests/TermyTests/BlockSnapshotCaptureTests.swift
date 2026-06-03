#if canImport(AppKit)
import AppKit
import XCTest
import SwiftTerm
import TermyCore
@testable import Termy

@MainActor
final class BlockSnapshotCaptureTests: XCTestCase {
    private func makeView() -> TappedLocalProcessTerminalView {
        TappedLocalProcessTerminalView(frame: CGRect(x: 0, y: 0, width: 800, height: 480))
    }
    private func feed(_ v: TappedLocalProcessTerminalView, _ s: String) {
        v.dataReceived(slice: Array(s.utf8)[...])
    }

    func testCapturesArmedCommandOutputAsAnsiString() {
        let view = makeView()
        feed(view, "boot\r\n")
        view.armBlockCapture()                       // OSC 133 C equivalent
        feed(view, "out-1\r\nout-2\r\nout-3\r\n")
        let snap = view.captureBlockSnapshotANSI()    // OSC 133 D equivalent
        XCTAssertNotNil(snap)
        XCTAssertTrue(snap!.contains("out-1"))
        XCTAssertTrue(snap!.contains("out-3"))
        XCTAssertFalse(snap!.contains("boot"), "pre-arm content must not be in the snapshot")
    }
}
#endif
