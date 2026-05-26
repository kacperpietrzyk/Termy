import SwiftUI
import TermyCore

/// DESIGN.md §4.2 / §6.7 sub-rail: Saved layouts (restore on tap) + Recent SSH.
struct WorkspacesSubRailView: View {
    @ObservedObject var store: TermyStore
    @State private var search = ""

    var body: some View {
        let layouts = store.workspaceStore.layouts
        let sshProfiles = store.profiles.filter { $0.kind == .ssh }
        let filteredLayouts = search.isEmpty ? layouts
            : layouts.filter { $0.name.localizedCaseInsensitiveContains(search) }
        let filteredSSH = search.isEmpty ? sshProfiles
            : sshProfiles.filter { $0.name.localizedCaseInsensitiveContains(search) }

        ModuleSubRailView(title: "Workspaces", count: layouts.count, search: $search) {
            if layouts.isEmpty && sshProfiles.isEmpty {
                Text("No saved layouts yet.\nSave the current pane tree with \u{201C}Save as\u{2026}\u{201D}.")
                    .font(Typography.ui(12)).foregroundStyle(Color(DesignTokens.fg4))
                    .fixedSize(horizontal: false, vertical: true).padding(.vertical, 8)
            } else {
                if !filteredLayouts.isEmpty {
                    section("Saved") {
                        ForEach(filteredLayouts) { layout in
                            WorkspaceSubCard(
                                icon: "square.grid.2x2", hue: DesignTokens.sync.base,
                                name: layout.name, meta: "\(layout.paneTree?.panes.count ?? layout.panelIDs.count) panes",
                                live: false, active: store.selectedWorkspaceID == layout.id
                            ) {
                                store.selectedWorkspaceID = layout.id
                                store.restoreSelectedWorkspace()
                            }
                        }
                    }
                }
                if !filteredSSH.isEmpty {
                    section("Recent SSH") {
                        ForEach(filteredSSH) { profile in
                            let isLive = store.sessions.contains { $0.profile.name == profile.name }
                            WorkspaceSubCard(
                                icon: "server.rack", hue: DesignTokens.host.base,
                                name: profile.name, meta: "ssh",
                                live: isLive, active: false
                            ) {}
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        Text(title.uppercased())
            .font(Typography.ui(10, weight: .semibold)).tracking(0.5)
            .foregroundStyle(Color(DesignTokens.fg5)).padding(.top, 8)
        content()
    }
}

private struct WorkspaceSubCard: View {
    let icon: String
    let hue: OKLCH
    let name: String
    let meta: String
    let live: Bool
    let active: Bool
    let onTap: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 13)).foregroundStyle(Color(hue))
                    .frame(width: 28, height: 28)
                    .background(Color(hue).opacity(0.14), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(Typography.ui(13, weight: .medium))
                        .foregroundStyle(Color(DesignTokens.fg1)).lineLimit(1)
                    Text(meta).font(Typography.mono(11)).foregroundStyle(Color(DesignTokens.fg4)).lineLimit(1)
                }
                Spacer(minLength: 0)
                if live { TermyStatusDot(hue: DesignTokens.sync.base, pulsing: false) }
            }
            .padding(.horizontal, 10).padding(.vertical, 9)
            .background((active || hovering) ? Color(DesignTokens.bg2) : Color.clear,
                        in: RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                .stroke(active ? Color(hue).opacity(0.5) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
