import SwiftUI
import TermyCore

/// AD-1 — the first-class dense agent dashboard that is now the Agents module's
/// home (it supplants the old sub-rail as primary nav). A waiting-first list of
/// dense rows (state · last-action · branch · ±files · time), keyboard-navigable
/// (↑/↓ move the highlight, ↩ drills into the detail body). Live: rows are the
/// shipped `agentVitals`; an event-driven refresh already runs on every
/// transition, and a view-lifetime git tick keeps idle agents' branch/dirty
/// fresh while the dashboard is on screen (auto-torn-down when it leaves).
struct AgentDashboardView: View {
    @ObservedObject var store: TermyStore
    /// Called when the user activates a row (↩ or double-click) — the module
    /// drills into the detail body for that agent.
    let onDrillIn: (UUID) -> Void

    @State private var selectedIndex = 0
    @State private var search = ""
    @FocusState private var focused: Bool

    private var rows: [AgentSessionVitals] {
        let all = store.agentVitals
        let filtered = search.isEmpty
            ? all
            : all.filter {
                $0.name.localizedCaseInsensitiveContains(search)
                    || ($0.branch ?? "").localizedCaseInsensitiveContains(search)
            }
        return AgentsModuleModel.dashboardOrder(filtered)
    }

    var body: some View {
        let items = rows
        VStack(spacing: 0) {
            toolbar
            Divider().overlay(Color(DesignTokens.hair))
            content(items)
        }
        .background(Color(DesignTokens.bg0))
        // Arrow/Enter nav lives on the shared ancestor so it keeps working after
        // focus moves into the filter field (the list + field are siblings); this
        // mirrors CommandCenterView's robust shape.
        .focusable()
        .focused($focused)
        .onAppear { focused = true }
        .onKeyPress(.downArrow) { move(1, count: items.count); return .handled }
        .onKeyPress(.upArrow) { move(-1, count: items.count); return .handled }
        .onKeyPress(.return) {
            if let i = AgentsModuleModel.clampedSelection(selectedIndex, count: items.count) {
                activate(items[i].id)
            }
            return .handled
        }
        // Light periodic git-cache tick (AD-1): idle agents don't emit
        // transitions, so without this their branch/dirty would stay stale.
        // Bound to the view's lifetime — no global timer, no leak.
        .task {
            while !Task.isCancelled {
                store.refreshAgentVitals()
                try? await Task.sleep(nanoseconds: 20_000_000_000)  // 20s
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Text("AGENTS").font(Typography.ui(11, weight: .semibold)).tracking(0.5)
                .foregroundStyle(Color(DesignTokens.fg4))
            let grouped = groupAgentVitals(store.agentVitals)
            if !grouped.waiting.isEmpty {
                TermyPill(title: "\(grouped.waiting.count) waiting", tint: Color(DesignTokens.agent.base))
            }
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").font(.system(size: 11))
                TextField("Filter agents", text: $search)
                    .textFieldStyle(.plain).font(Typography.ui(12))
            }
            .foregroundStyle(Color(DesignTokens.fg3))
            .padding(.horizontal, 11).frame(width: 220, height: 30)
            .background(Color(DesignTokens.bg2), in: Capsule())
            .overlay(Capsule().stroke(Color(DesignTokens.hair2), lineWidth: 1))
        }
        .padding(.horizontal, 18).frame(height: 52)
        .background(Color(DesignTokens.bg1))
    }

    @ViewBuilder private func content(_ items: [AgentSessionVitals]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 3) {
                    if items.isEmpty {
                        empty
                    } else {
                        ForEach(Array(items.enumerated()), id: \.element.id) { idx, v in
                            AgentRowView(
                                vitals: v,
                                selected: idx == clampedIndex(items.count),
                                onTap: { selectedIndex = idx; store.selectedSessionID = v.id },
                                onActivate: { activate(v.id) })
                                .id(v.id)
                        }
                    }
                    // AD-7: finished/archived sessions live below the live list.
                    if !store.archivedAgentSessions.isEmpty {
                        AgentHistoryView(store: store)
                            .padding(.top, items.isEmpty ? 0 : 12)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
            }
            .onChange(of: selectedIndex) { _, _ in
                if let i = AgentsModuleModel.clampedSelection(selectedIndex, count: items.count) {
                    proxy.scrollTo(items[i].id)
                }
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "cpu").font(.system(size: 30)).foregroundStyle(Color(DesignTokens.ai.base))
            Text("No agents running").font(Typography.display(22)).foregroundStyle(Color(DesignTokens.fg1))
            Text("Spawn a Claude Code or Codex agent with the action above, or press ⌘K.")
                .font(Typography.ui(13)).foregroundStyle(Color(DesignTokens.fg3))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(40)
    }

    private func clampedIndex(_ count: Int) -> Int {
        AgentsModuleModel.clampedSelection(selectedIndex, count: count) ?? 0
    }

    private func move(_ delta: Int, count: Int) {
        guard let next = AgentsModuleModel.clampedSelection(selectedIndex + delta, count: count) else { return }
        selectedIndex = next
        store.selectedSessionID = rows[next].id
    }

    private func activate(_ id: UUID) {
        store.selectedSessionID = id
        onDrillIn(id)
    }
}
