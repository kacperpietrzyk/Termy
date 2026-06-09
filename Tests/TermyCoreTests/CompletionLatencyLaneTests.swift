import XCTest
@testable import TermyCore

final class CompletionLatencyLaneTests: XCTestCase {

    // MARK: - Cache key windowing

    func testKeyClampsPrefixTailAndSuffixHead() {
        let prefix = String(repeating: "a", count: 300) + "TAIL"
        let suffix = "HEAD" + String(repeating: "b", count: 300)
        let key = CompletionLatencyLane.Key(
            prefix: prefix,
            suffix: suffix,
            cwd: "/tmp",
            completionModel: "qwen2.5-coder",
            prefixWindow: 8,
            suffixWindow: 8
        )
        XCTAssertEqual(key.prefixTail, "aaaaTAIL")
        XCTAssertEqual(key.suffixHead, "HEADbbbb")
        XCTAssertEqual(key.cwd, "/tmp")
        XCTAssertEqual(key.completionModel, "qwen2.5-coder")
    }

    func testKeyEqualityIgnoresFarAwayBufferEdits() {
        let a = CompletionLatencyLane.Key(
            prefix: "xxxxxxxx" + "tail", suffix: "head" + "yyyyyyyy",
            cwd: "/p", completionModel: "m", prefixWindow: 4, suffixWindow: 4
        )
        let b = CompletionLatencyLane.Key(
            prefix: "ZZZZ" + "tail", suffix: "head" + "WWWW",
            cwd: "/p", completionModel: "m", prefixWindow: 4, suffixWindow: 4
        )
        XCTAssertEqual(a, b)
    }

    func testKeyDiffersByCwdAndModel() {
        let base = CompletionLatencyLane.Key(prefixTail: "t", suffixHead: "h", cwd: "/a", completionModel: "m")
        XCTAssertNotEqual(base, CompletionLatencyLane.Key(prefixTail: "t", suffixHead: "h", cwd: "/b", completionModel: "m"))
        XCTAssertNotEqual(base, CompletionLatencyLane.Key(prefixTail: "t", suffixHead: "h", cwd: "/a", completionModel: "n"))
    }

    // MARK: - Cache-first

    func testCacheHitReturnsWithoutDebounceOrOperation() async {
        let clock = ManualSleepClock()
        let lane = CompletionLatencyLane(
            debounce: .milliseconds(225), timeout: .seconds(10), clock: clock
        )
        let key = CompletionLatencyLane.Key(prefixTail: "p", suffixHead: "s", cwd: "/c", completionModel: "m")

        // Prime the cache via a full run. This parks two sleepers: the debounce
        // sleep, then the timeout sleep inside the operation race.
        async let primed = lane.run(key: key) { "value" }
        await clock.waitForSleepers(count: 1)
        await clock.advance(.milliseconds(225)) // release debounce; op is sync → completes
        let first = await primed
        XCTAssertEqual(first, "value")
        let sleepersAfterPrime = await clock.totalSleepers

        // Second call: cache hit, must NOT park any new sleeper and must NOT call op.
        let opCalls = Counter()
        let second = await lane.run(key: key) {
            await opCalls.increment()
            return "fresh"
        }
        XCTAssertEqual(second, "value")
        let opCallCount = await opCalls.value
        XCTAssertEqual(opCallCount, 0)
        let sleeperCount = await clock.totalSleepers
        XCTAssertEqual(sleeperCount, sleepersAfterPrime, "Cache hit must not park any new sleeper")
    }

    // MARK: - Debounce supersession (trailing edge)

    func testRapidCallsSupersedeAndOnlyLastRuns() async {
        let clock = ManualSleepClock()
        let lane = CompletionLatencyLane(
            debounce: .milliseconds(225), timeout: .seconds(10), clock: clock
        )
        let opCalls = Counter()

        @Sendable func keyFor(_ s: String) -> CompletionLatencyLane.Key {
            CompletionLatencyLane.Key(prefixTail: s, suffixHead: "", cwd: "/c", completionModel: "m")
        }

        async let r1 = lane.run(key: keyFor("a")) { await opCalls.increment(); return "A" }
        await clock.waitForSleepers(count: 1)
        async let r2 = lane.run(key: keyFor("ab")) { await opCalls.increment(); return "AB" }
        await clock.waitForSleepers(count: 2)
        async let r3 = lane.run(key: keyFor("abc")) { await opCalls.increment(); return "ABC" }
        await clock.waitForSleepers(count: 3)

        // Release all three parked debounce sleeps.
        await clock.advance(.milliseconds(225))

        let v1 = await r1
        let v2 = await r2
        let v3 = await r3
        // Only the last call survives supersession; the first two return nil.
        XCTAssertEqual(v1, nil)
        XCTAssertEqual(v2, nil)
        XCTAssertEqual(v3, "ABC")
        let calls = await opCalls.value
        XCTAssertEqual(calls, 1, "Only the trailing call must hit the operation")
    }

    func testSequentialCallsEachRun() async {
        let clock = ManualSleepClock()
        let lane = CompletionLatencyLane(
            debounce: .milliseconds(225), timeout: .seconds(10), clock: clock
        )
        let key1 = CompletionLatencyLane.Key(prefixTail: "1", suffixHead: "", cwd: "/c", completionModel: "m")
        let key2 = CompletionLatencyLane.Key(prefixTail: "2", suffixHead: "", cwd: "/c", completionModel: "m")

        async let r1 = lane.run(key: key1) { "one" }
        await clock.waitForSleepers(count: 1)
        await clock.advance(.milliseconds(225))
        let v1 = await r1
        XCTAssertEqual(v1, "one")

        async let r2 = lane.run(key: key2) { "two" }
        await clock.waitForSleepers(count: 1)
        await clock.advance(.milliseconds(225))
        let v2 = await r2
        XCTAssertEqual(v2, "two")
    }

    // MARK: - Timeout

    func testTimeoutCancelsOperationAndReturnsNil() async {
        let clock = ManualSleepClock()
        let lane = CompletionLatencyLane(
            debounce: .milliseconds(225), timeout: .seconds(10), clock: clock
        )
        let key = CompletionLatencyLane.Key(prefixTail: "p", suffixHead: "s", cwd: "/c", completionModel: "m")
        let cancelled = Flag()

        async let result = lane.run(key: key) {
            // Hang until cancelled.
            do {
                try await Task.sleep(for: .seconds(3600))
                return "never"
            } catch {
                await cancelled.set()
                throw error
            }
        }

        // Release the debounce sleep first.
        await clock.waitForSleepers(count: 1)
        await clock.advance(.milliseconds(225))
        // Now the timeout sleep parks; release it to win the race.
        await clock.waitForSleepers(count: 1)
        await clock.advance(.seconds(10))

        let timedResult = await result
        XCTAssertNil(timedResult)
        let wasCancelled = await cancelled.value
        XCTAssertTrue(wasCancelled, "Operation must be cancelled when the timeout wins")
        let cachedAfterTimeout = await lane.cachedCount
        XCTAssertEqual(cachedAfterTimeout, 0, "A timed-out request must not be cached")
    }

    // MARK: - Empty result not cached

    func testEmptyOperationResultIsNotCached() async {
        let clock = ManualSleepClock()
        let lane = CompletionLatencyLane(
            debounce: .milliseconds(225), timeout: .seconds(10), clock: clock
        )
        let key = CompletionLatencyLane.Key(prefixTail: "p", suffixHead: "s", cwd: "/c", completionModel: "m")

        async let r = lane.run(key: key) { "" }
        await clock.waitForSleepers(count: 1)
        await clock.advance(.milliseconds(225))
        let emptyResult = await r
        XCTAssertEqual(emptyResult, "")
        let cached = await lane.cachedCount
        XCTAssertEqual(cached, 0)
    }

    // MARK: - LRU eviction

    func testLRUEvictsLeastRecentlyUsed() async {
        let clock = ManualSleepClock()
        let lane = CompletionLatencyLane(
            debounce: .milliseconds(225), timeout: .seconds(10), cacheCapacity: 2, clock: clock
        )

        @Sendable func key(_ s: String) -> CompletionLatencyLane.Key {
            CompletionLatencyLane.Key(prefixTail: s, suffixHead: "", cwd: "/c", completionModel: "m")
        }

        // Insert A, B (sequentially, each survives debounce).
        await primeRun(lane: lane, clock: clock, key: key("A"), value: "VA")
        await primeRun(lane: lane, clock: clock, key: key("B"), value: "VB")
        let countAfterAB = await lane.cachedCount
        XCTAssertEqual(countAfterAB, 2)

        // Touch A (cache hit → A becomes most-recently-used).
        let touchedA = await lane.run(key: key("A")) { "X" }
        XCTAssertEqual(touchedA, "VA")

        // Insert C → evicts B (the LRU), keeps A and C.
        await primeRun(lane: lane, clock: clock, key: key("C"), value: "VC")
        let countAfterC = await lane.cachedCount
        XCTAssertEqual(countAfterC, 2)

        // A still cached (hit, no op), B evicted (op runs).
        let opForB = Counter()
        let a = await lane.run(key: key("A")) { "X" }
        XCTAssertEqual(a, "VA")

        async let bRun = lane.run(key: key("B")) { await opForB.increment(); return "VB2" }
        await clock.waitForSleepers(count: 1)
        await clock.advance(.milliseconds(225))
        let bValue = await bRun
        XCTAssertEqual(bValue, "VB2")
        let bCalls = await opForB.value
        XCTAssertEqual(bCalls, 1, "B was evicted, so its op must re-run")
    }

    // Helper: run a key to completion through the debounce. `parkedNow` is back
    // to zero after each prior `await r`, so each prime waits for its own single
    // freshly-parked debounce sleeper.
    private func primeRun(
        lane: CompletionLatencyLane,
        clock: ManualSleepClock,
        key: CompletionLatencyLane.Key,
        value: String
    ) async {
        async let r = lane.run(key: key) { value }
        await clock.waitForSleepers(count: 1)
        await clock.advance(.milliseconds(225))
        _ = await r
    }
}

// MARK: - Deterministic virtual clock

/// A manual clock for the lane: sleepers park until enough virtual time is
/// advanced. Crucially, tests can `await waitForSleepers(count:)` so they never
/// advance *before* a sleeper has registered (the classic advance-before-register
/// hang). Total elapsed virtual time is tracked monotonically.
private actor ManualSleepClock: AsyncSleepClock {
    private var elapsed: Duration = .zero
    private var waiters: [(deadline: Duration, resume: CheckedContinuation<Void, Error>)] = []
    /// How many sleepers have *ever* parked (monotonic; never decremented). Used
    /// by the cache-first assertion to prove a cache hit added no new sleeper.
    private(set) var totalSleepers = 0
    /// How many sleepers are parked *right now* (decremented on wake/cancel).
    /// `waitForSleepers` gates on this so each sequential run waits for its own
    /// freshly-parked debounce sleeper rather than a stale cumulative count.
    private var parkedNow = 0
    private var sleeperWaiters: [(threshold: Int, resume: CheckedContinuation<Void, Never>)] = []

    nonisolated func sleep(for duration: Duration) async throws {
        try await register(duration)
    }

    private func register(_ duration: Duration) async throws {
        let deadline = elapsed + duration
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                waiters.append((deadline, continuation))
                totalSleepers += 1
                parkedNow += 1
                fireSleeperWaiters()
            }
        } onCancel: {
            Task { await self.cancelAll() }
        }
    }

    /// Advance virtual time, resuming any sleeper whose deadline has passed.
    func advance(_ duration: Duration) {
        elapsed += duration
        let due = waiters.filter { $0.deadline <= elapsed }
        waiters.removeAll { $0.deadline <= elapsed }
        parkedNow -= due.count
        for waiter in due {
            waiter.resume.resume()
        }
    }

    /// Suspend the caller until at least `count` sleepers are currently parked.
    func waitForSleepers(count: Int) async {
        if parkedNow >= count { return }
        await withCheckedContinuation { continuation in
            sleeperWaiters.append((count, continuation))
        }
    }

    private func fireSleeperWaiters() {
        let ready = sleeperWaiters.filter { parkedNow >= $0.threshold }
        sleeperWaiters.removeAll { parkedNow >= $0.threshold }
        for waiter in ready {
            waiter.resume.resume()
        }
    }

    private func cancelAll() {
        let pending = waiters
        waiters.removeAll()
        parkedNow -= pending.count
        for waiter in pending {
            waiter.resume.resume(throwing: CancellationError())
        }
    }
}

// MARK: - Test helpers

private actor Counter {
    private(set) var value = 0
    func increment() { value += 1 }
}

private actor Flag {
    private(set) var value = false
    func set() { value = true }
}
