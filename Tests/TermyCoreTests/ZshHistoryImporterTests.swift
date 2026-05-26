import XCTest
@testable import TermyCore

final class ZshHistoryImporterTests: XCTestCase {
    func test_parse_extendedFormat_singleLine() {
        let lines = [": 1709123456:0;git status"]
        let parsed = ZshHistoryImporter.parse(lines: lines, fallbackTime: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(parsed, [
            .init(command: "git status", timestamp: Date(timeIntervalSince1970: 1_709_123_456))
        ])
    }

    func test_parse_plainFormat() {
        let lines = ["git status"]
        let fallback = Date(timeIntervalSince1970: 1_700_000_000)
        let parsed = ZshHistoryImporter.parse(lines: lines, fallbackTime: fallback)
        XCTAssertEqual(parsed, [.init(command: "git status", timestamp: fallback)])
    }

    func test_parse_mixedFormats() {
        let fallback = Date(timeIntervalSince1970: 0)
        let parsed = ZshHistoryImporter.parse(
            lines: [
                ": 1709123456:0;ls",
                "pwd",
                ": 1709123457:5;cd ~"
            ],
            fallbackTime: fallback
        )
        XCTAssertEqual(parsed.count, 3)
        XCTAssertEqual(parsed[0].command, "ls")
        XCTAssertEqual(parsed[1].command, "pwd")
        XCTAssertEqual(parsed[1].timestamp, fallback)
        XCTAssertEqual(parsed[2].command, "cd ~")
    }

    func test_parse_skipsBlankAndCommentLines() {
        let parsed = ZshHistoryImporter.parse(
            lines: ["", "   ", "git status"],
            fallbackTime: Date(timeIntervalSince1970: 0)
        )
        XCTAssertEqual(parsed.map(\.command), ["git status"])
    }

    func test_aggregate_dedupesAndCountsAndCapsCount() {
        let fallback = Date(timeIntervalSince1970: 0)
        let parsed: [ZshHistoryImporter.Record] = (0..<60).map { _ in
            .init(command: "ls", timestamp: Date(timeIntervalSince1970: 1_000))
        } + [
            .init(command: "pwd", timestamp: Date(timeIntervalSince1970: 2_000))
        ]
        let aggregated = ZshHistoryImporter.aggregate(records: parsed, fallbackTime: fallback)
        XCTAssertEqual(aggregated.count, 2)
        let lsEntry = aggregated.first { $0.cmd == "ls" }!
        XCTAssertEqual(lsEntry.count, 50, "count capped at 50")
        XCTAssertEqual(lsEntry.lastUsedAt, Date(timeIntervalSince1970: 1_000))
        XCTAssertEqual(lsEntry.cwdCounts, [:])
    }

    func test_aggregate_lastUsedAtIsMaxOfTimestamps() {
        let entries = ZshHistoryImporter.aggregate(records: [
            .init(command: "ls", timestamp: Date(timeIntervalSince1970: 1_000)),
            .init(command: "ls", timestamp: Date(timeIntervalSince1970: 3_000)),
            .init(command: "ls", timestamp: Date(timeIntervalSince1970: 2_000))
        ], fallbackTime: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(entries.first?.lastUsedAt, Date(timeIntervalSince1970: 3_000))
    }

    func test_tailBound_lastNLines() {
        let lines = (0..<15_000).map { "cmd\($0)" }
        let tail = ZshHistoryImporter.tail(lines: lines, limit: 10_000)
        XCTAssertEqual(tail.count, 10_000)
        XCTAssertEqual(tail.first, "cmd5000")
        XCTAssertEqual(tail.last, "cmd14999")
    }
}
