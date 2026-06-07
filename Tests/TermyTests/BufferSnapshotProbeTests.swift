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

    // A command's footprint, armed with clearUpdateRange() at "command start",
    // is exactly its output rows (no empty-viewport tail) and re-reads
    // IDENTICALLY after lots more output scrolls it down — proving scroll-
    // invariant indices are stable for real content.
    func testScrollInvariantRangeIsStableAcrossScrolling() {
        let view = makeView()
        let term = view.getTerminal()
        feed(view, "boot\r\n")
        term.clearUpdateRange()                          // arm: "command start"
        feed(view, "MARKER-START\r\nline-A\r\nline-B\r\nline-C\r\n")
        guard let range = term.getScrollInvariantUpdateRange() else {
            return XCTFail("no scroll-invariant update range after output")
        }
        let before = BufferSnapshot.lines(term, scrollInvariantRows: range.startY...range.endY)
            .filter { !$0.isEmpty }
        XCTAssertEqual(before, ["MARKER-START", "line-A", "line-B", "line-C"],
                       "armed range should be exactly the command's output rows")

        for i in 0..<200 { feed(view, "filler-\(i)\r\n") }

        let after = BufferSnapshot.lines(term, scrollInvariantRows: range.startY...range.endY)
            .filter { !$0.isEmpty }
        XCTAssertEqual(before, after, "scroll-invariant indices drifted after scrolling")
    }

    // The real reason scroll-invariant anchoring matters: a command whose output
    // EXCEEDS the viewport pushes its top into scrollback. We must still recover
    // the FULL output (incl. scrolled-off rows) at finish via public API.
    func testRecoversFullOutputThatExceededViewport() {
        let view = makeView()
        let term = view.getTerminal()
        feed(view, "boot\r\n")
        term.clearUpdateRange()                          // arm: "command start"
        for i in 0..<100 { feed(view, "out-\(i)\r\n") }  // far more than the ~30-row viewport
        guard let range = term.getScrollInvariantUpdateRange() else {
            return XCTFail("no scroll-invariant update range")
        }
        let captured = BufferSnapshot.lines(term, scrollInvariantRows: range.startY...range.endY)
            .filter { !$0.isEmpty }
        XCTAssertEqual(captured, (0..<100).map { "out-\($0)" },
                       "must recover all 100 output lines incl. those scrolled into scrollback")
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

    // GAP 2: coordinate consistency between getScrollInvariantUpdateRange() and
    // getScrollInvariantLine(_:) under scrollback eviction (linesTop > 0).
    // Forces eviction by printing far more lines than scrollback capacity, then
    // verifies the range's rows resolve to the correct content via BufferSnapshot.lines.
    func testRangeAndLineAgreeUnderScrollbackEviction() {
        let view = makeView()                       // BufferSnapshotProbeTests has makeView()/feed()
        let term = view.getTerminal()
        term.changeScrollback(20)                   // small scrollback so eviction happens
        // Print a unique marker, then far more lines than scrollback+viewport so
        // the marker is evicted-pressure / scrolled well above the viewport but
        // still within the 20-line scrollback window... actually print the marker
        // LAST-but-not-visible: print filler, then marker, then more filler that
        // pushes marker above the viewport but keeps it within scrollback.
        for i in 0..<40 { feed(view, "pre-\(i)\r\n") }     // force linesTop > 0
        term.clearUpdateRange()
        feed(view, "UNIQUE-MARKER\r\n")
        guard let r = term.getScrollInvariantUpdateRange() else { return XCTFail("no range") }
        let captured = BufferSnapshot.lines(term, scrollInvariantRows: r.startY...r.endY).filter { !$0.isEmpty }
        XCTAssertTrue(captured.contains("UNIQUE-MARKER"),
                      "range↔line coords disagree under eviction (linesTop>0): got \(captured)")
    }

    func testAnsiStringReencodesColorRunsRoundTrippable() {
        let cells: [BufferSnapshot.Cell] = [
            .init(character: "A", fg: .defaultColor),
            .init(character: "B", fg: .defaultColor),
            .init(character: "C", fg: .ansi256(code: 3)),
            .init(character: "D", fg: .ansi256(code: 3)),
        ]
        let line = BufferSnapshot.ansiString(forCells: [cells])
        XCTAssertTrue(line.contains("AB"), "default run text present")
        XCTAssertTrue(line.contains("\u{1B}[38;5;3m"), "256-color SGR for the yellow run")
        XCTAssertTrue(line.contains("CD"), "colored run text present")
        XCTAssertFalse(line.contains("\u{1B}[38;5;3mAB"), "default run must not be colored")
    }

    func testCapturesForegroundColorPerCell() {
        let view = makeView()
        let term = view.getTerminal()
        // "AB" default, "CD" in ANSI yellow (SGR 33), back to default.
        feed(view, "AB\u{1B}[33mCD\u{1B}[0m\r\n")
        let cells = BufferSnapshot.coloredCells(term, viewportRow: 0)
        XCTAssertGreaterThanOrEqual(cells.count, 4)
        // The 'A' (default) and 'C' (yellow) foregrounds must differ.
        let a = cells.first { $0.character == "A" }
        let c = cells.first { $0.character == "C" }
        XCTAssertNotNil(a); XCTAssertNotNil(c)
        XCTAssertNotEqual(a!.fg, c!.fg, "yellow cell should differ from default cell")
    }
}
#endif
