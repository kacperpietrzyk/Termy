import Foundation

/// One source line's provenance, as reported by `git blame`. Read-only context
/// surfaced in the editor gutter (EDITOR-CESE Slice 5). `lineNumber` is the
/// 1-based line in the CURRENT file (the `--line-porcelain` "final" line number),
/// so it maps directly onto the editor's laid-out lines.
public struct GitBlameLine: Equatable, Sendable {
    public let lineNumber: Int
    public let sha: String
    /// Abbreviated SHA for the gutter (first 8 chars). All-zero SHA = a line that
    /// is not yet committed (uncommitted local change).
    public var shortSHA: String { String(sha.prefix(8)) }
    public let author: String
    /// Author time as a UTC `Date`, decoded from the porcelain `author-time` epoch.
    public let date: Date?
    /// True when the SHA is the all-zero "not committed yet" sentinel git emits for
    /// lines that exist only in the working tree.
    public var isUncommitted: Bool { sha.allSatisfy { $0 == "0" } }

    public init(lineNumber: Int, sha: String, author: String, date: Date?) {
        self.lineNumber = lineNumber
        self.sha = sha
        self.author = author
        self.date = date
    }
}

/// Per-file blame: the lines in file order plus the resolved repo HEAD at fetch
/// time. HEAD is carried so a cache can be invalidated when the repo advances.
public struct GitBlame: Equatable, Sendable {
    public let lines: [GitBlameLine]

    public init(lines: [GitBlameLine]) {
        self.lines = lines
    }

    /// O(1)-ish lookup of the blame for a 1-based line number; nil when out of range.
    public func line(_ number: Int) -> GitBlameLine? {
        lines.first { $0.lineNumber == number }
    }

    /// Parse the output of `git blame --line-porcelain <file>`.
    ///
    /// `--line-porcelain` repeats the FULL commit header for every line (unlike
    /// plain `--porcelain`, which emits headers only the first time a commit
    /// appears and forces the consumer to carry metadata forward). Repeating the
    /// header makes each line self-contained and the parse trivial + robust — the
    /// right tradeoff for editor-sized files.
    ///
    /// Each line's record looks like:
    /// ```
    /// <sha> <orig-line> <final-line> [<group-count>]
    /// author <name>
    /// author-mail <…>
    /// author-time <epoch>
    /// …more headers…
    /// \t<the source line text>
    /// ```
    /// The content line (prefixed with a literal TAB) terminates the record.
    public static func parse(linePorcelain output: String) -> GitBlame {
        var lines: [GitBlameLine] = []

        var sha = ""
        var finalLineNumber = 0
        var author = ""
        var authorTime: TimeInterval?
        var haveHeader = false

        func flush() {
            guard haveHeader, finalLineNumber > 0 else { return }
            let date = authorTime.map { Date(timeIntervalSince1970: $0) }
            lines.append(GitBlameLine(lineNumber: finalLineNumber, sha: sha,
                                      author: author, date: date))
            haveHeader = false
            author = ""
            authorTime = nil
        }

        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if line.hasPrefix("\t") {
                // Content line: closes the current record.
                flush()
                continue
            }
            if line.hasPrefix("author-time ") {
                authorTime = TimeInterval(line.dropFirst("author-time ".count)
                    .trimmingCharacters(in: .whitespaces))
                continue
            }
            if line.hasPrefix("author ") {
                author = String(line.dropFirst("author ".count))
                continue
            }
            // A header line that starts with a 40-hex SHA followed by line numbers
            // is the record's opening "<sha> <orig> <final> [<count>]" line.
            let fields = line.split(separator: " ")
            if let first = fields.first, isHex(String(first), length: 40),
               fields.count >= 3, let final = Int(fields[2]) {
                // New record begins — any partial record without a content line is
                // dropped (flush only emits on the TAB content line).
                sha = String(first)
                finalLineNumber = final
                haveHeader = true
                continue
            }
            // Other headers (author-mail, committer*, summary, filename, previous,
            // boundary, …) are intentionally ignored.
        }

        return GitBlame(lines: lines)
    }

    private static func isHex(_ string: String, length: Int) -> Bool {
        guard string.count == length else { return false }
        return string.allSatisfy { $0.isHexDigit }
    }
}
