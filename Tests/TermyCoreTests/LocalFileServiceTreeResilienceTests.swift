import XCTest
@testable import TermyCore

final class LocalFileServiceTreeResilienceTests: XCTestCase {
    /// Regression: opening the Files module showed "No files" whenever any
    /// single subdirectory was unreadable (permissions / broken symlink),
    /// because `treeItems` ran the whole recursive walk under one `try` and
    /// `refreshFiles()` discarded the entire tree on any thrown error.
    /// `tree()` must now skip the unreadable subtree and still return the
    /// readable entries.
    func testTreeSkipsUnreadableSubdirectoryAndReturnsReadableEntries() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("termy-tree-resilience-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: root.appendingPathComponent("good"), withIntermediateDirectories: true)
        try "x\n".write(to: root.appendingPathComponent("good/a.txt"), atomically: true, encoding: .utf8)
        try "y\n".write(to: root.appendingPathComponent("top.txt"), atomically: true, encoding: .utf8)

        let locked = root.appendingPathComponent("locked", isDirectory: true)
        try fm.createDirectory(at: locked, withIntermediateDirectories: true)
        try "secret\n".write(to: locked.appendingPathComponent("secret.txt"), atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)
        defer {
            // chmod 000 is a no-op under root; if this test ever runs as root
            // the fail-before guard below documents why it would not reproduce.
            try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path)
            try? fm.removeItem(at: root)
        }

        let service = LocalFileService(root: root)
        let tree = try service.tree()
        let paths = tree.map(\.item.relativePath)

        // The readable side must survive even though `locked` cannot be entered.
        XCTAssertTrue(paths.contains("good"), "expected readable folder node, got \(paths)")
        XCTAssertTrue(paths.contains("good/a.txt"), "expected readable nested file, got \(paths)")
        XCTAssertTrue(paths.contains("top.txt"), "expected readable top-level file, got \(paths)")
        // The unreadable folder is still listed (its node), just not descended into.
        XCTAssertTrue(paths.contains("locked"), "expected unreadable folder node, got \(paths)")
        XCTAssertFalse(paths.contains("locked/secret.txt"), "must not descend into unreadable subtree, got \(paths)")
        // Pre-fix this whole call threw → empty tree → "No files".
        XCTAssertFalse(tree.isEmpty, "tree must not be empty when readable entries exist")
    }

    /// Regression: launching via `open` sets cwd to `/`, so `projectRoot` defaulted
    /// to `/` and the UNBOUNDED recursive walk pinned the main thread walking the
    /// whole filesystem (no window, runaway CPU + RAM). `tree()` must cap recursion
    /// depth so a pathological root can never run away.
    func testTreeRespectsMaxDepth() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("termy-tree-depth-\(UUID().uuidString)", isDirectory: true)
        // Build a chain deeper than the cap: a/b/c/d/e with a file at the bottom.
        let deep = root.appendingPathComponent("a/b/c/d/e", isDirectory: true)
        try fm.createDirectory(at: deep, withIntermediateDirectories: true)
        try "x\n".write(to: deep.appendingPathComponent("leaf.txt"), atomically: true, encoding: .utf8)
        defer { try? fm.removeItem(at: root) }

        let tree = try LocalFileService(root: root).tree(maxDepth: 2, maxNodes: 5000)
        let maxObservedDepth = tree.map(\.depth).max() ?? 0
        XCTAssertLessThanOrEqual(maxObservedDepth, 2, "walk must not recurse past maxDepth, saw \(maxObservedDepth)")
        // The deep leaf is beyond the cap and must be absent.
        XCTAssertFalse(tree.map(\.item.relativePath).contains("a/b/c/d/e/leaf.txt"))
    }

    /// Regression: the node budget is a hard ceiling so a huge directory can never
    /// produce an unbounded result (the other half of the whole-filesystem-walk fix).
    func testTreeRespectsMaxNodes() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("termy-tree-nodes-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        for i in 0..<50 { try "x\n".write(to: root.appendingPathComponent("f\(i).txt"), atomically: true, encoding: .utf8) }
        defer { try? fm.removeItem(at: root) }

        let tree = try LocalFileService(root: root).tree(maxDepth: 8, maxNodes: 10)
        XCTAssertLessThanOrEqual(tree.count, 10, "node budget must cap the result, got \(tree.count)")
    }
}
