import XCTest
@testable import Termy
import TermyCore

// M3-1 byte-tap mechanism (pinned against SwiftTerm 1.13.0 source, Task 3):
//   SwiftTerm pinned: 1.13.0, rev 8e7a1e154f470e19c709a00a8768df348ba5fc43
//     (verified in Package.resolved).
//   Resolved checkout: .build/checkouts/SwiftTerm/Sources/SwiftTerm
//
//   MECHANISM: subclass-override  (plan mechanism 1 — the preferred, lowest-cost seam)
//
//   ENTRY POINT:
//     LocalProcessTerminalView.dataReceived(slice:) — Mac/MacLocalTerminalView.swift:183
//       open func dataReceived(slice: ArraySlice<UInt8>) { feed (byteArray: slice) }
//     It is declared `open` on the `open class LocalProcessTerminalView`
//     (MacLocalTerminalView.swift:67), so a subclass in the Termy target may
//     override it without forking/patching SwiftTerm. The class doc-comment
//     (MacLocalTerminalView.swift:64-65) explicitly invites this:
//       "If you want additional control over the delegate methods implemented
//        in this class, you can subclass this and override the methods".
//
//   FULL DATA PATH (every output byte flows through this single method):
//     LocalProcess.childProcessRead reads the PTY and dispatches each chunk via
//     `delegate?.dataReceived(slice:)` at EXACTLY two call sites and no other:
//       - LocalProcess.swift:157  (usesMainQueue path: enqueue → drainReceivedData)
//       - LocalProcess.swift:280  (non-main-queue path: dispatchQueue.sync)
//     The delegate is the view itself — `process = LocalProcess(delegate: self)`
//     at MacLocalTerminalView.swift:86 (LocalProcessTerminalView conforms to
//     LocalProcessDelegate, MacLocalTerminalView.swift:67). There is no other
//     consumer and no bypass of `dataReceived(slice:)` for received bytes.
//
//   OBSERVE-WITHOUT-CONSUME GUARANTEE:
//     The override calls `super.dataReceived(slice:)` FIRST. super's body is
//     `feed (byteArray: slice)` → AppleTerminalView.feed(byteArray:)
//     (Apple/AppleTerminalView.swift:1916) which runs
//       feedPrepare(); terminal.feed (buffer: byteArray); feedFinish()
//     i.e. SwiftTerm's unchanged, existing render path. `slice` is an immutable
//     `ArraySlice<UInt8>` value type; super reads from it and never mutates it,
//     so handing the SAME slice to the tap after super is lossless and cannot
//     perturb what SwiftTerm rendered. The tap therefore observes 100% of the
//     verbatim byte stream while SwiftTerm consumes/renders it unmodified.
//
//   REJECTED ALTERNATIVES:
//     Mechanisms 2 (LocalProcessDelegate re-host) and 3 (Terminal.feed compose,
//     seam-widening) are unnecessary: mechanism 1 already (a) sees every byte,
//     (b) does not consume/alter them, (c) requires no SwiftTerm fork/patch.
//     Per the decision rule, the lowest-numbered viable mechanism is chosen.
//
//   NOTE FOR TASK 4 (bridge impl): bytes arrive on LocalProcess's dispatch
//     queue (default DispatchQueue.main). The bridge below is exercised
//     synchronously by these unit tests (no queue concern at test time), but
//     the production SwiftTermTerminalView override should keep tap forwarding
//     on the same queue super was invoked on.
//   NOTE FOR TASK 4 (bridge impl, continued): the bridge must accumulate raw
//     bytes across ingest() calls before UTF-8-decoding and marker parsing.
//     An OSC 133 sequence (\e]133;…\a) or a multi-byte UTF-8 codepoint can
//     straddle two consecutive ingest() calls (see
//     testIngestSplitAcrossMarkerBoundaryStillParses). Decoding each slice
//     independently would corrupt or drop events at every such boundary.
// NOTE: SwiftTermStreamBridge arrives in Task 4 — this file is intentionally
//   compile-RED until then (by design; commit message documents it).
final class SwiftTermStreamBridgeTests: XCTestCase {
    func testBridgeForwardsBytesLosslesslyAsParserEvents() {
        var events: [ShellIntegrationEvent] = []
        let bridge = SwiftTermStreamBridge { events.append(contentsOf: $0) }

        let prompt = Array("ready$ ".utf8)
        let cmdStart = Array("\u{1B}]133;C;cmd=ls\u{07}".utf8)
        let output = Array("file-a\nfile-b\n".utf8)
        let cmdEnd = Array("\u{1B}]133;D;exit=0;pwd=/tmp\u{07}".utf8)

        bridge.ingest(prompt[...])
        bridge.ingest(cmdStart[...])
        bridge.ingest(output[...])
        bridge.ingest(cmdEnd[...])
        bridge.flush()

        XCTAssertEqual(events, [
            .output("ready$ "),
            .commandStarted("ls"),
            .output("file-a\nfile-b\n"),
            .commandFinished(exitCode: 0, workingDirectory: "/tmp"),
        ], "bridge must decode bytes and produce parser events verbatim and in order")
    }

    func testIngestSplitAcrossMarkerBoundaryStillParses() {
        var events: [ShellIntegrationEvent] = []
        let bridge = SwiftTermStreamBridge { events.append(contentsOf: $0) }
        let whole = Array("\u{1B}]133;C;cmd=echo hi\u{07}hi\n".utf8)
        bridge.ingest(whole[0..<6])      // marker split mid-sequence
        bridge.ingest(whole[6...])
        bridge.flush()
        XCTAssertEqual(
            events,
            [.commandStarted("echo hi"), .output("hi\n")],
            "marker split across an ingest boundary must still parse as a single command-started event followed by output"
        )
    }
}
