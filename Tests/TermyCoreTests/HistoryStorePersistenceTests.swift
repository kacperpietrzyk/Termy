import XCTest
@testable import TermyCore

@MainActor
final class HistoryStorePersistenceTests: XCTestCase {
    private var tempDir: URL!
    private var fileURL: URL!
    private var markerURL: URL!
    private var now = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUp() async throws {
        try await super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("F2Persist-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        fileURL = tempDir.appendingPathComponent("history.jsonl")
        markerURL = tempDir.appendingPathComponent(".history-imported")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
        try await super.tearDown()
    }

    private func makeStore(cap: Int = 10_000) -> HistoryStore {
        HistoryStore(
            fileURL: fileURL,
            markerURL: markerURL,
            clock: { [unowned self] in self.now },
            cwdMatchBoost: 2.0,
            halfLifeDays: 30,
            cap: cap,
            zshHistoryURL: nil
        )
    }

    func test_freshFile_emptyStore() {
        let store = makeStore()
        XCTAssertEqual(store.rankedSnapshot(forCwd: nil), [])
    }

    func test_recordAndFlush_writesJSONL() throws {
        let store = makeStore()
        store.record(command: "git status", cwd: "/A")
        store.flushPendingWrites()
        let data = try Data(contentsOf: fileURL)
        let text = String(decoding: data, as: UTF8.self)
        let lines = text.split(separator: "\n").map(String.init)
        XCTAssertEqual(lines.count, 1)
        let entry = try JSONDecoder.f2_history.decode(HistoryEntry.self, from: Data(lines[0].utf8))
        XCTAssertEqual(entry.cmd, "git status")
        XCTAssertEqual(entry.count, 1)
        XCTAssertEqual(entry.cwdCounts, ["/A": 1])
    }

    func test_roundTrip_acrossStoreInstances() {
        let storeA = makeStore()
        storeA.record(command: "ls", cwd: "/A")
        storeA.record(command: "ls", cwd: "/A")
        storeA.record(command: "cd ~", cwd: "/B")
        storeA.flushPendingWrites()

        let storeB = makeStore()
        let ranked = Set(storeB.rankedSnapshot(forCwd: nil))
        XCTAssertEqual(ranked, ["ls", "cd ~"])
        XCTAssertEqual(storeB.rankedSnapshot(forCwd: "/A").first, "ls")
    }

    func test_appendOnly_keepsLatestEntryAuthoritative_beforeCompaction() throws {
        let store = makeStore()
        store.record(command: "ls", cwd: "/A")
        store.flushPendingWrites()
        now = now.addingTimeInterval(60)
        store.record(command: "ls", cwd: "/A")
        store.flushPendingWrites()

        let text = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        XCTAssertGreaterThanOrEqual(lines.count, 1, "either two appends, or one compacted line")

        let store2 = makeStore()
        store2.record(command: "lz", cwd: nil)
        XCTAssertEqual(store2.rankedSnapshot(forCwd: nil).first, "ls", "ls used twice must out-rank single-use lz")
    }

    func test_corruptionTolerance_truncatedTailLineSkipped() throws {
        let goodEntry = HistoryEntry(
            cmd: "git status",
            lastUsedAt: Date(timeIntervalSince1970: 1_700_000_000),
            count: 1,
            cwdCounts: [:]
        )
        let goodLine = try JSONEncoder.f2_history.encode(goodEntry)
        var payload = Data()
        payload.append(goodLine)
        payload.append(UInt8(ascii: "\n"))
        payload.append(contentsOf: Data("{\"cmd\":\"ls\",\"lastUsed".utf8))  // truncated
        try payload.write(to: fileURL)

        let store = makeStore()
        XCTAssertEqual(store.rankedSnapshot(forCwd: nil), ["git status"])

        store.flushPendingWrites()
        let text = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertFalse(text.contains("{\"cmd\":\"ls\",\"lastUsed"), "truncated tail must be gone after compaction")
    }

    func test_compaction_triggeredAtThreshold() throws {
        let store = makeStore()
        // Two unique commands, each appended four times — 8 lines but only 2 unique.
        for _ in 0..<4 {
            store.record(command: "ls", cwd: nil)
            now = now.addingTimeInterval(1)
            store.record(command: "pwd", cwd: nil)
            now = now.addingTimeInterval(1)
        }
        store.flushPendingWrites()
        let text = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        XCTAssertLessThanOrEqual(lines.count, 2, "after compaction the file holds one line per unique cmd")
    }

    func test_flushPendingWrites_compactsCanonical() throws {
        let store = makeStore()
        store.record(command: "a", cwd: nil)
        now = now.addingTimeInterval(60)
        store.record(command: "a", cwd: nil)  // supersedes the first append
        store.flushPendingWrites()
        let text = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        XCTAssertEqual(lines.count, 1)
        let entry = try JSONDecoder.f2_history.decode(HistoryEntry.self, from: Data(lines[0].utf8))
        XCTAssertEqual(entry.count, 2)
    }

    func test_zshImport_seedsOnFirstInit() throws {
        let zshURL = tempDir.appendingPathComponent(".zsh_history")
        try ": 1700000000:0;git status\npwd\n".write(to: zshURL, atomically: true, encoding: .utf8)
        let store = HistoryStore(
            fileURL: fileURL,
            markerURL: markerURL,
            clock: { Date(timeIntervalSince1970: 1_700_500_000) },
            cwdMatchBoost: 2,
            halfLifeDays: 30,
            cap: 10_000,
            zshHistoryURL: zshURL
        )
        XCTAssertEqual(Set(store.rankedSnapshot(forCwd: nil)), ["git status", "pwd"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: markerURL.path), "marker must be written")
    }

    func test_zshImport_idempotent_markerSkipsReimport() throws {
        let zshURL = tempDir.appendingPathComponent(".zsh_history")
        try "git status\n".write(to: zshURL, atomically: true, encoding: .utf8)
        _ = HistoryStore(
            fileURL: fileURL,
            markerURL: markerURL,
            clock: { Date(timeIntervalSince1970: 1_700_500_000) },
            cwdMatchBoost: 2, halfLifeDays: 30, cap: 10_000,
            zshHistoryURL: zshURL
        )
        try "completely-different\n".write(to: zshURL, atomically: true, encoding: .utf8)
        let store2 = HistoryStore(
            fileURL: fileURL,
            markerURL: markerURL,
            clock: { Date(timeIntervalSince1970: 1_700_500_000) },
            cwdMatchBoost: 2, halfLifeDays: 30, cap: 10_000,
            zshHistoryURL: zshURL
        )
        XCTAssertEqual(Set(store2.rankedSnapshot(forCwd: nil)), ["git status"])
    }

    func test_zshImport_missingFile_writesMarkerAnyway() {
        let nonexistent = tempDir.appendingPathComponent("does-not-exist")
        _ = HistoryStore(
            fileURL: fileURL,
            markerURL: markerURL,
            clock: { Date(timeIntervalSince1970: 1_700_500_000) },
            cwdMatchBoost: 2, halfLifeDays: 30, cap: 10_000,
            zshHistoryURL: nonexistent
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: markerURL.path))
    }

    func test_zshImport_nilURL_doesNotWriteMarker() {
        _ = HistoryStore(
            fileURL: fileURL,
            markerURL: markerURL,
            clock: { Date(timeIntervalSince1970: 1_700_500_000) },
            cwdMatchBoost: 2, halfLifeDays: 30, cap: 10_000,
            zshHistoryURL: nil
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: markerURL.path))
    }
}
