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
                    store: store,
                    session: s,
                    blockCount: store.terminalCommandBlocks(forSession: s.id).count,
                    active: s.id == activeID
                ) { onPick(s.id) }
            }
        }
    }
}

/// Poziom 1: maps a `SessionColorTag` to a concrete swatch (view-layer only, so
/// the model stays UI-agnostic). `.none` → nil (use the neutral default).
extension SessionColorTag {
    var swatch: Color? {
        switch self {
        case .none:   return nil
        case .red:    return Color(red: 0.92, green: 0.36, blue: 0.36)
        case .orange: return Color(red: 0.95, green: 0.60, blue: 0.27)
        case .yellow: return Color(red: 0.92, green: 0.78, blue: 0.35)
        case .green:  return Color(red: 0.42, green: 0.78, blue: 0.46)
        case .blue:   return Color(red: 0.36, green: 0.62, blue: 0.95)
        case .purple: return Color(red: 0.62, green: 0.47, blue: 0.92)
        case .pink:   return Color(red: 0.90, green: 0.46, blue: 0.72)
        }
    }
    var menuLabel: String { self == .none ? "None" : rawValue.capitalized }
}

private struct ShellSubCard: View {
    @ObservedObject var store: TermyStore
    let session: TermySession
    let blockCount: Int
    let active: Bool
    let onTap: () -> Void
    @State private var hovering = false
    @State private var editing = false
    @State private var draft = ""
    @FocusState private var nameFocused: Bool

    private var icon: String {
        switch session.profile.kind {
        case .local: return "terminal"
        case .ssh:   return "network"
        case .rdp:   return "display"
        }
    }

    // Tab-management is reliable only when the row is NOT wrapped in a Button:
    // an editable TextField inside a `.plain` Button never receives clicks. So
    // selection is a tap gesture and the inline rename field is a sibling.
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 13))
                .foregroundStyle(session.colorTag.swatch ?? Color(DesignTokens.fg2))
                .frame(width: 28, height: 28)
                .background((session.colorTag.swatch.map { $0.opacity(0.20) } ?? Color(DesignTokens.bg3)),
                            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
            VStack(alignment: .leading, spacing: 2) {
                if editing {
                    TextField("", text: $draft)
                        .textFieldStyle(.plain)
                        .font(Typography.ui(13, weight: .medium))
                        .foregroundStyle(Color(DesignTokens.fg1))
                        .focused($nameFocused)
                        .onSubmit { commitRename() }
                        .onExitCommand { editing = false }     // Esc cancels
                        .onChange(of: nameFocused) { _, focused in // click-away commits
                            if !focused && editing { commitRename() }
                        }
                } else {
                    Text(session.title).font(Typography.ui(13, weight: .medium))
                        .foregroundStyle(Color(DesignTokens.fg1)).lineLimit(1)
                        .onTapGesture(count: 2) { beginRename() }
                }
                Text(ShellModuleModel.subCardMeta(session, blockCount: blockCount))
                    .font(Typography.mono(11))
                    .foregroundStyle(Color(DesignTokens.fg4)).lineLimit(1)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 5) {
                // Honest liveness: green only while the child is alive; dim once it exits.
                TermyStatusDot(hue: session.processExited ? DesignTokens.fg5 : DesignTokens.sync.base)
                if let status = ShellModuleModel.subCardStatusText(session) {
                    Text(status).font(Typography.mono(10.5)).foregroundStyle(Color(DesignTokens.fg5))
                }
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 9)
        // Neutral translucent selection bar — never a colored fill (DESIGN.md).
        .background(active ? DesignTokens.Glass.fillSelection
                    : (hovering ? Color(DesignTokens.bg2) : Color.clear),
                    in: RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
        .contentShape(Rectangle())
        .onTapGesture { if !editing { onTap() } }
        .onHover { hovering = $0 }
        .contextMenu { contextMenu }
    }

    @ViewBuilder private var contextMenu: some View {
        Button("Rename") { beginRename() }
        Menu("Color") {
            ForEach(SessionColorTag.allCases, id: \.self) { tag in
                Button {
                    store.setSessionColorTag(session.id, tag)
                } label: {
                    Label(tag.menuLabel,
                          systemImage: tag == .none
                            ? "circle.slash"
                            : (session.colorTag == tag ? "checkmark.circle.fill" : "circle.fill"))
                }
            }
        }
        Divider()
        Button("Copy Working Directory") { store.copySessionWorkingDirectory(session.id) }
        Button("Copy Branch") { store.copySessionGitBranch(session.id) }
        Divider()
        Button("Close") { store.closeSession(sessionID: session.id) }
        Button("Close Others") { store.closeOtherSessions(keeping: session.id) }
    }

    private func beginRename() {
        draft = session.title
        editing = true
        DispatchQueue.main.async { nameFocused = true }
    }

    private func commitRename() {
        store.renameSession(session.id, to: draft)
        editing = false
    }
}
