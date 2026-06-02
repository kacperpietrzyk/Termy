import SwiftUI
import TermyCore

/// Footer state for a command block. Poziom-2b: a successful command shows NO
/// footer chrome (clean, like Warp); only an error surfaces `EXIT n` (+ its
/// duration for context), and a still-running command shows `RUNNING`.
enum BlockFooterState: Equatable {
    case none                 // exit == 0 → clean, no chrome
    case running              // not finished yet
    case error(code: Int32)   // exit != 0 → surface it

    init(exitCode: Int32?) {
        guard let exit = exitCode else { self = .running; return }
        self = exit == 0 ? .none : .error(code: exit)
    }
}

/// §6.1 inline command block (NOT a bordered card — matches the handoff `.ln`):
/// a prompt line (`user@host:cwd ❯ command`) → ANSI-colored output → a footer
/// that is empty on success and shows `EXIT n` (+ duration) only on error, or
/// `RUNNING` while in flight. Output color comes from the foundation
/// `ANSITextParser` over the captured transcript text.
struct ShellCommandBlockCard: View {
    let block: TerminalRenderedCommandBlock
    let promptUserHost: String      // e.g. "kacper@mac-studio-kacper"
    let cwd: String?                // tilde-abbreviated, may be nil
    let theme: TerminalTheme
    let monoFont: Font

    private var outputSpans: [ANSISpan] {
        ANSITextParser().parse(block.outputLines.map(\.text).joined())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            promptLine
            if !block.outputLines.isEmpty {
                ANSISpanText(spans: outputSpans, theme: theme, font: monoFont)
            }
            footer
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private var promptLine: some View {
        (Text(promptUserHost).foregroundStyle(Color(DesignTokens.primary))
         + Text(cwd.map { ":\($0)" } ?? "").foregroundStyle(Color(DesignTokens.fg3))
         + Text("  ❯ ").foregroundStyle(Color(DesignTokens.primary))
         + Text(block.command).foregroundStyle(Color(DesignTokens.fg1)))
            .font(monoFont)
            .textSelection(.enabled)
    }

    @ViewBuilder private var footer: some View {
        switch BlockFooterState(exitCode: block.exitCode) {
        case .none:
            EmptyView()                              // success → clean, no chrome
        case .running:
            HStack(spacing: 8) { badge(text: "RUNNING", ok: nil) }
        case .error(let code):
            HStack(spacing: 8) {
                badge(text: "EXIT \(code)", ok: false)
                if let duration = block.duration {   // keep timing only where it informs
                    Text(ShellModuleModel.formatBlockDuration(duration))
                        .font(Typography.mono(10.5))
                        .foregroundStyle(Color(DesignTokens.fg4))
                }
            }
        }
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
