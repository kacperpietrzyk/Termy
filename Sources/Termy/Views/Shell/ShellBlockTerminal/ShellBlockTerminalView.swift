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
    private var ghost: String? { store.terminalCombinedGhost(for: session.id) }
    private var highlights: [InputHighlightSpan] { store.terminalLiveHighlights(for: session.id) }

    // T5: the completion menu flips ABOVE the bottom-pinned caret, so without
    // help it floats over the most-recent block (opaque bg2 → block invisible).
    // The caret lives in the PINNED bar, not in scroll content, so reserving a
    // band at the BOTTOM of the bottom-anchored transcript pushes the newest
    // block UP and clear of the menu — without moving the caret or the menu.
    private var menuOpen: Bool { store.terminalMenuSnapshot(for: session.id) != nil }
    // Safe upper bound for the menu's height (≤ 8 description rows + footer +
    // insets ≈ 340). Over-reserving is harmless: the space above is intentional
    // void, so the block simply rises a touch higher than strictly required.
    private static let menuClearance: CGFloat = 340

    // §12.1 live pinned-input context header: real live cwd + the precmd-fed
    // live branch/node for the CURRENT prompt (Bug 1: refreshes on `cd`, clears
    // in a non-repo; nil before the first precmd → cwd-only, never stale).
    private var liveContextPills: [ShellModuleModel.ContextPill] {
        let ctx = store.livePromptContext(for: session.id)
        return ShellModuleModel.blockContextPills(
            node: ctx?.node,
            cwd: session.currentWorkingDirectory,
            branch: ctx?.branch,
            gitStatus: ctx?.gitStatus,
            duration: nil)
    }

    // Slice-2a hover actions. Copy = command + its output; Copy cwd/branch copy the
    // single field. No-op when the field is absent (Copy branch before Slice-2c).
    private func copyBlock(_ block: TerminalRenderedCommandBlock) {
        // `outputLines` is the SGR-colored buffer snapshot (e.g. `ESC[39m…`); strip
        // it through the SAME parser the card renders with so the clipboard gets the
        // clean visible text, not raw escape codes (`[39m` litter when pasted).
        let raw = block.outputLines.map(\.text).joined()
        let output = ANSITextParser().parse(raw).map(\.text).joined()
        let text = output.isEmpty ? block.command : "\(block.command)\n\(output)"
        copyToPasteboard(text)
    }
    private func copyToPasteboard(_ text: String?) {
        guard let text, !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    var body: some View {
        // §12.1 pinned-input layout: history SCROLLS in the flexible top slot
        // (bottom-aligned — short history sits low, void above, Warp-style); the
        // live input is a permanently PINNED bar below, out of the scroll. The
        // pinned bar stays INSIDE this transcript (the opaque overlay over the
        // SwiftTerm host), so the covered host remains first responder and keys
        // still reach the shell — the live bar only mirrors OSC 133 T.
        VStack(spacing: 0) {
            if blocks.isEmpty {
                // T7: a fresh session (no OSC-133 command yet) has nothing to
                // scroll, so the bottom-anchored transcript would leave the whole
                // flexible top slot as bare bg1 (the "void"). Fill that slot with
                // a real-data empty-state panel instead — live cwd/git context +
                // recent commands for this folder, each a one-click prefill
                // affordance. This slot is height-bounded, so .infinity
                // fill works (the panel covers the void rather than relocating it).
                ShellEmptyStatePanel(
                    state: ShellEmptyStateModel.make(
                        cwd: session.currentWorkingDirectory ?? "",
                        node: store.livePromptContext(for: session.id)?.node,
                        branch: store.livePromptContext(for: session.id)?.branch,
                        gitStatus: store.livePromptContext(for: session.id)?.gitStatus,
                        recentCommands: store.frequentCommands()),
                    monoFont: monoFont,
                    onPrefill: { store.insertTerminalInput($0, for: session.id) })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(blocks) { block in
                            ShellCommandBlockCard(
                                block: block,
                                theme: store.terminalTheme,
                                monoFont: monoFont,
                                onCopy: { copyBlock(block) },
                                onRerun: { store.rerunCommand(block.command) },
                                onCopyCwd: { copyToPasteboard(block.contextCwd) },
                                onCopyBranch: { copyToPasteboard(block.branch) })
                                .id(block.startLine)
                        }
                        // T5: reserve a clear band below the newest block while
                        // the completion menu is open so the menu (which flips
                        // above the pinned caret) no longer covers that block.
                        // The bottom anchor targets the END of this band, so the
                        // newest block is pushed up by `menuClearance`.
                        Color.clear
                            .frame(height: menuOpen ? Self.menuClearance : 1)
                            .id(Self.bottomID)
                    }
                    .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                // Bottom-anchored: content shorter than the viewport sits at the
                // bottom (intentional void above); newest block stays pinned as
                // history grows. Explicit scrollTo backstops append/exec changes.
                .defaultScrollAnchor(.bottom)
                .onChange(of: blocks.count) { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
                .onChange(of: executing) { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
                // T5: when the menu opens, scroll the newest block up past the
                // reserved band so it sits clear of the upward-flipped menu.
                .onChange(of: menuOpen) { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            PinnedInputBar(
                contextPills: liveContextPills,
                executing: executing,
                text: liveInput.text,
                cursor: liveInput.cursor,
                ghost: ghost,
                highlights: highlights,
                monoFont: monoFont)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // §6.1 term-window surface = the handoff design dark (bg1), matching
        // ShellTermWindow's pane so the transcript and chrome are one surface.
        .background(Color(DesignTokens.bg1))
        // F-3: render the completion menu (same store state that drives the key
        // monitor) anchored to the live caret — now from the PINNED bar, so the
        // anchor is scroll-stable; the overlay flips the menu ABOVE the caret
        // since it sits near the viewport bottom.
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

/// §12.1 permanently-pinned bottom input bar: a muted live context header
/// (node·cwd·branch·gitStatus, mirroring the block header) above the live prompt.
/// While a command runs the prompt is a dim placeholder (no caret/anchor — zle
/// isn't publishing, and no menu should open), keeping the bar height stable so
/// the layout never jumps. The bar lives INSIDE the transcript overlay so the
/// covered SwiftTerm host keeps first-responder focus.
struct PinnedInputBar: View {
    let contextPills: [ShellModuleModel.ContextPill]
    let executing: Bool
    let text: String
    let cursor: Int
    let ghost: String?
    let highlights: [InputHighlightSpan]
    let monoFont: Font

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !contextPills.isEmpty {
                ContextPillRow(pills: contextPills)
            }
            if executing {
                // Stable-height placeholder; a command owns the line, no live input.
                (Text("❯ ").foregroundStyle(Color(DesignTokens.fg4))
                 + Text("running…").foregroundStyle(Color(DesignTokens.fg4)))
                    .font(monoFont)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ShellLiveBlock(
                    text: text, cursor: cursor, ghost: ghost,
                    highlights: highlights, monoFont: monoFont)
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(DesignTokens.bg1))
        .overlay(alignment: .top) { Rectangle().fill(Color(DesignTokens.hair)).frame(height: 1) }
    }
}

/// §12.2 T1 — the input-block context as capsule CHIPS (folder / branch / ±N diff
/// / node / duration) instead of a flat `·`-joined String. Reuses the actionsRow
/// capsule style (bg2 fill + hair2 stroke, mono 10.5, fg3 text). The diff pill
/// tints by dirtiness: fg3 at `±0` (clean, in-repo), warningGold when changes are
/// pending (or the legacy bare `±` unknown-dirty marker). Pure render over the
/// `ShellModuleModel.blockContextPills` model — no data fabrication here.
struct ContextPillRow: View {
    let pills: [ShellModuleModel.ContextPill]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(pills.enumerated()), id: \.offset) { _, pill in
                chip(pill)
            }
        }
    }

    @ViewBuilder private func chip(_ pill: ShellModuleModel.ContextPill) -> some View {
        let tint = tintColor(pill)
        HStack(spacing: 3) {
            if let icon = pill.icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(tint)
            }
            Text(pill.label)
                .font(Typography.mono(10.5))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 7).padding(.vertical, 2)
        .background(Color(DesignTokens.bg2), in: Capsule())
        .overlay(Capsule().stroke(Color(DesignTokens.hair2), lineWidth: 1))
    }

    /// Diff chip tints by dirtiness; everything else is the muted secondary text.
    private func tintColor(_ pill: ShellModuleModel.ContextPill) -> Color {
        guard pill.kind == .diff else { return Color(DesignTokens.fg3) }
        // "±0" = clean in-repo → muted; anything else (±N>0 or bare legacy "±") =
        // pending changes → warning gold.
        return pill.label == "±0"
            ? Color(DesignTokens.fg3)
            : DesignTokens.Glass.warningGold.opacity(0.85)
    }
}

/// T7 fresh-session empty-state panel: replaces the bare-bg1 void above the
/// pinned input before any command has run. A quiet bg1 card surfacing the live
/// cwd/git context (the SAME `ContextPillRow` the pinned bar shows) and a
/// "Recent in this folder" list of frecency-ranked commands. Each recent row is
/// a button that PREFILLS the live buffer (no execute) — P2 keyboard-first
/// preserved: typing stays the primary path; these are optional affordances
/// (the SwiftTerm host underneath keeps first responder, so these rows are a
/// pointer shortcut layered over the always-available keyboard input).
/// Honest by construction (P1): git pills vanish outside a repo; the recents
/// section is hidden when there is no history.
struct ShellEmptyStatePanel: View {
    let state: ShellModuleModel.ShellEmptyState
    let monoFont: Font
    let onPrefill: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("New session")
                    .font(Typography.ui(13, weight: .semibold))
                    .foregroundStyle(Color(DesignTokens.fg1))
                if !state.pills.isEmpty {
                    ContextPillRow(pills: state.pills)
                }
            }
            if state.showsRecents {
                VStack(alignment: .leading, spacing: 6) {
                    Text("RECENT IN THIS FOLDER")
                        .font(Typography.ui(10, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(Color(DesignTokens.fg4))
                    ForEach(Array(state.recents.enumerated()), id: \.offset) { _, cmd in
                        Button { onPrefill(cmd) } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.uturn.backward")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(Color(DesignTokens.fg4))
                                Text(cmd)
                                    .font(monoFont)
                                    .foregroundStyle(Color(DesignTokens.fg1))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(Color(DesignTokens.bg2), in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(DesignTokens.hair2), lineWidth: 1))
                    }
                }
            } else {
                Text("Type a command below to begin.")
                    .font(Typography.ui(12))
                    .foregroundStyle(Color(DesignTokens.fg4))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18).padding(.top, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// The live (currently-typed) command: `❯ <buffer>` + a blinking caret + dimmed
/// F-1 ghost text (the cwd/branch/node live above it in `PinnedInputBar`'s
/// header). Text comes from `TermyStore.terminalLiveInput` (OSC 133 T, the F-1
/// buffer publish); the ghost from `terminalCombinedGhost` (T4: history ?? sidecar).
struct ShellLiveBlock: View {
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
            (Text("❯ ").foregroundStyle(Color(DesignTokens.primary))
             + Text(beforeAttr))
                .font(monoFont)
            // Caret sits at the cursor index (supports mid-line editing).
            BlinkingCaret()
                .anchorPreference(key: LiveCaretBoundsKey.self, value: .bounds) { $0 }
            // Text after the cursor, then the dimmed F-1 ghost (ghost is non-nil
            // only when the cursor is at the end, so `afterAttr` is empty then).
            // T1: when a ghost is offered, trail a dim `→` accept-affordance so the
            // user can see the suggestion is acceptable (matches Warp's tab/→ hint).
            (Text(afterAttr)
             + Text(ghost ?? "").foregroundStyle(Color(DesignTokens.fg1).opacity(0.35))
             + Text(ghost != nil ? "  →" : "").foregroundStyle(Color(DesignTokens.fg4)))
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
