import SwiftUI
import TermyCore

/// Shell module — terminal-first. A sessions sub-rail beside a full-height live
/// terminal; the breadcrumb carries the session actions. No decorative metadata
/// cards — the terminal is the surface.
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
                        ShellTermWindow(store: store, session: session)
                            .padding(16)
                    } else {
                        ContentUnavailableView {
                            Label("No session", systemImage: "terminal")
                        } description: {
                            Text("Press ⌘T to start a local shell.")
                        }
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

    // MARK: breadcrumb actions (session-level: search, history, new, close)
    @ViewBuilder private var crumbActions: some View {
        Button { store.requestTerminalSearchFocus() } label: {
            Label("Find", systemImage: "magnifyingglass")
        }
        .buttonStyle(TermyCommandButtonStyle())

        Button { showHistory.toggle() } label: {
            Label("History", systemImage: "clock.arrow.circlepath")
        }
        .buttonStyle(TermyCommandButtonStyle())
        .popover(isPresented: $showHistory, arrowEdge: .bottom) {
            ShellHistoryPopover(store: store, cwd: store.selectedSession?.currentWorkingDirectory) {
                showHistory = false
            }
        }

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

        if let session = store.selectedSession {
            Button { store.closeSession(sessionID: session.id) } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(TermyCommandButtonStyle())
            .help("Close session (⌘W)")
        }
    }
}
