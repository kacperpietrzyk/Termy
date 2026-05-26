import Foundation

/// F-2 §6: one-time seed import from `~/.zsh_history`. Pure functions —
/// no IO. Caller (HistoryStore) reads the file and passes lines in.
public enum ZshHistoryImporter {
    public struct Record: Equatable, Sendable {
        public var command: String
        public var timestamp: Date
        public init(command: String, timestamp: Date) {
            self.command = command
            self.timestamp = timestamp
        }
    }

    /// Returns the last `limit` elements of `lines`. If `lines` is shorter,
    /// returns the input unchanged.
    public static func tail(lines: [String], limit: Int) -> [String] {
        guard lines.count > limit else { return lines }
        return Array(lines.suffix(limit))
    }

    /// Parse each non-blank line. Extended format `: <unix-ts>:<dur>;<cmd>`
    /// uses the embedded timestamp; plain lines fall back to `fallbackTime`.
    public static func parse(lines: [String], fallbackTime: Date) -> [Record] {
        var out: [Record] = []
        for raw in lines {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if trimmed.hasPrefix(":"),
               let (ts, cmd) = parseExtended(line: trimmed) {
                out.append(Record(command: cmd, timestamp: ts))
            } else {
                out.append(Record(command: trimmed, timestamp: fallbackTime))
            }
        }
        return out
    }

    private static func parseExtended(line: String) -> (Date, String)? {
        guard let semicolon = line.firstIndex(of: ";") else { return nil }
        let header = line[..<semicolon]
        let command = String(line[line.index(after: semicolon)...])
        let headerTrimmed = header.dropFirst().trimmingCharacters(in: .whitespaces)
        let parts = headerTrimmed.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true).map(String.init)
        guard let secondsStr = parts.first, let seconds = TimeInterval(secondsStr) else { return nil }
        return (Date(timeIntervalSince1970: seconds), command)
    }

    /// Convert parsed records to `HistoryEntry` values, deduping by command.
    /// count = min(occurrences, 50); lastUsedAt = max(timestamps); cwdCounts = empty.
    public static func aggregate(records: [Record], fallbackTime: Date) -> [HistoryEntry] {
        var buckets: [String: (count: Int, lastUsedAt: Date)] = [:]
        for r in records {
            let key = r.command
            if var existing = buckets[key] {
                existing.count += 1
                if r.timestamp > existing.lastUsedAt { existing.lastUsedAt = r.timestamp }
                buckets[key] = existing
            } else {
                buckets[key] = (1, r.timestamp)
            }
        }
        return buckets.map { cmd, info in
            HistoryEntry(
                cmd: cmd,
                lastUsedAt: info.lastUsedAt,
                count: min(info.count, 50),
                cwdCounts: [:]
            )
        }
    }
}
