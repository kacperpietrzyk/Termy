import SwiftUI
import TermyCore

/// Footer state for a command block. Poziom-2b: a successful command shows NO
/// footer chrome (clean, like Warp); only an error surfaces `EXIT n` (Slice-2a:
/// duration now lives on the context header, not here), and a still-running
/// command shows `RUNNING`.
enum BlockFooterState: Equatable {
    case none                 // exit == 0 → clean, no chrome
    case running              // not finished yet
    case error(code: Int32)   // exit != 0 → surface it

    init(exitCode: Int32?) {
        guard let exit = exitCode else { self = .running; return }
        self = exit == 0 ? .none : .error(code: exit)
    }
}

/// §12.2 Slice-2a flat-C block: a muted **context-header line**
/// (`node · cwd · branch · gitStatus · duration`) → the **command** in bold →
/// ANSI-colored output (the Slice-1 snapshot) → a footer that is empty on success
/// and shows `EXIT n` only on error. Blocks are separated by a 1px hairline;
/// hovering (or selection) reveals an actions row (Copy / Rerun / Copy cwd /
/// Copy branch). A finished alt-screen command (claude/vim) shows a compact
/// "▦ ran fullscreen" annotation instead of an empty body.
struct ShellCommandBlockCard: View {
    let block: TerminalRenderedCommandBlock
    let theme: TerminalTheme
    let monoFont: Font
    var onCopy: () -> Void = {}
    var onRerun: () -> Void = {}
    var onCopyCwd: () -> Void = {}
    var onCopyBranch: () -> Void = {}

    @State private var hovering = false

    private var outputSpans: [ANSISpan] {
        ANSITextParser().parse(block.outputLines.map(\.text).joined())
    }

    private var contextHeader: String {
        ShellModuleModel.blockContextHeader(
            node: block.node,
            cwd: block.contextCwd,
            branch: block.branch,
            gitStatus: block.gitStatus,
            duration: block.duration)
    }

    private var showActions: Bool { hovering || block.isSelected }

    /// Which body the card renders. Pure so criterion-#4 logic is unit-testable:
    /// a fullscreen (alt-screen) command with no inline output shows the compact
    /// annotation; a plain no-output command (`cd`/`export`) shows nothing.
    enum BodyKind: Equatable { case fullscreenAnnotation, output, empty }
    static func bodyKind(enteredAltScreen: Bool, hasOutput: Bool) -> BodyKind {
        if enteredAltScreen && !hasOutput { return .fullscreenAnnotation }
        return hasOutput ? .output : .empty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !contextHeader.isEmpty {
                Text(contextHeader)
                    .font(Typography.mono(10.5))
                    .foregroundStyle(Color(DesignTokens.fg4))
                    .textSelection(.enabled)
            }
            commandLine
            bodyContent
            footer
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        // §12.2 thin 1px separator between blocks.
        .overlay(alignment: .top) {
            Rectangle().fill(Color(DesignTokens.hair)).frame(height: 1)
        }
        // Hover actions float as an overlay so revealing them never shifts the
        // transcript layout under the cursor (Warp behavior).
        .overlay(alignment: .topTrailing) {
            if showActions { actionsRow.padding(.top, 4) }
        }
        .onHover { hovering = $0 }
    }

    private var commandLine: some View {
        (Text("❯ ").foregroundStyle(Color(DesignTokens.primary))
         + Text(block.command).foregroundStyle(Color(DesignTokens.fg1)))
            .font(monoFont.weight(.semibold))
            .textSelection(.enabled)
    }

    @ViewBuilder private var bodyContent: some View {
        switch Self.bodyKind(enteredAltScreen: block.enteredAltScreen, hasOutput: !block.outputLines.isEmpty) {
        case .fullscreenAnnotation:
            // The alt-screen owned the display; the inline block is intentionally
            // empty (NOT a no-output command).
            Text("▦ ran fullscreen\(block.exitCode.map { " · exit \($0)" } ?? "")")
                .font(Typography.mono(10.5))
                .foregroundStyle(Color(DesignTokens.fg4))
        case .output:
            ANSISpanText(spans: outputSpans, theme: theme, font: monoFont)
        case .empty:
            EmptyView()
        }
    }

    @ViewBuilder private var footer: some View {
        switch BlockFooterState(exitCode: block.exitCode) {
        case .none:
            EmptyView()                              // success → clean, no chrome
        case .running:
            HStack(spacing: 8) { badge(text: "RUNNING", ok: nil) }
        case .error(let code):
            HStack(spacing: 8) { badge(text: "EXIT \(code)", ok: false) }
        }
    }

    private var actionsRow: some View {
        HStack(spacing: 12) {
            actionButton("Copy", action: onCopy)
            actionButton("Rerun", action: onRerun)
            if block.contextCwd != nil { actionButton("Copy cwd", action: onCopyCwd) }
            if block.branch != nil { actionButton("Copy branch", action: onCopyBranch) }
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Color(DesignTokens.bg2), in: Capsule())
        .overlay(Capsule().stroke(Color(DesignTokens.hair2), lineWidth: 1))
    }

    private func actionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Typography.mono(9.5, weight: .medium)).tracking(0.3)
                .foregroundStyle(Color(DesignTokens.fg3))
        }
        .buttonStyle(.plain)
    }

    private func badge(text: String, ok: Bool?) -> some View {
        let tint: OKLCH = ok == nil
            ? DesignTokens.fg4
            : (ok! ? DesignTokens.sync.base : DesignTokens.error.base)
        return Text(text)
            .font(Typography.mono(9.5, weight: .semibold)).tracking(0.4)
            .foregroundStyle(Color(tint))
            .padding(.horizontal, 6).padding(.vertical, 1)
            .background(Color(tint).opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(tint).opacity(0.4), lineWidth: 1))
    }
}
