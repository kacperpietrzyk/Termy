import Foundation

/// AD-4 (the moat): pure logic turning a set of diff-review comments into ONE
/// steering instruction line for a live CLI agent's REPL.
///
/// Why a single line: the agent PTY sink (`TermyStore.sendAgentReply`) appends a
/// carriage return and submits. An interactive REPL (Claude Code) treats every
/// embedded newline as a *submit*, so a multi-line instruction would fire partial
/// turns. `compose` therefore flattens all internal newlines and joins the
/// comments into a single, ordered, human-readable line — the form most likely to
/// land intact in the agent's prompt. Git/SwiftUI-free so it is unit-tested
/// without a process or a view.
public enum AgentSteering {
    /// One review note anchored to a file (and optionally a hunk/line label),
    /// carrying the user's free-text body.
    public struct Comment: Equatable, Sendable, Identifiable {
        public let id: UUID
        public let filePath: String      // the diff file the note hangs off
        public let anchor: String?       // optional hunk header / line label, e.g. "@@ -12,4 +12,6 @@"
        public let body: String          // the user's instruction text

        public init(id: UUID = UUID(), filePath: String, anchor: String? = nil, body: String) {
            self.id = id; self.filePath = filePath; self.anchor = anchor; self.body = body
        }
    }

    /// The lead-in sentence prepended to the joined comments.
    public static let preamble = "Address these code-review comments on your current diff:"

    /// Compose an ordered set of comments into a single instruction line, or
    /// `nil` when nothing meaningful remains (all bodies blank). Behavior the
    /// live gate depends on:
    ///   - every internal newline/tab in a body or anchor is flattened to a space
    ///     (no partial REPL submits);
    ///   - blank-bodied comments are dropped;
    ///   - comments keep their given order and are numbered for the agent;
    ///   - the file (and anchor, when present) is named so the agent can locate it.
    public static func compose(_ comments: [Comment]) -> String? {
        let parts = comments
            .map { render($0) }
            .filter { !$0.isEmpty }
        guard !parts.isEmpty else { return nil }

        if parts.count == 1 {
            return "\(preamble) \(parts[0])"
        }
        let numbered = parts.enumerated()
            .map { "(\($0.offset + 1)) \($0.element)" }
            .joined(separator: " ")
        return "\(preamble) \(numbered)"
    }

    /// Render one comment to `path[ · anchor]: body`, or "" when its body is
    /// blank after flattening. All whitespace runs collapse to single spaces so
    /// the result is a clean single line.
    private static func render(_ comment: Comment) -> String {
        let body = flatten(comment.body)
        guard !body.isEmpty else { return "" }
        var location = flatten(comment.filePath)
        if let anchor = comment.anchor.map(flatten), !anchor.isEmpty {
            location += " · \(anchor)"
        }
        return location.isEmpty ? body : "\(location): \(body)"
    }

    /// Replace every newline/tab/whitespace run with a single space and trim the
    /// ends. This is the load-bearing guard: it guarantees the composed
    /// instruction never carries a `\n` into the agent's line-oriented REPL.
    private static func flatten(_ text: String) -> String {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
