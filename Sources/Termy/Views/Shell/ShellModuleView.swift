import SwiftUI
import TermyCore

/// DESIGN.md §6.1 Shell module — Phase-3 Slice-3 body. Single-session layout:
/// dt-header → ShellTermWindow → ShellSessionStatsCard + ShellAIContextCard.
/// The Phase-2 bridge (ShellTabBodyView + pane-tree) is retired.
struct ShellModuleView: View {
    @ObservedObject var store: TermyStore
    @State private var showHistory = false

    var body: some View {
        ModulePageView(store: store, module: .shell,
                       trailingCrumb: store.selectedSession?.title,
                       actions: { crumbActions }) {
            HStack(spacing: 0) {
                ShellSubRailView(store: store, activeID: store.selectedSessionID) { id in
                    store.selectedSessionID = id
                }
                Group {
                    if let session = store.selectedSession {
                        ScrollView {
                            VStack(spacing: 16) {
                                dtHeader(session)
                                ShellTermWindow(store: store, session: session)
                                HStack(alignment: .top, spacing: 16) {
                                    ShellSessionStatsCard(store: store, session: session)
                                    ShellAIContextCard(store: store)
                                }
                            }
                            .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 18)
                        }
                    } else {
                        Text("No session").font(Typography.ui(13)).foregroundStyle(Color(DesignTokens.fg3))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear(perform: ensureSelection)
    }

    /// Shell always shows a session; if none is selected, pick the first local,
    /// else the first session (honest — no synthetic session is created).
    private func ensureSelection() {
        guard store.selectedSessionID == nil else { return }
        let (local, _) = ShellModuleModel.partition(store.sessions)
        store.selectedSessionID = local.first?.id ?? store.sessions.first?.id
    }

    // MARK: dt-header (§4.3)
    private func dtHeader(_ session: TermySession) -> some View {
        ModuleDetailHeaderView(
            icon: "terminal",
            hue: DesignTokens.fg2,
            title: session.title,
            chip: { ShellLiveChip(label: ShellModuleModel.liveChipLabel(
                kind: session.profile.kind,
                zshVersion: store.shellVersion(forSession: session.id))) },
            subtitle: { subtitle(session) },
            actions: { headerActions(session) }
        )
    }

    private func subtitle(_ session: TermySession) -> some View {
        ShellModuleModel.headerSubtitle(session, commandsToday: store.commandsToday())
            .reduce(Text("")) { acc, span in
                acc + Text(span.text).foregroundStyle(
                    span.accent == .dim ? Color(DesignTokens.fg5) : Color(DesignTokens.fg3))
            }
    }

    // MARK: actions
    @ViewBuilder private var crumbActions: some View {
        Button { store.requestTerminalSearchFocus() } label: {
            Label("Find", systemImage: "magnifyingglass")
        }
        .buttonStyle(TermyCommandButtonStyle())

        Button { store.openModuleTab(.settings) } label: {
            Image(systemName: "slider.horizontal.3")
        }
        .buttonStyle(TermyCommandButtonStyle())
        .help("Shell settings")

        Button { store.newLocalShellSession() } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                Text("New session")
                TermyKbd("⌘T")
            }
        }
        .buttonStyle(TermyCommandButtonStyle(emphasized: true))
        .help("New local shell (⌘T)")
    }

    @ViewBuilder private func headerActions(_ session: TermySession) -> some View {
        Button { showHistory.toggle() } label: {
            Label("History", systemImage: "clock.arrow.circlepath")
        }
        .buttonStyle(TermyCommandButtonStyle())
        .popover(isPresented: $showHistory, arrowEdge: .bottom) {
            ShellHistoryPopover(store: store, cwd: session.currentWorkingDirectory) {
                showHistory = false
            }
        }

        Button { store.closeSession(sessionID: session.id) } label: {
            Image(systemName: "xmark")
        }
        .buttonStyle(TermyCommandButtonStyle())
        .help("Close session")
    }
}
