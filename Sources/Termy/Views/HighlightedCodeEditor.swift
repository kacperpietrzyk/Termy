import SwiftUI
import AppKit
import TermyCore

/// Maps a syntax token kind to its on-brand color. Single source of truth shared
/// by the SwiftUI preview and the AppKit editor surface (DESIGN.md: content keeps
/// its own brand hues while chrome stays monochrome).
enum SyntaxTokenColor {
    static func color(for kind: SyntaxTokenKind) -> Color {
        switch kind {
        case .plain:            return Color(DesignTokens.fg1)
        case .heading:          return Color(DesignTokens.primary)
        case .keyword, .key:    return Color(DesignTokens.git.base)
        case .string:           return Color(DesignTokens.sync.base)
        case .number:           return Color(DesignTokens.agent.base)
        case .comment:          return Color(DesignTokens.fg3)
        }
    }
}

/// An editable, syntax-highlighted code surface backed by `NSTextView`.
///
/// The Editor module previously edited in a plain SwiftUI `TextEditor` and showed
/// colors only in a *separate read-only* preview pane ("worse than notepad", G6).
/// This applies the existing `SyntaxHighlighter` directly to the editing surface
/// as the user types — real in-place highlighting, no heavy dependency (P3 lean).
/// Language is inferred from `fileName`; an unknown extension renders plain.
struct HighlightedCodeEditor: NSViewRepresentable {
    @Binding var text: String
    let fileName: String?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        scroll.borderType = .noBorder
        scroll.drawsBackground = true
        scroll.backgroundColor = NSColor(Color(DesignTokens.bg1))
        guard let textView = scroll.documentView as? NSTextView else { return scroll }

        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.allowsUndo = true
        textView.font = Coordinator.editorFont
        textView.backgroundColor = NSColor(Color(DesignTokens.bg1))
        textView.textColor = NSColor(Color(DesignTokens.fg1))
        textView.insertionPointColor = NSColor(Color(DesignTokens.primary2))
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.string = text
        context.coordinator.applyHighlight(to: textView)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = scroll.documentView as? NSTextView else { return }
        context.coordinator.parent = self
        // Only overwrite when the external binding diverged (e.g. opening a new
        // file or a Vim command rewrote the buffer) — never on the user's own
        // keystrokes, which would fight the cursor.
        if textView.string != text {
            let nsText = text as NSString
            let previous = textView.selectedRange()
            textView.string = text
            let caret = min(previous.location, nsText.length)
            textView.setSelectedRange(NSRange(location: caret, length: 0))
            context.coordinator.applyHighlight(to: textView)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: HighlightedCodeEditor
        private let highlighter = SyntaxHighlighter()
        static let editorFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

        init(_ parent: HighlightedCodeEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            applyHighlight(to: textView)
        }

        /// Re-tokenize the whole buffer and recolor. Guards against a tokenizer
        /// whose concatenated tokens don't reconstruct the source length exactly
        /// (which would drift the offsets and mis-color) by falling back to a
        /// single plain color in that case. The guard sums token UTF-16 lengths
        /// rather than rebuilding the whole string, so it adds no per-keystroke
        /// allocation. (Re-highlight is whole-buffer; fine for the editor's
        /// typical file sizes — revisit with edited-range scoping for huge files.)
        func applyHighlight(to textView: NSTextView) {
            guard let storage = textView.textStorage else { return }
            let source = textView.string
            let nsSource = source as NSString
            let full = NSRange(location: 0, length: nsSource.length)

            storage.beginEditing()
            storage.addAttribute(.font, value: Coordinator.editorFont, range: full)
            storage.addAttribute(.foregroundColor, value: NSColor(SyntaxTokenColor.color(for: .plain)), range: full)

            let tokens = highlighter.highlight(source, fileName: parent.fileName)
            let tokenLengthSum = tokens.reduce(0) { $0 + ($1.text as NSString).length }
            if tokenLengthSum == nsSource.length {
                var location = 0
                for token in tokens {
                    let length = (token.text as NSString).length
                    let range = NSRange(location: location, length: length)
                    if NSMaxRange(range) <= nsSource.length, token.kind != .plain {
                        storage.addAttribute(.foregroundColor,
                                             value: NSColor(SyntaxTokenColor.color(for: token.kind)),
                                             range: range)
                    }
                    location += length
                }
            }
            storage.endEditing()
        }
    }
}
