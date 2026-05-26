import SwiftUI
import TermyCore

/// §6.7 body: hero card → 2-col (pane-tree viz 1fr · summary/persistence/saved cards 280pt).
struct WorkspacesBodyView: View {
    @ObservedObject var store: TermyStore

    private var liveAgents: Int {
        let grouped = groupAgentVitals(store.agentVitals)
        return grouped.waiting.count + grouped.running.count
    }
    private var liveSSH: Int {
        store.sessions.filter { s in store.profiles.contains { $0.name == s.profile.name && $0.kind == .ssh } }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                WorkspaceHeroCardView(store: store)
                HStack(alignment: .top, spacing: 16) {
                    WorkspacePaneTreeVizView(
                        node: store.paneLayout.renderPlan.root,
                        focused: store.paneLayout.focusedPane,
                        store: store
                    )
                    .frame(minHeight: 420)
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color(DesignTokens.bg1), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
                    .overlay(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                        .stroke(Color(DesignTokens.hair), lineWidth: 1))

                    VStack(spacing: 12) {
                        WorkspaceSummaryCardView(store: store, liveAgents: liveAgents, liveSSH: liveSSH)
                        WorkspacePersistenceCardView()
                        WorkspaceSavedLayoutsCardView(store: store)
                    }
                    .frame(width: 280)
                }
            }
            .padding(.horizontal, 28).padding(.top, 24).padding(.bottom, 48)
        }
    }
}

/// Hero card: active workspace name + badge + summary + kbd hints + actions.
private struct WorkspaceHeroCardView: View {
    @ObservedObject var store: TermyStore

    /// The matched saved layout's name, or nil when nothing is saved/selected.
    private var savedName: String? {
        store.workspaceStore.layouts.first { $0.id == store.selectedWorkspaceID }?.name
    }

    var body: some View {
        TermyCard(hue: DesignTokens.sync.edge) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(savedName ?? "Current workspace")
                            .font(Typography.display(26)).foregroundStyle(Color(DesignTokens.fg1))
                        // Honest: "active" only when a saved layout is selected; else "unsaved".
                        if savedName != nil {
                            TermyPill(title: "active", systemImage: "circle.fill", tint: Color(DesignTokens.sync.base))
                        } else {
                            TermyPill(title: "unsaved", tint: Color(DesignTokens.fg4))
                        }
                    }
                    Text(summary).font(Typography.mono(12)).foregroundStyle(Color(DesignTokens.fg3))
                    HStack(spacing: 14) {
                        kbd("⌘D", "split right"); kbd("⌘⇧D", "split down")
                        kbd("⌘'", "focus next"); kbd("⌘W", "close tab")
                    }
                    .padding(.top, 2)
                }
                Spacer()
                Button { store.saveCurrentWorkspaceLayout() } label: {
                    Label("Save changes", systemImage: "checkmark")
                }
                .buttonStyle(TermyCommandButtonStyle())
            }
        }
    }

    private var summary: String {
        let tree = store.paneLayout.renderPlan.root
        return "\(WorkspacesModuleModel.leafCount(tree)) panes · \(WorkspacesModuleModel.layoutShape(tree)) · synced via WorkspaceLayout · CloudKit"
    }

    private func kbd(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key).font(Typography.mono(11, weight: .medium)).foregroundStyle(Color(DesignTokens.fg2))
                .padding(.horizontal, 5).padding(.vertical, 1)
                .background(Color(DesignTokens.bg3), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.xs))
            Text(label).font(Typography.ui(11)).foregroundStyle(Color(DesignTokens.fg4))
        }
    }
}
