import SwiftUI
import TermyCore

/// DESIGN.md §4.2 / §6.1 sub-rail: Local (zsh) + Remote (SSH/RDP) sessions from
/// `ShellModuleModel.partition`. Selecting a card drives `store.selectedSessionID`
/// (which already re-renders the bridged terminal body). Honest empty-state.
struct ShellSubRailView: View {
    @ObservedObject var store: TermyStore
    let activeID: UUID?
    let onPick: (UUID) -> Void
    @State private var search = ""

    var body: some View {
        let all = store.sessions
        let (allLocal, allRemote) = ShellModuleModel.partition(all)
        let filtered = search.isEmpty
            ? all
            : all.filter { $0.title.localizedCaseInsensitiveContains(search) }
        let (local, remote) = ShellModuleModel.partition(filtered)
        ModuleSubRailView(
            title: "Sessions",
            countText: ShellModuleModel.sessionCountSummary(local: allLocal.count, remote: allRemote.count),
            searchPlaceholder: "Search sessions…",
            searchShortcut: "⌘P",
            search: $search
        ) {
            if allLocal.isEmpty && allRemote.isEmpty {
                Text("No sessions.\nStart one with New session (⌘T), or ⌘K.")
                    .font(Typography.ui(12)).foregroundStyle(Color(DesignTokens.fg4))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 8)
            } else {
                section("Local", local)
                section("Remote", remote)
            }
        }
    }

    @ViewBuilder private func section(_ title: String, _ items: [TermySession]) -> some View {
        if !items.isEmpty {
            Text(title.uppercased())
                .font(Typography.ui(10, weight: .semibold)).tracking(0.5)
                .foregroundStyle(Color(DesignTokens.fg5))
                .padding(.top, 8)
            ForEach(items) { s in
                ShellSubCard(
                    session: s,
                    blockCount: store.terminalCommandBlocks(forSession: s.id).count,
                    active: s.id == activeID
                ) { onPick(s.id) }
            }
        }
    }
}

private struct ShellSubCard: View {
    let session: TermySession
    let blockCount: Int
    let active: Bool
    let onTap: () -> Void
    @State private var hovering = false

    private var icon: String {
        switch session.profile.kind {
        case .local: return "terminal"
        case .ssh:   return "network"
        case .rdp:   return "display"
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 13))
                    .foregroundStyle(Color(DesignTokens.fg2))
                    .frame(width: 28, height: 28)
                    .background(Color(DesignTokens.bg3), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.title).font(Typography.ui(13, weight: .medium))
                        .foregroundStyle(Color(DesignTokens.fg1)).lineLimit(1)
                    Text(ShellModuleModel.subCardMeta(session, blockCount: blockCount))
                        .font(Typography.mono(11))
                        .foregroundStyle(Color(DesignTokens.fg4)).lineLimit(1)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 5) {
                    TermyStatusDot(hue: DesignTokens.sync.base)
                    if let status = ShellModuleModel.subCardStatusText(session) {
                        Text(status).font(Typography.mono(10.5)).foregroundStyle(Color(DesignTokens.fg5))
                    }
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 9)
            .background((active || hovering) ? Color(DesignTokens.bg2) : Color.clear,
                        in: RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                .stroke(active ? Color(DesignTokens.primary).opacity(0.5) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
