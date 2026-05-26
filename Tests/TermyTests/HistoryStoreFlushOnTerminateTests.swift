import XCTest
import AppKit
@testable import Termy
@testable import TermyCore

@MainActor
final class HistoryStoreFlushOnTerminateTests: XCTestCase {
    func test_willTerminateNotification_compactsHistoryFile() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("F2Quit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("history.jsonl")
        let markerURL = tempDir.appendingPathComponent(".history-imported")
        let store = HistoryStore(
            fileURL: fileURL,
            markerURL: markerURL,
            clock: Date.init,
            cwdMatchBoost: 2, halfLifeDays: 30, cap: 10_000,
            zshHistoryURL: nil
        )
        // Install the observer the same way TermyStore.init does.
        var observer: NSObjectProtocol?
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: nil
        ) { _ in
            MainActor.assumeIsolated { store.flushPendingWrites() }
        }
        defer { if let observer { NotificationCenter.default.removeObserver(observer) } }

        store.record(command: "ls", cwd: nil)
        // File is not necessarily written yet (background queue).
        NotificationCenter.default.post(name: NSApplication.willTerminateNotification, object: nil)

        let text = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        XCTAssertEqual(lines.count, 1)
        let entry = try JSONDecoder.f2_history.decode(HistoryEntry.self, from: Data(lines[0].utf8))
        XCTAssertEqual(entry.cmd, "ls")
    }

    // Regression guard: verifies TermyStore.init itself installs the observer
    // (the previous test only proves the pattern works in isolation). Without
    // this, a silent removal of the install in TermyStore.init would still
    // leave the prior test green.
    func test_termyStore_installsWillTerminateObserver_andFlushes() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("F2QuitWire-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("history.jsonl")
        let markerURL = tempDir.appendingPathComponent(".history-imported")
        let isolatedStore = HistoryStore(
            fileURL: fileURL,
            markerURL: markerURL,
            zshHistoryURL: nil
        )
        let restoreStore = SessionRestoreStore(
            directoryURL: tempDir.appendingPathComponent("session-restore", isDirectory: true)
        )
        // Inject the isolated store into a real TermyStore so its init runs
        // the production observer install path.
        let termyStore = TermyStore(
            startInitialPTY: false,
            historyStore: isolatedStore,
            sessionRestoreStore: restoreStore
        )
        isolatedStore.record(command: "production-wired", cwd: nil)

        withExtendedLifetime(termyStore) {
            NotificationCenter.default.post(name: NSApplication.willTerminateNotification, object: nil)
        }

        let text = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        XCTAssertEqual(lines.count, 1, "TermyStore.init must install the willTerminate observer that flushes the store")
        let entry = try JSONDecoder.f2_history.decode(HistoryEntry.self, from: Data(lines[0].utf8))
        XCTAssertEqual(entry.cmd, "production-wired")
    }
}
