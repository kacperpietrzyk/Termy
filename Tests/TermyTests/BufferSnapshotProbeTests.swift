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

    // Reproduces screenshot #6: run `claude`, it enters alt-screen and paints an
    // MCP picker (with CSI cursor moves incl. a split `ESC[78G`), then exits. The
    // MAIN buffer must show ONLY the clean prompt+command region — no `78`, no
    // picker text — because picker repaints happened in the ALT buffer.
    func testMainBufferSnapshotIsResidueFreeAfterClaudeExit() {
        let view = makeView()
        // prompt + command on the main buffer
        feed(view, "kacper@mac ~/threatforge ❯ claude\r\n")
        // claude enters alt-screen and paints a picker with cursor positioning;
        // include a CSI split across slices (the `78` culprit) entirely inside alt.
        feed(view, "\u{1B}[?1049h\u{1B}[2J")
        feed(view, "2 new MCP servers found\r\n[x] obsidian\r\n[x] code-review-graph")
        feed(view, "\u{1B}[78")        // split CSI mid-slice (the `78` fragment)
        feed(view, "G\u{1B}[1;1H")
        XCTAssertTrue(view.getTerminal().isCurrentBufferAlternate)
        // claude exits → main buffer restored
        feed(view, "\u{1B}[?1049l")
        XCTAssertFalse(view.getTerminal().isCurrentBufferAlternate)

        // Read the whole main viewport and assert it is residue-free.
        let term = view.getTerminal()
        var dump = ""
        for row in 0..<term.rows {
            if let t = BufferSnapshot.lineText(term, viewportRow: row) { dump += t + "\n" }
        }
        XCTAssertTrue(dump.contains("claude"), "main buffer should retain the command")
        XCTAssertFalse(dump.contains("78"), "main-buffer snapshot leaked `78`")
        XCTAssertFalse(dump.contains("obsidian"), "alt-screen picker leaked into main buffer")
        XCTAssertFalse(dump.contains("code-review-graph"), "alt-screen picker leaked")
    }
}
#endif
