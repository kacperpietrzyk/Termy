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

    // GAP 1: alt-screen accumulation bug. When a command (e.g. `claude`) enters
    // alt-screen and exits (like `claude` launching its TUI picker), accumulation
    // must be skipped while in alt-screen so pendingBlockRange stays nil — the
    // command produced no main-buffer output, so the snapshot must be nil.
    //
    // Pre-fix: accumulateBlockRange() runs unconditionally → alt ranges accumulate
    //          → captureBlockSnapshotANSI() returns non-nil (blank row padding).
    // Post-fix: accumulation gated to non-alt slices → stays nil → returns nil.
    func testAltScreenCommandProducesCleanSnapshot() {
        let view = makeView()
        feed(view, "prompt ❯ claude\r\n")
        view.armBlockCapture()                                  // claude starts
        feed(view, "\u{1B}[?1049h\u{1B}[2J2 new MCP servers\r\n[x] obsidian")
        feed(view, "\u{1B}[78")                                 // split CSI inside alt
        feed(view, "G\u{1B}[?1049l")                            // alt exit
        // A pure alt-screen episode produces no main-buffer output.
        // The snapshot must be nil (pendingBlockRange must remain nil).
        XCTAssertNil(view.captureBlockSnapshotANSI(),
            "alt-screen episode accumulated into pendingBlockRange — snapshot should be nil")
    }
}
#endif
