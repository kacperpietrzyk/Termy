import SwiftUI
import TermyCore

/// DESIGN.md §6.1 dt-header History action: a popover of frecency-ranked commands
/// for the selected session's cwd (`HistoryStore.rankedSnapshot`). Clicking a row
/// places the command at the live prompt without executing it
/// (`store.insertCommandAtPrompt`). Empty-tolerant.
struct ShellHistoryPopover: View {
    @ObservedObject var store: TermyStore
    let cwd: String?
    let onDismiss: () -> Void

    private var entries: [String] {
        store.historyStore.rankedSnapshot(forCwd: cwd, limit: 50)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("HISTORY")
                .font(Typography.ui(10, weight: .semibold)).tracking(0.5)
                .foregroundStyle(Color(DesignTokens.fg5))
                .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 6)
            if entries.isEmpty {
                Text("No history yet.")
                    .font(Typography.ui(12)).foregroundStyle(Color(DesignTokens.fg4))
                    .padding(.horizontal, 12).padding(.bottom, 12)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(entries.enumerated()), id: \.offset) { _, cmd in
                            Button {
                                store.insertCommandAtPrompt(cmd)
                                onDismiss()
                            } label: {
                                Text(cmd)
                                    .font(Typography.mono(12))
                                    .foregroundStyle(Color(DesignTokens.fg2))
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 280)
            }
        }
        .frame(width: 360)
        .background(Color(DesignTokens.bg1))
    }
}
