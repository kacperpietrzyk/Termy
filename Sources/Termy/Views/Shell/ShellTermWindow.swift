import SwiftUI
import TermyCore

/// DESIGN.md §6.1 term-window: a `t-h` header strip over the selected session's
/// live render. Reuses `TerminalStageView` (rawPTY LiveTerminalSurface / blocks /
/// stream / RDP / SSH input + search) with its own `Header` suppressed — the
/// dt-header + this strip already identify the session. No new terminal engine.
struct ShellTermWindow: View {
    @ObservedObject var store: TermyStore
    let session: TermySession

    private var shellLabel: String {
        ShellModuleModel.liveChipLabel(kind: session.profile.kind,
                                       zshVersion: store.shellVersion(forSession: session.id))
    }

    var body: some View {
        let mode = store.selectedTerminalOutputModeValue
        let routeBlocks = session.profile.kind == .local && session.interactionMode == .rawPTY && mode == .blocks
        let altScreen = store.terminalAltScreenActive(for: session.id)
        // §6.1 design-faithful: the block transcript (history cards + the live
        // block) covers the whole pane while at the prompt; the live SwiftTerm is
        // revealed only when a TUI owns the alternate screen (vim/htop).
        let showTranscript = routeBlocks && !altScreen

        VStack(spacing: 0) {
            header
            ZStack {
                // SwiftTerm host: ALWAYS the first ZStack child so its structural
                // slot never moves (a moved slot remounts the NSView → black,
                // focus-less terminal — ffb4a38). It is the input engine AND the
                // alt-screen TUI renderer; the transcript covers it otherwise.
                TerminalStageView(store: store, showsHeader: false)
                if showTranscript {
                    // Opaque transcript ON TOP of the host. Keystrokes still route
                    // to the covered host (covered ≠ hidden — AppKit dispatches to
                    // the first responder regardless of z-order); the live block
                    // renders the current line-editor buffer so you see your input.
                    ShellBlockTranscript(store: store, session: session)
                }
            }
        }
        // Fill the available pane height — the terminal is the focus, not a
        // boxed card. The parent gives a definite size, so the transcript's
        // ScrollView scrolls internally and the vim takeover stays bounded.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // §6.1 term-window surface = the handoff's `oklch(10% 0.01 285)` ≈ bg1
        // (the design system's dark), not the per-user terminal theme bg.
        .background(Color(DesignTokens.bg1),
                    in: RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
            .stroke(Color(DesignTokens.hair), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
    }

    private var header: some View {
        HStack(spacing: 8) {
            // Pulses green only while the child is alive; settles to a dim dot once it exits.
            TermyStatusDot(hue: session.processExited ? DesignTokens.fg5 : DesignTokens.sync.base,
                           pulsing: !session.processExited)
            Text(session.title).font(Typography.ui(12, weight: .medium)).foregroundStyle(Color(DesignTokens.fg1))
            Text("· \(shellLabel)").font(Typography.mono(11)).foregroundStyle(Color(DesignTokens.fg4))
            Spacer()
            Text("sidecar \(store.sidecarDisabledSessions.contains(session.id) ? "disabled" : "healthy")")
                .font(Typography.mono(10.5)).foregroundStyle(Color(DesignTokens.fg4))
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        // Handoff `.t-h` uses --bg-1; the hairline below delineates it.
        .background(Color(DesignTokens.bg1))
        .overlay(alignment: .bottom) { Rectangle().fill(Color(DesignTokens.hair)).frame(height: 1) }
    }
}
