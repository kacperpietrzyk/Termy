import SwiftUI
import AppKit

/// The Termy type ramp — **macOS system font (San Francisco)** for all UI chrome
/// and **SF Mono** for keycaps / aliases / code (root `DESIGN.md`: the v2 app
/// renders in the system font, not a webfont; tracking is neutral). The terminal
/// engine font is a separate SwiftTerm setting and is intentionally not touched.
enum Typography {
    /// Returns the PostScript name if a face by that name is registered, else nil.
    static func availablePostScriptName(_ name: String) -> String? {
        NSFont(name: name, size: 12) == nil ? nil : name
    }

    /// UI text in San Francisco. Default body 13/14, meta 12, caption 11.
    static func ui(_ size: CGFloat = 13, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    /// UI-mono in SF Mono — keycaps, aliases, code, calculator expressions.
    static func mono(_ size: CGFloat = 12, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// Display (panel/section titles): 18–24, weight 600. Apply neutral/slightly
    /// negative tracking at the use site if desired (Font cannot carry tracking).
    static func display(_ size: CGFloat = 24) -> Font {
        .system(size: size, weight: .semibold)
    }
}
