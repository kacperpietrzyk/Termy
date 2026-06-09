import SwiftUI
import AppKit
import TermyCore

/// DESIGN.md §6.2 Agents module — the Phase-2 Slice-3 canary. Renders its own
/// `ModulePageView` (breadcrumb actions + the waiting `.alert` page-state),
/// resolves the active agent, and composes the sub-rail + body. Consumes the
/// shipped FB-3-4/5/6 data layer; real-state-or-honest-empty.
struct AgentsModuleView: View {
    @ObservedObject var store: TermyStore
    /// AD-1: nil = the dense dashboard home; non-nil = drilled into that agent's
    /// detail body. The dashboard is the module's landing view; drilling in is an
    /// explicit row activation (↩ / double-click), never an auto-select.
    @State private var drilledIn: UUID?

    /// The agent currently drilled into, if it still exists.
    private var drilledVitals: AgentSessionVitals? {
        guard let id = drilledIn else { return nil }
        return store.agentVitals.first { $0.id == id }
    }

    var body: some View {
        let active = drilledVitals
        ModulePageView(
            store: store,
            module: .agents,
            alert: active?.state == .waitingForInput,
            trailingCrumb: active?.name,
            actions: { actions(for: active) }
        ) {
            Group {
                if let active {
                    AgentBodyView(store: store, vitals: active)
                } else {
                    AgentDashboardView(store: store) { id in drilledIn = id }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // A drilled-into agent that vanishes (exited+pruned) returns to the home.
        .onChange(of: store.agentVitals.map(\.id)) { _, ids in
            if let id = drilledIn, !ids.contains(id) { drilledIn = nil }
        }
    }

    @ViewBuilder private func actions(for active: AgentSessionVitals?) -> some View {
        if active != nil {
            Button { drilledIn = nil } label: {
                Label("All agents", systemImage: "chevron.left")
            }
            .buttonStyle(TermyCommandButtonStyle())
        }
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
        Menu {
            let here = AgentsModuleModel.resolvedLaunchTarget(
                selectedCwd: store.agentLaunchHereCwd, projectRoot: store.agentLaunchProjectRoot, isolation: .here)
            let wt = AgentsModuleModel.resolvedLaunchTarget(
                selectedCwd: nil, projectRoot: store.agentLaunchProjectRoot, isolation: .worktree(path: ""))
            Button("Run Claude Code here — \(here)") { store.perform("run-claude-code-here") }
            Button("Run Claude Code — \(wt)") { store.perform("run-claude-code-worktree") }
            Button("Run Codex here — \(here)") { store.perform("run-codex-here") }
            Button("Run Codex — \(wt)") { store.perform("run-codex-worktree") }
        } label: {
            Label("Spawn agent", systemImage: "plus")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
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
                    AgentDiffReviewView(store: store, vitals: vitals)
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
