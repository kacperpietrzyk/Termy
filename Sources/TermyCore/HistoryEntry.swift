import Foundation

/// F-2: persistent history entry. `cwdCounts` maps the absolute path that was
/// active when the command was run to the number of times it was run there.
/// Codable as a flat JSON object (one JSON-Lines record per entry on disk).
public struct HistoryEntry: Codable, Equatable, Sendable {
    public var cmd: String
    public var lastUsedAt: Date
    public var count: Int
    public var cwdCounts: [String: Int]

    public init(cmd: String, lastUsedAt: Date, count: Int, cwdCounts: [String: Int]) {
        self.cmd = cmd
        self.lastUsedAt = lastUsedAt
        self.count = count
        self.cwdCounts = cwdCounts
    }
}
