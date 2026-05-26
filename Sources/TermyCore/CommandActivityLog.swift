import Foundation

/// v3 Shell §6.1: a global, day-bucketed count of commands run, persisted as a
/// flat JSON map `{ "yyyy-MM-dd": count }`. Mirrors `HistoryStore`'s ownership
/// (injectable `fileURL` + `clock`, background I/O queue, `flushPendingWrites`).
/// Incremented once per OSC-133 `.commandStarted`. Cross-session (no session key).
@MainActor
public final class CommandActivityLog {
    private let fileURL: URL
    private let clock: () -> Date
    private let retentionDays: Int
    private var counts: [String: Int] = [:]   // dayKey -> count
    private let ioQueue = DispatchQueue(label: "termy.command-activity.io", qos: .utility)

    public init(fileURL: URL, clock: @escaping () -> Date = Date.init, retentionDays: Int = 35) {
        self.fileURL = fileURL
        self.clock = clock
        self.retentionDays = retentionDays
        loadFromDisk()
    }

    public func record(at date: Date) {
        counts[Self.dayKey(for: date), default: 0] += 1
        scheduleWrite()
    }

    public func commandsToday(now: Date) -> Int {
        counts[Self.dayKey(for: now)] ?? 0
    }

    public func flushPendingWrites() {
        prune(now: clock())
        let snapshot = counts
        let fileURL = self.fileURL
        ioQueue.sync { Self.write(snapshot, to: fileURL) }
    }

    /// `yyyy-MM-dd` in the user's local time zone. POSIX locale so it never drifts.
    /// Lexicographic order of these keys equals chronological order (used by `prune`).
    public nonisolated static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func prune(now: Date) {
        guard retentionDays > 0,
              let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: now)
        else { return }
        let cutoffKey = Self.dayKey(for: cutoff)
        counts = counts.filter { $0.key >= cutoffKey }
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: fileURL),
              let loaded = try? JSONDecoder().decode([String: Int].self, from: data)
        else { return }
        counts = loaded
    }

    private func scheduleWrite() {
        let snapshot = counts
        let fileURL = self.fileURL
        ioQueue.async { Self.write(snapshot, to: fileURL) }
    }

    private nonisolated static func write(_ snapshot: [String: Int], to url: URL) {
        let fm = FileManager.default
        try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
