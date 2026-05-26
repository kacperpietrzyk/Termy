import SwiftUI
import AppKit

/// The v3 type ramp (DESIGN.md §1.4 / §2.4). Geist (UI) + Geist Mono (UI-mono),
/// each with an explicit SF fallback if the bundled face is not registered
/// (e.g. running unbundled via `swift run`, or before the fonts are vendored).
/// The terminal engine font is a separate SwiftTerm setting and is intentionally
/// not touched here.
enum Typography {
    /// Returns the PostScript name if a face by that name is registered, else nil.
    static func availablePostScriptName(_ name: String) -> String? {
        NSFont(name: name, size: 12) == nil ? nil : name
    }

    private static func custom(_ name: String, size: CGFloat, fallbackWeight: Font.Weight) -> Font {
        if let resolved = availablePostScriptName(name) {
            return .custom(resolved, size: size)   // weight is encoded in the chosen face
        }
        return .system(size: size, weight: fallbackWeight)   // SF fallback keeps the weight
    }

    private static func customMono(_ name: String, size: CGFloat, fallbackWeight: Font.Weight) -> Font {
        if let resolved = availablePostScriptName(name) {
            return .custom(resolved, size: size)
        }
        return .system(size: size, weight: fallbackWeight, design: .monospaced)
    }

    /// UI text. Default body 14, meta 12.
    static func ui(_ size: CGFloat = 14, weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .semibold, .bold, .heavy, .black: return custom("Geist-SemiBold", size: size, fallbackWeight: weight)
        case .medium:                          return custom("Geist-Medium", size: size, fallbackWeight: weight)
        default:                               return custom("Geist-Regular", size: size, fallbackWeight: weight)
        }
    }

    /// UI-mono. Terminal 13, UI mono 12, label 11.
    static func mono(_ size: CGFloat = 12, weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .medium, .semibold, .bold, .heavy, .black: return customMono("GeistMono-Medium", size: size, fallbackWeight: weight)
        default:                                        return customMono("GeistMono-Regular", size: size, fallbackWeight: weight)
        }
    }

    /// Display (h1/h2): 26–32, weight 600. Apply `.tracking(-size * 0.025)` at the
    /// use site (Font cannot carry tracking).
    static func display(_ size: CGFloat = 28) -> Font {
        custom("Geist-SemiBold", size: size, fallbackWeight: .semibold)
    }
}
