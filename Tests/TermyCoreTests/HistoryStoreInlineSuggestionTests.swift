import XCTest
@testable import TermyCore

@MainActor
final class HistoryStoreInlineSuggestionTests: XCTestCase {
    private var tempDir: URL!
    private var fileURL: URL!
    private var now = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUp() async throws {
        try await super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("F2Tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        fileURL = tempDir.appendingPathComponent("history.jsonl")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
        try await super.tearDown()
    }

    private func makeStore() -> HistoryStore {
        HistoryStore(
            fileURL: fileURL,
            markerURL: tempDir.appendingPathComponent(".history-imported"),
            clock: { [unowned self] in self.now },
            cwdMatchBoost: 2.0,
            halfLifeDays: 30,
            cap: 10_000,
            zshHistoryURL: nil
        )
    }

    func test_record_firstTime_createsEntry() {
        let store = makeStore()
        store.record(command: "git status", cwd: "/A")
        XCTAssertEqual(store.rankedSnapshot(forCwd: nil), ["git status"])
    }

    func test_record_blank_isIgnored() {
        let store = makeStore()
        store.record(command: "   ", cwd: "/A")
        store.record(command: "", cwd: "/A")
        XCTAssertEqual(store.rankedSnapshot(forCwd: nil), [])
    }

    func test_record_repeat_incrementsCountAndUpdatesTime() {
        let store = makeStore()
        store.record(command: "ls", cwd: "/A")
        now = now.addingTimeInterval(60)
        store.record(command: "ls", cwd: "/B")
        store.record(command: "ls", cwd: "/A")
        XCTAssertEqual(store.rankedSnapshot(forCwd: nil), ["ls"])
        store.record(command: "lsblk", cwd: "/A")
        let ranked = store.rankedSnapshot(forCwd: nil)
        XCTAssertEqual(ranked.first, "ls")
        XCTAssertTrue(ranked.contains("lsblk"))
    }

    func test_rankedSnapshot_orderedByFrecency_recentBeatsOld() {
        let store = makeStore()
        store.record(command: "old", cwd: nil)
        now = now.addingTimeInterval(60 * 86_400)
        store.record(command: "fresh", cwd: nil)
        let ranked = store.rankedSnapshot(forCwd: nil)
        XCTAssertEqual(ranked, ["fresh", "old"])
    }

    func test_rankedSnapshot_cwdBoost_promotesMatchingEntry() {
        let store = makeStore()
        store.record(command: "noCwd", cwd: nil)
        store.record(command: "atA", cwd: "/A")
        store.record(command: "noCwd", cwd: nil)
        store.record(command: "atA", cwd: "/A")
        let withCwd = store.rankedSnapshot(forCwd: "/A")
        XCTAssertEqual(withCwd.first, "atA", "cwd boost must promote /A entry above /A=nil entry")
    }

    func test_inlineSuggestion_returnsHighestScoringPrefixMatch() {
        let store = makeStore()
        store.record(command: "git status", cwd: nil)
        store.record(command: "git push origin main", cwd: nil)
        store.record(command: "git status", cwd: nil)
        let s = store.inlineSuggestion(for: "git", cwd: nil)
        XCTAssertEqual(s?.replacement, "git status")
        XCTAssertEqual(s?.ghostText, " status")
    }

    func test_inlineSuggestion_ignoresEntriesShorterOrEqualToInput() {
        let store = makeStore()
        store.record(command: "ls", cwd: nil)
        XCTAssertNil(store.inlineSuggestion(for: "ls", cwd: nil))
        XCTAssertNil(store.inlineSuggestion(for: "lsblk", cwd: nil))
    }

    func test_inlineSuggestion_caseInsensitivePrefix() {
        let store = makeStore()
        store.record(command: "Git Status", cwd: nil)
        let s = store.inlineSuggestion(for: "git", cwd: nil)
        XCTAssertEqual(s?.replacement, "Git Status")
    }

    func test_inlineSuggestion_emptyInput_returnsNil() {
        let store = makeStore()
        store.record(command: "anything", cwd: nil)
        XCTAssertNil(store.inlineSuggestion(for: "", cwd: nil))
    }

    func test_inlineSuggestion_cwdBoostPicksMatchingEntry() {
        let store = makeStore()
        store.record(command: "git status", cwd: "/A")
        store.record(command: "git stash", cwd: "/B")
        let s = store.inlineSuggestion(for: "git st", cwd: "/A")
        XCTAssertEqual(s?.replacement, "git status")
    }

    func test_eviction_atCap_dropsLowestBaseFrecency() {
        let store = HistoryStore(
            fileURL: fileURL,
            markerURL: tempDir.appendingPathComponent(".history-imported"),
            clock: { [unowned self] in self.now },
            cwdMatchBoost: 2.0,
            halfLifeDays: 30,
            cap: 3,
            zshHistoryURL: nil
        )
        // Three entries at distinct times so frecency ordering is unambiguous.
        now = Date(timeIntervalSince1970: 1_700_000_000)
        store.record(command: "veryOld", cwd: nil)
        now = now.addingTimeInterval(86_400)
        store.record(command: "old", cwd: nil)
        now = now.addingTimeInterval(86_400)
        store.record(command: "recent", cwd: nil)
        XCTAssertEqual(Set(store.rankedSnapshot(forCwd: nil)), ["veryOld", "old", "recent"])
        // 4th forces eviction of lowest base frecency = "veryOld".
        now = now.addingTimeInterval(86_400)
        store.record(command: "newest", cwd: nil)
        XCTAssertEqual(Set(store.rankedSnapshot(forCwd: nil)), ["old", "recent", "newest"])
    }

    func test_eviction_ignoresCwdBoost() {
        // Eviction must be deterministic w.r.t. on-disk state. Boosts are query-time.
        let store = HistoryStore(
            fileURL: fileURL,
            markerURL: tempDir.appendingPathComponent(".history-imported"),
            clock: { [unowned self] in self.now },
            cwdMatchBoost: 2.0,
            halfLifeDays: 30,
            cap: 2,
            zshHistoryURL: nil
        )
        now = Date(timeIntervalSince1970: 1_700_000_000)
        store.record(command: "old_at_A", cwd: "/A")
        now = now.addingTimeInterval(86_400)
        store.record(command: "recent_at_B", cwd: "/B")
        now = now.addingTimeInterval(86_400)
        store.record(command: "newest_no_cwd", cwd: nil)
        // Even though "/A" is the boost cwd, eviction must drop "old_at_A" (lowest base score).
        XCTAssertEqual(Set(store.rankedSnapshot(forCwd: "/A")), ["recent_at_B", "newest_no_cwd"])
    }
}
