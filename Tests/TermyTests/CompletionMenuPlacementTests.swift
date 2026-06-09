import XCTest
import SwiftUI
@testable import Termy

/// T5: unit gate for `CompletionMenuPlacement` — the pure geometry that keeps
/// the Tab completion menu from covering the previous command block.
///
/// The block transcript pins the caret at the viewport bottom, so the menu must
/// flip upward, reserve a clear band above the caret line, never grow off the
/// viewport top, and shrink-to-fit when there is not enough room above. The
/// legacy raw-PTY mid-viewport case must keep opening downward unchanged.
final class CompletionMenuPlacementTests: XCTestCase {

    private let reservedGap: CGFloat = 8
    private let rowHeight: CGFloat = 22

    /// Caret near the viewport bottom (block-transcript pinned input) ⇒ flip up.
    func test_placement_flipsUpward_whenCaretNearBottom() {
        let p = CompletionMenuPlacement(
            anchor: CGPoint(x: 40, y: 430),
            viewportSize: CGSize(width: 600, height: 460),
            totalHeight: 200, width: 320,
            reservedGap: reservedGap, caretLineHeight: rowHeight)
        XCTAssertTrue(p.flipUpward)
    }

    /// The menu's bottom edge sits a clear `reservedGap` ABOVE the caret line —
    /// proving it no longer butts against / overlaps the input bar.
    func test_placement_reservesGapAboveCaret() {
        let p = CompletionMenuPlacement(
            anchor: CGPoint(x: 40, y: 430),
            viewportSize: CGSize(width: 600, height: 460),
            totalHeight: 200, width: 320,
            reservedGap: reservedGap, caretLineHeight: rowHeight)
        XCTAssertTrue(p.flipUpward)
        XCTAssertLessThanOrEqual(p.resolvedTop + p.totalHeight, p.anchor.y - reservedGap)
    }

    /// A tall menu with a low caret must clamp its top to the viewport (>= 0).
    func test_placement_neverOverflowsViewportTop() {
        let p = CompletionMenuPlacement(
            anchor: CGPoint(x: 40, y: 120),
            viewportSize: CGSize(width: 600, height: 460),
            totalHeight: 400, width: 320,
            reservedGap: reservedGap, caretLineHeight: rowHeight)
        XCTAssertGreaterThanOrEqual(p.resolvedTop, 0)
    }

    /// Caret near the bottom of a SHORT viewport (so the menu must flip up) but
    /// with little room above ⇒ shrink-to-fit: fewer rows than requested, and
    /// the capped menu fits in the band above the caret.
    func test_placement_shrinksToFit_whenInsufficientRoomAbove() {
        let footerHeight: CGFloat = 60
        let verticalInset: CGFloat = 4
        let requested = 8
        // Short viewport, caret pinned near the bottom: must flip up, but only
        // ~120pt of room sits above the caret line — far less than 8 rows + footer.
        let anchor = CGPoint(x: 40, y: 120)
        let p = CompletionMenuPlacement(
            anchor: anchor,
            viewportSize: CGSize(width: 600, height: 140),
            totalHeight: 0, width: 320,
            reservedGap: reservedGap, caretLineHeight: rowHeight)
        XCTAssertTrue(p.flipUpward)
        let fit = p.effectiveVisibleRows(
            rowHeight: rowHeight, footerHeight: footerHeight,
            verticalInset: verticalInset, requested: requested)
        XCTAssertLessThan(fit, requested)
        // The capped menu must fit in the band above the caret.
        let cappedHeight = CGFloat(fit) * rowHeight + 2 * verticalInset + footerHeight
        XCTAssertLessThanOrEqual(cappedHeight, anchor.y - reservedGap)
    }

    /// Legacy raw-PTY surface: a mid-viewport caret with room below opens
    /// downward, a full caret line below the caret top (never on the line it
    /// completes), unchanged from the original raw-PTY behaviour.
    func test_placement_downwardCase_unchanged() {
        let p = CompletionMenuPlacement(
            anchor: CGPoint(x: 40, y: 100),
            viewportSize: CGSize(width: 600, height: 460),
            totalHeight: 200, width: 320,
            reservedGap: reservedGap, caretLineHeight: rowHeight)
        XCTAssertFalse(p.flipUpward)
        XCTAssertEqual(p.resolvedTop, p.anchor.y + rowHeight + reservedGap)
    }
}
