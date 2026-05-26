import Foundation
import Observation
import TermyCore

/// Tab/stage navigation state for the v3 app shell (Phase 2). Mirrors the
/// prototype `design_handoff_termy_v3/app.jsx`: a permanent Desktop Tab 0
/// plus dynamic module tabs. Pure state — no SwiftUI — so it is unit-tested
/// directly. Views observe it through `TermyStore` forwarders (M2c-3 pattern);
/// they do not reach this `@Observable` through the `ObservableObject` store
/// reference.
@MainActor
@Observable
final class ShellNavigationModel {
    /// The eight design modules (DESIGN.md §3.2 orbs, stable order).
    enum Module: String, CaseIterable, Identifiable, Equatable {
        case shell, agents, connections, editor, files, git, workspaces, settings
        var id: String { rawValue }

        var title: String {
            switch self {
            case .shell: "Shell"
            case .agents: "Agents"
            case .connections: "Connections"
            case .editor: "Editor"
            case .files: "Files"
            case .git: "Git"
            case .workspaces: "Workspaces"
            case .settings: "Settings"
            }
        }

        var systemImage: String {
            switch self {
            case .shell: "terminal"
            case .agents: "cpu"
            case .connections: "network"
            case .editor: "chevron.left.forwardslash.chevron.right"
            case .files: "folder"
            case .git: "point.3.connected.trianglepath.dotted"
            case .workspaces: "square.grid.2x2"
            case .settings: "slider.horizontal.3"
            }
        }

        var area: ProductArea {
            switch self {
            case .shell: .terminal
            case .agents: .ai
            case .connections: .ssh
            case .editor: .editor
            case .files: .files
            case .git: .git
            case .workspaces: .sync
            case .settings: .commandCenter
            }
        }
    }

    enum ActiveTab: Equatable {
        case desktop
        case module(Module)
    }

    private(set) var openTabs: [Module] = []
    private(set) var activeTab: ActiveTab = .desktop

    /// A stable string key for `.animation(value:)` driving the §7 transition.
    var activeTabKey: String {
        switch activeTab {
        case .desktop: "desktop"
        case .module(let m): m.rawValue
        }
    }

    /// Open a module: append if not already open, then activate.
    func open(_ m: Module) {
        if !openTabs.contains(m) { openTabs.append(m) }
        activeTab = .module(m)
    }

    /// Switch to a tab; opening the module first if it isn't already open.
    func goTo(_ tab: ActiveTab) {
        if case .module(let m) = tab { open(m); return }
        activeTab = tab
    }

    /// Close a module tab; if it was active, fall back to Desktop.
    func close(_ m: Module) {
        openTabs.removeAll { $0 == m }
        if activeTab == .module(m) { activeTab = .desktop }
    }

    /// Close whatever module tab is active (no-op on Desktop).
    func closeActive() {
        if case .module(let m) = activeTab { close(m) }
    }

    /// 1-based lookup for ⌘1..9.
    func tab(at index: Int) -> Module? {
        let i = index - 1
        guard openTabs.indices.contains(i) else { return nil }
        return openTabs[i]
    }
}
