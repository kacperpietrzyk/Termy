import SwiftUI

/// Dim "⚠" indicator that appears when the F-4 completion sidecar for
/// the active session is `.disabled` (3 crashes in 60s, non-zsh $SHELL,
/// or sidecar spawn failure).
///
/// Per spec §7.1: no toast, no notification — just a quietly visible
/// signal in the session header area. Clears on session restart.
struct CompletionSidecarStatusIndicator: View {
    let disabled: Bool

    var body: some View {
        if disabled {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.secondary.opacity(0.55))
                .font(.caption2)
                .help("zsh features (completions, command syntax highlighting) unavailable — restart session or use zsh to retry")
                .accessibilityLabel("zsh completion and syntax highlighting unavailable")
        } else {
            EmptyView()
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        CompletionSidecarStatusIndicator(disabled: false)
        CompletionSidecarStatusIndicator(disabled: true)
    }
    .padding()
}
