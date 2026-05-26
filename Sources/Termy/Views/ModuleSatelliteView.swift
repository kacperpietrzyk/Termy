import SwiftUI
import TermyCore

/// §3.2 hover satellite. Real data only (locked decision): Agents (grouped
/// vitals) and Git (branch + dirty rows). Other modules return `nil` content →
/// the orb shows no satellite.
struct ModuleSatelliteView: View {
    let module: ShellNavigationModel.Module
    @ObservedObject var store: TermyStore

    struct Row: Identifiable {
        let id = UUID()
        let name: String
        let meta: String
        let hue: OKLCH
    }

    /// `nil` → no satellite for this module (suppressed). Non-empty → render.
    static func content(for module: ShellNavigationModel.Module,
                        store: TermyStore) -> [Row]? {
        switch module {
        case .agents:
            let rows = agentVitalsFlatOrder(store.agentVitals).prefix(3).map { v in
                Row(name: v.name,
                    meta: "\(v.agentType.displayName) · \(stateLabel(v.state))",
                    hue: TermyDesign.activityToken(v.state))
            }
            return rows.isEmpty ? nil : Array(rows)
        case .git:
            var rows: [Row] = []
            if let branch = store.selectedGitBranch, !branch.isEmpty {
                rows.append(Row(name: branch, meta: "branch", hue: DesignTokens.git.base))
            }
            for r in DesktopModel.gitMiniRows(from: store.gitStatus, limit: 2) {
                rows.append(Row(name: r.path, meta: r.code, hue: DesignTokens.fg3))
            }
            return rows.isEmpty ? nil : rows
        default:
            return nil
        }
    }

    private static func stateLabel(_ state: AgentActivityState) -> String {
        switch state {
        case .working: "running"
        case .idle: "idle"
        case .waitingForInput: "waiting"
        case .exited: "exited"
        }
    }

    var body: some View {
        let rows = Self.content(for: module, store: store) ?? []
        VStack(alignment: .leading, spacing: 6) {
            Text("RECENT")
                .font(Typography.ui(10, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(Color(DesignTokens.fg4))
            ForEach(rows) { row in
                HStack(spacing: 7) {
                    Circle().fill(Color(row.hue)).frame(width: 6, height: 6)
                    Text(row.name).font(Typography.ui(12))
                        .foregroundStyle(Color(DesignTokens.fg2)).lineLimit(1)
                    Spacer(minLength: 8)
                    Text(row.meta).font(Typography.mono(10))
                        .foregroundStyle(Color(DesignTokens.fg4)).lineLimit(1)
                }
            }
        }
        .padding(10)
        .frame(width: 220, alignment: .leading)
        .background(Color(DesignTokens.bg2), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DesignTokens.Radius.md).stroke(Color(DesignTokens.hair2), lineWidth: 1))
        .shadow(color: DesignTokens.Shadow.popColor, radius: DesignTokens.Shadow.popRadius, y: DesignTokens.Shadow.popY)
    }
}
