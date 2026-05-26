import SwiftUI
import TermyCore

/// §3.2 module orb: 64×64 hue-iconed square + label, optional badge, hover lift
/// + satellite, click → open the module tab. Reveal-staggers on mount (delay =
/// index·60ms). Reduce Motion disables the lift + stagger.
struct ModuleOrbView: View {
    @ObservedObject var store: TermyStore
    let module: ShellNavigationModel.Module
    let index: Int
    let revealed: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    private var hue: OKLCH { TermyDesign.areaToken(module.area) }

    var body: some View {
        Button { store.openModuleTab(module) } label: {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: module.systemImage)
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(Color(hue))
                        .frame(width: 64, height: 64)
                        .background(Color(DesignTokens.bg2), in: RoundedRectangle(cornerRadius: 18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(hovering ? Color(hue).opacity(0.7) : Color(DesignTokens.hair2),
                                        lineWidth: 1)
                        )
                        .shadow(color: hovering ? Color(hue).opacity(0.3) : .clear, radius: 12)
                    badge.padding(5)
                }
                Text(module.title)
                    .font(Typography.ui(12))
                    .foregroundStyle(Color(DesignTokens.fg3))
            }
        }
        .buttonStyle(.plain)
        .scaleEffect((hovering ? 1.06 : 1.0) * (revealed ? 1.0 : 0.85))
        .offset(y: hovering ? -4 : 0)
        .opacity(revealed ? 1 : 0)
        .animation(reduceMotion ? nil : DesignTokens.Motion.easeOutSnappy, value: hovering)
        .animation(reduceMotion ? nil : DesignTokens.Motion.easeOut.delay(Double(index) * 0.06),
                   value: revealed)
        .onHover { hovering = $0 }
        .overlay(alignment: .top) {
            if hovering, ModuleSatelliteView.content(for: module, store: store) != nil {
                ModuleSatelliteView(module: module, store: store)
                    .offset(y: 92)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
    }

    @ViewBuilder private var badge: some View {
        switch module {
        case .agents:
            if case .waiting = DesktopModel.attentionSignal(store.agentVitals) {
                TermyStatusDot(hue: DesignTokens.agent.base, pulsing: true)
            }
        case .git:
            if DesktopModel.gitHasConflict(store.gitStatus) {
                TermyStatusDot(hue: DesignTokens.error.base)
            } else if DesktopModel.gitDirtyCount(store.gitStatus) > 0 {
                TermyStatusDot(hue: DesignTokens.git.base)
            }
        default:
            EmptyView()
        }
    }
}
