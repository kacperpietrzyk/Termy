import XCTest
@testable import TermyCore

/// Finder-lite expand/collapse model: the Files module must show a navigable
/// tree (directories collapsed by default, children listed lazily only when
/// expanded) instead of a fully-flattened depth-8 dump of up to 5000 nodes.
final class LocalFileServiceVisibleTreeTests: XCTestCase {
    private func makeFixture() throws -> (LocalFileService, URL) {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("termy-visible-tree-\(UUID().uuidString)", isDirectory: true)
        // root/
        //   src/        (dir)
        //     app.swift
        //     util/      (dir)
        //       helper.swift
        //   docs/        (dir)
        //     readme.md
        //   top.txt
        try fm.createDirectory(at: root.appendingPathComponent("src/util"), withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appendingPathComponent("docs"), withIntermediateDirectories: true)
        try "a\n".write(to: root.appendingPathComponent("src/app.swift"), atomically: true, encoding: .utf8)
        try "b\n".write(to: root.appendingPathComponent("src/util/helper.swift"), atomically: true, encoding: .utf8)
        try "c\n".write(to: root.appendingPathComponent("docs/readme.md"), atomically: true, encoding: .utf8)
        try "d\n".write(to: root.appendingPathComponent("top.txt"), atomically: true, encoding: .utf8)
        return (LocalFileService(root: root), root)
    }

    func test_collapsedByDefault_showsOnlyTopLevel() throws {
        let (service, root) = try makeFixture()
        defer { try? FileManager.default.removeItem(at: root) }

        let visible = try service.visibleTree(expanded: [])
        let paths = visible.map(\.item.relativePath)

        // Only the root's direct children — never any nested descendant.
        XCTAssertEqual(Set(paths), ["src", "docs", "top.txt"])
        XCTAssertFalse(paths.contains("src/app.swift"), "collapsed dir must not list children")
        // Directories sort before files (src, docs before top.txt).
        XCTAssertEqual(paths.last, "top.txt")
        // Every row is at depth 0.
        XCTAssertTrue(visible.allSatisfy { $0.depth == 0 })
    }

    func test_expandingDirectory_revealsItsImmediateChildrenOnly() throws {
        let (service, root) = try makeFixture()
        defer { try? FileManager.default.removeItem(at: root) }

        let visible = try service.visibleTree(expanded: ["src"])
        let paths = visible.map(\.item.relativePath)

        XCTAssertTrue(paths.contains("src"))
        XCTAssertTrue(paths.contains("src/app.swift"), "expanded dir must list its children")
        XCTAssertTrue(paths.contains("src/util"), "nested dir node appears")
        // …but the nested dir is itself collapsed — its child stays hidden.
        XCTAssertFalse(paths.contains("src/util/helper.swift"))
        // docs stays collapsed.
        XCTAssertFalse(paths.contains("docs/readme.md"))

        // Children render one level deeper than their parent.
        let appRow = try XCTUnwrap(visible.first { $0.item.relativePath == "src/app.swift" })
        XCTAssertEqual(appRow.depth, 1)
    }

    func test_expandingNestedDirectory_revealsGrandchildren() throws {
        let (service, root) = try makeFixture()
        defer { try? FileManager.default.removeItem(at: root) }

        let visible = try service.visibleTree(expanded: ["src", "src/util"])
        let paths = visible.map(\.item.relativePath)

        XCTAssertTrue(paths.contains("src/util/helper.swift"))
        let helperRow = try XCTUnwrap(visible.first { $0.item.relativePath == "src/util/helper.swift" })
        XCTAssertEqual(helperRow.depth, 2)
        // Ordering: a parent always appears immediately before its children.
        let utilIdx = try XCTUnwrap(paths.firstIndex(of: "src/util"))
        let helperIdx = try XCTUnwrap(paths.firstIndex(of: "src/util/helper.swift"))
        XCTAssertLessThan(utilIdx, helperIdx)
    }

    func test_directoryRows_areMarkedExpandable_filesAreNot() throws {
        let (service, root) = try makeFixture()
        defer { try? FileManager.default.removeItem(at: root) }

        let visible = try service.visibleTree(expanded: ["src"])
        let srcRow = try XCTUnwrap(visible.first { $0.item.relativePath == "src" })
        let fileRow = try XCTUnwrap(visible.first { $0.item.relativePath == "src/app.swift" })
        XCTAssertTrue(srcRow.isExpandable)
        XCTAssertFalse(fileRow.isExpandable)
    }

    func test_expandingMissingDirInSet_isIgnored() throws {
        let (service, root) = try makeFixture()
        defer { try? FileManager.default.removeItem(at: root) }
        // A stale expanded path (deleted dir) must not crash or leak rows.
        let visible = try service.visibleTree(expanded: ["does/not/exist", "src"])
        XCTAssertTrue(visible.map(\.item.relativePath).contains("src/app.swift"))
    }

    func test_respectsNodeBudget() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("termy-visible-budget-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        for i in 0..<50 { try "x\n".write(to: root.appendingPathComponent("f\(i).txt"), atomically: true, encoding: .utf8) }
        defer { try? fm.removeItem(at: root) }
        let visible = try LocalFileService(root: root).visibleTree(expanded: [], maxNodes: 10)
        XCTAssertLessThanOrEqual(visible.count, 10)
    }
}
