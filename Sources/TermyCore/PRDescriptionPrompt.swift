import Foundation

/// AD-8 — the pure prompt builder that turns an agent's branch context (head/base
/// branch, commit subjects, touched files, and a bounded diff) into a single
/// prompt for the LOCAL model to draft a PR title + body. Git/SwiftUI/network
/// free so it is unit-tested without a process, a view, or a model call.
///
/// Privacy (P1): the draft is produced by the LOCAL model only (LM Studio/Ollama,
/// offline) — this builder just assembles the prompt text. The diff is bounded so
/// a large worktree diff can't blow the local model's context window.
///
/// B4: the model's output is a *draft* the user reviews and edits before any
/// `gh pr create` runs — this builder neither sends nor submits anything.
public enum PRDescriptionPrompt {
    /// Context gathered from the agent's worktree to ground the draft.
    public struct Context: Equatable, Sendable {
        public let headBranch: String
        public let baseBranch: String
        /// Commit subjects on `head` not yet on `base` (newest first), if known.
        public let commitSubjects: [String]
        /// Files touched by the branch (relative paths).
        public let touchedFiles: [String]
        /// The branch diff (bounded by the caller / `build` before prompting).
        public let diff: String

        public init(
            headBranch: String,
            baseBranch: String,
            commitSubjects: [String] = [],
            touchedFiles: [String] = [],
            diff: String = ""
        ) {
            self.headBranch = headBranch
            self.baseBranch = baseBranch
            self.commitSubjects = commitSubjects
            self.touchedFiles = touchedFiles
            self.diff = diff
        }
    }

    /// Default cap on the diff text fed to the model (characters). A pull request's
    /// summary needs the shape of the change, not every line; bounding keeps the
    /// prompt inside a small local model's context. The diff is truncated with a
    /// visible marker so the model knows it was abridged.
    public static let defaultDiffCharBudget = 8_000

    /// The first line of the model's response is the PR title; the rest is the
    /// body. This contract is stated in the prompt and parsed by ``parseResponse``.
    public static let instruction =
        "Write a GitHub pull request title and description for the change below. "
        + "Respond as plain text with the PR title on the FIRST line, then a blank line, "
        + "then a concise Markdown body (a one-paragraph summary and a short bulleted "
        + "list of notable changes). No code fences around the whole response."

    /// Build the full prompt from `context`, truncating the diff to `diffCharBudget`.
    public static func build(_ context: Context, diffCharBudget: Int = defaultDiffCharBudget) -> String {
        var sections: [String] = [instruction]

        sections.append("Branch: \(context.headBranch) → \(context.baseBranch)")

        let subjects = context.commitSubjects
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !subjects.isEmpty {
            sections.append("Commits:\n" + subjects.map { "- \($0)" }.joined(separator: "\n"))
        }

        let files = context.touchedFiles
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !files.isEmpty {
            sections.append("Changed files:\n" + files.map { "- \($0)" }.joined(separator: "\n"))
        }

        let diff = context.diff.trimmingCharacters(in: .whitespacesAndNewlines)
        if !diff.isEmpty {
            sections.append("Diff:\n" + truncatedDiff(diff, budget: diffCharBudget))
        }

        return sections.joined(separator: "\n\n")
    }

    /// Truncate `diff` to at most `budget` characters, appending an explicit
    /// marker when abridged so the model (and any reader) knows it is partial.
    public static func truncatedDiff(_ diff: String, budget: Int) -> String {
        guard budget > 0, diff.count > budget else { return diff }
        let endIndex = diff.index(diff.startIndex, offsetBy: budget)
        return String(diff[..<endIndex]) + "\n… (diff truncated for length)"
    }

    /// Parse a model response into `(title, body)`. The first non-empty line is the
    /// title; everything after the following blank line (or the remainder) is the
    /// body. Strips a markdown heading marker (`# `) or wrapping code fence the
    /// model may have added. A response with only a title yields an empty body.
    public static func parseResponse(_ response: String) -> (title: String, body: String) {
        let stripped = stripOuterFence(response)
        let lines = stripped.components(separatedBy: "\n")

        var index = 0
        // Skip leading blank lines to the title line.
        while index < lines.count,
              lines[index].trimmingCharacters(in: .whitespaces).isEmpty {
            index += 1
        }
        guard index < lines.count else { return (title: "", body: "") }

        let title = normalizeTitle(lines[index])
        let bodyLines = Array(lines[(index + 1)...])
        // Drop a single leading blank separator line so the body starts at content.
        let body = bodyLines
            .drop { $0.trimmingCharacters(in: .whitespaces).isEmpty }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (title: title, body: body)
    }

    // MARK: - private

    /// Remove a leading `#`/`##` heading marker and surrounding quotes/whitespace
    /// from a candidate title line.
    private static func normalizeTitle(_ line: String) -> String {
        var t = line.trimmingCharacters(in: .whitespaces)
        while t.hasPrefix("#") { t.removeFirst() }
        t = t.trimmingCharacters(in: .whitespaces)
        if t.count >= 2, t.hasPrefix("\""), t.hasSuffix("\"") {
            t = String(t.dropFirst().dropLast())
        }
        return t.trimmingCharacters(in: .whitespaces)
    }

    /// If the WHOLE response is wrapped in a ``` code fence, unwrap it.
    private static func stripOuterFence(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```") else { return text }
        var lines = trimmed.components(separatedBy: "\n")
        guard lines.count >= 2, lines.last?.trimmingCharacters(in: .whitespaces) == "```" else {
            return text
        }
        lines.removeFirst()   // opening ```lang
        lines.removeLast()    // closing ```
        return lines.joined(separator: "\n")
    }
}
