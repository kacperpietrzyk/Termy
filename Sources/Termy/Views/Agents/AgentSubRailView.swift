import SwiftUI
import TermyCore

/// DESIGN.md §4.2 / §6.2 sub-rail: agent sessions grouped Waiting / Running /
/// Idle / Recent from `groupAgentVitals`. Honest empty-state when there are none.
struct AgentSubRailView: View {
    @ObservedObject var store: TermyStore
    let activeID: UUID?
    let onPick: (UUID) -> Void
    @State private var search = ""

    var body: some View {
        let all = store.agentVitals
        let filtered = search.isEmpty
            ? all
            : all.filter { $0.name.localizedCaseInsensitiveContains(search) }
        let grouped = groupAgentVitals(filtered)
        ModuleSubRailView(title: "Agents", count: all.count, search: $search) {
            if all.isEmpty {
                Text("No agents running.\nSpawn one with the action above, or ⌘K.")
                    .font(Typography.ui(12)).foregroundStyle(Color(DesignTokens.fg4))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 8)
            } else {
                section("Waiting", grouped.waiting)
                section("Running", grouped.running)
                section("Idle", grouped.idle)
                section("Recent", grouped.recent)
            }
        }
    }

    @ViewBuilder private func section(_ title: String, _ items: [AgentSessionVitals]) -> some View {
        if !items.isEmpty {
            Text(title.uppercased())
                .font(Typography.ui(10, weight: .semibold)).tracking(0.5)
                .foregroundStyle(Color(DesignTokens.fg5))
                .padding(.top, 8)
            ForEach(items) { v in
                AgentSubCard(vitals: v, active: v.id == activeID) { onPick(v.id) }
            }
        }
    }
}

private struct AgentSubCard: View {
    let vitals: AgentSessionVitals
    let active: Bool
    let onTap: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: "cpu").font(.system(size: 13))
                    .foregroundStyle(Color(DesignTokens.ai.base))
                    .frame(width: 28, height: 28)
                    .background(Color(DesignTokens.ai.base).opacity(0.14),
                                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
                VStack(alignment: .leading, spacing: 2) {
                    Text(vitals.name).font(Typography.ui(13, weight: .medium))
                        .foregroundStyle(Color(DesignTokens.fg1)).lineLimit(1)
                    Text(metaLine).font(Typography.mono(11))
                        .foregroundStyle(Color(DesignTokens.fg4)).lineLimit(1)
                }
                Spacer(minLength: 0)
                TermyStatusDot(hue: TermyDesign.activityToken(vitals.state),
                               pulsing: vitals.state == .waitingForInput)
            }
            .padding(.horizontal, 10).padding(.vertical, 9)
            .background((active || hovering) ? Color(DesignTokens.bg2) : Color.clear,
                        in: RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                .stroke(active ? Color(DesignTokens.ai.base).opacity(0.5) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }

    private var metaLine: String {
        let age = DesktopModel.relativeAge(Date().timeIntervalSince(vitals.stateChangedAt))
        return "\(vitals.agentType.displayName.lowercased()) · \(AgentsModuleModel.stateLabel(vitals.state)) \(age)"
    }
}
