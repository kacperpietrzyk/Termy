#if canImport(AppKit)
import AppKit
import XCTest
import SwiftTerm
import TermyCore
@testable import Termy

/// Slice-1 end-to-end gate: drives the REAL view→bridge→store→render pipeline and
/// proves a finished command block is sourced from the SwiftTerm buffer snapshot —
/// residue-free (kills #6) and color-preserving.
@MainActor
final class Slice1ResidueGateTests: XCTestCase {

    private func wire() -> (TermyStore, TappedLocalProcessTerminalView, UUID) {
        let store = TermyStore(startInitialPTY: false)
        let id = store.selectedSessionID!
        let view = TappedLocalProcessTerminalView(frame: CGRect(x: 0, y: 0, width: 800, height: 480))
        view.streamBridge = SwiftTermStreamBridge { events in store.ingestShellIntegrationEvents(events, for: id) }
        store.registerTerminalBlockArmHandler({ view.armBlockCapture() }, for: id)
        store.registerTerminalBlockSnapshotProvider({ view.captureBlockSnapshotANSI() }, for: id)
        return (store, view, id)
    }
    private func feed(_ v: TappedLocalProcessTerminalView, _ s: String) {
        v.dataReceived(slice: Array(s.utf8)[...])
    }
    private func renderedOutput(_ store: TermyStore, command: String) -> String? {
        store.renderedTerminalCommandBlocks().first(where: { $0.command == command })?
            .outputLines.map(\.text).joined()
    }

    func testNormalCommandBlockIsColoredAndResidueFree() {
        let (store, view, _) = wire()
        feed(view, "\u{1B}]133;C;cmd=git log\u{07}")
        feed(view, "\u{1B}[33m9a14613b\u{1B}[0m fix(appsync)\r\n")   // yellow hash + default text
        feed(view, "\u{1B}]133;D;exit=0\u{07}")
        let out = renderedOutput(store, command: "git log") ?? ""
        XCTAssertTrue(out.contains("9a14613b"), "block output present")
        // BufferSnapshot.sgr(for:) encodes ESC[33m (ansi256 code 3) as ESC[38;5;3m.
        // Also accept trueColor form (38;2;) as a valid color-preserving encoding.
        XCTAssertTrue(out.contains("\u{1B}[38;5;3m") || out.contains("\u{1B}[38;2;"),
                      "yellow color preserved as SGR in the rendered snapshot — got: \(out.debugDescription)")
    }

    func testClaudeAltScreenBlockIsClean() {
        let (store, view, _) = wire()
        feed(view, "\u{1B}]133;C;cmd=claude\u{07}")
        // Verify alt-screen state transitions are real (not silently bypassed)
        feed(view, "\u{1B}[?1049h\u{1B}[2J2 new MCP servers\r\n[x] obsidian")
        XCTAssertTrue(view.getTerminal().isCurrentBufferAlternate, "must be in alt-screen after ?1049h")
        feed(view, "\u{1B}[78")                       // split CSI inside alt (the `78` culprit)
        feed(view, "G\u{1B}[?1049l")                  // alt exit
        XCTAssertFalse(view.getTerminal().isCurrentBufferAlternate, "must have exited alt-screen after ?1049l")
        feed(view, "\u{1B}]133;D;exit=0\u{07}")
        let out = renderedOutput(store, command: "claude") ?? "<<no block>>"
        XCTAssertNotEqual(out, "<<no block>>", "claude block should exist")
        XCTAssertFalse(out.contains("78"), "no `78` residue in the claude block")
        XCTAssertFalse(out.contains("obsidian"), "no alt-screen picker leak in the claude block")
    }
}
#endif
