import XCTest
import TermyCore
@testable import Termy

final class TermyStoreFileTests: XCTestCase {
    @MainActor
    func testFileExplorerPublishesTreeItemsAndSearchFallsBackToFlatMatches() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-store-files-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Sources/Termy"), withIntermediateDirectories: true)
        try "let app = true\n".write(to: root.appendingPathComponent("Sources/Termy/App.swift"), atomically: true, encoding: .utf8)
        try "# Termy\n".write(to: root.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)

        let store = TermyStore(startInitialPTY: false, projectRoot: root)

        // Finder-lite: collapsed by default → only the top-level entries, never
        // the nested descendants of an unexpanded directory.
        XCTAssertEqual(store.fileTreeItems.map(\.item.relativePath), ["Sources", "README.md"])
        XCTAssertEqual(store.visibleFileTreeItems.map(\.depth), [0, 0])

        // Expanding the directories reveals their children (one level per expand).
        store.expandedFileDirectories = ["Sources", "Sources/Termy"]
        store.refreshFiles()
        XCTAssertEqual(store.fileTreeItems.map(\.item.relativePath), [
            "Sources",
            "Sources/Termy",
            "Sources/Termy/App.swift",
            "README.md"
        ])
        XCTAssertEqual(store.visibleFileTreeItems.map(\.depth), [0, 1, 2, 0])

        // Search still spans the WHOLE bounded corpus (not just what is expanded),
        // falling back to a flat list of matches.
        store.expandedFileDirectories = []
        store.refreshFiles()
        store.fileSearchQuery = "app"
        XCTAssertEqual(store.visibleFileTreeItems.map(\.item.relativePath), ["Sources/Termy/App.swift"])
        XCTAssertEqual(store.visibleFileTreeItems.map(\.depth), [0])
        XCTAssertEqual(store.visibleFileTreeItems.map(\.iconName), ["curlybraces"])
    }

    @MainActor
    func testToggleFileDirectoryTracksExpansionAndCollapsesDescendants() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-store-files-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Sources/Termy"), withIntermediateDirectories: true)
        try "x\n".write(to: root.appendingPathComponent("Sources/Termy/App.swift"), atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = TermyStore(startInitialPTY: false, projectRoot: root)
        XCTAssertFalse(store.isFileDirectoryExpanded("Sources"))

        store.toggleFileDirectory("Sources")
        XCTAssertTrue(store.isFileDirectoryExpanded("Sources"))
        store.toggleFileDirectory("Sources/Termy")
        XCTAssertTrue(store.isFileDirectoryExpanded("Sources/Termy"))

        // Collapsing a parent must also drop its now-hidden descendant from the
        // expanded set, so re-opening the parent doesn't silently re-expand children.
        store.toggleFileDirectory("Sources")
        XCTAssertFalse(store.isFileDirectoryExpanded("Sources"))
        XCTAssertFalse(store.isFileDirectoryExpanded("Sources/Termy"))
    }

    @MainActor
    func testFileExplorerKeyboardNavigationSelectsVisibleTreeItems() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-store-files-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Sources"), withIntermediateDirectories: true)
        try "let app = true\n".write(to: root.appendingPathComponent("Sources/App.swift"), atomically: true, encoding: .utf8)
        try "# Termy\n".write(to: root.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)

        let store = TermyStore(startInitialPTY: false, projectRoot: root)

        // Collapsed by default → keyboard nav walks only the visible top-level rows
        // (Sources/App.swift is hidden until Sources is expanded).
        store.selectNextFileTreeItem()
        XCTAssertEqual(store.selectedFilePath, "Sources")
        store.selectNextFileTreeItem()
        XCTAssertEqual(store.selectedFilePath, "README.md")
        store.selectPreviousFileTreeItem()
        XCTAssertEqual(store.selectedFilePath, "Sources")
        store.selectPreviousFileTreeItem()
        XCTAssertEqual(store.selectedFilePath, "README.md")

        // Once expanded, the revealed child joins the navigable sequence.
        store.expandedFileDirectories = ["Sources"]
        store.refreshFiles()
        store.selectedFilePath = "Sources"
        store.selectNextFileTreeItem()
        XCTAssertEqual(store.selectedFilePath, "Sources/App.swift")

        store.fileSearchQuery = "readme"
        store.perform("file-next-item")
        XCTAssertEqual(store.selectedFilePath, "README.md")
        store.perform("file-previous-item")
        XCTAssertEqual(store.selectedFilePath, "README.md")
    }

    @MainActor
    func testSFTPKeyboardNavigationSelectsVisibleRemoteItems() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-store-files-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = TermyStore(startInitialPTY: false, projectRoot: root)
        store.sftpRemoteItems = [
            SFTPRemoteItem(name: "src", path: "/home/deploy/src", isDirectory: true, size: 0),
            SFTPRemoteItem(name: "README.md", path: "/home/deploy/README.md", isDirectory: false, size: 128),
            SFTPRemoteItem(name: "app.log", path: "/home/deploy/app.log", isDirectory: false, size: 42)
        ]

        store.selectNextSFTPRemoteItem()
        XCTAssertEqual(store.selectedSFTPRemotePath, "/home/deploy/src")
        store.selectNextSFTPRemoteItem()
        XCTAssertEqual(store.selectedSFTPRemotePath, "/home/deploy/README.md")
        store.selectPreviousSFTPRemoteItem()
        XCTAssertEqual(store.selectedSFTPRemotePath, "/home/deploy/src")
        store.selectPreviousSFTPRemoteItem()
        XCTAssertEqual(store.selectedSFTPRemotePath, "/home/deploy/app.log")

        store.fileSearchQuery = "readme"
        store.perform("sftp-next-item")
        XCTAssertEqual(store.selectedSFTPRemotePath, "/home/deploy/README.md")
        store.perform("sftp-previous-item")
        XCTAssertEqual(store.selectedSFTPRemotePath, "/home/deploy/README.md")
    }

    @MainActor
    func testMoveSelectedFileUsesDestinationFolderAndRefreshesSelection() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-store-files-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("notes"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try "# Today\n".write(to: root.appendingPathComponent("notes/today.md"), atomically: true, encoding: .utf8)

        let store = TermyStore(startInitialPTY: false, projectRoot: root)
        store.selectedFilePath = "notes/today.md"
        store.fileMoveDestination = "archive"

        store.moveSelectedFile()

        XCTAssertEqual(store.selectedFilePath, "archive/today.md")
        XCTAssertEqual(store.fileMoveDestination, "")
        XCTAssertEqual(store.statusMessage, "Moved notes/today.md to archive/today.md.")
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("notes/today.md").path))
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("archive/today.md"), encoding: .utf8), "# Today\n")
        XCTAssertTrue(store.fileItems.contains { $0.relativePath == "archive" && $0.isDirectory })
    }

    /// M6: Reveal-in-Finder / Quick Look resolve through `selectedFileURL`. Assert
    /// the seam (a no-op nil when nothing is selected; the correct absolute URL
    /// under projectRoot when set) without a live Finder/Quick Look call.
    @MainActor
    func testSelectedFileURLResolvesUnderProjectRootAndIsNilWhenUnselected() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-store-files-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try "# Termy\n".write(to: root.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)

        let store = TermyStore(startInitialPTY: false, projectRoot: root)

        // No selection → no URL (reveal/Quick Look are no-ops).
        XCTAssertNil(store.selectedFileURL)
        store.revealSelectedFileInFinder() // must not crash

        store.selectedFilePath = "README.md"
        let url = try XCTUnwrap(store.selectedFileURL)
        XCTAssertEqual(url.lastPathComponent, "README.md")
        // The selected file sits directly under the sanitized project root.
        let expectedRoot = TermyStore.sanitizedProjectRoot(root)
        XCTAssertEqual(url.deletingLastPathComponent().standardizedFileURL, expectedRoot)
    }
}
