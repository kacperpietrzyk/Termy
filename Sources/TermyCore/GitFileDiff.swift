import Foundation

/// AD-3: a single line of a unified diff, classified for rendering. Pure value
/// type — the view colors by `kind` and (for `.code`) tints the content via the
/// FB-1 `SyntaxHighlighter` after the leading marker is stripped.
public struct GitDiffLine: Equatable, Sendable, Identifiable {
    public enum Kind: Equatable, Sendable {
        case hunkHeader   // "@@ -1,4 +1,6 @@ context"
        case added        // "+..."
        case removed       // "-..."
        case context      // " ..."
        case meta         // "\ No newline at end of file" and other non-content rows
    }

    public let id: Int          // stable per-file index (parse order)
    public let kind: Kind
    public let text: String     // RAW line including its leading marker

    /// Content with the leading +/-/space marker stripped — what the syntax
    /// highlighter tokenizes. Hunk-headers/meta have no marker to strip.
    public var content: String {
        switch kind {
        case .added, .removed, .context:
            return text.isEmpty ? "" : String(text.dropFirst())
        case .hunkHeader, .meta:
            return text
        }
    }

    public init(id: Int, kind: Kind, text: String) {
        self.id = id; self.kind = kind; self.text = text
    }
}

/// AD-3: the per-file diff for one changed path in an agent's worktree. Carries
/// the change status (so the row badges add/modify/delete/rename), the ± counts,
/// and the classified body lines. `untracked` marks a file synthesized read-only
/// from disk (the agent created it; it isn't in the index yet).
public struct GitFileDiff: Equatable, Sendable, Identifiable {
    public enum Status: String, Equatable, Sendable {
        case added, modified, deleted, renamed, untracked
    }

    public let path: String         // new path (post-rename)
    public let oldPath: String?     // pre-rename path, when renamed
    public let status: Status
    public let untracked: Bool      // synthesized from a `??` file on disk
    public let lines: [GitDiffLine]

    public var id: String { path }

    public var addedCount: Int { lines.filter { $0.kind == .added }.count }
    public var removedCount: Int { lines.filter { $0.kind == .removed }.count }

    public init(path: String, oldPath: String?, status: Status, untracked: Bool, lines: [GitDiffLine]) {
        self.path = path; self.oldPath = oldPath; self.status = status
        self.untracked = untracked; self.lines = lines
    }
}

/// AD-3: pure parser turning raw `git diff` (unified, `--no-color`) output into
/// per-file structures. Git-free and Foundation-only so it is unit-tested without
/// shelling out. Handles new-file/deleted-file/rename headers and the
/// "\ No newline at end of file" trailer.
public enum UnifiedDiffParser {
    public static func parse(_ raw: String) -> [GitFileDiff] {
        var files: [GitFileDiff] = []
        // Accumulators for the file currently being assembled.
        var newPath: String?
        var oldPath: String?
        var status: GitFileDiff.Status = .modified
        var lines: [GitDiffLine] = []
        var lineID = 0
        var inHunk = false

        func flush() {
            guard let path = newPath else { return }
            files.append(GitFileDiff(path: path, oldPath: oldPath,
                                     status: status, untracked: false, lines: lines))
            newPath = nil; oldPath = nil; status = .modified; lines = []; lineID = 0; inHunk = false
        }

        for rawLine in raw.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if rawLine.hasPrefix("diff --git ") {
                flush()
                // "diff --git a/<old> b/<new>" — fall back to b/ path; refined by ---/+++.
                let parts = parseDiffGitPaths(rawLine)
                oldPath = parts.old; newPath = parts.new
                status = .modified
                continue
            }
            guard newPath != nil else { continue }   // skip any preamble

            if rawLine.hasPrefix("new file mode") { status = .added; continue }
            if rawLine.hasPrefix("deleted file mode") { status = .deleted; continue }
            if rawLine.hasPrefix("rename from ") {
                status = .renamed; oldPath = String(rawLine.dropFirst("rename from ".count)); continue
            }
            if rawLine.hasPrefix("rename to ") {
                status = .renamed; newPath = String(rawLine.dropFirst("rename to ".count)); continue
            }
            if rawLine.hasPrefix("--- ") {
                if let p = pathFromHeader(rawLine), p != "/dev/null" { oldPath = p }
                continue
            }
            if rawLine.hasPrefix("+++ ") {
                if let p = pathFromHeader(rawLine), p != "/dev/null" { newPath = p }
                continue
            }
            // index / similarity / mode lines before the first hunk are git metadata.
            if !inHunk, rawLine.hasPrefix("index ") || rawLine.hasPrefix("similarity ")
                || rawLine.hasPrefix("old mode") || rawLine.hasPrefix("copy ") {
                continue
            }

            if rawLine.hasPrefix("@@") {
                inHunk = true
                lines.append(GitDiffLine(id: lineID, kind: .hunkHeader, text: rawLine)); lineID += 1
                continue
            }
            guard inHunk else { continue }

            let kind: GitDiffLine.Kind
            if rawLine.hasPrefix("+") { kind = .added }
            else if rawLine.hasPrefix("-") { kind = .removed }
            else if rawLine.hasPrefix("\\") { kind = .meta }   // "\ No newline at end of file"
            else { kind = .context }
            lines.append(GitDiffLine(id: lineID, kind: kind, text: rawLine)); lineID += 1
        }
        flush()
        return files
    }

    /// "diff --git a/old/path b/new/path" → (old, new), each with the a//b/ prefix
    /// trimmed. Best-effort split on " b/" so paths containing spaces survive.
    private static func parseDiffGitPaths(_ line: String) -> (old: String?, new: String?) {
        let body = String(line.dropFirst("diff --git ".count))
        guard let range = body.range(of: " b/") else { return (nil, nil) }
        var old = String(body[body.startIndex..<range.lowerBound])
        let new = String(body[range.upperBound...])
        if old.hasPrefix("a/") { old.removeFirst(2) }
        return (old.isEmpty ? nil : old, new.isEmpty ? nil : new)
    }

    /// "--- a/path" / "+++ b/path" → "path" (or "/dev/null"). Strips the a//b/
    /// prefix; tolerates a trailing tab-delimited timestamp.
    private static func pathFromHeader(_ line: String) -> String? {
        var rest = String(line.dropFirst(4))   // drop "--- " or "+++ "
        if let tab = rest.firstIndex(of: "\t") { rest = String(rest[rest.startIndex..<tab]) }
        if rest == "/dev/null" { return rest }
        if rest.hasPrefix("a/") || rest.hasPrefix("b/") { rest.removeFirst(2) }
        return rest.isEmpty ? nil : rest
    }
}
