import SwiftTerm

/// Reads clean text and attributes DIRECTLY from SwiftTerm's emulated buffer —
/// the single source of truth for command-block output. Uses ONLY public
/// SwiftTerm API (no internal `linesTop`/`yBase`). This is the seam the terminal
/// rebuild is built on: output is never re-parsed from the byte stream.
enum BufferSnapshot {

    /// One viewport-relative row (0..<rows) as trimmed text. Cells are
    /// space-filled by the emulator, so trailing spaces are stripped.
    static func lineText(_ terminal: Terminal, viewportRow row: Int) -> String? {
        guard let line = terminal.getLine(row: row) else { return nil }
        return trimmedText(of: line)
    }

    static func trimmedText(of line: BufferLine) -> String {
        var chars: [Character] = []
        for col in 0..<line.count { chars.append(line[col].getCharacter()) }
        // SwiftTerm fills unused cells with code=0 (→ "\0"), not " "; strip both.
        while let last = chars.last, last == " " || last == "\0" { chars.removeLast() }
        return String(chars)
    }
}
