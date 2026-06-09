import Foundation

/// CK-S2: per-item exp-decay frecency record for the ⌘K command palette.
///
/// Unlike `HistoryEntry` (shell-history, cwd-scoped), palette items are not
/// cwd-scoped, so this is the minimal `id`/`lastUsedAt`/`count` shape. `id` is
/// the stable `CommandCenterItem.id` (`action-<id>`, `profile-<uuid>`,
/// `agent-<uuid>`); the store treats it as opaque.
///
/// Codable as a flat JSON object — one JSON-Lines record per entry on disk.
public struct PaletteFrecencyEntry: Codable, Equatable, Sendable {
    public var id: String
    public var lastUsedAt: Date
    public var count: Int

    public init(id: String, lastUsedAt: Date, count: Int) {
        self.id = id
        self.lastUsedAt = lastUsedAt
        self.count = count
    }
}

/// CK-S2: on-device exp-decay frecency for ⌘K palette items.
///
/// Mirrors `HistoryStore`'s persistence (JSON-Lines in Application Support/Termy
/// via an append-then-compact `ioQueue`) and decay math (`ln2`/half-life), but
/// keyed by stable item identity rather than command text, with no cwd boost
/// (palette context boosts live in CK-S3, blended on top of these scores).
///
/// **Privacy (P1):** strictly local. The JSONL lives only under the injected
/// `fileURL`; it never enters any network/sync payload — frecency is a local
/// ranking signal, not analytics.
///
/// This slice (CK-S2) is the pure store only: `record(itemID:)` on accept,
/// `scores(now:)`/`frecency(...)` for the blender, `flushPendingWrites()`.
/// Wiring acceptance recording and fuzzy-score blending into `TermyStore` is
/// CK-S3.
@MainActor
public final class PaletteFrecencyStore {
    private let fileURL: URL
    private let clock: () -> Date
    private let halfLifeDays: Double
    private let cap: Int

    private var entries: [String: PaletteFrecencyEntry] = [:]
    private let ioQueue = DispatchQueue(label: "termy.palette.frecency.io", qos: .utility)
    private var appendsSinceCompaction = 0
    private var loadHadMalformedLines = false

    public init(
        fileURL: URL,
        clock: @escaping () -> Date = Date.init,
        halfLifeDays: Double = 30,
        cap: Int = 5_000
    ) {
        self.fileURL = fileURL
        self.clock = clock
        self.halfLifeDays = halfLifeDays
        self.cap = cap
        loadFromDisk()
        if loadHadMalformedLines {
            scheduleCompaction()
        }
    }

    /// Record one acceptance of the item with the given stable id.
    public func record(itemID: String) {
        let trimmed = itemID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let now = clock()
        if var existing = entries[trimmed] {
            existing.lastUsedAt = now
            existing.count += 1
            entries[trimmed] = existing
        } else {
            entries[trimmed] = PaletteFrecencyEntry(id: trimmed, lastUsedAt: now, count: 1)
        }
        evictIfNeeded()
        if let entry = entries[trimmed] {
            scheduleAppend(entry)
        }
    }

    /// Frecency for a single item id, or `0` if never accepted.
    public func score(forID id: String, now: Date? = nil) -> Double {
        guard let entry = entries[id] else { return 0 }
        return Self.frecency(entry: entry, now: now ?? clock(), halfLifeDays: halfLifeDays)
    }

    /// Snapshot of every known item's frecency at `now` (defaults to the clock).
    /// CK-S3 calls this once per query and blends with the fuzzy score, instead
    /// of touching disk per item.
    public func scores(now: Date? = nil) -> [String: Double] {
        let when = now ?? clock()
        var result: [String: Double] = [:]
        result.reserveCapacity(entries.count)
        for (id, entry) in entries {
            result[id] = Self.frecency(entry: entry, now: when, halfLifeDays: halfLifeDays)
        }
        return result
    }

    private func evictIfNeeded() {
        guard entries.count > cap else { return }
        let now = clock()
        let scored = entries.values.map { (id: $0.id, score: Self.frecency(
            entry: $0, now: now, halfLifeDays: halfLifeDays
        )) }
        let drop = entries.count - cap
        let losers = scored.sorted { $0.score < $1.score }.prefix(drop).map { $0.id }
        for id in losers { entries.removeValue(forKey: id) }
    }

    // MARK: - Persistence

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let text = String(decoding: data, as: UTF8.self)
        let decoder = JSONDecoder.ckPaletteFrecency
        var loaded: [String: PaletteFrecencyEntry] = [:]
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let entry = try? decoder.decode(PaletteFrecencyEntry.self, from: Data(line.utf8)) else {
                loadHadMalformedLines = true
                continue
            }
            loaded[entry.id] = entry  // last line for id wins (append-only)
        }
        self.entries = loaded
    }

    private func scheduleAppend(_ entry: PaletteFrecencyEntry) {
        let encoder = JSONEncoder.ckPaletteFrecency
        guard let line = try? encoder.encode(entry) else { return }
        let fileURL = self.fileURL
        ioQueue.async {
            Self.appendLine(line, to: fileURL)
        }
        appendsSinceCompaction += 1
        if appendsSinceCompaction >= entries.count, entries.count > 0 {
            scheduleCompaction()
        }
    }

    public func flushPendingWrites() {
        let snapshot = Array(entries.values)
        let fileURL = self.fileURL
        ioQueue.sync {
            Self.writeCompacted(snapshot, to: fileURL)
        }
        appendsSinceCompaction = 0
    }

    private func scheduleCompaction() {
        let snapshot = Array(entries.values)
        let fileURL = self.fileURL
        ioQueue.async {
            Self.writeCompacted(snapshot, to: fileURL)
        }
        appendsSinceCompaction = 0
    }

    private nonisolated static func writeCompacted(_ snapshot: [PaletteFrecencyEntry], to url: URL) {
        let encoder = JSONEncoder.ckPaletteFrecency
        let fm = FileManager.default
        try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let tmpURL = url.appendingPathExtension("tmp")
        var buffer = Data()
        for entry in snapshot {
            guard let line = try? encoder.encode(entry) else { continue }
            buffer.append(line)
            buffer.append(UInt8(ascii: "\n"))
        }
        try? buffer.write(to: tmpURL, options: .atomic)
        do {
            _ = try fm.replaceItemAt(url, withItemAt: tmpURL)
        } catch {
            try? buffer.write(to: url, options: .atomic)
            try? fm.removeItem(at: tmpURL)
        }
    }

    private nonisolated static func appendLine(_ jsonLine: Data, to url: URL) {
        let fm = FileManager.default
        try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var payload = Data()
        payload.append(jsonLine)
        payload.append(UInt8(ascii: "\n"))
        if fm.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: payload)
            }
        } else {
            try? payload.write(to: url, options: .atomic)
        }
    }

    /// Exp-decay frecency. Mirrors `HistoryStore.frecency` (`Sources/TermyCore/
    /// HistoryStore.swift`) minus the cwd boost: `count × exp(-ln2·ageDays/halfLife)`.
    /// `log(2.0)` is the natural log of 2; the `ln(2)/halfLife` factor turns the
    /// "half-life in days" parameter into the exponent base required by `exp`.
    public nonisolated static func frecency(
        entry: PaletteFrecencyEntry,
        now: Date,
        halfLifeDays: Double
    ) -> Double {
        let ageSeconds = now.timeIntervalSince(entry.lastUsedAt)
        let ageDays = max(0, ageSeconds / 86_400)
        let decay = exp(-log(2.0) * ageDays / halfLifeDays)
        return Double(entry.count) * decay
    }
}

// MARK: - Coders

extension JSONEncoder {
    /// CK-S2: canonical encoder. ISO-8601 dates.
    static var ckPaletteFrecency: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }
}

extension JSONDecoder {
    static var ckPaletteFrecency: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
