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

    public func parse(_ input: String) -> [ANSISpan] {
        var spans: [ANSISpan] = []
        var current = ANSIAttributes()
        var buffer = ""
        let scalars = Array(input.unicodeScalars)
        var i = 0

        func flush() {
            guard !buffer.isEmpty else { return }
            spans.append(ANSISpan(text: buffer, attributes: current))
            buffer = ""
        }

        while i < scalars.count {
            let s = scalars[i]
            // ESC [ … <final-byte>
            if s == "\u{1b}", i + 1 < scalars.count, scalars[i + 1] == "[" {
                var j = i + 2
                var params = ""
                // CSI params/intermediates run until a final byte 0x40–0x7E.
                while j < scalars.count {
                    let c = scalars[j]
                    if c.value >= 0x40 && c.value <= 0x7E { break }
                    params.unicodeScalars.append(c)
                    j += 1
                }
                guard j < scalars.count else { break } // incomplete → drop tail
                let finalByte = scalars[j]
                if finalByte == "m" {
                    flush()
                    apply(params: params, to: &current)
                }
                // any non-'m' final byte (J, H, K, …) is a non-SGR CSI → dropped
                i = j + 1
                continue
            }
            // OSC: ESC ] … terminated by BEL (0x07) or ST (ESC \). Dropped.
            if s == "\u{1b}", i + 1 < scalars.count, scalars[i + 1] == "]" {
                var j = i + 2
                while j < scalars.count {
                    if scalars[j] == "\u{07}" {                       // BEL
                        j += 1
                        break
                    }
                    if scalars[j] == "\u{1b}", j + 1 < scalars.count,
                       scalars[j + 1] == "\\" {                       // ST = ESC \
                        j += 2
                        break
                    }
                    j += 1
                }
                i = j   // consume OSC (+terminator if found); no text emitted
                continue
            }
            buffer.unicodeScalars.append(s)
            i += 1
        }
        flush()
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
