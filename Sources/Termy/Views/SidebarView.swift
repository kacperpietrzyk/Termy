import SwiftUI
import TermyCore

/// The fixed left **glass rail** (root `DESIGN.md`): a compact icon-only column —
/// Home at the top (under the traffic-light inset), the module icons, then ⌘K and
/// Settings pinned at the bottom. The active item gets a quiet translucent
/// `fill-selection` bar; color enters only through the small agent badge. Tooltips
/// name each icon, so the rail stays minimal without truncated labels.
struct SidebarView: View {
    @ObservedObject var store: TermyStore

    /// The rail width (DESIGN.md: compact icon rail; tuned at the visual gate).
    private let railWidth: CGFloat = 60
    /// Reserve the vertical space the system traffic lights occupy at top-left.
    private let trafficLightInset: CGFloat = 30

    /// Modules shown in the scrolling middle of the rail (Settings is pinned at the
    /// bottom, so it is excluded here).
    private var railModules: [ShellNavigationModel.Module] {
        ShellNavigationModel.Module.allCases.filter { $0 != .settings }
    }

    private var waitingAgentCount: Int {
        groupAgentVitals(store.agentVitals).waiting.count
    }

    var body: some View {
        VStack(spacing: 4) {
            Color.clear.frame(height: trafficLightInset)

            SidebarItem(
                systemImage: "house",
                tooltip: "Home (⌘0)",
                isActive: store.activeTab == .home,
                action: { store.goToHome() }
            )

            Rectangle()
                .fill(DesignTokens.Glass.hairline)
                .frame(width: 26, height: 1)
                .padding(.vertical, 4)

            ForEach(railModules) { module in
                SidebarItem(
                    systemImage: module.systemImage,
                    tooltip: tooltip(for: module),
                    isActive: store.activeTab == .module(module),
                    badge: module == .agents && waitingAgentCount > 0 ? waitingAgentCount : nil,
                    action: { store.openModuleTab(module) }
                )
            }

            Spacer(minLength: 8)

            SidebarItem(
                systemImage: "magnifyingglass",
                tooltip: "Search & run a command (⌘K)",
                isActive: false,
                action: { store.perform("open-command-center") }
            )

            SidebarItem(
                systemImage: ShellNavigationModel.Module.settings.systemImage,
                tooltip: "Settings (⌘,)",
                isActive: store.activeTab == .module(.settings),
                action: { store.openModuleTab(.settings) }
            )
            .padding(.bottom, 8)
        }
        .frame(width: railWidth)
        .frame(maxHeight: .infinity)
        .background(alignment: .trailing) {
            Rectangle().fill(DesignTokens.Glass.hairline).frame(width: 1)
        }
    }

    private func tooltip(for module: ShellNavigationModel.Module) -> String {
        let index = (ShellNavigationModel.Module.allCases.firstIndex(of: module) ?? 0) + 1
        return "\(module.title) (⌘\(index))"
    }
}

/// One rail entry: a 36×36 rounded icon with a quiet selection bar when active and
/// an optional content badge (e.g. agents waiting). Hover lightens the icon.
private struct SidebarItem: View {
    let systemImage: String
    let tooltip: String
    let isActive: Bool
    var badge: Int? = nil
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isActive ? DesignTokens.Glass.accent
                                     : (hovering ? DesignTokens.Glass.textPrimary : DesignTokens.Glass.textSecondary))
                    .frame(width: 38, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                            .fill(isActive ? DesignTokens.Glass.fillSelection
                                  : (hovering ? DesignTokens.Glass.fillControl : Color.clear))
                    )

                if let badge {
                    Text("\(badge)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(minWidth: 14, minHeight: 14)
                        .padding(.horizontal, 2)
                        .background(Color(DesignTokens.agent.base), in: Capsule())
                        .offset(x: 4, y: -2)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(tooltip)
        .animation(DesignTokens.Motion.easeOut, value: isActive)
    }
}
