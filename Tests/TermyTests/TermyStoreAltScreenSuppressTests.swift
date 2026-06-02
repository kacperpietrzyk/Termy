import XCTest
import TermyCore
@testable import Termy

/// P2a follow-up: when a full-screen TUI (claude/vim) leaves the alternate screen,
/// its command block must not capture the alt↔normal transition residue (e.g.
/// `787878%`). `.output` is suppressed from alt-screen exit until the next command.
@MainActor
final class TermyStoreAltScreenSuppressTests: XCTestCase {
    private func makeStore() -> (TermyStore, UUID) {
        let store = TermyStore(startInitialPTY: false)
        let s = TermySession(
            title: "S",
            profile: ConnectionProfile.local(),
            currentWorkingDirectory: nil,
            interactionMode: .rawPTY
        )
        store.sessions = [s]
        return (store, s.id)
    }

    func test_altScreenExit_suppressesOutputUntilNextCommand() {
        let (store, id) = makeStore()
        let before = store.sessions[0].lines.count

        store.setTerminalAltScreen(true, for: id)
        store.setTerminalAltScreen(false, for: id)                 // exit → suppress armed
        store.ingestShellIntegrationEvents([.output("787878%")], for: id)
        XCTAssertEqual(store.sessions[0].lines.count, before,
                       "post-alt-screen transition residue must be suppressed")

        store.ingestShellIntegrationEvents([.commandStarted("ls")], for: id)
        store.ingestShellIntegrationEvents([.output("real output")], for: id)
        let texts = store.sessions[0].lines.map(\.text)
        XCTAssertTrue(texts.contains("real output"), "capture resumes after a fresh command")
        XCTAssertFalse(texts.contains("787878%"), "suppressed residue never appears")
    }

    func test_normalOutput_notSuppressed_withoutAltScreen() {
        let (store, id) = makeStore()
        store.ingestShellIntegrationEvents([.output("hello")], for: id)
        XCTAssertTrue(store.sessions[0].lines.map(\.text).contains("hello"),
                      "plain output (no alt-screen) is captured normally")
    }

    // MARK: - End-to-end ordering (residue fix, PRODUCT_DIAGNOSIS §9)

    /// Drive the store exactly as the fixed `dataReceived` does: for each PTY
    /// slice, run `AltScreenTapDecision`, arm alt-state on a change, THEN ingest.
    /// The `claude` exit timeline is: enter → repaint → exit → orphan-fragment
    /// slice. Because the exit slice reports the change (arming suppression)
    /// BEFORE the orphan slice is ingested, the `78`-style residue is swallowed.
    func test_altExit_armsSuppression_beforeOrphanSlice_isCaptured() {
        let (store, id) = makeStore()
        let before = store.sessions[0].lines.count

        // (was, now, outputThisSliceWouldCarry)
        let slices: [(Bool, Bool, String?)] = [
            (false, true, nil),         // ESC[?1049h — enter alt (dropped)
            (true, true, nil),          // TUI repaint (dropped)
            (true, false, nil),         // ESC[?1049l — EXIT (dropped, but reported)
            (false, false, "78"),       // orphaned escape tail — ingestable, must be suppressed
        ]
        for (was, now, carried) in slices {
            let d = AltScreenTapDecision.decide(wasAlternate: was, nowAlternate: now)
            if d.altScreenChanged { store.setTerminalAltScreen(now, for: id) }
            if d.ingest, let carried {
                store.ingestShellIntegrationEvents([.output(carried)], for: id)
            }
        }
        XCTAssertEqual(store.sessions[0].lines.count, before,
                       "alt-exit residue is suppressed — arming preceded the orphan ingest")

        // A fresh command resumes capture.
        store.ingestShellIntegrationEvents([.commandStarted("ls")], for: id)
        store.ingestShellIntegrationEvents([.output("real")], for: id)
        XCTAssertTrue(store.sessions[0].lines.map(\.text).contains("real"))
        XCTAssertFalse(store.sessions[0].lines.map(\.text).contains("78"))
    }

    /// Documents the defect the fix removes: if the orphan slice is ingested
    /// BEFORE the alt-exit arms suppression (the old render-callback lag), the
    /// residue leaks into the block. The fix makes this ordering impossible by
    /// deriving the arm + ingest from one synchronous per-slice decision.
    func test_laggingArm_leaksResidue_regressionWitness() {
        let (store, id) = makeStore()
        store.setTerminalAltScreen(true, for: id)                  // entered alt
        store.ingestShellIntegrationEvents([.output("78")], for: id)  // orphan ingested FIRST (lag)
        store.setTerminalAltScreen(false, for: id)                 // render callback arms LATE
        XCTAssertTrue(store.sessions[0].lines.map(\.text).contains("78"),
                      "with lagging arm the residue leaks — exactly what the synchronous fix prevents")
    }
}
