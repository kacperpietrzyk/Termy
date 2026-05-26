import SwiftUI
import TermyCore

/// §6.1 inline command block (NOT a bordered card — matches the handoff `.ln`):
/// a prompt line (`user@host:cwd ❯ command`) → ANSI-colored output → a footer
/// chip (`EXIT 0` / `EXIT n` / `RUNNING`) + duration. Output color comes from the
/// foundation `ANSITextParser` over the captured transcript text.
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
        HStack(spacing: 8) {
            if let exit = block.exitCode {
                badge(text: "EXIT \(exit)", ok: exit == 0)
            } else {
                badge(text: "RUNNING", ok: nil)
            }
            if let duration = block.duration {
                Text(ShellModuleModel.formatBlockDuration(duration))
                    .font(Typography.mono(10.5))
                    .foregroundStyle(Color(DesignTokens.fg4))
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
