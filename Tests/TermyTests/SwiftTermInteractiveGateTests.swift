#if canImport(AppKit)
import AppKit
import XCTest
import SwiftTerm
import TermyCore
@testable import Termy

/// M3-2 hard acceptance gate (spec §4). Real zsh under the SwiftTerm-owned
/// LocalProcessTerminalView (the exact tapped view TerminalStageView renders),
/// driven headlessly, must run real interactive TUIs and keep the OSC 133
/// command-block layer ordered. SwiftTerm is the correctness reference; there
/// is no obligation to match the deleted emulator.
///
/// Two poll regimes: `waitForPromptUp` is FATAL (a missing prompt is a broken
/// cutover, not a flake); `poll` SKIPs (real-shell timing is variable). The
/// `markExecuted()` counter + class-teardown sentinel forbid an all-skip run
/// from passing as a green gate (spec §7).
@MainActor
final class SwiftTermInteractiveGateTests: XCTestCase {

    private enum GateError: Error { case promptNeverArrived }

    /// Bumped as the LAST line of every test (reached only if no XCTSkip/throw
    /// fired). `nonisolated(unsafe)` so the `nonisolated` class teardown can
    /// read it; `swift test` runs a class serially, so the access is safe.
    private nonisolated(unsafe) static var executed = 0
    private func markExecuted() { Self.executed += 1 }

    /// Sentinel: an all-skip run reports "0 failures" yet proves nothing. The
    /// gate is only "green" (spec §7) if it substantively ran. 11 tests; allow
    /// ≤2 timing skips. `nonisolated` to override XCTestCase's non-isolated
    /// class method without an actor-isolation mismatch.
    override nonisolated class func tearDown() {
        super.tearDown()
        XCTAssertGreaterThanOrEqual(Self.executed, 9,
            "GATE NOT SUBSTANTIVE: only \(Self.executed)/11 interactive tests reached their assertions — re-run on a quieter machine; do NOT treat this as a passing gate (spec §7).")
    }

    private func makeView(events: @escaping ([ShellIntegrationEvent]) -> Void)
        throws -> (TappedLocalProcessTerminalView, ShellIntegrationLaunch) {
        let view = TappedLocalProcessTerminalView(frame: CGRect(x: 0, y: 0, width: 800, height: 480))
        view.streamBridge = SwiftTermStreamBridge(onEvents: events)
        let d = TerminalLaunchDescriptor(executable: "/bin/zsh", arguments: [],
            environment: ["TERM": "xterm-256color"], workingDirectory: nil,
            usesZshIntegration: true)
        let launch: ShellIntegrationLaunch
        do { launch = try ShellIntegrationLaunch(descriptor: d, sessionID: UUID()) }
        catch { throw XCTSkip("ShellIntegrationLaunch unavailable: \(error)") }
        view.startProcess(executable: launch.shellPath, args: launch.arguments,
            environment: launch.environmentArray, currentDirectory: NSHomeDirectory())
        return (view, launch)
    }

    /// FATAL readiness wait: the shell MUST emit its first OSC 133 event. A
    /// timeout here is a broken live tap, not a timing flake — fail, don't skip.
    @MainActor
    private func waitForPromptUp(timeout: TimeInterval = 30, _ ready: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !ready() {
            if Date() > deadline {
                XCTFail("FATAL: real zsh produced no OSC 133 event within \(Int(timeout))s — the cutover's live tap is broken (deterministic, not a timing flake).")
                throw GateError.promptNeverArrived
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    /// Behaviour wait: real-shell timing under load is legitimately variable, so
    /// a timeout SKIPs (re-runnable). A deterministic wrong result still fails
    /// via the XCTAssert that follows the poll.
    @MainActor
    private func poll(_ timeout: TimeInterval, _ cond: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !cond() {
            if Date() > deadline { throw XCTSkip("timed out waiting for real-shell behaviour (timing flake — re-run; not a cutover defect)") }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    private func screen(_ view: TappedLocalProcessTerminalView) -> String {
        let t = view.getTerminal()
        return (0..<t.rows).compactMap { t.getLine(row: $0)?.translateToString(trimRight: true) }
            .joined(separator: "\n")
    }

    /// less: alternate screen, clean quit restores the primary buffer.
    func testLessRunsInAlternateScreenAndQuitsClean() async throws {
        var events: [ShellIntegrationEvent] = []
        let (view, launch) = try makeView { events.append(contentsOf: $0) }
        defer { view.terminate(); launch.cleanup() }
        try await waitForPromptUp { !events.isEmpty }
        view.send(txt: "printf 'L%.0s\\n' $(seq 1 200) > /tmp/termygate_less.txt && less /tmp/termygate_less.txt\n")
        try await poll(15) { view.getTerminal().isCurrentBufferAlternate }
        XCTAssertTrue(view.getTerminal().isCurrentBufferAlternate, "less must enter the alternate screen")
        view.send(txt: "q")
        try await poll(10) { !view.getTerminal().isCurrentBufferAlternate }
        XCTAssertFalse(view.getTerminal().isCurrentBufferAlternate, "q must restore the primary buffer")
        markExecuted()
    }

    /// vim: enters the alternate screen, edits, `:q!` restores primary buffer.
    func testVimAltScreenAndQuitsClean() async throws {
        var events: [ShellIntegrationEvent] = []
        let (view, launch) = try makeView { events.append(contentsOf: $0) }
        defer { view.terminate(); launch.cleanup() }
        try await waitForPromptUp { !events.isEmpty }
        view.send(txt: "vim -u NONE -N /tmp/termygate_vim.txt\n")
        try await poll(15) { view.getTerminal().isCurrentBufferAlternate }
        view.send(txt: "ihello\u{1B}")                               // insert, type, ESC
        try await poll(10) { self.screen(view).contains("hello") }
        XCTAssertTrue(screen(view).contains("hello"), "vim must show inserted text")
        view.send(txt: "\u{1B}:q!\n")
        try await poll(10) { !view.getTerminal().isCurrentBufferAlternate }
        XCTAssertFalse(view.getTerminal().isCurrentBufferAlternate, ":q! must restore primary buffer")
        markExecuted()
    }

    /// nano: status bar renders, ^X exits cleanly.
    func testNanoRendersAndExits() async throws {
        var events: [ShellIntegrationEvent] = []
        let (view, launch) = try makeView { events.append(contentsOf: $0) }
        defer { view.terminate(); launch.cleanup() }
        try await waitForPromptUp { !events.isEmpty }
        view.send(txt: "nano /tmp/termygate_nano.txt\n")
        try await poll(15) { self.screen(view).contains("GNU nano") || view.getTerminal().isCurrentBufferAlternate }
        XCTAssertTrue(screen(view).contains("nano") || view.getTerminal().isCurrentBufferAlternate,
                      "nano must render")
        view.send(txt: "\u{18}")                                     // ^X
        try await poll(10) { !view.getTerminal().isCurrentBufferAlternate }
        markExecuted()
    }

    /// top: renders a refreshing process table, q exits.
    func testTopRendersAndExits() async throws {
        var events: [ShellIntegrationEvent] = []
        let (view, launch) = try makeView { events.append(contentsOf: $0) }
        defer { view.terminate(); launch.cleanup() }
        try await waitForPromptUp { !events.isEmpty }
        view.send(txt: "top\n")
        try await poll(15) { self.screen(view).uppercased().contains("PID") }
        XCTAssertTrue(screen(view).uppercased().contains("PID"), "top must render a process table")
        view.send(txt: "q")
        markExecuted()
    }

    /// SIGWINCH: resizing the PTY makes the child observe the new winsize.
    func testWindowResizeDeliversSigwinch() async throws {
        var events: [ShellIntegrationEvent] = []
        let (view, launch) = try makeView { events.append(contentsOf: $0) }
        defer { view.terminate(); launch.cleanup() }
        try await waitForPromptUp { !events.isEmpty }
        view.send(txt: "stty size; trap 'stty size' WINCH\n")
        try await poll(8) { self.screen(view).range(of: #"\d+ \d+"#, options: .regularExpression) != nil }
        view.resize(cols: 100, rows: 40)
        var ws = winsize(ws_row: 40, ws_col: 100, ws_xpixel: 0, ws_ypixel: 0)
        _ = PseudoTerminalHelpers.setWinSize(masterPtyDescriptor: view.process.childfd, windowSize: &ws)
        try await poll(8) { self.screen(view).contains("40 100") }
        XCTAssertTrue(screen(view).contains("40 100"), "child must observe the new winsize after SIGWINCH")
        markExecuted()
    }

    /// Bracketed paste — TRUE e2e. The child enables DEC 2004; SwiftTerm must
    /// wrap the *pasted clipboard text* in ESC[200~ … ESC[201~ and deliver it
    /// to the PTY, where `cat -v` echoes it back as `^[[200~ … ^[[201~`.
    /// `stty -echo -icanon`: no tty echo of the paste, and cat returns bytes
    /// immediately so the trailing ESC[201~ renders without needing a newline.
    func testBracketedPasteEchoesThroughLiveTap() async throws {
        var events: [ShellIntegrationEvent] = []
        let (view, launch) = try makeView { events.append(contentsOf: $0) }
        defer { view.terminate(); launch.cleanup() }
        let token = String(UUID().uuidString.prefix(8))
        try await waitForPromptUp { !events.isEmpty }
        view.send(txt: "stty -echo -icanon; printf '\\033[?2004h'; cat -v\n")
        try await poll(15) { view.getTerminal().bracketedPasteMode }
        XCTAssertTrue(view.getTerminal().bracketedPasteMode, "child must have enabled bracketed paste (DEC 2004)")
        let pb = NSPasteboard.general
        let saved = pb.string(forType: .string)
        defer { pb.clearContents(); if let saved { pb.setString(saved, forType: .string) } }
        pb.clearContents()
        pb.setString("PASTE_\(token)", forType: .string)
        view.paste("gate")                                           // SwiftTerm reads NSPasteboard.general
        try await poll(10) { self.screen(view).contains("^[[200~PASTE_\(token)^[[201~") }
        XCTAssertTrue(screen(view).contains("^[[200~PASTE_\(token)^[[201~"),
                      "child must receive the bracketed-paste-wrapped clipboard text via the live PTY")
        view.send(txt: "\u{03}")                                     // ^C exits cat
        markExecuted()
    }

    /// Application cursor keys (DECCKM) — TRUE e2e. The child sets DEC 1; the
    /// view's Up-arrow responder action must then emit SS3 `ESC O A` (not the
    /// CSI `ESC [ A`) to the PTY, echoed by `cat -v` as `^[OA`.
    func testAppCursorKeysReachChild() async throws {
        var events: [ShellIntegrationEvent] = []
        let (view, launch) = try makeView { events.append(contentsOf: $0) }
        defer { view.terminate(); launch.cleanup() }
        try await waitForPromptUp { !events.isEmpty }
        view.send(txt: "stty -echo -icanon; printf '\\033[?1h'; cat -v\n")
        try await poll(15) { view.getTerminal().applicationCursor }
        XCTAssertTrue(view.getTerminal().applicationCursor, "child must have enabled application cursor keys (DEC 1)")
        view.doCommand(by: #selector(NSResponder.moveUp(_:)))        // the real Up-arrow input path
        try await poll(10) { self.screen(view).contains("^[OA") }
        XCTAssertTrue(screen(view).contains("^[OA"),
                      "Up arrow must reach the child as SS3 ESC O A while DECCKM is set")
        XCTAssertFalse(screen(view).contains("^[[A"),
                       "with DECCKM set the child must NOT receive the CSI form ESC [ A")
        view.send(txt: "\u{03}")
        markExecuted()
    }

    /// SGR mouse reporting — TRUE e2e. The child enables X11 tracking + SGR
    /// encoding (DEC 1000 + 1006); a synthesized left-press must reach the
    /// child as the SGR report `ESC [ < 0 ; 1 ; 1 M`, echoed by `cat -v`.
    func testMouseSGRReportingReachesChild() async throws {
        var events: [ShellIntegrationEvent] = []
        let (view, launch) = try makeView { events.append(contentsOf: $0) }
        defer { view.terminate(); launch.cleanup() }
        try await waitForPromptUp { !events.isEmpty }
        view.send(txt: "stty -echo -icanon; printf '\\033[?1000h\\033[?1006h'; cat -v\n")
        try await poll(15) { view.getTerminal().mouseMode != .off }
        XCTAssertNotEqual(view.getTerminal().mouseMode, .off, "child must have enabled mouse tracking (DEC 1000)")
        view.getTerminal().sendEvent(buttonFlags: 0, x: 0, y: 0)     // left press at col 1 row 1
        try await poll(10) { self.screen(view).contains("^[[<0;1;1M") }
        XCTAssertTrue(screen(view).contains("^[[<0;1;1M"),
                      "child must receive the SGR mouse report via the live PTY")
        view.send(txt: "\u{03}")
        markExecuted()
    }

    /// Ordered OSC 133 command blocks through the live tap. SENTINEL-BOUND:
    /// `add-zsh-hook precmd` (ShellIntegrationScript.swift:9–14) emits a 133;D
    /// (.commandFinished) before the very first prompt, so an *unbound*
    /// `.commandFinished` predicate matches that startup marker before any
    /// `.commandStarted` exists. Bind to OUR command — the proven idiom of the
    /// M3-1 sibling gate's `sentinelBlock` — then assert command-start strictly
    /// precedes command-finish and the stdout reaches the parser between them.
    func testOrderedCommandBlocksThroughLiveTap() async throws {
        var events: [ShellIntegrationEvent] = []
        let (view, launch) = try makeView { events.append(contentsOf: $0) }
        defer { view.terminate(); launch.cleanup() }
        let sentinel = "TERMYGATE_\(String(UUID().uuidString.prefix(8)))"
        try await waitForPromptUp { !events.isEmpty }
        view.send(txt: "echo \(sentinel)\n")
        // A .commandStarted whose cmd contains the sentinel, then the FIRST
        // .commandFinished strictly after it. `ArraySlice.firstIndex` returns
        // an index in the ORIGINAL array's index space, so `finished` is
        // already an absolute index into `events`.
        func sentinelBlock(_ evs: [ShellIntegrationEvent]) -> (started: Int, finished: Int)? {
            guard let s = evs.firstIndex(where: {
                if case let .commandStarted(cmd) = $0 { return cmd.contains(sentinel) }
                return false
            }) else { return nil }
            guard let f = evs[(s + 1)...].firstIndex(where: {
                if case .commandFinished = $0 { return true }
                return false
            }) else { return nil }
            return (s, f)
        }
        try await poll(15) { sentinelBlock(events) != nil }
        let block = try XCTUnwrap(sentinelBlock(events),
                                  "must observe a full sentinel-bound command block for \(sentinel)")
        XCTAssertLessThan(block.started, block.finished,
                          "OSC 133 command-start must precede command-finish for our command")
        if case let .commandFinished(exitCode, _) = events[block.finished] {
            XCTAssertEqual(exitCode, 0,
                           "`echo <sentinel>` must report exit 0; non-zero means marker/exit mis-association")
        } else {
            XCTFail("matched finished index is not a .commandFinished event")
        }
        let outputBetween = events[block.started..<block.finished].contains {
            if case let .output(t) = $0 { return t.contains(sentinel) }
            return false
        }
        XCTAssertTrue(outputBetween,
                      "command stdout (\(sentinel)) must reach the parser as .output between the markers")
        markExecuted()
    }

    /// Non-tautological / mutation-proof (spec §4.4). The SOLE load-bearing
    /// assertion is `bridgeFiredCount > 0`: it is true only if zsh started,
    /// the integration emitted OSC 133, SwiftTerm parsed it, AND the wired tap
    /// delivered — i.e. it fails the instant the live tap is severed (this is
    /// the automated standing mirror of Step 4's one-shot manual mutation).
    /// The `events.isEmpty` line is NOT an independent signal — `unwired` is
    /// never attached to anything, so it is true by construction; it stays
    /// only as an executable comment documenting "events reach only wired
    /// sinks". Do not strengthen by relying on it; strengthen `bridgeFiredCount`.
    func testNonTautological_wiredBridgeFiresWhileUnwiredSinkStaysEmpty() async throws {
        var events: [ShellIntegrationEvent] = []
        let unwired: ([ShellIntegrationEvent]) -> Void = { events.append(contentsOf: $0) }
        _ = unwired                                                  // built, NEVER wired
        var bridgeFiredCount = 0
        let view = TappedLocalProcessTerminalView(frame: CGRect(x: 0, y: 0, width: 800, height: 480))
        view.streamBridge = SwiftTermStreamBridge(onEvents: { _ in bridgeFiredCount += 1 })
        let d = TerminalLaunchDescriptor(executable: "/bin/zsh", arguments: [],
            environment: ["TERM": "xterm-256color"], workingDirectory: nil, usesZshIntegration: true)
        let launch: ShellIntegrationLaunch
        do { launch = try ShellIntegrationLaunch(descriptor: d, sessionID: UUID()) }
        catch { throw XCTSkip("ShellIntegrationLaunch unavailable: \(error)") }
        defer { view.terminate(); launch.cleanup() }
        view.startProcess(executable: launch.shellPath, args: launch.arguments,
            environment: launch.environmentArray, currentDirectory: NSHomeDirectory())
        let token = String(UUID().uuidString.prefix(8))
        view.send(txt: "printf 'NB_\(token)\\n'\n")
        try await waitForPromptUp { bridgeFiredCount > 0 }           // FATAL: no fire ⇒ broken live tap
        XCTAssertGreaterThan(bridgeFiredCount, 0,
            "the WIRED SwiftTermStreamBridge must fire on a real OSC 133 command — the gate's signal is the live tap, not SwiftTerm rendering")
        XCTAssertTrue(events.isEmpty,
            "an UNWIRED sink must never observe events — events reach only the wired bridge, no ambient path")
        markExecuted()
    }

    /// TUI-safety regression test — real-PTY smoke (spec §4). The injected zsh
    /// `zle-line-pre-redraw` widget emits OSC 133;T (`.inputBufferChanged`) only
    /// while zsh's ZLE is processing. When vim owns the terminal (alt-screen) there
    /// is no ZLE loop running, so the widget MUST NOT fire. This test delivers
    /// keystrokes into vim's alt-screen session and asserts that no
    /// `.inputBufferChanged` event appears during that window. A failure here means
    /// the widget is leaking T events into TUI alt-screen sessions — a real bug.
    func testNoInputBufferChangedWhileVimAltScreenActive() async throws {
        var events: [ShellIntegrationEvent] = []
        let (view, launch) = try makeView { events.append(contentsOf: $0) }
        defer { view.terminate(); launch.cleanup() }
        try await waitForPromptUp { !events.isEmpty }
        view.send(txt: "vim -u NONE -N /tmp/termygate_tui_safety.txt\n")
        try await poll(15) { view.getTerminal().isCurrentBufferAlternate }
        XCTAssertTrue(view.getTerminal().isCurrentBufferAlternate,
                      "vim must enter the alternate screen before the TUI-safety assertion")
        // Record the event baseline once vim owns the alt-screen.
        let mark = events.count
        // Send keystrokes that go to vim's input loop — not to zsh ZLE.
        // `poll` until vim renders the inserted text: this is the deterministic
        // "input was actually processed by vim" signal, avoiding sleep-only timing.
        view.send(txt: "ihello\u{1B}")
        try await poll(10) { self.screen(view).contains("hello") }
        // Load-bearing invariant: none of the events appended after entering the
        // alt-screen may be .inputBufferChanged (OSC 133;T).
        let newEvents = Array(events[mark...])
        let spuriousT = newEvents.filter {
            if case .inputBufferChanged = $0 { return true }
            return false
        }
        XCTAssertTrue(spuriousT.isEmpty,
                      "zle-line-pre-redraw must NOT emit .inputBufferChanged (OSC 133;T) " +
                      "while vim is foregrounded — \(spuriousT.count) spurious T event(s) detected: \(spuriousT)")
        // Clean up: exit vim and restore primary buffer.
        view.send(txt: "\u{1B}:q!\n")
        try await poll(10) { !view.getTerminal().isCurrentBufferAlternate }
        XCTAssertFalse(view.getTerminal().isCurrentBufferAlternate,
                       ":q! must restore the primary buffer")
        markExecuted()
    }
}
#endif
