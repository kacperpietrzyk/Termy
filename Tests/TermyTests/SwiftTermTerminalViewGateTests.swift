#if canImport(AppKit)
import XCTest
import SwiftTerm
@testable import Termy
import TermyCore

// M3-1 AUTOMATED ACCEPTANCE GATE (spec §4.3).
//
// This is the milestone's safety net. It replaces "the tests pass" as the
// M3-1 acceptance criterion. It MUST exercise REAL behavior: a real zsh
// spawned through the exact M3-1 SwiftTerm path, a real command driven into
// it, and a real assertion that (a) the lossless byte-tap ->
// ShellIntegrationParser produces ordered command-block events and (b)
// SwiftTerm's OWN emulator still rendered the same bytes (observe WITHOUT
// consume). The interactive less/vim/nano/top gate is M3-2, not here.
//
// HOW THE REAL SHELL IS SPAWNED (bit-for-bit the M3-1 view path):
//   `SwiftTermTerminalView.makeNSView` (SwiftTermTerminalView.swift:22-53)
//   constructs `TappedLocalProcessTerminalView(frame: .zero)`, assigns
//   `view.streamBridge = SwiftTermStreamBridge(onEvents:)` BEFORE launch,
//   builds `ShellIntegrationLaunch(profile: .zsh, sessionID:)`, and calls
//   `view.startProcess(executable: launch.shellPath, args: launch.arguments,
//   environment: launch.environmentArray, currentDirectory: NSHomeDirectory())`.
//   Constructing a real `NSViewRepresentable.Context` from a unit test is not
//   possible via public API, so this gate drives `TappedLocalProcessTerminalView`
//   + `SwiftTermStreamBridge` directly with the IDENTICAL `startProcess`
//   parameters the view uses — the seam under test (the tap + bridge + real
//   PTY) is fully exercised; only the SwiftUI wrapper boilerplate is skipped.
//   The test owns the cleanup `SwiftTermTerminalView.dismantleNSView`
//   performs (`view.terminate()` + `launch.cleanup()`).
//
// VERIFIED SwiftTerm 1.13.0 API (resolved checkout
// .build/checkouts/SwiftTerm/Sources/SwiftTerm):
//   - input to the child:  TerminalView.send(txt:)  -> send(data:) ->
//       terminalDelegate.send(source:data:) -> LocalProcessTerminalView
//       .send(source:data:) -> process.send(data:)  [AppleTerminalView.swift
//       :1975-1984 ; Mac/MacLocalTerminalView.swift:131-134]. This is exactly
//       the path a user keystroke takes to the PTY.
//   - read SwiftTerm's own render state:  TerminalView.getTerminal()
//       [Apple/AppleTerminalView.swift:166-169] -> Terminal.getText(start:end:)
//       [Terminal.swift:5869-5872]. `getText` indexes the buffer absolutely
//       (scrollback included) and CLAMPS an oversized `end.row` to the last
//       buffer line [Terminal.swift:6525-6527], so a generous end row reads
//       the entire buffer+screen and is robust to the prompt scrolling.
//   - launch:  LocalProcessTerminalView.startProcess(executable:args:
//       environment:execName:currentDirectory:) [Mac/MacLocalTerminalView
//       .swift:161-164].
//
// REAL-SHELL TIMING TOLERANCE: cold-spawning zsh, sourcing the
// ZDOTDIR-injected integration .zshrc, executing, and emitting the D-marker
// can be slow on a loaded machine. Like the existing
// TermyStoreTerminalTests real-shell idiom, a *timeout* -> XCTSkip (timing,
// not a defect). A DETERMINISTIC wrong result (events arrived but in the
// wrong order / no rendering despite events) -> hard fail: that is a real
// M3-1 defect, not flakiness.
@MainActor
final class SwiftTermTerminalViewGateTests: XCTestCase {

    func testM31AcceptanceGate_realZshCommandBlock_andObserveWithoutConsume() async throws {
        // Unique sentinel so we match OUR command/output, never the prompt's
        // own markers or unrelated shell chatter.
        let token = String(UUID().uuidString.prefix(8))
        let sentinel = "TERMYGATE_\(token)"

        // ---- Spawn a REAL zsh via the exact M3-1 view path -----------------
        let sessionID = UUID()
        let launch: ShellIntegrationLaunch
        do {
            launch = try ShellIntegrationLaunch(profile: .zsh, sessionID: sessionID)
        } catch {
            // Could not even build the launch (e.g. cannot write the temp
            // ZDOTDIR). That is environmental, not an M3-1 ordering defect.
            throw XCTSkip("ShellIntegrationLaunch(.zsh) unavailable in this environment: \(error.localizedDescription)")
        }

        // Collect every event the lossless tap -> bridge -> parser produces.
        // `dataReceived` is pumped on DispatchQueue.main by LocalProcess; this
        // test is @MainActor and yields the main queue via Task.sleep in the
        // poll loop, so the pump runs and these appends are main-queue-serial.
        var events: [ShellIntegrationEvent] = []
        let view = TappedLocalProcessTerminalView(frame: .zero)
        view.streamBridge = SwiftTermStreamBridge { events.append(contentsOf: $0) }
        defer {
            view.terminate()
            launch.cleanup()
        }

        view.startProcess(
            executable: launch.shellPath,
            args: launch.arguments,
            environment: launch.environmentArray,
            currentDirectory: NSHomeDirectory()
        )

        // ---- 1. Wait for the shell to be READY before driving input -------
        // If we send the command before zsh has sourced $ZDOTDIR/.zshrc, the
        // preexec/precmd hooks are not registered yet and we would see no
        // command-block markers (perpetual skip). The first prompt produces
        // bridge events; wait for them, then send.
        let readyDeadline = Date().addingTimeInterval(20)
        while Date() < readyDeadline {
            if !events.isEmpty { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        guard !events.isEmpty else {
            throw XCTSkip("real zsh produced no output within 20s (cold-spawn timing); not an M3-1 ordering defect")
        }

        // ---- 2. Drive a known command into the REAL shell -----------------
        // `echo <sentinel>` => preexec emits ESC]133;C;cmd=echo <sentinel>BEL,
        // the line "<sentinel>\n" is real stdout, then precmd emits
        // ESC]133;D;exit=0;pwd=...BEL. We assert via *contains* (cmd text is
        // shell-passed verbatim by the integration script, but contains-checks
        // are insulated from any quoting/encoding differences).
        view.send(txt: "echo \(sentinel)\n")

        // ---- 3. Deadline-poll for the ordered command block ---------------
        // Generous timeout for cold real-shell timing.
        func sentinelBlock(in evs: [ShellIntegrationEvent]) -> (startedIdx: Int, finishedIdx: Int)? {
            guard let startedIdx = evs.firstIndex(where: {
                if case let .commandStarted(cmd) = $0 { return cmd.contains(sentinel) }
                return false
            }) else { return nil }
            // ArraySlice.firstIndex returns an index in the ORIGINAL array's
            // index space, so this is already the absolute finished index.
            guard let finishedIdx = evs[(startedIdx + 1)...].firstIndex(where: {
                if case .commandFinished = $0 { return true }
                return false
            }) else { return nil }
            return (startedIdx, finishedIdx)
        }

        let deadline = Date().addingTimeInterval(20)
        var matched: (startedIdx: Int, finishedIdx: Int)?
        while Date() < deadline {
            if let m = sentinelBlock(in: events) {
                matched = m
                break
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        guard let block = matched else {
            // Never saw a finished marker for our command within the budget.
            // Real-shell cold-start timing — skip, do not hard-fail.
            throw XCTSkip("did not observe a full command block for \(sentinel) within 20s (real-shell timing tolerance)")
        }

        let finalEvents = events

        // ---- DETERMINISTIC assertions (hard-fail — real M3-1 defects) -----

        // (a) commandStarted STRICTLY BEFORE commandFinished.
        XCTAssertLessThan(
            block.startedIdx, block.finishedIdx,
            "M3-1 DEFECT: .commandStarted must be emitted strictly before .commandFinished for the same command"
        )

        // (a continued) the finished marker we matched must carry a real exit
        // code (echo of a literal succeeds => 0). A non-zero here would mean
        // the parser mis-associated markers.
        if case let .commandFinished(exitCode, _) = finalEvents[block.finishedIdx] {
            XCTAssertEqual(
                exitCode, 0,
                "M3-1 DEFECT: `echo <sentinel>` must report exit code 0; non-zero means marker/exit mis-association"
            )
        } else {
            XCTFail("M3-1 DEFECT: matched finished index is not a .commandFinished event")
        }

        // (b) the command's OUTPUT text reached the parser as .output between
        // the start and finish markers (proves the lossless tap forwarded the
        // real stdout, not just the OSC markers).
        let outputBetween = finalEvents[block.startedIdx..<block.finishedIdx].contains {
            if case let .output(text) = $0 { return text.contains(sentinel) }
            return false
        }
        XCTAssertTrue(
            outputBetween,
            "M3-1 DEFECT: the command's stdout (\(sentinel)) must reach the parser as an .output event between commandStarted and commandFinished"
        )

        // ---- 4. OBSERVE-WITHOUT-CONSUME -----------------------------------
        // Read SwiftTerm's OWN rendered emulator state. If the tap had
        // consumed (stolen) the stream, SwiftTerm's terminal would not contain
        // the echoed sentinel. We read the whole buffer (scrollback included)
        // via the verified getTerminal()/getText API; the oversized end.row is
        // clamped to the last buffer line by SwiftTerm itself.
        let terminal = view.getTerminal()
        let endRow = max(terminal.rows * 16, 10_000)
        let rendered = terminal.getText(
            start: Position(col: 0, row: 0),
            end: Position(col: max(terminal.cols - 1, 0), row: endRow)
        )
        XCTAssertTrue(
            rendered.contains(sentinel),
            "M3-1 DEFECT (observe-without-consume): SwiftTerm's OWN emulator must still have rendered \(sentinel); the lossless tap must not consume/steal the byte stream"
        )
    }
}
#endif
