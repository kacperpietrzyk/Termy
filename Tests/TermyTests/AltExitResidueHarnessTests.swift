#if canImport(AppKit)
import AppKit
import XCTest
import SwiftTerm
import TermyCore
@testable import Termy

/// FAITHFUL alt-exit residue harness (the `claude`-exit `78` leak). Unlike the
/// pure-string ShellIntegrationParser tests, this drives the REAL
/// `TappedLocalProcessTerminalView.dataReceived` ingest gate (sampling SwiftTerm's
/// own `isCurrentBufferAlternate` before/after each slice) and mirrors
/// TermyStore's `.output` suppression EXACTLY — so a slice dropped by the ingest
/// gate (alt-screen) or dropped by suppression (post-alt-exit) is reproduced as
/// in production. This is the layer all 6 prior attempts never tested.
///
/// We feed byte slices directly (no live process) so the split position is under
/// our control — the one degree of freedom real PTY chunking randomizes.
@MainActor
final class AltExitResidueHarnessTests: XCTestCase {

    /// Mirrors TermyStore.setTerminalAltScreen + applyShellIntegration suppression.
    private final class SuppressionMirror {
        private var altActive = false
        private(set) var suppress = false
        /// Outputs that SURVIVED suppression — what the block transcript renders.
        private(set) var keptOutput: [String] = []

        func noteAltScreen(_ active: Bool) {
            guard altActive != active else { return }
            let wasActive = altActive
            altActive = active
            if wasActive && !active { suppress = true }   // alt-exit arms suppression
        }
        func apply(_ events: [ShellIntegrationEvent]) {
            for event in events {
                switch event {
                case .output(let text):
                    if suppress { break }                 // dropped post-alt-exit
                    keptOutput.append(text)
                case .commandStarted:
                    suppress = false                      // fresh prompt resumes capture
                default:
                    break
                }
            }
        }
        /// Render kept output the way the block does: each `.output` is its own
        /// line, parsed independently and statelessly.
        func renderedBlock() -> String {
            let ansi = TerminalANSIParser()
            return keptOutput.map { ansi.parse($0).map(\.text).joined() }.joined()
        }
    }

    private func makeHarness() -> (TappedLocalProcessTerminalView, SuppressionMirror) {
        let view = TappedLocalProcessTerminalView(frame: CGRect(x: 0, y: 0, width: 800, height: 480))
        let mirror = SuppressionMirror()
        view.streamBridge = SwiftTermStreamBridge { mirror.apply($0) }
        view.onAltScreenChanged = { mirror.noteAltScreen($0) }
        return (view, mirror)
    }

    private func feed(_ view: TappedLocalProcessTerminalView, _ s: String) {
        let bytes = Array(s.utf8)
        view.dataReceived(slice: bytes[...])
    }

    // ───────────────────────────────────────────────────────────────────────
    // Scenario A — advisor Concern 2: `ESC[` trapped in the alt-exit slice,
    // `78G` in the following normal slice. Prediction under the real gate:
    // alt-exit slice NOT ingested (wasAlternate=true), suppression armed, the
    // `78G` slice's .output is DROPPED → no leak (my holdback never even runs).
    func testScenarioA_escSplitAcrossAltExitBoundary() {
        let (view, mirror) = makeHarness()
        feed(view, "\u{1B}[?1049h\u{1B}[2Jalt-content")        // enter alt-screen
        XCTAssertTrue(view.getTerminal().isCurrentBufferAlternate, "must be in alt-screen")
        feed(view, "\u{1B}[?1049l\u{1B}[")                      // alt-EXIT slice, ends mid-CSI
        XCTAssertFalse(view.getTerminal().isCurrentBufferAlternate, "must have exited alt-screen")
        feed(view, "78G ")                                      // next normal slice: orphan tail
        XCTAssertFalse(mirror.renderedBlock().contains("78"), "Scenario A leaked `78`")
    }

    // Scenario B — `ESC[78G` split across two NORMAL slices, NO alt-screen at all
    // (e.g. claude/spinner output before entering, or a program that never enters
    // alt). No suppression is active, both halves ingested → this is the layout
    // the holdback actually addresses.
    func testScenarioB_escSplitInNormalOutputNoAltScreen() {
        let (view, mirror) = makeHarness()
        feed(view, "x\u{1B}[78")                                // normal slice, ends mid-CSI
        feed(view, "G y")                                       // normal slice, orphan tail
        XCTAssertFalse(mirror.renderedBlock().contains("78"), "Scenario B leaked `78`")
        XCTAssertEqual(mirror.renderedBlock(), "x y")
    }

    // Scenario C — `ESC[78G` split, fully AFTER alt-exit (both halves normal &
    // ingested, but suppression armed by the exit). Prediction: suppression drops
    // both → no leak regardless of the holdback.
    func testScenarioC_escSplitPostAltExitSuppressed() {
        let (view, mirror) = makeHarness()
        feed(view, "\u{1B}[?1049h\u{1B}[2Jalt")                 // enter
        feed(view, "\u{1B}[?1049l")                             // exit (own slice) → arm suppress
        XCTAssertFalse(view.getTerminal().isCurrentBufferAlternate)
        feed(view, "x\u{1B}[78")                                // post-exit normal, mid-CSI
        feed(view, "G y")
        XCTAssertFalse(mirror.renderedBlock().contains("78"), "Scenario C leaked `78`")
    }

    // Scenario D — claude-like: enter alt, exit alt, THEN a fresh command starts
    // (OSC 133 C lifts suppression), and the NEXT command's output contains a
    // split `ESC[78G`. After the prompt the suppression is gone, so a split CSI
    // leaks unless the holdback catches it.
    func testScenarioD_splitCSIAfterPromptResumes() {
        let (view, mirror) = makeHarness()
        feed(view, "\u{1B}[?1049h alt \u{1B}[?1049l")           // enter+exit alt → suppress armed
        feed(view, "\u{1B}]133;C;cmd=next\u{07}")               // new command → suppress lifts
        feed(view, "out\u{1B}[78")                              // command output, mid-CSI
        feed(view, "G done")
        XCTAssertFalse(mirror.renderedBlock().contains("78"), "Scenario D leaked `78`")
    }
}
#endif
