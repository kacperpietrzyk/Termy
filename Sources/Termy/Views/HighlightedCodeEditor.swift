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
    /// ED-4: reports the live caret/selection (UTF-16 offset + length) back to the
    /// model so local-AI explain/complete operate on the user's real selection in
    /// normal editing — not only in Vim mode. Optional so existing callers that
    /// don't care about selection stay source-unchanged.
    var onSelectionChange: ((EditorSelection) -> Void)?

    init(text: Binding<String>, fileName: String?, onSelectionChange: ((EditorSelection) -> Void)? = nil) {
        self._text = text
        self.fileName = fileName
        self.onSelectionChange = onSelectionChange
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    /// Build the editor's scroll view + text view + line-number gutter. Pulled
    /// out of `makeNSView` so the gutter wiring is testable without a SwiftUI
    /// `Context` (which is not directly constructible). Returns the scroll view;
    /// its `documentView` is the configured `NSTextView`.
    static func makeScrollViewWithGutter(text: String) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        scroll.borderType = .noBorder
        scroll.drawsBackground = true
        scroll.backgroundColor = NSColor(Color(DesignTokens.bg1))
        guard let textView = scroll.documentView as? NSTextView else { return scroll }

        // Line-number gutter: the most basic "this is a code editor" signal (M3).
        // Pure AppKit NSRulerView — no dependency (P3 lean).
        let ruler = LineNumberRulerView(textView: textView)
        scroll.verticalRulerView = ruler
        scroll.hasVerticalRuler = true
        scroll.rulersVisible = true

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
        return scroll
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = Self.makeScrollViewWithGutter(text: text)
        guard let textView = scroll.documentView as? NSTextView else { return scroll }
        textView.delegate = context.coordinator
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
            scroll.verticalRulerView?.needsDisplay = true
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
            textView.enclosingScrollView?.verticalRulerView?.needsDisplay = true
        }

        /// ED-4: forward the live caret/selection (UTF-16 offsets) to the model so
        /// the AI-on-selection path sees the user's real selection in normal
        /// editing. A no-op when no observer is wired.
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let onSelectionChange = parent.onSelectionChange,
                  let textView = notification.object as? NSTextView else { return }
            let range = textView.selectedRange()
            onSelectionChange(EditorSelection(location: range.location, length: range.length))
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

/// A line-number gutter for the editor's `NSTextView`, drawn as the scroll view's
/// vertical ruler. Pure AppKit (no dependency, P3 lean). Numbers are 1-based,
/// monospaced `fg3` against the editor's `bg1`, and stay aligned to each line's
/// laid-out glyph rect so they track soft-wrapping and scrolling.
final class LineNumberRulerView: NSRulerView {
    private weak var textView: NSTextView?

    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 40
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 1-based line number for each line whose glyph rect intersects the visible
    /// region, used both for drawing and as the gate's "ruler reports >=1 label".
    func visibleLineLabels() -> [(number: Int, y: CGFloat)] {
        guard let textView,
              let layoutManager = textView.layoutManager,
              let container = textView.textContainer else { return [] }

        let nsString = textView.string as NSString
        let fullGlyphRange = layoutManager.glyphRange(for: container)
        guard fullGlyphRange.length > 0 || nsString.length == 0 else { return [] }

        var labels: [(Int, CGFloat)] = []
        let inset = textView.textContainerInset.height
        var lineNumber = 1
        var charIndex = 0

        // Walk character lines; for each, find the glyph rect of its first glyph.
        while charIndex < nsString.length {
            let lineRange = nsString.lineRange(for: NSRange(location: charIndex, length: 0))
            let glyphRange = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)
            let rect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphRange.location, length: 0), in: container)
            labels.append((lineNumber, rect.minY + inset))
            lineNumber += 1
            charIndex = NSMaxRange(lineRange)
        }

        // Trailing empty line (string ends in a newline, or is empty).
        if nsString.length == 0 || nsString.hasSuffix("\n") {
            let rect = layoutManager.boundingRect(
                forGlyphRange: NSRange(location: layoutManager.numberOfGlyphs, length: 0), in: container)
            labels.append((lineNumber, rect.minY + inset))
        }
        return labels
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView, let scrollView = textView.enclosingScrollView else { return }

        NSColor(Color(DesignTokens.bg1)).setFill()
        rect.fill()

        let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(Color(DesignTokens.fg3)),
        ]

        let relativePoint = convert(NSZeroPoint, from: textView)
        let visibleRect = scrollView.contentView.bounds

        for label in visibleLineLabels() {
            let y = label.y + relativePoint.y
            guard y + font.boundingRectForFont.height >= 0, y <= visibleRect.height else { continue }
            let text = "\(label.number)" as NSString
            let size = text.size(withAttributes: attributes)
            let drawX = ruleThickness - size.width - 6
            text.draw(at: NSPoint(x: drawX, y: y), withAttributes: attributes)
        }
    }
}
