import XCTest
@testable import TermyCore

final class SessionRestoreStoreTests: XCTestCase {
    func testDefaultInitializerUsesDefaultDirectoryAndFileManager() {
        let store = SessionRestoreStore()

        XCTAssertEqual(store.directoryURL, SessionRestoreStore.defaultDirectoryURL())
        XCTAssertTrue(store.fileManager === FileManager.default)
    }

    func testSaveLoadAndMetadataRoundTrip() throws {
        let dir = try makeTempDir()
        let store = SessionRestoreStore(directoryURL: dir)
        let snapshot = makeSnapshot()

        try store.save(snapshot)

        XCTAssertTrue(store.hasValidSnapshot())
        XCTAssertEqual(try store.load(), snapshot)
        XCTAssertEqual(try store.metadata()?.sessionCount, 1)
    }

    func testMissingSnapshotReturnsNilAndNoMetadata() throws {
        let store = SessionRestoreStore(directoryURL: try makeTempDir())

        XCTAssertFalse(store.hasValidSnapshot())
        XCTAssertNil(try store.load())
        XCTAssertNil(try store.metadata())
    }

    func testEmptySnapshotIsNotValidAndHasNoMetadata() throws {
        let dir = try makeTempDir()
        let store = SessionRestoreStore(directoryURL: dir)
        try store.save(.makeBounded(
            capturedAt: Date(timeIntervalSince1970: 1),
            selectedSessionID: nil,
            paneTree: "terminal",
            focusedPane: .terminal,
            activePanel: nil,
            sessions: []
        ))

        XCTAssertFalse(store.hasValidSnapshot())
        XCTAssertNil(try store.metadata())
    }

    func testCorruptJSONIsMovedAsideAndIgnored() throws {
        let dir = try makeTempDir()
        let store = SessionRestoreStore(directoryURL: dir)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("{not-json".utf8).write(to: store.snapshotURL)

        XCTAssertNil(try store.load())
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.snapshotURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.corruptSnapshotURL.path))
    }

    func testConcurrentCorruptLoadsPreserveAtLeastOneBadSnapshot() async throws {
        for _ in 0..<50 {
            let dir = try makeTempDir()
            let store = SessionRestoreStore(directoryURL: dir)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try Data("{not-json".utf8).write(to: store.snapshotURL)
            let tasks = (0..<8).map { _ in
                Task.detached {
                    try store.load()
                }
            }

            for task in tasks {
                let snapshot = try await task.value
                XCTAssertNil(snapshot)
            }

            XCTAssertFalse(FileManager.default.fileExists(atPath: store.snapshotURL.path))
            let badFiles = try FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: nil
            ).filter { $0.lastPathComponent.hasSuffix(".bad") }
            XCTAssertFalse(badFiles.isEmpty)
        }
    }

    func testCorruptQuarantineSkipsWhenCurrentSnapshotDataDiffers() throws {
        let dir = try makeTempDir()
        let store = SessionRestoreStore(directoryURL: dir)
        let corruptData = Data("{not-json".utf8)
        let validSnapshot = makeSnapshot(title: "fresh")
        let validData = try JSONEncoder.sessionRestore.encode(validSnapshot)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try validData.write(to: store.snapshotURL)

        try store.moveCorruptSnapshotAside(matching: corruptData)

        XCTAssertEqual(try store.load(), validSnapshot)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.corruptSnapshotURL.path))
    }

    func testFutureSchemaIsPreservedButNotLoaded() throws {
        let dir = try makeTempDir()
        let store = SessionRestoreStore(directoryURL: dir)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(#"{"schemaVersion":99,"futureField":"different-shape"}"#.utf8).write(to: store.snapshotURL)

        XCTAssertNil(try store.load())
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.snapshotURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.corruptSnapshotURL.path))
    }

    func testSaveReplacesExistingSnapshotAtomically() throws {
        let dir = try makeTempDir()
        let store = SessionRestoreStore(directoryURL: dir)
        let first = makeSnapshot(title: "first")
        let second = makeSnapshot(title: "second")

        try store.save(first)
        try store.save(second)

        XCTAssertEqual(try store.load()?.sessions.first?.title, "second")
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.temporarySnapshotURL.path))
    }

    func testClearRemovesExistingSnapshotAndIsIdempotent() throws {
        let dir = try makeTempDir()
        let store = SessionRestoreStore(directoryURL: dir)
        try store.save(makeSnapshot())

        try store.clear()
        try store.clear()

        XCTAssertFalse(store.hasValidSnapshot())
        XCTAssertNil(try store.load())
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.snapshotURL.path))
    }

    func testConcurrentSavesUseUniqueTemporaryFilesAndCleanUp() async throws {
        let dir = try makeTempDir()
        let store = SessionRestoreStore(directoryURL: dir)
        let snapshots = (0..<20).map { makeSnapshot(title: "concurrent-\($0)") }
        let tasks = snapshots.map { snapshot in
            Task.detached {
                try store.save(snapshot)
            }
        }

        for task in tasks {
            try await task.value
        }

        let loaded = try XCTUnwrap(try store.load())
        XCTAssertTrue(snapshots.contains(loaded))
        let temporaryFiles = try FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "tmp" }
        XCTAssertEqual(temporaryFiles, [])
    }

    private func makeSnapshot(title: String = "Local") -> SessionRestoreSnapshot {
        let sessionID = UUID()
        return SessionRestoreSnapshot.makeBounded(
            capturedAt: Date(timeIntervalSince1970: 1_779_340_800),
            selectedSessionID: sessionID,
            paneTree: "terminal",
            focusedPane: .terminal,
            activePanel: nil,
            sessions: [
                SessionRestoreEntry(
                    id: sessionID,
                    title: title,
                    kind: .localPTY,
                    profileReference: .local,
                    workingDirectory: "/tmp",
                    launch: .localShell(shellKind: "zsh", executable: "/bin/zsh", arguments: ["-l"]),
                    scrollback: [RestoredTerminalLine(role: .stdout, text: "hello")],
                    scrollbackBytes: 5,
                    lastExitCode: nil,
                    capturedAt: Date(timeIntervalSince1970: 1_779_340_801)
                )
            ]
        )
    }

    private func makeTempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-session-restore-store-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }
}
