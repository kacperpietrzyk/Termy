import SwiftUI
import TermyCore

/// A 2-column key/value stat row shared by the Workspaces right-rail cards.
@ViewBuilder
private func workspaceStatRow(_ key: String, _ value: String, hue: OKLCH?) -> some View {
    HStack(alignment: .top, spacing: 8) {
        Text(key).font(Typography.ui(11)).foregroundStyle(Color(DesignTokens.fg4))
            .frame(width: 84, alignment: .leading)
        Text(value).font(Typography.mono(12))
            .foregroundStyle(hue.map { Color($0) } ?? Color(DesignTokens.fg1))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Pane-tree summary card (DESIGN.md §6.7 right rail): layout shape, counts,
/// focused pane, live signals derived from real state.
struct WorkspaceSummaryCardView: View {
    @ObservedObject var store: TermyStore
    let liveAgents: Int
    let liveSSH: Int

    var body: some View {
        let tree = store.paneLayout.renderPlan.root
        TermyDetailCard(title: "Pane tree") {
            VStack(alignment: .leading, spacing: 7) {
                workspaceStatRow("layout", WorkspacesModuleModel.layoutShape(tree), hue: nil)
                workspaceStatRow("panes", "\(WorkspacesModuleModel.leafCount(tree)) leaves", hue: nil)
                workspaceStatRow("splits", "\(WorkspacesModuleModel.splitCount(tree))", hue: nil)
                workspaceStatRow("focused", store.paneLayout.focusedPane.rawValue, hue: DesignTokens.primary)
                workspaceStatRow("live agents", liveAgents == 0 ? "—" : "\(liveAgents)",
                    hue: liveAgents == 0 ? nil : DesignTokens.agent.base)
                workspaceStatRow("live ssh", liveSSH == 0 ? "—" : "\(liveSSH)",
                    hue: liveSSH == 0 ? nil : DesignTokens.sync.base)
            }
        }
    }
}

/// Persistence card — static-truthful descriptor of how layouts persist.
struct WorkspacePersistenceCardView: View {
    var body: some View {
        TermyDetailCard(title: "Persistence") {
            VStack(alignment: .leading, spacing: 7) {
                workspaceStatRow("descriptor", "WorkspaceLayout", hue: nil)
                workspaceStatRow("parser", "deterministic", hue: nil)
                workspaceStatRow("sync", "CloudKit private", hue: DesignTokens.sync.base)
                workspaceStatRow("restore", "on launch", hue: nil)
                workspaceStatRow("scrollback", "local only", hue: nil)
                workspaceStatRow("model", "CoordinatorModel", hue: nil)
            }
        }
    }
}

/// Saved-layouts card — real list from WorkspaceStore, honest-empty.
struct WorkspaceSavedLayoutsCardView: View {
    @ObservedObject var store: TermyStore

    var body: some View {
        let layouts = store.workspaceStore.layouts
        TermyDetailCard(title: "Saved layouts", trailing: "\(layouts.count)") {
            if layouts.isEmpty {
                Text("No saved layouts yet — Save as… to create one.")
                    .font(Typography.ui(12)).foregroundStyle(Color(DesignTokens.fg4))
            } else {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(layouts) { layout in
                        HStack(spacing: 8) {
                            Text(layout.name).font(Typography.mono(12)).foregroundStyle(Color(DesignTokens.fg1))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            // paneTree is the truthful pane count; panelIDs also carries the
                            // activePanel id (TermyStore.swift:2060), which would overcount.
                            Text("\(layout.paneTree?.panes.count ?? layout.panelIDs.count) panes")
                                .font(Typography.mono(11)).foregroundStyle(Color(DesignTokens.fg4))
                        }
                    }
                }
            }
        }
    }
}
