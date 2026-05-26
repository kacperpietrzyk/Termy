import Foundation

@MainActor
public final class HistoryStore {
    private let fileURL: URL
    private let markerURL: URL
    private let zshHistoryURL: URL?
    private let clock: () -> Date
    private let cwdMatchBoost: Double
    private let halfLifeDays: Double
    private let cap: Int

    private var entries: [String: HistoryEntry] = [:]
    private let ioQueue = DispatchQueue(label: "termy.history.io", qos: .utility)
    private var appendsSinceCompaction = 0
    private var loadHadMalformedLines = false

    public init(
        fileURL: URL,
        markerURL: URL,
        clock: @escaping () -> Date = Date.init,
        cwdMatchBoost: Double = 2.0,
        halfLifeDays: Double = 30,
        cap: Int = 10_000,
        zshHistoryURL: URL? = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".zsh_history")
    ) {
        self.fileURL = fileURL
        self.markerURL = markerURL
        self.zshHistoryURL = zshHistoryURL
        self.clock = clock
        self.cwdMatchBoost = cwdMatchBoost
        self.halfLifeDays = halfLifeDays
        self.cap = cap
        performZshImportIfNeeded()
        loadFromDisk()
        if loadHadMalformedLines {
            scheduleCompaction()
        }
    }

    public func record(command: String, cwd: String?) {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let now = clock()
        if var existing = entries[trimmed] {
            existing.lastUsedAt = now
            existing.count += 1
            if let cwd { existing.cwdCounts[cwd, default: 0] += 1 }
            entries[trimmed] = existing
        } else {
            var cwdCounts: [String: Int] = [:]
            if let cwd { cwdCounts[cwd] = 1 }
            entries[trimmed] = HistoryEntry(cmd: trimmed, lastUsedAt: now, count: 1, cwdCounts: cwdCounts)
        }
        evictIfNeeded()
        if let entry = entries[trimmed] {
            scheduleAppend(entry)
        }
    }

    public func rankedSnapshot(forCwd cwd: String?, limit: Int = 100) -> [String] {
        let now = clock()
        let scored = entries.values.map { (entry: $0, score: Self.frecency(
            entry: $0, now: now, currentCwd: cwd, halfLifeDays: halfLifeDays, cwdMatchBoost: cwdMatchBoost
        )) }
        return scored
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0.entry.cmd }
    }

    public func inlineSuggestion(for input: String, cwd: String?) -> InlineAutosuggestion? {
        guard !input.isEmpty else { return nil }
        let lower = input.lowercased()
        let now = clock()
        var best: (entry: HistoryEntry, score: Double)?
        for entry in entries.values {
            guard entry.cmd.count > input.count,
                  entry.cmd.lowercased().hasPrefix(lower) else { continue }
            let s = Self.frecency(
                entry: entry, now: now, currentCwd: cwd,
                halfLifeDays: halfLifeDays, cwdMatchBoost: cwdMatchBoost
            )
            if best == nil || s > best!.score {
                best = (entry, s)
            }
        }
        guard let winner = best?.entry else { return nil }
        let ghostStart = winner.cmd.index(winner.cmd.startIndex, offsetBy: input.count)
        return InlineAutosuggestion(replacement: winner.cmd, ghostText: String(winner.cmd[ghostStart...]))
    }

    private func evictIfNeeded() {
        guard entries.count > cap else { return }
        let now = clock()
        let scored = entries.values.map { (cmd: $0.cmd, score: Self.frecency(
            entry: $0, now: now, currentCwd: nil,
            halfLifeDays: halfLifeDays, cwdMatchBoost: cwdMatchBoost
        )) }
        let drop = entries.count - cap
        let losers = scored.sorted { $0.score < $1.score }.prefix(drop).map { $0.cmd }
        for cmd in losers { entries.removeValue(forKey: cmd) }
    }

    // MARK: - Zsh history import

    private func performZshImportIfNeeded() {
        let fm = FileManager.default
        guard let zshHistoryURL else { return }
        guard !fm.fileExists(atPath: markerURL.path) else { return }

        defer {
            try? fm.createDirectory(at: markerURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            fm.createFile(atPath: markerURL.path, contents: Data(), attributes: nil)
        }

        guard let data = try? Data(contentsOf: zshHistoryURL) else { return }
        let text = String(decoding: data, as: UTF8.self)
        let allLines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let tailLines = ZshHistoryImporter.tail(lines: allLines, limit: 10_000)
        let now = clock()
        let parsed = ZshHistoryImporter.parse(lines: tailLines, fallbackTime: now)
        let aggregated = ZshHistoryImporter.aggregate(records: parsed, fallbackTime: now)

        var buffer = Data()
        let encoder = JSONEncoder.f2_history
        for entry in aggregated {
            guard let line = try? encoder.encode(entry) else { continue }
            buffer.append(line)
            buffer.append(UInt8(ascii: "\n"))
        }
        guard !buffer.isEmpty else { return }
        try? fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? buffer.write(to: fileURL, options: .atomic)
    }

    // MARK: - Persistence

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let text = String(decoding: data, as: UTF8.self)
        let decoder = JSONDecoder.f2_history
        var loaded: [String: HistoryEntry] = [:]
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let entry = try? decoder.decode(HistoryEntry.self, from: Data(line.utf8)) else {
                loadHadMalformedLines = true
                continue
            }
            loaded[entry.cmd] = entry  // last line for cmd wins (append-only)
        }
        self.entries = loaded
    }

    private func scheduleAppend(_ entry: HistoryEntry) {
        let encoder = JSONEncoder.f2_history
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

    private nonisolated static func writeCompacted(_ snapshot: [HistoryEntry], to url: URL) {
        let encoder = JSONEncoder.f2_history
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

    /// F-2 §4.8: Ctrl-→ component-wise accept.
    ///
    /// 1. Empty → nil.
    /// 2. Leading whitespace → return the run of whitespace.
    /// 3. Else scan until first whitespace OR `/`.
    /// 4. If the scan stopped at `/`, include the `/` in the returned prefix.
    public nonisolated static func nextComponent(of ghostText: String) -> String? {
        guard !ghostText.isEmpty else { return nil }
        let scalars = ghostText.unicodeScalars
        let whitespace = CharacterSet.whitespaces

        var index = scalars.startIndex
        if whitespace.contains(scalars[index]) {
            while index < scalars.endIndex, whitespace.contains(scalars[index]) {
                index = scalars.index(after: index)
            }
            return String(String.UnicodeScalarView(scalars[scalars.startIndex..<index]))
        }

        while index < scalars.endIndex {
            let s = scalars[index]
            if whitespace.contains(s) {
                return String(String.UnicodeScalarView(scalars[scalars.startIndex..<index]))
            }
            if s == "/" {
                let next = scalars.index(after: index)
                return String(String.UnicodeScalarView(scalars[scalars.startIndex..<next]))
            }
            index = scalars.index(after: index)
        }
        return ghostText
    }

    /// Spec §4.6. Pure, deterministic given the inputs.
    /// `log(2.0)` is the natural log of 2 (from `<math.h>`, re-exported via
    /// Foundation). The ln(2)/halfLife factor converts the "half-life in
    /// days" parameter into the exponent base required by `exp`.
    public nonisolated static func frecency(
        entry: HistoryEntry,
        now: Date,
        currentCwd: String?,
        halfLifeDays: Double,
        cwdMatchBoost: Double
    ) -> Double {
        let ageSeconds = now.timeIntervalSince(entry.lastUsedAt)
        let ageDays = max(0, ageSeconds / 86_400)
        let decay = exp(-log(2.0) * ageDays / halfLifeDays)
        let cwdBoost: Double = {
            guard let currentCwd, let n = entry.cwdCounts[currentCwd], n > 0 else { return 1.0 }
            return cwdMatchBoost
        }()
        return Double(entry.count) * decay * cwdBoost
    }
}

// MARK: - Coders

extension JSONEncoder {
    /// F-2: canonical encoder. ISO-8601 dates.
    static var f2_history: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }
}

extension JSONDecoder {
    static var f2_history: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
