import XCTest
@testable import TermyCore

@MainActor
final class PaletteFrecencyStoreTests: XCTestCase {
    private var tempDir: URL!
    private var fileURL: URL!
    private var now = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUp() async throws {
        try await super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("CKS2-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        fileURL = tempDir.appendingPathComponent("palette-frecency.jsonl")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
        try await super.tearDown()
    }

    private func makeStore(cap: Int = 5_000, halfLifeDays: Double = 30) -> PaletteFrecencyStore {
        PaletteFrecencyStore(
            fileURL: fileURL,
            clock: { [unowned self] in self.now },
            halfLifeDays: halfLifeDays,
            cap: cap
        )
    }

    // MARK: - Empty / basic

    func test_freshFile_emptyScores() {
        let store = makeStore()
        XCTAssertTrue(store.scores().isEmpty)
        XCTAssertEqual(store.score(forID: "action-openSettings"), 0)
    }

    func test_record_emptyIDIgnored() {
        let store = makeStore()
        store.record(itemID: "")
        store.record(itemID: "   ")
        XCTAssertTrue(store.scores().isEmpty)
    }

    func test_record_trimsWhitespace() {
        let store = makeStore()
        store.record(itemID: "  action-foo  ")
        XCTAssertGreaterThan(store.score(forID: "action-foo"), 0)
        XCTAssertEqual(store.score(forID: "  action-foo  "), 0, "key is trimmed, not raw")
    }

    // MARK: - Persistence

    func test_recordAndFlush_writesJSONL() throws {
        let store = makeStore()
        store.record(itemID: "profile-1234")
        store.flushPendingWrites()
        let data = try Data(contentsOf: fileURL)
        let text = String(decoding: data, as: UTF8.self)
        let lines = text.split(separator: "\n").map(String.init)
        XCTAssertEqual(lines.count, 1)
        let entry = try JSONDecoder.ckPaletteFrecency.decode(PaletteFrecencyEntry.self, from: Data(lines[0].utf8))
        XCTAssertEqual(entry.id, "profile-1234")
        XCTAssertEqual(entry.count, 1)
    }

    func test_roundTrip_acrossStoreInstances() {
        let storeA = makeStore()
        storeA.record(itemID: "action-a")
        storeA.record(itemID: "action-a")
        storeA.record(itemID: "action-b")
        storeA.flushPendingWrites()

        let storeB = makeStore()
        XCTAssertEqual(Set(storeB.scores().keys), ["action-a", "action-b"])
        // Same age (same clock) → higher count wins.
        XCTAssertGreaterThan(storeB.score(forID: "action-a"), storeB.score(forID: "action-b"))
    }

    func test_appendOnly_latestEntryAuthoritative_beforeCompaction() {
        let store = makeStore()
        store.record(itemID: "action-x")
        store.flushPendingWrites()
        now = now.addingTimeInterval(60)
        store.record(itemID: "action-x")
        store.flushPendingWrites()

        let store2 = makeStore()
        XCTAssertEqual(store2.scores().count, 1)
        // count must be 2 (latest append wins), not reset to 1.
        let entry = PaletteFrecencyEntry(id: "action-x", lastUsedAt: now, count: 2)
        let expected = PaletteFrecencyStore.frecency(entry: entry, now: now, halfLifeDays: 30)
        XCTAssertEqual(store2.score(forID: "action-x", now: now), expected, accuracy: 1e-9)
    }

    func test_corruptionTolerance_truncatedTailLineSkipped() throws {
        let goodEntry = PaletteFrecencyEntry(id: "action-good", lastUsedAt: now, count: 1)
        let goodLine = try JSONEncoder.ckPaletteFrecency.encode(goodEntry)
        var payload = Data()
        payload.append(goodLine)
        payload.append(UInt8(ascii: "\n"))
        payload.append(contentsOf: Data("{\"id\":\"action-bad\",\"lastUsed".utf8))  // truncated
        try payload.write(to: fileURL)

        let store = makeStore()
        XCTAssertEqual(Set(store.scores().keys), ["action-good"])

        store.flushPendingWrites()
        let text = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertFalse(text.contains("{\"id\":\"action-bad\",\"lastUsed"), "truncated tail must be gone after compaction")
    }

    func test_compaction_triggeredAtThreshold() throws {
        let store = makeStore()
        // Two unique ids, each recorded four times — 8 appends but only 2 unique.
        for _ in 0..<4 {
            store.record(itemID: "action-a")
            now = now.addingTimeInterval(1)
            store.record(itemID: "action-b")
            now = now.addingTimeInterval(1)
        }
        store.flushPendingWrites()
        let text = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        XCTAssertLessThanOrEqual(lines.count, 2, "after compaction one line per unique id")
    }

    func test_flushPendingWrites_compactsCanonical() throws {
        let store = makeStore()
        store.record(itemID: "action-a")
        now = now.addingTimeInterval(60)
        store.record(itemID: "action-a")  // supersedes the first append
        store.flushPendingWrites()
        let text = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        XCTAssertEqual(lines.count, 1)
        let entry = try JSONDecoder.ckPaletteFrecency.decode(PaletteFrecencyEntry.self, from: Data(lines[0].utf8))
        XCTAssertEqual(entry.count, 2)
    }

    // MARK: - Eviction

    func test_eviction_dropsLowestFrecencyOverCap() {
        let store = makeStore(cap: 2)
        // Three distinct ids. "old" is recorded first then aged so it decays below
        // the two fresh ones, which keep getting recorded at the current clock.
        store.record(itemID: "agent-old")
        now = now.addingTimeInterval(60 * 86_400)  // 2 half-lives later
        store.record(itemID: "agent-fresh1")
        store.record(itemID: "agent-fresh2")  // cap=2 exceeded → evict lowest (old)

        let keys = Set(store.scores().keys)
        XCTAssertEqual(keys, ["agent-fresh1", "agent-fresh2"])
        XCTAssertFalse(keys.contains("agent-old"))
    }

    // MARK: - Frecency math

    func test_frecency_higherCountRanksHigher_sameAge() {
        let a = PaletteFrecencyEntry(id: "a", lastUsedAt: now, count: 5)
        let b = PaletteFrecencyEntry(id: "b", lastUsedAt: now, count: 1)
        let sa = PaletteFrecencyStore.frecency(entry: a, now: now, halfLifeDays: 30)
        let sb = PaletteFrecencyStore.frecency(entry: b, now: now, halfLifeDays: 30)
        XCTAssertGreaterThan(sa, sb)
    }

    func test_frecency_olderRanksLower_sameCount() {
        let recent = PaletteFrecencyEntry(id: "r", lastUsedAt: now, count: 3)
        let old = PaletteFrecencyEntry(id: "o", lastUsedAt: now.addingTimeInterval(-30 * 86_400), count: 3)
        let sr = PaletteFrecencyStore.frecency(entry: recent, now: now, halfLifeDays: 30)
        let so = PaletteFrecencyStore.frecency(entry: old, now: now, halfLifeDays: 30)
        XCTAssertGreaterThan(sr, so)
    }

    func test_frecency_halfLifeHalvesScore() {
        let entry = PaletteFrecencyEntry(id: "h", lastUsedAt: now, count: 4)
        let full = PaletteFrecencyStore.frecency(entry: entry, now: now, halfLifeDays: 30)
        let halved = PaletteFrecencyStore.frecency(
            entry: entry, now: now.addingTimeInterval(30 * 86_400), halfLifeDays: 30
        )
        XCTAssertEqual(halved, full / 2, accuracy: 1e-9)
    }

    func test_frecency_futureClampedToZeroAge() {
        // A stamp slightly in the future (clock skew) must not exceed a now-stamp.
        let entry = PaletteFrecencyEntry(id: "f", lastUsedAt: now.addingTimeInterval(120), count: 1)
        let score = PaletteFrecencyStore.frecency(entry: entry, now: now, halfLifeDays: 30)
        XCTAssertEqual(score, 1.0, accuracy: 1e-9, "negative age clamps to 0 → decay 1.0")
    }

    func test_scores_matchesPerIDScore() {
        let store = makeStore()
        store.record(itemID: "action-a")
        store.record(itemID: "action-a")
        store.record(itemID: "agent-b")
        let snap = store.scores(now: now)
        XCTAssertEqual(snap["action-a"], store.score(forID: "action-a", now: now))
        XCTAssertEqual(snap["agent-b"], store.score(forID: "agent-b", now: now))
    }
}
