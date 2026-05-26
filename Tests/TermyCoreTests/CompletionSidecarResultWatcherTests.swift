import XCTest
@testable import TermyCore

final class CompletionSidecarResultWatcherTests: XCTestCase {
    private var tmpDir: URL!

    override func setUpWithError() throws {
        tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("termy-watcher-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmpDir)
    }

    private func write(_ relative: String, _ contents: String) throws {
        try contents.write(
            to: tmpDir.appendingPathComponent(relative),
            atomically: false,
            encoding: .utf8
        )
    }

    // ----- happy paths -----

    func test_consume_bootFlag_emitsBoot() throws {
        try write("__boot__.flag", "")
        let events = CompletionSidecarResultWatcher.consumeResultFiles(in: tmpDir)
        XCTAssertEqual(events, [.boot])
    }

    func test_consume_resultTSV_emitsResultWithParsedItems() throws {
        try write("req-7.tsv", "command\tpush\tgit push\tUpdate remote refs\n")
        let events = CompletionSidecarResultWatcher.consumeResultFiles(in: tmpDir)
        XCTAssertEqual(events.count, 1)
        guard case let .result(id, items) = events[0] else {
            return XCTFail("Expected .result, got \(events[0])")
        }
        XCTAssertEqual(id, 7)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].title, "push")
        XCTAssertEqual(items[0].description, "Update remote refs")
    }

    func test_consume_errFile_emitsError() throws {
        try write("req-9.err", "err=bad-cwd\n")
        let events = CompletionSidecarResultWatcher.consumeResultFiles(in: tmpDir)
        XCTAssertEqual(events, [.error(id: 9, code: "bad-cwd")])
    }

    func test_consume_deletesProcessedFiles() throws {
        try write("__boot__.flag", "")
        try write("req-1.tsv", "command\ta\ta\t\n")
        try write("req-2.err", "err=internal\n")
        _ = CompletionSidecarResultWatcher.consumeResultFiles(in: tmpDir)
        let remaining = try FileManager.default.contentsOfDirectory(atPath: tmpDir.path)
        XCTAssertTrue(remaining.isEmpty, "All consumed files must be deleted; remaining: \(remaining)")
    }

    func test_consume_secondCall_returnsEmpty() throws {
        try write("req-1.tsv", "command\ta\ta\t\n")
        _ = CompletionSidecarResultWatcher.consumeResultFiles(in: tmpDir)
        let second = CompletionSidecarResultWatcher.consumeResultFiles(in: tmpDir)
        XCTAssertEqual(second, [])
    }

    func test_consume_multipleResultsInIdOrder() throws {
        try write("req-2.tsv", "command\tb\tb\t\n")
        try write("req-1.tsv", "command\ta\ta\t\n")
        try write("req-10.tsv", "command\tc\tc\t\n")
        let events = CompletionSidecarResultWatcher.consumeResultFiles(in: tmpDir)
        // Numeric, not lexical: 1, 2, 10 (not 1, 10, 2).
        let ids = events.compactMap { e -> Int? in
            if case let .result(id, _) = e { return id }
            return nil
        }
        XCTAssertEqual(ids, [1, 2, 10])
    }

    // ----- safety / skip paths -----

    func test_consume_tmpFile_isIgnored() throws {
        try write("req-1.tsv.tmp", "command\ta\ta\t\n")
        let events = CompletionSidecarResultWatcher.consumeResultFiles(in: tmpDir)
        XCTAssertEqual(events, [])
        let remaining = try FileManager.default.contentsOfDirectory(atPath: tmpDir.path)
        XCTAssertEqual(remaining, ["req-1.tsv.tmp"], "tmp must NOT be deleted — it's mid-write")
    }

    func test_consume_unrelatedFile_isIgnored() throws {
        try write("debris.log", "random")
        let events = CompletionSidecarResultWatcher.consumeResultFiles(in: tmpDir)
        XCTAssertEqual(events, [])
        let remaining = try FileManager.default.contentsOfDirectory(atPath: tmpDir.path)
        XCTAssertEqual(remaining, ["debris.log"], "unrelated files must NOT be deleted")
    }

    func test_consume_directoryDoesNotExist_returnsEmpty() {
        let missing = URL(fileURLWithPath: "/tmp/termy-nonexistent-\(UUID().uuidString)")
        let events = CompletionSidecarResultWatcher.consumeResultFiles(in: missing)
        XCTAssertEqual(events, [])
    }

    func test_consume_malformedReqFilename_isIgnored() throws {
        // Filename matches "req-" prefix but the id is not numeric.
        try write("req-abc.tsv", "command\ta\ta\t\n")
        let events = CompletionSidecarResultWatcher.consumeResultFiles(in: tmpDir)
        XCTAssertEqual(events, [])
        let remaining = try FileManager.default.contentsOfDirectory(atPath: tmpDir.path)
        XCTAssertEqual(remaining, ["req-abc.tsv"], "non-numeric id must NOT be consumed")
    }

    func test_consume_emptyResultFile_returnsZeroItems() throws {
        try write("req-1.tsv", "")
        let events = CompletionSidecarResultWatcher.consumeResultFiles(in: tmpDir)
        XCTAssertEqual(events.count, 1)
        if case let .result(_, items) = events[0] {
            XCTAssertEqual(items, [])
        } else {
            XCTFail("Expected .result with zero items")
        }
    }

    func test_consume_errFile_malformedBody_emitsErrorMalformedCode() throws {
        try write("req-3.err", "not-an-err-line\n")
        let events = CompletionSidecarResultWatcher.consumeResultFiles(in: tmpDir)
        XCTAssertEqual(events, [.error(id: 3, code: "malformed")])
        let remaining = try FileManager.default.contentsOfDirectory(atPath: tmpDir.path)
        XCTAssertTrue(remaining.isEmpty)
    }
}
