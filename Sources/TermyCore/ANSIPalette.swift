import Foundation

/// 8-bit RGB triple (UI-free; the view maps it to a SwiftUI Color).
public struct RGB8: Equatable, Sendable {
    public let r: UInt8, g: UInt8, b: UInt8
    public init(_ r: UInt8, _ g: UInt8, _ b: UInt8) { self.r = r; self.g = g; self.b = b }
}

/// Maps `ANSIColor` to concrete RGB using the standard xterm 256-color palette.
/// 0–15 base, 16–231 the 6×6×6 cube, 232–255 the 24-step grayscale ramp.
public enum ANSIPalette {
    private static let base: [RGB8] = [
        RGB8(0, 0, 0),       RGB8(205, 0, 0),     RGB8(0, 205, 0),     RGB8(205, 205, 0),
        RGB8(0, 0, 238),     RGB8(205, 0, 205),   RGB8(0, 205, 205),   RGB8(229, 229, 229),
        RGB8(127, 127, 127), RGB8(255, 0, 0),     RGB8(0, 255, 0),     RGB8(255, 255, 0),
        RGB8(92, 92, 255),   RGB8(255, 0, 255),   RGB8(0, 255, 255),   RGB8(255, 255, 255),
    ]
    private static let cubeLevels: [UInt8] = [0, 95, 135, 175, 215, 255]

    public static func rgb(forIndex index: Int) -> RGB8 {
        let i = max(0, min(255, index))
        switch i {
        case 0...15:
            return base[i]
        case 16...231:
            let n = i - 16
            return RGB8(cubeLevels[(n / 36) % 6], cubeLevels[(n / 6) % 6], cubeLevels[n % 6])
        default:
            let level = UInt8(8 + (i - 232) * 10)
            return RGB8(level, level, level)
        }
    }

    public static func resolve(_ color: ANSIColor) -> RGB8 {
        switch color {
        case .rgb(let r, let g, let b): return RGB8(r, g, b)
        case .indexed(let n): return rgb(forIndex: n)
        }
    }
}
