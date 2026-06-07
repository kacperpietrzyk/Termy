import XCTest
import SwiftUI
import AppKit
import TermyCore
@testable import Termy

/// Static visual gate for the Git multi-lane graph slice (D-DEBT-ORDER #7).
/// Builds a real branch+merge history via the pure GitGraphLayout and renders
/// the actual GitGraphRowView rows to a PNG for inspection.
@MainActor
final class GitGraphRenderGateTests: XCTestCase {
    private func commit(_ hash: String, _ parents: [String], _ subject: String, refs: [String] = []) -> GitLogEntry {
        GitLogEntry(hash: hash, shortHash: String(hash.prefix(7)), parents: parents,
                    refNames: refs, author: "kacper", relativeDate: "2h ago", subject: subject)
    }

    func test_branchMergeHistory_renders() throws {
        // A realistic shape: a merge, a feature branch alongside mainline, then a
        // shared ancestor — exercises pass-through, merge-in, and branch-out edges.
        let commits = [
            commit("m1", ["b2", "f2"], "Merge feature/login", refs: ["HEAD -> main"]),
            commit("f2", ["f1"], "Wire up form validation"),
            commit("b2", ["b1"], "Bump dependencies"),
            commit("f1", ["b1"], "Add login screen", refs: ["origin/feature/login"]),
            commit("b1", ["a0"], "Refactor router"),
            commit("a0", [], "Initial commit", refs: ["tag: v0.1"]),
        ]
        let layout = GitGraphLayout.compute(commits)
        XCTAssertGreaterThanOrEqual(layout.maxLanes, 2)

        let view = VStack(spacing: 0) {
            ForEach(layout.rows) { row in
                GitGraphRowView(row: row, maxLanes: layout.maxLanes)
            }
        }
        .frame(width: 460)
        .background(Color(DesignTokens.bg2))

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        if let img = renderer.nsImage, let tiff = img.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: "/tmp/gate-git-01-graph.png"))
        }
        XCTAssertEqual(layout.rows.count, 6)
    }
}
