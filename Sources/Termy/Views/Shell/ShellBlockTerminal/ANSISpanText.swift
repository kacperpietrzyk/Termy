import SwiftUI
import TermyCore

/// Renders ANSI spans (from `ANSITextParser`) as a single SwiftUI `Text` —
/// concatenation preserves inline runs. Default foreground falls back to the
/// theme's foreground; bold/italic/underline applied per run. Backgrounds are
/// not painted per-run in v1 (rare in command output; revisit if needed).
struct ANSISpanText: View {
    let spans: [ANSISpan]
    let theme: TerminalTheme
    let font: Font

    var body: some View {
        spans.reduce(Text("")) { $0 + styled($1) }
            .font(font)
            .textSelection(.enabled)
    }

    private func styled(_ span: ANSISpan) -> Text {
        let fg: Color = span.attributes.foreground.map { Color(rgb: ANSIPalette.resolve($0)) }
            ?? Color(hex: theme.foregroundHex)
        var t = Text(span.text).foregroundStyle(fg)   // macOS 14: returns Text
        if span.attributes.bold { t = t.bold() }
        if span.attributes.italic { t = t.italic() }
        if span.attributes.underline { t = t.underline() }
        return t
    }
}

extension Color {
    /// Bridge `ANSIPalette`'s RGB triple to a SwiftUI sRGB color.
    /// (`Color(hex:)` already exists in the module — do not redefine it.)
    init(rgb: RGB8) {
        self.init(.sRGB,
                  red: Double(rgb.r) / 255,
                  green: Double(rgb.g) / 255,
                  blue: Double(rgb.b) / 255)
    }
}
