import Foundation

/// An awaitable sleep abstraction so the latency lane is deterministic in tests.
///
/// The lane only ever *sleeps* (debounce delay, timeout race) — it never reads a
/// wall-clock instant — so this is a one-method protocol rather than a full
/// `Clock` conformance. The production impl wraps `Task.sleep`; a test impl can
/// drive virtual time and resume parked sleepers on demand.
public protocol AsyncSleepClock: Sendable {
    /// Suspend for `duration`, honouring task cancellation (throws
    /// `CancellationError` if the awaiting task is cancelled).
    func sleep(for duration: Duration) async throws
}

/// Real-time clock backed by `Task.sleep(for:)`.
public struct ContinuousSleepClock: AsyncSleepClock {
    public init() {}

    public func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}

/// A trailing-edge debounce + per-request timeout + LRU cache in front of the
/// local-AI fill-in-the-middle (FIM) completion path.
///
/// Why an actor: completion requests fire on every keystroke; without a lane
/// each one would spawn a fresh FIM round-trip and the slowest stale one could
/// overwrite a newer result. The lane serialises bookkeeping (the generation
/// counter and the LRU cache) on the actor while the actual model call runs
/// off-actor inside the injected `operation` closure.
///
/// Behaviour of ``run(key:operation:)``:
/// 1. **Cache-first.** A cache hit for `key` returns immediately (no debounce,
///    no model call) and refreshes the entry's recency.
/// 2. **Debounce.** Otherwise the call parks for `debounce`. Each entry bumps a
///    generation counter; while one call is parked, a newer call bumps the
///    counter, so the older call wakes, sees it has been superseded, and returns
///    `nil`. Only the last call in a rapid burst proceeds (trailing edge). This
///    relies on actor reentrancy — no manual cancellation of the parked call.
/// 3. **Timeout.** The surviving call races `operation` against a `timeout`
///    sleep; if the timeout wins, the operation task is cancelled and the call
///    returns `nil`.
/// 4. **Cache store.** A non-nil, non-empty result is cached under `key`.
///
/// A `nil` return always means "no completion to show" — the caller treats it
/// as a no-op (superseded, timed out, or the operation itself returned nil).
public actor CompletionLatencyLane {
    /// Cache key for a completion request.
    ///
    /// Keyed on a bounded tail of the prefix + a bounded head of the suffix (so
    /// far-away buffer edits don't bust the cache), plus the working directory
    /// and the completion model name (different cwd/model ⇒ different answer).
    public struct Key: Hashable, Sendable {
        public let prefixTail: String
        public let suffixHead: String
        public let cwd: String
        public let completionModel: String

        public init(prefixTail: String, suffixHead: String, cwd: String, completionModel: String) {
            self.prefixTail = prefixTail
            self.suffixHead = suffixHead
            self.cwd = cwd
            self.completionModel = completionModel
        }

        /// Build a key from raw context, clamping the prefix to its last
        /// `prefixWindow` characters and the suffix to its first `suffixWindow`.
        public init(
            prefix: String,
            suffix: String,
            cwd: String,
            completionModel: String,
            prefixWindow: Int = CompletionLatencyLane.defaultPrefixWindow,
            suffixWindow: Int = CompletionLatencyLane.defaultSuffixWindow
        ) {
            self.prefixTail = String(prefix.suffix(prefixWindow))
            self.suffixHead = String(suffix.prefix(suffixWindow))
            self.cwd = cwd
            self.completionModel = completionModel
        }
    }

    /// Default character window for the cache-key prefix tail.
    public static let defaultPrefixWindow = 256
    /// Default character window for the cache-key suffix head.
    public static let defaultSuffixWindow = 256

    private let debounce: Duration
    private let timeout: Duration
    private let cacheCapacity: Int
    private let clock: any AsyncSleepClock

    /// Monotonically increasing per-call token; the newest call wins.
    private var generation: UInt64 = 0

    // Insertion-ordered LRU: `order` is least→most recently used; `storage` maps
    // key→value. Capacity-bounded; eviction drops the front (LRU) entry.
    private var storage: [Key: String] = [:]
    private var order: [Key] = []

    public init(
        debounce: Duration = .milliseconds(225),
        timeout: Duration = .seconds(10),
        cacheCapacity: Int = 64,
        clock: any AsyncSleepClock = ContinuousSleepClock()
    ) {
        self.debounce = debounce
        self.timeout = timeout
        self.cacheCapacity = max(1, cacheCapacity)
        self.clock = clock
    }

    /// Number of entries currently cached. Exposed for tests/diagnostics.
    public var cachedCount: Int { storage.count }

    /// Run a completion `operation` through the debounce → timeout → cache lane.
    ///
    /// - Returns: the completion text, or `nil` if this request was superseded
    ///   by a newer one, timed out, or the operation produced no completion.
    public func run(
        key: Key,
        operation: @escaping @Sendable () async throws -> String?
    ) async -> String? {
        // 1. Cache-first: a hit short-circuits debounce and the model call.
        if let cached = lookup(key) {
            return cached
        }

        // 2. Debounce (trailing edge via generation supersession).
        generation &+= 1
        let myGeneration = generation
        do {
            try await clock.sleep(for: debounce)
        } catch {
            return nil // cancelled while parked
        }
        guard myGeneration == generation else {
            return nil // a newer request arrived during the debounce window
        }

        // A newer request may have cached a result for this exact key while we
        // were parked — honour it rather than re-running the model.
        if let cached = lookup(key) {
            return cached
        }

        // 3. Timeout race: operation vs. timeout sleep.
        let result: String?
        do {
            result = try await withTimeout(operation: operation)
        } catch {
            return nil
        }

        // 4. Cache a usable result.
        if let result, !result.isEmpty {
            store(key: key, value: result)
        }
        return result
    }

    /// Race `operation` against the timeout. Returns the operation's value, or
    /// `nil` if the timeout wins (the operation task is cancelled). Re-throws
    /// only an operation error.
    private func withTimeout(
        operation: @escaping @Sendable () async throws -> String?
    ) async throws -> String? {
        let timeout = self.timeout
        let clock = self.clock
        return try await withThrowingTaskGroup(of: TimedOutcome.self) { group in
            group.addTask {
                let value = try await operation()
                return .completed(value)
            }
            group.addTask {
                // A clean timeout sleep wins the race → .timedOut. If this task
                // is the loser it is cancelled and its sleep throws, which we
                // swallow so only a real operation error escapes the group.
                do {
                    try await clock.sleep(for: timeout)
                    return .timedOut
                } catch {
                    return .cancelledLoser
                }
            }

            defer { group.cancelAll() }
            while let outcome = try await group.next() {
                switch outcome {
                case .completed(let value):
                    return value
                case .timedOut:
                    return nil
                case .cancelledLoser:
                    continue
                }
            }
            return nil
        }
    }

    private enum TimedOutcome: Sendable {
        case completed(String?)
        case timedOut
        case cancelledLoser
    }

    // MARK: - LRU cache

    private func lookup(_ key: Key) -> String? {
        guard let value = storage[key] else { return nil }
        touch(key)
        return value
    }

    private func store(key: Key, value: String) {
        storage[key] = value
        touch(key)
        while order.count > cacheCapacity {
            let evicted = order.removeFirst()
            storage.removeValue(forKey: evicted)
        }
    }

    /// Mark `key` as most-recently-used.
    private func touch(_ key: Key) {
        if let index = order.firstIndex(of: key) {
            order.remove(at: index)
        }
        order.append(key)
    }
}
