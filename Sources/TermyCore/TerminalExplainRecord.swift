import Foundation

/// v3 Shell §6.1 AI-context card ("Last explain · block N · 0.92s"): metadata of
/// the most recent terminal AI-explain. `blockOrdinal` is the 1-based command ordinal
/// shown as "block N"; it is nil when the block is no longer locatable (e.g. session
/// switched mid-explain) — the UI elides it honestly rather than showing a fabricated 0.
/// `blockStartLine` is kept only for optional jump-to (it shifts as scrollback grows).
public struct TerminalExplainRecord: Equatable, Sendable {
    public let blockOrdinal: Int?
    public let blockStartLine: Int
    /// The explained command text (e.g. "keychain test"); "" when the block was
    /// not locatable — honest empty, never fabricated.
    public let command: String
    public let durationSeconds: Double
    public let finishedAt: Date
    public let succeeded: Bool

    public init(blockOrdinal: Int?, blockStartLine: Int, command: String,
                durationSeconds: Double, finishedAt: Date, succeeded: Bool) {
        self.blockOrdinal = blockOrdinal
        self.blockStartLine = blockStartLine
        self.command = command
        self.durationSeconds = durationSeconds
        self.finishedAt = finishedAt
        self.succeeded = succeeded
    }

    /// 1-based ordinal of the block whose `startLine` matches, or nil if absent.
    public static func ordinal(ofBlockStartingAt startLine: Int,
                               in blocks: [TerminalCommandBlock]) -> Int? {
        guard let index = blocks.firstIndex(where: { $0.startLine == startLine }) else { return nil }
        return index + 1
    }
}
