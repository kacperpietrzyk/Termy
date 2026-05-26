import SwiftUI
import TermyCore

/// The 32pt global status bar (DESIGN.md §1.4). Mono, never wraps. Wired to
/// real store values where they exist; static where the datum is not yet
/// modelled (Slice 1).
struct StatusBarView: View {
    @ObservedObject var store: TermyStore

    var body: some View {
        HStack(spacing: 10) {
            // Git
            HStack(spacing: 6) {
                Image(systemName: "point.3.connected.trianglepath.dotted").font(.system(size: 10))
                Text(store.gitStatusBarSummary).foregroundStyle(Color(DesignTokens.fg1))
            }
            .foregroundStyle(Color(DesignTokens.git.base))

            divider
            // Shell info (static this slice — no shell-info model yet)
            Label("zsh · UTF-8", systemImage: "terminal").labelStyle(.titleAndIcon)

            divider
            // Sync
            HStack(spacing: 6) {
                Circle().fill(Color(DesignTokens.sync.base)).frame(width: 6, height: 6)
                Text(store.privateSyncStatus).foregroundStyle(Color(DesignTokens.fg3))
            }

            divider
            // AI — the §1.4 "0 net" invariant
            HStack(spacing: 6) {
                Image(systemName: "sparkles").font(.system(size: 10))
                Text("\(store.aiModel) · local · 0 net").foregroundStyle(Color(DesignTokens.fg3))
            }
            .foregroundStyle(Color(DesignTokens.ai.base))

            if let waiting = waitingAgentSummary {
                divider
                HStack(spacing: 6) {
                    Circle().fill(Color(DesignTokens.agent.base)).frame(width: 6, height: 6)
                    Text(waiting).foregroundStyle(Color(DesignTokens.agent.base))
                }
            }

            Spacer(minLength: 12)

            HStack(spacing: 12) {
                Text("⌘0 desktop")
                Text("⌘K cmd")
                Text("⌘P switch")
            }
            .foregroundStyle(Color(DesignTokens.fg4))
        }
        .font(Typography.mono(11))
        .foregroundStyle(Color(DesignTokens.fg3))
        .lineLimit(1)
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background(Color(DesignTokens.bg1))
        .overlay(alignment: .top) {
            Rectangle().fill(Color(DesignTokens.hair)).frame(height: 1)
        }
    }

    private var divider: some View {
        Rectangle().fill(Color(DesignTokens.hair2)).frame(width: 1, height: 12)
    }

    /// "N waiting" derived from the FB-3-4 vitals layer (DESIGN.md §1.4 item 5).
    private var waitingAgentSummary: String? {
        let waiting = groupAgentVitals(store.agentVitals).waiting
        guard let first = waiting.first else { return nil }
        return waiting.count == 1
            ? "\(first.name) waiting"
            : "\(waiting.count) agents waiting"
    }
}
