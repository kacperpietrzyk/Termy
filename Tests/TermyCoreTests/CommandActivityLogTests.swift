import XCTest
@testable import TermyCore

@MainActor
final class CommandActivityLogTests: XCTestCase {
    private var fileURL: URL!

    override func setUpWithError() throws {
        fileURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("termy-cmdlog-\(UUID().uuidString).json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: fileURL)
    }

    func test_recordIncrementsToday() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let log = CommandActivityLog(fileURL: fileURL, clock: { now })
        XCTAssertEqual(log.commandsToday(now: now), 0)
        log.record(at: now)
        log.record(at: now)
        XCTAssertEqual(log.commandsToday(now: now), 2)
    }

    func test_separateDaysAreSeparateBuckets() {
        let day1 = Date(timeIntervalSince1970: 1_780_000_000)
        let day2 = day1.addingTimeInterval(48 * 3600)
        let log = CommandActivityLog(fileURL: fileURL, clock: { day2 })
        log.record(at: day1)
        log.record(at: day2)
        XCTAssertEqual(log.commandsToday(now: day1), 1)
        XCTAssertEqual(log.commandsToday(now: day2), 1)
    }

    func test_persistenceRoundTrip() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let log = CommandActivityLog(fileURL: fileURL, clock: { now })
        log.record(at: now)
        log.record(at: now)
        log.flushPendingWrites()

        let reloaded = CommandActivityLog(fileURL: fileURL, clock: { now })
        XCTAssertEqual(reloaded.commandsToday(now: now), 2)
    }

    func test_pruneDropsBucketsBeyondRetention() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let old = now.addingTimeInterval(-100 * 24 * 3600)
        let log = CommandActivityLog(fileURL: fileURL, clock: { now }, retentionDays: 35)
        log.record(at: old)
        log.record(at: now)
        log.flushPendingWrites()

        let reloaded = CommandActivityLog(fileURL: fileURL, clock: { now })
        XCTAssertEqual(reloaded.commandsToday(now: now), 1)
        XCTAssertEqual(reloaded.commandsToday(now: old), 0)
    }
}
