import SwiftUI
import AppKit
import TermyCore

/// DESIGN.md §6.2 Agents module — the Phase-2 Slice-3 canary. Renders its own
/// `ModulePageView` (breadcrumb actions + the waiting `.alert` page-state),
/// resolves the active agent, and composes the sub-rail + body. Consumes the
/// shipped FB-3-4/5/6 data layer; real-state-or-honest-empty.
struct AgentsModuleView: View {
    @ObservedObject var store: TermyStore

    private var activeVitals: AgentSessionVitals? {
        let vitals = store.agentVitals
        guard let id = AgentsModuleModel.activeAgentID(vitals: vitals, selected: store.selectedSessionID)
        else { return nil }
        return vitals.first { $0.id == id }
    }

    var body: some View {
        let active = activeVitals
        ModulePageView(
            store: store,
            module: .agents,
            alert: active?.state == .waitingForInput,
            actions: { actions(for: active) }
        ) {
            HStack(spacing: 0) {
                AgentSubRailView(store: store, activeID: active?.id) { id in
                    store.selectedSessionID = id
                }
                Group {
                    if let active {
                        AgentBodyView(store: store, vitals: active)
                    } else {
                        emptyBody
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear(perform: syncSelection)
    }

    /// §4.4: focus the resolved active agent app-wide so the embed + lifecycle
    /// actions + ⌘K all target one session. Idempotent.
    private func syncSelection() {
        if let id = AgentsModuleModel.activeAgentID(vitals: store.agentVitals, selected: store.selectedSessionID),
           store.selectedSessionID != id {
            store.selectedSessionID = id
        }
    }

    @ViewBuilder private func actions(for active: AgentSessionVitals?) -> some View {
        if let active, let cwd = active.cwd {
            Button { NSWorkspace.shared.open(URL(fileURLWithPath: (cwd as NSString).expandingTildeInPath)) } label: {
                Label("Open cwd", systemImage: "folder")
            }
            .buttonStyle(TermyCommandButtonStyle())
        }
        if let active, active.state != .exited {
            Button { store.interruptAgent(sessionID: active.id) } label: {
                Label("Pause", systemImage: "pause")
            }
            .buttonStyle(TermyCommandButtonStyle())
        }
        Button { store.isCommandCenterPresented = true } label: {
            Label("Spawn agent", systemImage: "plus")
        }
        .buttonStyle(TermyCommandButtonStyle(emphasized: true))
    }

    private var emptyBody: some View {
        VStack(spacing: 10) {
            Image(systemName: "cpu").font(.system(size: 30)).foregroundStyle(Color(DesignTokens.ai.base))
            Text("No agents running").font(Typography.display(22)).foregroundStyle(Color(DesignTokens.fg1))
            Text("Spawn a Claude Code or Codex agent with the action above, or press ⌘K.")
                .font(Typography.ui(13)).foregroundStyle(Color(DesignTokens.fg3))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

/// The §6.2 module body: dt-header → vitals strip → 2-col grid → sticky reply.
private struct AgentBodyView: View {
    @ObservedObject var store: TermyStore
    let vitals: AgentSessionVitals

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    AgentVitalsStripView(vitals: vitals)
                    grid
                }
                .padding(.horizontal, 28).padding(.top, 24).padding(.bottom, 18)
            }
            AgentReplyBarView(store: store, vitals: vitals)
                .padding(.horizontal, 28).padding(.vertical, 14)
                .background(Color(DesignTokens.bg1))
                .overlay(alignment: .top) { Rectangle().fill(Color(DesignTokens.hair)).frame(height: 1) }
        }
    }

    private var header: some View {
        ModuleDetailHeaderView(
            icon: "cpu",
            hue: DesignTokens.ai.base,
            title: vitals.name,
            chip: { chip },
            subtitle: { subtitle },
            actions: { EmptyView() }
        )
    }

    @ViewBuilder private var chip: some View {
        switch AgentsModuleModel.chipKind(vitals.state) {
        case .waiting: TermyLiveChip(state: .waiting)
        case .running: TermyLiveChip(state: .running)
        case .idle:    TermyLiveChip(state: .idle)
        case .ended:
            Text("ended").font(Typography.mono(12, weight: .medium))
                .foregroundStyle(Color(DesignTokens.fg4))
                .padding(.horizontal, 8).padding(.vertical, 2)
                .background(Color(DesignTokens.bg2), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
        }
    }

    private var subtitle: some View {
        AgentsModuleModel.headerSubtitle(vitals).reduce(Text("")) { acc, span in
            acc + Text(span.text).foregroundStyle(
                span.accent == .branch ? Color(DesignTokens.primary) : Color(DesignTokens.fg3))
        }
    }

    private var grid: some View {
        HStack(alignment: .top, spacing: 16) {
            AgentTUIPaneView(store: store, vitals: vitals)
                .frame(minHeight: 380)
            VStack(spacing: 14) {
                AgentPlanCardView(plan: vitals.plan)
                AgentSignalsCardView(vitals: vitals)
                AgentTouchedCardView(touched: vitals.touched)
            }
            .frame(width: 300)
        }
    }
}
