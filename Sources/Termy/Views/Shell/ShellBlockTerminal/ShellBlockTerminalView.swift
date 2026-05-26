import SwiftUI
import TermyCore

/// Publishes the live block's caret bounds so the F-3 completion menu can anchor
/// to it (re-anchored from `SwiftTerm.caretFrame`, which is covered/invisible
/// once the transcript overlays the host).
private struct LiveCaretBoundsKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

/// §6.1 Warp-style block-terminal transcript: one scrolling `.t-body` column of
/// frozen command-block cards (finished OSC-133 blocks) followed by the **live
/// block** — the current prompt + line-editor buffer + caret + F-1 ghost text —
/// rendered in the SAME block style so there is no visible raw terminal. Shown
/// as an opaque overlay over the live SwiftTerm host in `ShellTermWindow`; the
/// host stays the input engine underneath (covered ≠ hidden — AppKit still
/// routes keys to it). The F-3 completion menu anchors to the live caret.
struct ShellBlockTranscript: View {
    @ObservedObject var store: TermyStore
    let session: TermySession

    private var monoFont: Font { Typography.mono(12.5) }
    private static let bottomID = "termy.transcript.bottom"

    // All blocks — the running command (exitCode == nil) renders as a RUNNING
    // card with its live, accumulating output; finished ones get the EXIT badge.
    private var blocks: [TerminalRenderedCommandBlock] {
        store.renderedTerminalCommandBlocks()
    }
    private var executing: Bool { store.terminalCommandIsExecuting(for: session.id) }
    private var liveInput: (text: String, cursor: Int) {
        store.terminalLiveInput(for: session.id) ?? ("", 0)
    }
    private var ghost: String? { store.terminalInlineSuggestionSuffix(for: session.id) }
    private var highlights: [InputHighlightSpan] { store.terminalLiveHighlights(for: session.id) }

    private var promptUserHost: String {
        let host = session.profile.kind == .local ? ShellModuleModel.machineShortName : session.profile.host
        return session.profile.user.map { "\($0)@\(host)" } ?? host
    }
    private var cwd: String? {
        session.currentWorkingDirectory.map { ShellModuleModel.abbreviateTilde($0) }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(blocks) { block in
                        ShellCommandBlockCard(
                            block: block,
                            promptUserHost: promptUserHost,
                            cwd: cwd,
                            theme: store.terminalTheme,
                            monoFont: monoFont)
                            .id(block.startLine)
                    }
                    // The live input block — only at the prompt. While a command
                    // runs, the RUNNING card above is the active line instead.
                    if !executing {
                        ShellLiveBlock(
                            promptUserHost: promptUserHost,
                            cwd: cwd,
                            text: liveInput.text,
                            cursor: liveInput.cursor,
                            ghost: ghost,
                            highlights: highlights,
                            monoFont: monoFont)
                    }
                    Color.clear.frame(height: 1).id(Self.bottomID)
                }
                .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 14)
            }
            // Keep the bottom (live block / running card) in view as history
            // grows and as you type.
            .onChange(of: blocks.count) { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
            .onChange(of: liveInput.text) { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
            .onChange(of: executing) { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // §6.1 term-window surface = the handoff design dark (bg1), matching
        // ShellTermWindow's pane so the transcript and chrome are one surface.
        .background(Color(DesignTokens.bg1))
        // F-3: render the completion menu (same store state that drives the key
        // monitor) anchored under the live caret, on top of the transcript.
        .overlayPreferenceValue(LiveCaretBoundsKey.self) { caretAnchor in
            GeometryReader { geo in
                if let caretAnchor, let menu = store.terminalMenuSnapshot(for: session.id) {
                    let rect = geo[caretAnchor]
                    CompletionMenuOverlay(
                        snapshot: menu,
                        anchor: CGPoint(x: rect.minX, y: rect.minY),
                        viewportSize: geo.size,
                        font: terminalNSFont(store.terminalFontPreferences))
                        .allowsHitTesting(false)
                }
            }
        }
    }
}

/// The live (currently-typed) command, rendered as a block matching
/// `ShellCommandBlockCard`'s prompt line: `user@host:cwd ❯ <buffer>` + a blinking
/// caret + dimmed F-1 ghost text. Text comes from `TermyStore.terminalLiveInput`
/// (OSC 133 T, the F-1 buffer publish); the ghost from `terminalInlineSuggestionSuffix`.
struct ShellLiveBlock: View {
    let promptUserHost: String
    let cwd: String?
    let text: String
    let cursor: Int
    let ghost: String?
    let highlights: [InputHighlightSpan]
    let monoFont: Font

    var body: some View {
        // FB-1: color the buffer with the zsh-syntax-highlighting spans, then
        // split at the cursor so the caret sits at the edit position.
        let full = Self.styled(text, highlights: highlights)
        let idx = max(0, min(cursor, text.count))
        let splitIndex = full.index(full.startIndex, offsetByCharacters: idx)
        let beforeAttr = AttributedString(full[full.startIndex..<splitIndex])
        let afterAttr = AttributedString(full[splitIndex..<full.endIndex])
        HStack(alignment: .center, spacing: 0) {
            (Text(promptUserHost).foregroundStyle(Color(DesignTokens.primary))
             + Text(cwd.map { ":\($0)" } ?? "").foregroundStyle(Color(DesignTokens.fg3))
             + Text("  ❯ ").foregroundStyle(Color(DesignTokens.primary))
             + Text(beforeAttr))
                .font(monoFont)
            // Caret sits at the cursor index (supports mid-line editing).
            BlinkingCaret()
                .anchorPreference(key: LiveCaretBoundsKey.self, value: .bounds) { $0 }
            // Text after the cursor, then the dimmed F-1 ghost (ghost is non-nil
            // only when the cursor is at the end, so `afterAttr` is empty then).
            (Text(afterAttr)
             + Text(ghost ?? "").foregroundStyle(Color(DesignTokens.fg1).opacity(0.35)))
                .font(monoFont)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    /// Build an `AttributedString` of the buffer with per-span foreground colors
    /// (FB-1 `region_highlight`). Unspanned text uses `fg1`.
    private static func styled(_ text: String, highlights: [InputHighlightSpan]) -> AttributedString {
        var attr = AttributedString(text)
        attr.foregroundColor = Color(DesignTokens.fg1)
        let len = text.count
        for span in highlights {
            guard let hex = span.foregroundHex else { continue }
            let lo = max(0, min(span.start, len))
            let hi = max(lo, min(span.end, len))
            guard lo < hi else { continue }
            let start = attr.index(attr.startIndex, offsetByCharacters: lo)
            let end = attr.index(attr.startIndex, offsetByCharacters: hi)
            attr[start..<end].foregroundColor = Color(hex: hex)
            if span.underline { attr[start..<end].underlineStyle = .single }
        }
        return attr
    }
}

/// A blinking block caret (matches the handoff `.caret`: ~7×14 primary, ~1.1s
/// blink). State-free — derives phase from the timeline clock.
struct BlinkingCaret: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.55)) { context in
            let on = Int(context.date.timeIntervalSinceReferenceDate / 0.55) % 2 == 0
            RoundedRectangle(cornerRadius: 1)
                .fill(Color(DesignTokens.primary))
                .frame(width: 7, height: 15)
                .opacity(on ? 1 : 0)
                .padding(.leading, 2)
        }
    }
}
