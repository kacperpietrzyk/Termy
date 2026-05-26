import XCTest
@testable import TermyCore

final class HistoryStoreFrecencyTests: XCTestCase {
    private let reference = Date(timeIntervalSince1970: 1_700_000_000)

    private func entry(
        cmd: String = "git status",
        count: Int = 1,
        lastUsedAt: Date,
        cwdCounts: [String: Int] = [:]
    ) -> HistoryEntry {
        HistoryEntry(cmd: cmd, lastUsedAt: lastUsedAt, count: count, cwdCounts: cwdCounts)
    }

    func test_score_usedToday_count1_noCwd() {
        let e = entry(lastUsedAt: reference)
        XCTAssertEqual(
            HistoryStore.frecency(entry: e, now: reference, currentCwd: nil, halfLifeDays: 30, cwdMatchBoost: 2),
            1.0,
            accuracy: 1e-9
        )
    }

    func test_score_used30DaysAgo_count1_halvesAtHalfLife() {
        let e = entry(lastUsedAt: reference.addingTimeInterval(-30 * 86_400))
        XCTAssertEqual(
            HistoryStore.frecency(entry: e, now: reference, currentCwd: nil, halfLifeDays: 30, cwdMatchBoost: 2),
            0.5,
            accuracy: 1e-9
        )
    }

    func test_score_used60DaysAgo_count1_quarter() {
        let e = entry(lastUsedAt: reference.addingTimeInterval(-60 * 86_400))
        XCTAssertEqual(
            HistoryStore.frecency(entry: e, now: reference, currentCwd: nil, halfLifeDays: 30, cwdMatchBoost: 2),
            0.25,
            accuracy: 1e-9
        )
    }

    func test_score_cwdBoost_appliesWhenCurrentCwdInCounts() {
        let e = entry(lastUsedAt: reference, cwdCounts: ["/A": 1])
        let scoreA = HistoryStore.frecency(entry: e, now: reference, currentCwd: "/A", halfLifeDays: 30, cwdMatchBoost: 2)
        let scoreOther = HistoryStore.frecency(entry: e, now: reference, currentCwd: "/B", halfLifeDays: 30, cwdMatchBoost: 2)
        XCTAssertEqual(scoreA, 2.0, accuracy: 1e-9)
        XCTAssertEqual(scoreOther, 1.0, accuracy: 1e-9)
    }

    func test_score_cwdBoost_skippedWhenCurrentCwdNil() {
        let e = entry(lastUsedAt: reference, cwdCounts: ["/A": 1])
        XCTAssertEqual(
            HistoryStore.frecency(entry: e, now: reference, currentCwd: nil, halfLifeDays: 30, cwdMatchBoost: 2),
            1.0,
            accuracy: 1e-9
        )
    }

    func test_score_futureLastUsedAt_clampsAgeToZero() {
        let e = entry(lastUsedAt: reference.addingTimeInterval(86_400))  // tomorrow
        XCTAssertEqual(
            HistoryStore.frecency(entry: e, now: reference, currentCwd: nil, halfLifeDays: 30, cwdMatchBoost: 2),
            1.0,
            accuracy: 1e-9
        )
    }

    func test_score_count_multipliesLinearly() {
        let e = entry(count: 5, lastUsedAt: reference)
        XCTAssertEqual(
            HistoryStore.frecency(entry: e, now: reference, currentCwd: nil, halfLifeDays: 30, cwdMatchBoost: 2),
            5.0,
            accuracy: 1e-9
        )
    }
}
