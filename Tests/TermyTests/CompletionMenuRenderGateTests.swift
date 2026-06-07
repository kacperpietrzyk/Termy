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
