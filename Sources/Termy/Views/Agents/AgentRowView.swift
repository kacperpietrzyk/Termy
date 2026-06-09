import SwiftUI
import TermyCore

/// AD-1 — one dense dashboard row: state dot · name · last-action · branch ·
/// ±files · relative time. Reads the shipped FB-3-4/5 vitals; never fabricates
/// (Codex degrades to a bare state label, no branch/file chips when unmodelled).
/// `selected` is the keyboard/click highlight; selection is a neutral translucent
/// bar (DESIGN.md), never a colored fill.
struct AgentRowView: View {
    let vitals: AgentSessionVitals
    let selected: Bool
    let onTap: () -> Void
    let onActivate: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                TermyStatusDot(hue: TermyDesign.activityToken(vitals.state),
                               pulsing: vitals.state == .waitingForInput)
                    .frame(width: 10)

                // Name + last-action stacked.
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 7) {
                        Image(systemName: "cpu").font(.system(size: 11))
                            .foregroundStyle(Color(DesignTokens.ai.base))
                        Text(vitals.name).font(Typography.ui(13, weight: .medium))
                            .foregroundStyle(Color(DesignTokens.fg1)).lineLimit(1)
                        Text(vitals.agentType.displayName.lowercased())
                            .font(Typography.mono(10)).foregroundStyle(Color(DesignTokens.fg4))
                    }
                    Text(AgentsModuleModel.lastAction(vitals))
                        .font(Typography.mono(11)).foregroundStyle(Color(DesignTokens.fg3))
                        .lineLimit(1).truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Branch.
                if let branch = vitals.branch, !branch.isEmpty {
                    Label(branch, systemImage: "arrow.triangle.branch")
                        .labelStyle(.titleAndIcon)
                        .font(Typography.mono(11))
                        .foregroundStyle(Color(DesignTokens.git.base))
                        .lineLimit(1).truncationMode(.middle)
                        .frame(maxWidth: 150, alignment: .trailing)
                }

                // ±files.
                if let dirty = AgentsModuleModel.dirtySummary(vitals) {
                    Text(dirty).font(Typography.mono(11, weight: .medium))
                        .foregroundStyle(Color(DesignTokens.agent.base))
                        .frame(width: 44, alignment: .trailing)
                }

                // Relative time since the last state change.
                Text(DesktopModel.relativeAge(Date().timeIntervalSince(vitals.stateChangedAt)))
                    .font(Typography.mono(11)).foregroundStyle(Color(DesignTokens.fg4))
                    .frame(width: 36, alignment: .trailing)
                    .help("Last state change")
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .contentShape(Rectangle())
            .background(selected ? DesignTokens.Glass.fillSelection
                        : (hovering ? Color(DesignTokens.bg2) : Color.clear),
                        in: RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .simultaneousGesture(TapGesture(count: 2).onEnded(onActivate))
        .accessibilityLabel("\(vitals.name), \(AgentsModuleModel.stateLabel(vitals.state))")
    }
}
