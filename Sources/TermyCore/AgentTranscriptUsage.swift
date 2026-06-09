import Foundation

/// AD-6 — per-agent token / context-window occupancy, parsed **read-only and
/// locally** from a Claude Code transcript on disk. NO network, no metering
/// endpoint, no telemetry (P1): the figure comes purely from the `.jsonl` CC
/// already writes under `~/.claude/projects/<encoded-cwd>/<session>.jsonl`.
///
/// Honest CC/Codex asymmetry: this is derived only for Claude Code sessions.
/// Codex has no equivalent transcript, so the UI shows "n/a" keyed on the agent
/// type — it must never fabricate a number (never-fabricate).
public struct AgentTranscriptUsage: Sendable, Equatable {
    /// Reconstructed context occupancy for the most recent assistant turn:
    /// `input_tokens + cache_creation_input_tokens + cache_read_input_tokens`.
    /// This is what reconstitutes the whole conversation for that turn — i.e.
    /// "how full is the window" — and matches CC's own `/context`. We deliberately
    /// do NOT sum across turns: `cache_read_input_tokens` re-counts the same
    /// context every turn, so a sum overcounts by orders of magnitude.
    public let contextTokens: Int
    /// The model id from the same assistant message (e.g. `claude-opus-4-7`).
    /// nil when the transcript carried no model field.
    public let model: String?
    /// The model's context-window size, mapped from `model`. nil when the model
    /// is unknown — in that case the UI shows the raw token count with NO
    /// percentage rather than inventing a denominator (never-fabricate).
    public let contextWindow: Int?

    public init(contextTokens: Int, model: String?, contextWindow: Int?) {
        self.contextTokens = contextTokens
        self.model = model
        self.contextWindow = contextWindow
    }

    /// Fraction of the context window in use (0...1), or nil when the window is
    /// unknown. Clamped to 1.0 — a turn can momentarily exceed the nominal window.
    public var fraction: Double? {
        guard let w = contextWindow, w > 0 else { return nil }
        return min(1.0, Double(contextTokens) / Double(w))
    }
}

public enum AgentTranscriptParser {
    /// Known Claude model id → context window (tokens). Grounded against the real
    /// ids found in `~/.claude/projects/*.jsonl`: full ids (`claude-opus-4-7`,
    /// `claude-opus-4-8`, dated `claude-3-5-sonnet-...`) AND bare family aliases
    /// (`opus`/`sonnet`/`haiku`) both occur, so we match either. Every current
    /// Claude family ships a 200k standard window.
    ///
    /// The 1M long-context window is a REQUEST-TIME beta header, NOT a distinct
    /// model id — no `1m`-tagged id appears in real transcripts — so the `1m`
    /// check below is a best-effort hook for a hypothetical future id and never
    /// fires for today's CC (this is the unverified part of the live gate). The
    /// `<synthetic>` placeholder and any non-Claude model → nil: raw tokens, NO
    /// fabricated percentage (never-fabricate the denominator).
    public static func contextWindow(forModel model: String?) -> Int? {
        guard let model = model?.lowercased(), !model.isEmpty else { return nil }
        if model.contains("1m") { return 1_000_000 }
        let isClaudeFamily = model.hasPrefix("claude")
            || ["opus", "sonnet", "haiku"].contains(model)
        return isClaudeFamily ? 200_000 : nil
    }

    /// Parse the last assistant `usage` out of a CC transcript's text. Scans from
    /// the END so we stop at the first (newest) decodable assistant turn, and
    /// tolerates a trailing truncated line (the transcript is written live) plus
    /// any non-JSON / non-assistant garbage lines. Returns nil when no assistant
    /// usage is present at all (e.g. an empty transcript or a still-thinking
    /// first turn).
    public static func parse(_ transcript: String) -> AgentTranscriptUsage? {
        let lines = transcript.split(separator: "\n", omittingEmptySubsequences: true)
        let decoder = JSONDecoder()
        for line in lines.reversed() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            guard let data = trimmed.data(using: .utf8),
                  let row = try? decoder.decode(TranscriptRow.self, from: data) else {
                continue   // truncated / non-JSON line — keep scanning upward
            }
            guard row.type == "assistant", let message = row.message,
                  let usage = message.usage else { continue }
            let context = usage.inputTokens
                + usage.cacheCreationInputTokens
                + usage.cacheReadInputTokens
            return AgentTranscriptUsage(
                contextTokens: context,
                model: message.model,
                contextWindow: contextWindow(forModel: message.model))
        }
        return nil
    }
}

// MARK: - Lenient transcript row decoding.

/// One transcript line, narrowed to the fields AD-6 reads. Lenient: missing or
/// wrong-shaped fields decode to nil so a single odd row never aborts the scan.
private struct TranscriptRow: Decodable {
    let type: String?
    let message: Message?

    struct Message: Decodable {
        let role: String?
        let model: String?
        let usage: Usage?
    }

    struct Usage: Decodable {
        let inputTokens: Int
        let cacheCreationInputTokens: Int
        let cacheReadInputTokens: Int

        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case cacheCreationInputTokens = "cache_creation_input_tokens"
            case cacheReadInputTokens = "cache_read_input_tokens"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            // Any of the cache fields can be absent on a first turn → treat as 0.
            inputTokens = (try? c.decode(Int.self, forKey: .inputTokens)) ?? 0
            cacheCreationInputTokens =
                (try? c.decode(Int.self, forKey: .cacheCreationInputTokens)) ?? 0
            cacheReadInputTokens =
                (try? c.decode(Int.self, forKey: .cacheReadInputTokens)) ?? 0
        }
    }
}

// MARK: - Locating the transcript on disk (off-main caller territory).

public enum AgentTranscriptLocator {
    /// The Claude Code project-dir encoding: every non-alphanumeric character of
    /// the absolute cwd becomes `-` (verified against real `~/.claude/projects`
    /// dirs: `/`, `.`, `~`, space and non-ASCII all map to `-`). Lossy by design —
    /// this mirrors CC's own scheme exactly so we land in the same directory.
    public static func encodedProjectDirName(forCwd cwd: String) -> String {
        // ASCII-alnum only: non-ASCII path chars must munge to "-" the way CC
        // does, so we cannot use the Unicode-aware Character.isLetter/.isNumber.
        let dash = Unicode.Scalar("-")
        return String(String.UnicodeScalarView(cwd.unicodeScalars.map {
            CharacterSet.asciiAlnum.contains($0) ? $0 : dash
        }))
    }

    /// Path of the newest `*.jsonl` transcript for `cwd`, or nil when the project
    /// dir is absent / has no transcript. `projectsRoot` defaults to
    /// `~/.claude/projects` (overridable for tests). Picks by modification date
    /// so the live session's file wins.
    public static func newestTranscript(
        forCwd cwd: String,
        projectsRoot: URL = AgentTranscriptLocator.defaultProjectsRoot
    ) -> URL? {
        let dir = projectsRoot.appendingPathComponent(encodedProjectDirName(forCwd: cwd))
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) else { return nil }
        let transcripts = entries.filter { $0.pathExtension == "jsonl" }
        func mtime(_ url: URL) -> Date {
            (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
        }
        return transcripts.max { mtime($0) < mtime($1) }
    }

    public static var defaultProjectsRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects", isDirectory: true)
    }

    /// Read at most the trailing `maxBytes` of a transcript. We only need the last
    /// assistant turn for occupancy, so tailing keeps a multi-MB transcript cheap
    /// to parse each refresh. Reads UTF-8; a chopped leading line is tolerated by
    /// the parser (it scans from the end and skips the one undecodable fragment).
    public static func tailRead(_ url: URL, maxBytes: Int = 256 * 1024) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        let start = size > UInt64(maxBytes) ? size - UInt64(maxBytes) : 0
        try? handle.seek(toOffset: start)
        guard let data = try? handle.readToEnd() else { return nil }
        return String(decoding: data, as: UTF8.self)
    }
}

private extension CharacterSet {
    static let asciiAlnum: CharacterSet = {
        var s = CharacterSet()
        s.insert(charactersIn: "0123456789")
        s.insert(charactersIn: "abcdefghijklmnopqrstuvwxyz")
        s.insert(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        return s
    }()
}
