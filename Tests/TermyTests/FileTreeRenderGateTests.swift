import XCTest
import SwiftUI
import AppKit
import TermyCore
@testable import Termy

/// Static visual gate for the Files Finder-lite slice (D-DEBT-ORDER #3).
/// Builds a real expand/collapse tree from a temp fixture via the same
/// LocalFileService.visibleTree the app uses, then rasterizes the row list with
/// ImageRenderer (ScrollView content does not rasterize, so rows are drawn in a
/// plain stack) and writes PNGs to /tmp for inspection.
@MainActor
final class FileTreeRenderGateTests: XCTestCase {
    private func makeFixture() throws -> (LocalFileService, URL) {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("termy-filetree-gate-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: root.appendingPathComponent("src/views"), withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appendingPathComponent("Resources"), withIntermediateDirectories: true)
        try "a\n".write(to: root.appendingPathComponent("src/App.swift"), atomically: true, encoding: .utf8)
        try "b\n".write(to: root.appendingPathComponent("src/views/Home.swift"), atomically: true, encoding: .utf8)
        try "c\n".write(to: root.appendingPathComponent("Resources/icon.png"), atomically: true, encoding: .utf8)
        try "# Readme\n".write(to: root.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        try "{}\n".write(to: root.appendingPathComponent("Package.json"), atomically: true, encoding: .utf8)
        return (LocalFileService(root: root), root)
    }

    private func renderRows(_ items: [LocalFileTreeItem], expanded: Set<String>, selected: String?, name: String) {
        let rows = VStack(spacing: 1) {
            ForEach(items) { item in
                FileTreeRowView(
                    treeItem: item,
                    selected: item.item.relativePath == selected,
                    expanded: expanded.contains(item.item.relativePath),
                    showDisclosure: item.item.isDirectory,
                    onTap: {}
                )
            }
        }
        .frame(width: 360)
        .padding(8)
        .background(Color(DesignTokens.bg2))

        let renderer = ImageRenderer(content: rows)
        renderer.scale = 2
        if let img = renderer.nsImage, let tiff = img.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: "/tmp/gate-files-\(name).png"))
        }
    }

    func test_collapsed_thenExpanded_render() throws {
        let (service, root) = try makeFixture()
        defer { try? FileManager.default.removeItem(at: root) }

        // Collapsed: only top-level dirs + files, every row a chevron for dirs.
        let collapsed = try service.visibleTree(expanded: [])
        XCTAssertEqual(Set(collapsed.map(\.item.relativePath)), ["src", "Resources", "README.md", "Package.json"])
        renderRows(collapsed, expanded: [], selected: nil, name: "01-collapsed")

        // Expanded src + nested views, with a file selected.
        let expanded: Set<String> = ["src", "src/views"]
        let tree = try service.visibleTree(expanded: expanded)
        XCTAssertTrue(tree.map(\.item.relativePath).contains("src/views/Home.swift"))
        renderRows(tree, expanded: expanded, selected: "src/views/Home.swift", name: "02-expanded")

        // M6: a real file item now carries the metadata the row renders
        // (size + modification date); the type is conveyed by the icon.
        let fileItem = try XCTUnwrap(tree.first { $0.item.relativePath == "src/views/Home.swift" }).item
        XCTAssertNotNil(fileItem.byteCount, "rendered file rows have a size")
        XCTAssertNotNil(fileItem.modificationDate, "rendered file rows have a modification date")
        XCTAssertNotNil(LocalFileMetadata.sizeLabel(fileItem.byteCount))
        XCTAssertNotNil(LocalFileMetadata.dateLabel(fileItem.modificationDate))
    }
}
