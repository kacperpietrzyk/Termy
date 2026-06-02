import XCTest
@testable import TermyCore

/// Residue fix (PRODUCT_DIAGNOSIS §9): the command-block tap must (a) ingest
/// only genuine non-alternate output and (b) report the alt-screen state change
/// from the SAME per-slice sample that gates ingest, so the store's alt-exit
/// output-suppression window arms synchronously with the bytes (never lagging
/// behind via the render callback).
final class AltScreenTapDecisionTests: XCTestCase {

    func test_normalOutput_isIngested_noChange() {
        let d = AltScreenTapDecision.decide(wasAlternate: false, nowAlternate: false)
        XCTAssertTrue(d.ingest, "Output produced entirely on the primary screen is captured.")
        XCTAssertFalse(d.altScreenChanged)
    }

    func test_enterAltScreen_notIngested_andReportsChange() {
        // Slice that flips INTO the alt screen (e.g. contains `ESC[?1049h`).
        let d = AltScreenTapDecision.decide(wasAlternate: false, nowAlternate: true)
        XCTAssertFalse(d.ingest, "The enter-transition slice must not be captured.")
        XCTAssertTrue(d.altScreenChanged, "Entering alt screen is a state change.")
    }

    func test_insideAltScreen_notIngested_noChange() {
        let d = AltScreenTapDecision.decide(wasAlternate: true, nowAlternate: true)
        XCTAssertFalse(d.ingest, "TUI repaint frames must never reach the block tap.")
        XCTAssertFalse(d.altScreenChanged)
    }

    func test_exitAltScreen_notIngested_butReportsChangeToArmSuppression() {
        // THE residue-critical case: the alt→normal exit slice. It must NOT be
        // ingested, but it MUST report the change so the store arms `.output`
        // suppression IMMEDIATELY — before the next (non-alt) slice carrying the
        // orphaned escape fragment is ingested.
        let d = AltScreenTapDecision.decide(wasAlternate: true, nowAlternate: false)
        XCTAssertFalse(d.ingest, "The exit-transition slice (final TUI frame + ESC[?1049l) is dropped.")
        XCTAssertTrue(d.altScreenChanged, "Exit MUST be reported so suppression arms synchronously.")
    }

    /// End-to-end ordering: enter → repaint → exit → orphan-fragment slice. The
    /// exit is observed (arming suppression) on the slice BEFORE the orphan slice
    /// is ingested — the property the lagging render callback violated.
    func test_exitReportedBeforeNextSliceIngest() {
        let timeline: [(was: Bool, now: Bool)] = [
            (false, true),   // enter alt
            (true, true),    // repaint frame
            (true, false),   // EXIT — must report change here
            (false, false),  // orphan fragment slice — would be ingested
        ]
        var armedAtStep: Int?
        var ingestedSteps: [Int] = []
        for (i, s) in timeline.enumerated() {
            let d = AltScreenTapDecision.decide(wasAlternate: s.was, nowAlternate: s.now)
            if d.altScreenChanged && !s.now && armedAtStep == nil { armedAtStep = i }
            if d.ingest { ingestedSteps.append(i) }
        }
        XCTAssertEqual(armedAtStep, 2, "Exit suppression arms on the exit slice (step 2).")
        XCTAssertEqual(ingestedSteps, [3], "Only the post-exit orphan slice is ingestable…")
        XCTAssertTrue(armedAtStep! < ingestedSteps.first!,
            "…and arming strictly precedes that ingest, so the orphan is suppressed in time.")
    }
}
