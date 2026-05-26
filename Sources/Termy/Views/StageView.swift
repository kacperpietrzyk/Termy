import SwiftUI
import TermyCore

/// The stage (DESIGN.md §1.3): Desktop (Tab 0) or a module page, with the §7
/// declarative transition. Reduce Motion disables it.
struct StageView: View {
    @ObservedObject var store: TermyStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            switch store.activeTab {
            case .desktop:
                DesktopSceneView(store: store)
                    .transition(.opacity.combined(with: .scale(scale: 1.04)))
            case .module(.agents):
                AgentsModuleView(store: store)
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
            case .module(.workspaces):
                WorkspacesModuleView(store: store)
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
            case .module(.shell):
                ShellModuleView(store: store)
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
            case .module(let m):
                ModulePageView(store: store, module: m) {
                    ModuleBodyView(store: store, module: m)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.985)))
            }
        }
        .id(store.activeTabKey)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(reduceMotion ? nil : DesignTokens.Motion.easeOut, value: store.activeTabKey)
    }
}

/// Maps a module to its Slice-1 body — bridged surfaces for ported-later
/// modules, placeholders for Agents (Slice 3) and Workspaces (Slice 4).
private struct ModuleBodyView: View {
    @ObservedObject var store: TermyStore
    let module: ShellNavigationModel.Module

    var body: some View {
        switch module {
        case .connections:
            OverlayPanelView(panel: .connections, store: store, showsHeader: false)
        case .editor:
            OverlayPanelView(panel: .editor, store: store, showsHeader: false)
        case .files:
            OverlayPanelView(panel: .files, store: store, showsHeader: false)
        case .git:
            OverlayPanelView(panel: .git, store: store, showsHeader: false)
        case .settings:
            SettingsView(store: store)
        case .shell:
            EmptyView()   // routed to ShellModuleView in StageView before reaching here
        case .agents:
            EmptyView()   // routed to AgentsModuleView in StageView before reaching here
        case .workspaces:
            EmptyView()   // routed to WorkspacesModuleView in StageView before reaching here
        }
    }
}
