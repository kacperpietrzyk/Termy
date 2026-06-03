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

    /// Read an inclusive scroll-invariant row range into trimmed text lines.
    /// Indices MUST come from `getScrollInvariantUpdateRange()` (origin `linesTop`
    /// is internal and cannot be hand-computed). Rows evicted from scrollback
    /// return nil from `getScrollInvariantLine` and are skipped.
    static func lines(_ terminal: Terminal, scrollInvariantRows range: ClosedRange<Int>) -> [String] {
        var out: [String] = []
        for row in range {
            guard let line = terminal.getScrollInvariantLine(row: row) else { continue }
            out.append(trimmedText(of: line))
        }
        return out
    }

    struct Cell: Equatable {
        let character: Character
        let fg: Attribute.Color
    }

    /// One viewport row as cells with per-cell foreground color. Trailing
    /// space/null-filled cells are dropped (match `lineText` trimming).
    static func coloredCells(_ terminal: Terminal, viewportRow row: Int) -> [Cell] {
        guard let line = terminal.getLine(row: row) else { return [] }
        var cells: [Cell] = []
        for col in 0..<line.count {
            let cd = line[col]
            cells.append(Cell(character: cd.getCharacter(), fg: cd.attribute.fg))
        }
        while let last = cells.last, last.character == " " || last.character == "\0" {
            cells.removeLast()
        }
        return cells
    }

    /// Re-encode captured rows of cells into an SGR-colored, `\n`-joined string
    /// that `TermyCore.ANSITextParser` parses back to the same colors. This lets
    /// the existing block card render a buffer snapshot with zero card changes.
    /// Consecutive same-foreground cells are coalesced into one SGR run; each
    /// line resets (`ESC[0m`) at its end. Trailing blanks are already trimmed by
    /// the cell readers.
    static func ansiString(forCells rows: [[Cell]]) -> String {
        rows.map { cells -> String in
            var out = ""
            var current: Attribute.Color? = nil
            for cell in cells {
                if cell.fg != current {
                    out += sgr(for: cell.fg)
                    current = cell.fg
                }
                out.append(cell.character)
            }
            if current != nil && current != .defaultColor { out += "\u{1B}[0m" }
            return out
        }.joined(separator: "\n")
    }

    private static func sgr(for color: Attribute.Color) -> String {
        switch color {
        case .ansi256(let code):              return "\u{1B}[38;5;\(code)m"
        case .trueColor(let r, let g, let b): return "\u{1B}[38;2;\(r);\(g);\(b)m"
        case .defaultColor, .defaultInvertedColor: return "\u{1B}[39m"
        }
    }

    /// Read a scroll-invariant row range as an SGR-colored string (one snapshot
    /// of a command's output, ready for the block card).
    static func ansiString(_ terminal: Terminal, scrollInvariantRows range: ClosedRange<Int>) -> String {
        var rows: [[Cell]] = []
        for row in range {
            guard let line = terminal.getScrollInvariantLine(row: row) else { continue }
            var cells: [Cell] = []
            for col in 0..<line.count {
                let cd = line[col]
                cells.append(Cell(character: cd.getCharacter(), fg: cd.attribute.fg))
            }
            while let last = cells.last, last.character == " " || last.character == "\0" {
                cells.removeLast()
            }
            rows.append(cells)
        }
        return ansiString(forCells: rows)
    }

    static func trimmedText(of line: BufferLine) -> String {
        var chars: [Character] = []
        for col in 0..<line.count { chars.append(line[col].getCharacter()) }
        // SwiftTerm fills unused cells with code=0 (→ "\0"), not " "; strip both.
        while let last = chars.last, last == " " || last == "\0" { chars.removeLast() }
        return String(chars)
    }
}
