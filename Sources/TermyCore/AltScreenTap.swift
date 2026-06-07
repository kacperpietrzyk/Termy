import Foundation

/// Per-slice decision for the command-block tap that observes SwiftTerm's PTY
/// output (`TappedLocalProcessTerminalView.dataReceived`).
///
/// Background — the `787878%` residue. A full-screen TUI (vim/htop/`claude`)
/// owns the alternate screen and repaints the same cells thousands of times; the
/// block tap must never capture those frames. We key off SwiftTerm's own
/// `isCurrentBufferAlternate`, sampled BEFORE and AFTER `super.dataReceived`, so
/// a slice is only forwarded to the tap when it is genuine non-alternate output.
///
/// The subtle bug the 2026-06-02 forensic (PRODUCT_DIAGNOSIS §9) pinned down:
/// at the alt→normal EXIT, an escape sequence (`ESC[78G…`) can straddle the
/// boundary between the dropped alt-exit slice and the next ingested slice,
/// leaving a bare `78` fragment that surfaces as residue. The store suppresses
/// `.output` from alt-exit until the next command — but that suppression was
/// armed by SwiftTerm's *render* callback, which fires AFTER `dataReceived` has
/// already ingested and committed the fragment. The arming lagged the bytes.
///
/// The fix: derive BOTH "ingest this slice?" and "alt-screen state changed?"
/// from the SAME synchronous per-slice sample, so the store learns about the
/// alt-exit (and opens its suppression window) in the same call that would
/// ingest the next slice — the arming can no longer lag the byte stream.
public struct AltScreenTapDecision: Equatable, Sendable {
    /// Forward this slice to the command-block tap. True only for output produced
    /// entirely on the primary (non-alternate) screen.
    ///
    /// RECLASSIFIED post-Slice-1 (terminal rebuild): originally this only gated the
    /// re-parse path that spec §9 planned to retire. Slice 1 repurposed it to ALSO
    /// gate the SwiftTerm-buffer SNAPSHOT accumulation — the rebuild's clean source.
    /// So this decision is now LOAD-BEARING, not retire-able scaffolding: dropping the
    /// gate re-pollutes the snapshot with alt-buffer repaint frames. See the call site
    /// in `SwiftTermTerminalView.dataReceived`.
    public let ingest: Bool

    /// The alternate-screen flag changed across this slice. The view must
    /// propagate `nowAlternate` to the store SYNCHRONOUSLY (in this same
    /// `dataReceived` call, before any subsequent slice is ingested) so the
    /// alt-exit `.output` suppression window opens in time to swallow the
    /// transition residue.
    public let altScreenChanged: Bool

    public init(ingest: Bool, altScreenChanged: Bool) {
        self.ingest = ingest
        self.altScreenChanged = altScreenChanged
    }

    /// Decide from the alternate-screen flag sampled before/after SwiftTerm
    /// processed the slice.
    public static func decide(wasAlternate: Bool, nowAlternate: Bool) -> AltScreenTapDecision {
        AltScreenTapDecision(
            ingest: !wasAlternate && !nowAlternate,
            altScreenChanged: wasAlternate != nowAlternate
        )
    }
}
