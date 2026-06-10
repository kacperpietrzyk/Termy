import Foundation

/// A best-effort, OFFLINE extractor for the enclosing-scope header(s) around an
/// editor selection — used to enrich local-AI prompts with structural context so
/// "explain / propose on selection" sees the surrounding declaration rather than
/// a bare fragment.
///
/// ED-4 (EDITOR-CESE Slice 4): the blueprint's "tree-sitter symbols as context"
/// is gated on the CodeEditSourceEditor / SwiftTreeSitter adoption (Slice 1),
/// which has NOT landed. Rather than fabricate a fake "tree-sitter" layer, this
/// is a deliberately-named, lexical, heuristic extractor: it walks the lines
/// ABOVE the selection and reports the nearest enclosing declaration header(s)
/// (function / type / block opener). It is correct for the common case and
/// honest about being a heuristic — semantic, grammar-accurate symbols arrive
/// with the tree-sitter engine in a later slice.
///
/// Pure value logic with no I/O, so it is trivially unit-testable and can never
/// reach the network (preserving the P1 zero-remote posture of the AI path).
public enum EditorEnclosingScope {

    /// Extract the enclosing-scope header lines for the UTF-16 selection
    /// `[location, location+length)` inside `text`, for the given `language`.
    ///
    /// Returns an ordered list of header lines from outermost to innermost
    /// (e.g. `["struct Foo {", "func bar() {"]`), trimmed of trailing
    /// whitespace, with at most `maxDepth` entries kept (the innermost are
    /// preferred when the nesting is deeper). Returns an empty array when no
    /// enclosing scope can be identified (top-level selection, plain text, or a
    /// language without a recognised block structure).
    public static func headers(
        in text: String,
        selection: EditorSelection,
        language: EditorLanguage,
        maxDepth: Int = 3
    ) -> [String] {
        guard maxDepth > 0, !text.isEmpty else { return [] }

        // Resolve the selection's start line (UTF-16 offsets → line index).
        let ns = text as NSString
        let clampedStart = max(0, min(selection.location, ns.length))
        let startLineRange = ns.lineRange(for: NSRange(location: clampedStart, length: 0))
        let startLineIndex = ns.substring(to: startLineRange.location)
            .components(separatedBy: "\n").count - 1

        let lines = text.components(separatedBy: "\n")
        guard startLineIndex >= 0, startLineIndex < lines.count else { return [] }

        switch language {
        case .python:
            return pythonHeaders(lines: lines, startLineIndex: startLineIndex, maxDepth: maxDepth)
        default:
            return braceHeaders(lines: lines, startLineIndex: startLineIndex, maxDepth: maxDepth)
        }
    }

    /// A compact, prompt-ready context block built from the enclosing headers.
    /// Empty string when there is no scope to report, so callers can append it
    /// unconditionally without adding noise.
    public static func promptContext(
        in text: String,
        selection: EditorSelection,
        language: EditorLanguage,
        maxDepth: Int = 3
    ) -> String {
        let headers = headers(in: text, selection: selection, language: language, maxDepth: maxDepth)
        guard !headers.isEmpty else { return "" }
        return headers.joined(separator: "\n")
    }

    // MARK: - Brace-family (Swift / JS / TS / Go / Rust / C-like / JSON-ish)

    /// Walk upward from the selection's line, tracking net brace depth. A line
    /// that opens a block (its running depth, scanned bottom-up, drops below the
    /// baseline) and looks like a declaration/control header is recorded as an
    /// enclosing scope. Bottom-up scanning lets us find the openers whose
    /// matching `}` is at-or-after the selection.
    private static func braceHeaders(lines: [String], startLineIndex: Int, maxDepth: Int) -> [String] {
        var headers: [String] = []
        // `depth` = number of currently-unmatched `}` seen scanning upward. When
        // we hit a line that takes us to a new minimum (an unmatched `{`), that
        // line is an enclosing opener.
        var closeDeficit = 0
        var index = startLineIndex
        while index >= 0 {
            let line = lines[index]
            let opens = countOutsideStringsAndComments(line, char: "{")
            let closes = countOutsideStringsAndComments(line, char: "}")

            // Process closers first (they belong to inner scopes already passed),
            // then openers. Net effect upward: each unmatched opener on this line
            // (opens beyond what its own closes + the pending deficit absorb) is an
            // enclosing block for the selection.
            closeDeficit += closes
            let unmatchedOpens = opens - closeDeficit
            if unmatchedOpens > 0 {
                let header = line.trimmingCharacters(in: CharacterSet(charactersIn: " \t"))
                if !header.isEmpty {
                    headers.append(trimToHeader(header))
                }
                closeDeficit = 0
            } else {
                closeDeficit = max(0, closeDeficit - opens)
            }

            if headers.count >= maxDepth { break }
            index -= 1
        }
        return headers.reversed()
    }

    // MARK: - Python (indentation + def/class)

    /// For Python, the enclosing scope is the nearest line with strictly smaller
    /// indentation that begins a `def`/`class`/block keyword. Walk upward keeping
    /// only headers at successively smaller indents.
    private static func pythonHeaders(lines: [String], startLineIndex: Int, maxDepth: Int) -> [String] {
        var headers: [String] = []
        let selectionIndent = indentWidth(lines[startLineIndex])
        var currentIndent = selectionIndent
        var index = startLineIndex - 1
        let openers = ["def ", "class ", "async def ", "if ", "elif ", "else:", "for ", "while ", "with ", "try:", "except", "finally:"]
        while index >= 0 {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: CharacterSet(charactersIn: " \t"))
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                index -= 1
                continue
            }
            let lineIndent = indentWidth(line)
            if lineIndent < currentIndent, openers.contains(where: { trimmed.hasPrefix($0) }) {
                headers.append(trimToHeader(trimmed))
                currentIndent = lineIndent
                if headers.count >= maxDepth || lineIndent == 0 { break }
            }
            index -= 1
        }
        return headers.reversed()
    }

    // MARK: - Helpers

    /// Keep the header line readable: drop a trailing `{` and collapse to the
    /// signature so the prompt context is a clean "func bar(...)" rather than the
    /// raw source line with its opening brace.
    private static func trimToHeader(_ line: String) -> String {
        var header = line
        if header.hasSuffix("{") {
            header = String(header.dropLast()).trimmingCharacters(in: CharacterSet(charactersIn: " \t"))
        }
        return header
    }

    /// Leading-whitespace width (tabs counted as 1) of a line.
    private static func indentWidth(_ line: String) -> Int {
        var width = 0
        for ch in line {
            if ch == " " || ch == "\t" { width += 1 } else { break }
        }
        return width
    }

    /// Count occurrences of `char` in `line`, skipping characters inside string
    /// literals (single/double quotes) and after a line comment (`//` or `#`).
    /// A small lexer — not a full parser — sufficient to avoid the common
    /// false-positive where a `{` appears inside a string or trailing comment.
    private static func countOutsideStringsAndComments(_ line: String, char: Character) -> Int {
        var count = 0
        var inSingle = false
        var inDouble = false
        var previous: Character?
        let chars = Array(line)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if !inSingle && !inDouble {
                // Line comments end the scan.
                if c == "/" && i + 1 < chars.count && chars[i + 1] == "/" { break }
                if c == "#" { break }
            }
            if c == "\"" && !inSingle && previous != "\\" {
                inDouble.toggle()
            } else if c == "'" && !inDouble && previous != "\\" {
                inSingle.toggle()
            } else if c == char && !inSingle && !inDouble {
                count += 1
            }
            previous = c
            i += 1
        }
        return count
    }
}
