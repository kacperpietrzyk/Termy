import XCTest
import SwiftUI
import AppKit
import TermyCore
@testable import Termy

/// Static visual gate for the completion-menu richness slice (D-DEBT-ORDER #2).
///
/// The completion menu is a transient async popup (Tab → zsh sidecar), which makes
/// the live capture-mode gate flaky. Instead we rasterize `CompletionMenuOverlay`
/// directly with `ImageRenderer` in fixed states and write PNGs to /tmp for visual
/// inspection. This deterministically exercises the new render path: SF-Symbol
/// icons, per-kind tint, type tags, and the selection-gated detail footer.
///
/// The hard B4 assertion lives at the state layer (selection sentinel = no
/// highlight); here we also prove the *render* honours it: the no-selection PNG
/// and the selected PNG must differ (footer + highlight appear only when selected).
@MainActor
final class CompletionMenuRenderGateTests: XCTestCase {
    private func sampleItems() -> [CompletionCandidate] {
        [
            .init(title: "status", replacement: "git status", kind: .command,
                  description: "Show the working tree status"),
            .init(title: "stash", replacement: "git stash", kind: .command,
                  description: "Stash the changes in a dirty working directory away"),
            .init(title: "Projects/", replacement: "Projects/", kind: .directory),
            .init(title: "README.md", replacement: "README.md", kind: .file),
            .init(title: "main", replacement: "main", kind: .gitBranch,
                  description: "current branch"),
            .init(title: "prod-box", replacement: "prod-box", kind: .sshHost,
                  description: "10.0.0.4"),
            .init(title: "--verbose", replacement: "--verbose", kind: .flag,
                  description: "be more verbose"),
        ]
    }

    private func render(_ snapshot: TermyStore.MenuSnapshot, name: String) throws -> NSImage {
        let overlay = CompletionMenuOverlay(
            snapshot: snapshot,
            anchor: CGPoint(x: 40, y: 40),
            viewportSize: CGSize(width: 600, height: 460),
            font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        )
        // Constrain to the viewport so .position lays out inside a known frame.
        let framed = overlay.frame(width: 600, height: 460)
        let renderer = ImageRenderer(content: framed)
        renderer.scale = 2
        let image = renderer.nsImage
        let unwrapped = try XCTUnwrap(image, "ImageRenderer produced no image for \(name)")
        if let tiff = unwrapped.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: "/tmp/gate-rich-\(name).png"))
        }
        return unwrapped
    }

    /// Render the row list directly in a plain stack (ImageRenderer does not
    /// rasterize ScrollView content) so the gate PNG actually shows the icons,
    /// titles, descriptions, and type tags for every kind.
    func test_rendersRowList() throws {
        let items = sampleItems()
        let rows = VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                CompletionMenuRow(
                    item: item,
                    isSelected: idx == 2,                 // directory row highlighted
                    font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
                    rowHeight: 22,
                    descriptionRowHeight: 34,
                    horizontalInset: 8
                )
            }
        }
        .frame(width: 460)
        .background(Color(DesignTokens.bg2))

        let renderer = ImageRenderer(content: rows)
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.nsImage, "no row-list image")
        if let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: "/tmp/gate-rich-04-rows.png"))
        }
        XCTAssertGreaterThan(image.size.width, 100)
        XCTAssertGreaterThan(image.size.height, 100)
    }

    /// T5 visual gate: render the menu with the caret pinned near the viewport
    /// bottom (the block-transcript layout) AND a stand-in "previous command
    /// block" drawn directly above the caret. This is the discriminating check
    /// the owner inspects in capture-mode: does the upward-flipped, reserved-band
    /// menu still float over the prior block (Option A), or is the block clear?
    ///
    /// The geometry assertion proves the reserved band: the menu's resolved top
    /// sits a clear `reservedGap` above the caret line (so it never butts the
    /// input bar). It does NOT, by itself, prove the block is uncovered — that
    /// is the owner's eyes-on verdict from the PNG.
    func test_bottomAnchoredMenu_reservesBandAboveCaret() throws {
        let items = sampleItems()
        let snapshot = TermyStore.MenuSnapshot(items: items, selection: 2)
        let viewport = CGSize(width: 600, height: 460)
        let caret = CGPoint(x: 40, y: viewport.height - 30) // pinned near bottom

        // Compose a stand-in prior command block behind the menu so the PNG
        // shows whether the menu covers it.
        let scene = ZStack(alignment: .topLeading) {
            Color(DesignTokens.bg1)
            VStack(alignment: .leading, spacing: 6) {
                Text("user@host  ~/Projects/Termy")
                    .font(.system(size: 11))
                    .foregroundColor(Color(DesignTokens.fg4))
                Text("$ cd /Users/kacper/Projects/Termy")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color(DesignTokens.fg2))
            }
            .padding(12)
            .background(Color(DesignTokens.bg2))
            .padding(.horizontal, 18)
            .padding(.top, viewport.height - 120) // block sits just above the caret
            CompletionMenuOverlay(
                snapshot: snapshot,
                anchor: caret,
                viewportSize: viewport,
                font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular))
        }
        .frame(width: viewport.width, height: viewport.height)

        let renderer = ImageRenderer(content: scene)
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.nsImage, "no bottom-anchored scene image")
        if let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: "/tmp/gate-t5-bottom-anchored.png"))
        }
        XCTAssertGreaterThan(image.size.width, 100)
        XCTAssertGreaterThan(image.size.height, 100)

        // Band assertion: the menu's bottom edge stays a clear reservedGap above
        // the caret line (never overlapping the pinned input bar).
        let totalHeight: CGFloat = 22 * 8 + 2 * 4 + 60 // worst-case menu+footer estimate
        let placement = CompletionMenuPlacement(
            anchor: caret, viewportSize: viewport,
            totalHeight: totalHeight, width: 320, caretLineHeight: 22)
        XCTAssertTrue(placement.flipUpward, "bottom-pinned caret must flip the menu upward")
        XCTAssertLessThanOrEqual(placement.resolvedTop + placement.totalHeight,
                                 caret.y - placement.reservedGap,
                                 "menu bottom must stay above the caret by the reserved band")
    }

    func test_rendersAllStates_andHonoursB4() throws {
        let items = sampleItems()

        // State A — menu open, NOTHING selected (B4 default). No row highlight, no footer.
        let noSel = TermyStore.MenuSnapshot(items: items, selection: -1)
        let imgNoSel = try render(noSel, name: "01-no-selection")

        // State B — user navigated to the directory row → highlight + detail footer.
        let dirSel = TermyStore.MenuSnapshot(items: items, selection: 2)
        let imgDirSel = try render(dirSel, name: "02-dir-selected")

        // State C — selected a row with a long description → footer wraps untruncated.
        let descSel = TermyStore.MenuSnapshot(items: items, selection: 1)
        let imgDescSel = try render(descSel, name: "03-desc-selected")

        // All three must produce a non-trivial bitmap.
        for img in [imgNoSel, imgDirSel, imgDescSel] {
            XCTAssertGreaterThan(img.size.width, 100)
            XCTAssertGreaterThan(img.size.height, 50)
        }

        // The no-selection render must differ from the selected render — proving the
        // footer / highlight are genuinely gated on selection (B4 reads visually).
        let dataNoSel = imgNoSel.tiffRepresentation
        let dataDirSel = imgDirSel.tiffRepresentation
        XCTAssertNotNil(dataNoSel)
        XCTAssertNotNil(dataDirSel)
        XCTAssertNotEqual(dataNoSel, dataDirSel,
                          "no-selection and selected renders are identical — footer/highlight not gating on selection")
    }
}
