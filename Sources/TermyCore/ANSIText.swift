import Foundation

/// SGR color, kept UI-free (indexed 0–255 or rgb). The view layer maps these to
/// the terminal theme palette; TermyCore never imports SwiftUI.
public enum ANSIColor: Equatable, Sendable {
    /// Palette index, expected 0–255 (8-bit color). The view layer maps it to the
    /// terminal theme palette.
    case indexed(Int)
    case rgb(UInt8, UInt8, UInt8)
}

/// SGR attribute set active for a run of text.
public struct ANSIAttributes: Equatable, Sendable {
    public var foreground: ANSIColor?
    public var background: ANSIColor?
    public var bold: Bool
    public var italic: Bool
    public var underline: Bool

    public init(foreground: ANSIColor? = nil, background: ANSIColor? = nil,
                bold: Bool = false, italic: Bool = false, underline: Bool = false) {
        self.foreground = foreground
        self.background = background
        self.bold = bold
        self.italic = italic
        self.underline = underline
    }
}

/// A run of text sharing one attribute set (DESIGN.md §6.1 colored output).
public struct ANSISpan: Equatable, Sendable {
    public var text: String
    public var attributes: ANSIAttributes

    public init(text: String, attributes: ANSIAttributes = ANSIAttributes()) {
        self.text = text
        self.attributes = attributes
    }
}

/// Parses ANSI SGR (`ESC [ … m`) escapes into spans, applying color/bold/italic/
/// underline. Other CSI escapes (`ESC [ … <final ≠ m>`), OSC escapes
/// (`ESC ] … BEL/ST`), and incomplete/bare escapes are dropped from the visible
/// text — never rendered.
public struct ANSITextParser: Sendable {
    public init() {}

    /// One rendered cell: a scalar plus the SGR attributes active when written.
    private struct Cell { var scalar: Unicode.Scalar; var attrs: ANSIAttributes }

    public func parse(_ input: String) -> [ANSISpan] {
        // P2a#2: render into a cursor-addressable cell grid so inline-TUI repaints
        // (claude's progress: write `78%`, move the cursor back/up, rewrite) collapse
        // to their FINAL state instead of concatenating into `787878%`. Forward-only
        // output (ls, build logs) never moves the cursor backward, so it lands cell
        // by cell exactly as before — byte-identical spans. `ESC[2J`/`H`/`J` stay
        // dropped no-ops (the pre-existing contract; alt-screen is already guarded
        // upstream), so only in-line horizontal/vertical motion is resolved.
        var lines: [[Cell]] = [[]]
        var row = 0, col = 0
        var current = ANSIAttributes()
        let scalars = Array(input.unicodeScalars)
        var i = 0

        func ensureRow() { while lines.count <= row { lines.append([]) } }
        func write(_ sc: Unicode.Scalar) {
            ensureRow()
            if col > lines[row].count {                       // CUF past end → pad
                lines[row].append(contentsOf:
                    repeatElement(Cell(scalar: " ", attrs: ANSIAttributes()),
                                  count: col - lines[row].count))
            }
            let cell = Cell(scalar: sc, attrs: current)
            if col < lines[row].count { lines[row][col] = cell } else { lines[row].append(cell) }
            col += 1
        }
        func leadingInt(_ params: String, default def: Int) -> Int {
            let digits = params.prefix { $0.isNumber }
            return digits.isEmpty ? def : (Int(digits) ?? def)
        }

        while i < scalars.count {
            let s = scalars[i]
            if s == "\n" { row += 1; col = 0; ensureRow(); i += 1; continue }
            if s == "\r" { col = 0; i += 1; continue }   // (normally normalized away)
            // ESC [ … <final-byte>
            if s == "\u{1b}", i + 1 < scalars.count, scalars[i + 1] == "[" {
                var j = i + 2
                var params = ""
                while j < scalars.count {
                    let c = scalars[j]
                    if c.value >= 0x40 && c.value <= 0x7E { break }
                    params.unicodeScalars.append(c)
                    j += 1
                }
                guard j < scalars.count else { break } // incomplete → drop tail
                switch scalars[j] {
                case "m":
                    apply(params: params, to: &current)
                case "A": row = max(0, row - leadingInt(params, default: 1)); ensureRow()
                case "B": row += leadingInt(params, default: 1); ensureRow()
                case "C": col += leadingInt(params, default: 1)
                case "D": col = max(0, col - leadingInt(params, default: 1))
                case "G": col = max(0, leadingInt(params, default: 1) - 1)   // CHA (1-based)
                case "K":                                                    // erase in line
                    ensureRow()
                    switch leadingInt(params, default: 0) {
                    case 1: for x in 0..<min(col, lines[row].count) {        // start→cursor
                                lines[row][x] = Cell(scalar: " ", attrs: ANSIAttributes()) }
                    case 2: lines[row] = []                                  // whole line
                    default: if col < lines[row].count {                     // cursor→end
                                lines[row].removeSubrange(col..<lines[row].count) }
                    }
                default: break   // J/H/f/… → dropped no-op (preserves prior contract)
                }
                i = j + 1
                continue
            }
            // Charset designation: ESC ( / ) / * / + + one final byte (e.g. `ESC ( B`).
            // Inline TUIs emit these between frames; DROP them or the bare `(B` leaks
            // as literal text (the reported `78(B78%` residue). Mirrors TerminalANSIParser.
            if s == "\u{1b}", i + 1 < scalars.count,
               "()*+".unicodeScalars.contains(scalars[i + 1]) {
                i = min(i + 3, scalars.count)
                continue
            }
            // OSC: ESC ] … terminated by BEL (0x07) or ST (ESC \). Dropped.
            if s == "\u{1b}", i + 1 < scalars.count, scalars[i + 1] == "]" {
                var j = i + 2
                while j < scalars.count {
                    if scalars[j] == "\u{07}" { j += 1; break }                       // BEL
                    if scalars[j] == "\u{1b}", j + 1 < scalars.count,
                       scalars[j + 1] == "\\" { j += 2; break }                        // ST
                    j += 1
                }
                i = j
                continue
            }
            write(s)
            i += 1
        }

        // Emit: walk the grid in order, re-insert `\n` between rows (inheriting the
        // row's trailing attrs so forward-only multi-line output coalesces exactly as
        // before), then merge runs of equal attributes into spans.
        var spans: [ANSISpan] = []
        var buffer = ""
        var bufferAttrs = ANSIAttributes()
        func push(_ sc: Unicode.Scalar, _ attrs: ANSIAttributes) {
            if !buffer.isEmpty && attrs != bufferAttrs {
                spans.append(ANSISpan(text: buffer, attributes: bufferAttrs))
                buffer = ""
            }
            if buffer.isEmpty { bufferAttrs = attrs }
            buffer.unicodeScalars.append(sc)
        }
        for (r, line) in lines.enumerated() {
            for cell in line { push(cell.scalar, cell.attrs) }
            if r < lines.count - 1 { push("\n", line.last?.attrs ?? ANSIAttributes()) }
        }
        if !buffer.isEmpty { spans.append(ANSISpan(text: buffer, attributes: bufferAttrs)) }
        return spans
    }

    private func apply(params: String, to attrs: inout ANSIAttributes) {
        if params.isEmpty { attrs = ANSIAttributes(); return }   // bare ESC[m = reset
        let codes = params.split(separator: ";", omittingEmptySubsequences: false)
            .map { Int($0) ?? 0 }
        var k = 0
        while k < codes.count {
            let code = codes[k]
            switch code {
            case 0:  attrs = ANSIAttributes()
            case 1:  attrs.bold = true
            case 3:  attrs.italic = true
            case 4:  attrs.underline = true
            case 22: attrs.bold = false
            case 23: attrs.italic = false
            case 24: attrs.underline = false
            case 30...37: attrs.foreground = .indexed(code - 30)
            case 39: attrs.foreground = nil
            case 40...47: attrs.background = .indexed(code - 40)
            case 49: attrs.background = nil
            case 90...97:  attrs.foreground = .indexed(code - 90 + 8)
            case 100...107: attrs.background = .indexed(code - 100 + 8)
            case 38, 48:
                let (color, consumed) = extendedColor(codes, after: k)
                if let color { if code == 38 { attrs.foreground = color } else { attrs.background = color } }
                k += consumed
            default: break // unknown SGR → ignore
            }
            k += 1
        }
    }

    /// Parses `5;n` (indexed) or `2;r;g;b` (truecolor) after a 38/48 introducer.
    /// Returns the color and how many EXTRA codes it consumed.
    private func extendedColor(_ codes: [Int], after index: Int) -> (ANSIColor?, Int) {
        guard index + 1 < codes.count else { return (nil, 0) }
        switch codes[index + 1] {
        case 5:
            guard index + 2 < codes.count else { return (nil, 1) }
            return (.indexed(codes[index + 2]), 2)
        case 2:
            guard index + 4 < codes.count else { return (nil, 1) }
            let r = UInt8(clamping: codes[index + 2])
            let g = UInt8(clamping: codes[index + 3])
            let b = UInt8(clamping: codes[index + 4])
            return (.rgb(r, g, b), 4)
        default:
            return (nil, 1)
        }
    }
}
