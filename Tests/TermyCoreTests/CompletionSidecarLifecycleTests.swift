import XCTest
@testable import TermyCore

final class CompletionSidecarLifecycleTests: XCTestCase {
    private var workDir: URL!
    private var writeBuffer: WriteBuffer?
    private var captureBuffer: CaptureBuffer?

    override func setUpWithError() throws {
        workDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("termy-sidecar-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        writeBuffer = nil
        captureBuffer = nil
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: workDir)
    }

    private func makeSidecar() -> CompletionSidecar {
        let wb = WriteBuffer()
        let cb = CaptureBuffer()
        self.writeBuffer = wb
        self.captureBuffer = cb
        return CompletionSidecar(
            workDir: workDir,
            writer: { line in wb.append(line) },
            onEvent: { event in cb.append(event) }
        )
    }

    // Helpers for thread-safe accumulation across async actor boundaries.
    final class WriteBuffer: @unchecked Sendable {
        private var items: [String] = []
        private let lock = NSLock()
        func append(_ s: String) { lock.lock(); items.append(s); lock.unlock() }
        var snapshot: [String] { lock.lock(); defer { lock.unlock() }; return items }
    }
    final class CaptureBuffer: @unchecked Sendable {
        private var items: [CompletionSidecarResultWatcher.Event] = []
        private let lock = NSLock()
        func append(_ e: CompletionSidecarResultWatcher.Event) { lock.lock(); items.append(e); lock.unlock() }
        var snapshot: [CompletionSidecarResultWatcher.Event] { lock.lock(); defer { lock.unlock() }; return items }
    }

    private func writeFile(_ relative: String, _ contents: String) throws {
        try contents.write(
            to: workDir.appendingPathComponent(relative),
            atomically: false,
            encoding: .utf8
        )
    }

    // ----- state transitions -----

    func test_initialState_isBooting() async {
        let sidecar = makeSidecar()
        let state = await sidecar.state
        XCTAssertEqual(state, .booting)
    }

    func test_bootFlagConsumed_transitionsToReady() async throws {
        let sidecar = makeSidecar()
        try writeFile("__boot__.flag", "")
        await sidecar.pollResultsOnce()
        let state = await sidecar.state
        XCTAssertEqual(state, .ready)
        XCTAssertEqual(captureBuffer?.snapshot, [.boot])
    }

    // ----- query issuance -----

    func test_query_beforeReady_isQueued_thenFlushed() async throws {
        let sidecar = makeSidecar()
        await sidecar.query(buffer: "g", cursor: 1, cwd: "/tmp")
        XCTAssertEqual(writeBuffer?.snapshot.count, 0, "pre-ready queries must not flush")
        try writeFile("__boot__.flag", "")
        await sidecar.pollResultsOnce()
        XCTAssertEqual(writeBuffer?.snapshot.count, 1)
        XCTAssertTrue(writeBuffer?.snapshot.first?.hasPrefix("__termy_complete") ?? false)
    }

    func test_query_afterReady_writesImmediately() async throws {
        let sidecar = makeSidecar()
        try writeFile("__boot__.flag", "")
        await sidecar.pollResultsOnce()
        await sidecar.query(buffer: "git p", cursor: 5, cwd: "/tmp")
        XCTAssertEqual(writeBuffer?.snapshot.count, 1)
        XCTAssertTrue(writeBuffer?.snapshot[0].contains("__termy_complete") ?? false)
    }

    func test_consecutiveQueries_incrementReqId() async throws {
        let sidecar = makeSidecar()
        try writeFile("__boot__.flag", "")
        await sidecar.pollResultsOnce()
        await sidecar.query(buffer: "g", cursor: 1, cwd: "/tmp")
        await sidecar.query(buffer: "gi", cursor: 2, cwd: "/tmp")
        await sidecar.query(buffer: "git", cursor: 3, cwd: "/tmp")
        let lines = writeBuffer?.snapshot ?? []
        XCTAssertEqual(lines.count, 3)
        // Each line ends with " <reqId>\n"; reqIds are monotonic.
        let ids = lines.compactMap { line -> Int? in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            return Int(trimmed.split(separator: " ").last ?? "")
        }
        XCTAssertEqual(ids.count, 3)
        XCTAssertTrue(ids[0] < ids[1] && ids[1] < ids[2])
    }

    func test_preReadyQueue_coalesces_onlyLatestFlushes() async throws {
        let sidecar = makeSidecar()
        await sidecar.query(buffer: "a", cursor: 1, cwd: "/tmp")
        await sidecar.query(buffer: "ab", cursor: 2, cwd: "/tmp")
        await sidecar.query(buffer: "abc", cursor: 3, cwd: "/tmp")
        try writeFile("__boot__.flag", "")
        await sidecar.pollResultsOnce()
        let writes = writeBuffer?.snapshot ?? []
        XCTAssertEqual(writes.count, 1, "pre-ready queue must coalesce; only latest survives")
        // The decoded buffer in the flushed line is the latest ("abc").
        let parts = writes[0].split(separator: " ")
        if let b64 = parts.dropFirst().first.map(String.init),
           let data = Data(base64Encoded: b64),
           let decoded = String(data: data, encoding: .utf8) {
            XCTAssertEqual(decoded, "abc")
        } else {
            XCTFail("Could not decode flushed buffer")
        }
    }

    // ----- cd op -----

    func test_notifyCwd_writesCdOp() async throws {
        let sidecar = makeSidecar()
        try writeFile("__boot__.flag", "")
        await sidecar.pollResultsOnce()
        await sidecar.notifyCwd("/var/log")
        let writes = writeBuffer?.snapshot ?? []
        XCTAssertEqual(writes.count, 1)
        XCTAssertTrue(writes[0].hasPrefix("__termy_cd /var/log"))
    }

    func test_notifyCwd_beforeReady_dropped() async {
        let sidecar = makeSidecar()
        await sidecar.notifyCwd("/var")
        XCTAssertEqual(writeBuffer?.snapshot.count, 0, "cd op without ready state must drop")
    }

    // ----- result polling -----

    func test_resultFile_polled_emitsEvent() async throws {
        let sidecar = makeSidecar()
        try writeFile("__boot__.flag", "")
        try writeFile("req-7.tsv", "command\tpush\tgit push\tUpdate remote refs\n")
        await sidecar.pollResultsOnce()
        let events = captureBuffer?.snapshot ?? []
        XCTAssertEqual(events.count, 2, "boot + result")
        guard case let .result(id, items) = events[1] else {
            return XCTFail("Expected .result, got \(events[1])")
        }
        XCTAssertEqual(id, 7)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].title, "push")
    }

    // ----- crash threshold -----

    func test_oneCrash_respawnsBooting() async throws {
        let sidecar = makeSidecar()
        try writeFile("__boot__.flag", "")
        await sidecar.pollResultsOnce()
        await sidecar.simulateCrash()
        let state = await sidecar.state
        XCTAssertEqual(state, .booting)
    }

    func test_threeCrashes_within60s_disables() async throws {
        let sidecar = makeSidecar()
        try writeFile("__boot__.flag", "")
        await sidecar.pollResultsOnce()
        await sidecar.simulateCrash()
        await sidecar.simulateCrash()
        await sidecar.simulateCrash()
        let state = await sidecar.state
        XCTAssertEqual(state, .disabled)
    }

    // ----- terminate -----

    func test_terminate_setsDisabled_andStopsWrites() async throws {
        let sidecar = makeSidecar()
        try writeFile("__boot__.flag", "")
        await sidecar.pollResultsOnce()
        await sidecar.terminate()
        let state = await sidecar.state
        XCTAssertEqual(state, .disabled)
        await sidecar.query(buffer: "x", cursor: 1, cwd: "/tmp")
        XCTAssertEqual(writeBuffer?.snapshot.count, 0, "no writes after terminate")
    }

    func test_simulateCrash_whenDisabled_doesNotResurrect() async {
        let sidecar = makeSidecar()
        await sidecar.terminate()
        await sidecar.simulateCrash()
        let state = await sidecar.state
        XCTAssertEqual(state, .disabled, "Disabled sidecar must not be resurrected by a stray crash")
    }

    func test_terminate_removesWorkDir() async throws {
        let sidecar = makeSidecar()
        try writeFile("__boot__.flag", "")
        XCTAssertTrue(FileManager.default.fileExists(atPath: workDir.path))
        await sidecar.terminate()
        XCTAssertFalse(FileManager.default.fileExists(atPath: workDir.path),
                       "terminate() must remove its own workDir")
    }

    // ----- sweepStaleWorkDirs -----

    func test_sweepStaleWorkDirs_removesAllEntries_keepsParent() throws {
        let fm = FileManager.default
        let parent = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("termy-sweep-test-\(UUID().uuidString)")
        try fm.createDirectory(at: parent, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: parent) }

        for _ in 0..<3 {
            let sub = parent.appendingPathComponent(UUID().uuidString)
            try fm.createDirectory(at: sub, withIntermediateDirectories: true)
            try Data("# stale".utf8).write(to: sub.appendingPathComponent("__bootstrap__.zsh"))
        }
        XCTAssertEqual(try fm.contentsOfDirectory(atPath: parent.path).count, 3)

        CompletionSidecar.sweepStaleWorkDirs(in: parent)

        XCTAssertEqual(try fm.contentsOfDirectory(atPath: parent.path).count, 0,
                       "sweep must remove every entry")
        XCTAssertTrue(fm.fileExists(atPath: parent.path),
                      "sweep must keep the parent directory")
    }

    func test_sweepStaleWorkDirs_missingParent_isNoop() {
        let parent = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("termy-sweep-missing-\(UUID().uuidString)")
        CompletionSidecar.sweepStaleWorkDirs(in: parent)  // must not throw
    }

    // ----- production spawn -----

    func test_recentCrashCount_countsWithinWindow_andExpiresOutside() async {
        let sidecar = makeSidecar()
        var count = await sidecar.recentCrashCount(now: Date())
        XCTAssertEqual(count, 0)
        await sidecar.simulateCrash()
        await sidecar.simulateCrash()
        count = await sidecar.recentCrashCount(now: Date())
        XCTAssertEqual(count, 2)
        // A `now` 120 s in the future puts every crash outside the 60 s window.
        count = await sidecar.recentCrashCount(now: Date().addingTimeInterval(120))
        XCTAssertEqual(count, 0)
    }

    func test_spawn_withNonZshShell_returnsDisabled() async throws {
        let workDir = try FileManager.default.url(
            for: .itemReplacementDirectory,
            in: .userDomainMask,
            appropriateFor: URL(fileURLWithPath: "/tmp"),
            create: true
        )
        defer { try? FileManager.default.removeItem(at: workDir) }
        let sidecar = try CompletionSidecar.spawn(
            shellPath: "/bin/bash",  // not zsh
            zdotdir: nil,
            extraEnvironment: [:],
            cwd: "/tmp",
            workDir: workDir,
            onEvent: { _ in }
        )
        // makeImmediatelyDisabled uses initialState: .disabled — no async hop needed.
        let state = await sidecar.state
        XCTAssertEqual(state, .disabled,
                       "Non-zsh $SHELL must fail-closed to .disabled immediately")
    }
}
