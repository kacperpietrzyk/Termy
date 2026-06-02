import Foundation
import Observation
import TermyCore

/// Navigation state for the Raycast-v2 glass shell: a **fixed left rail** of all
/// eight modules plus a permanent **Home** surface (root `DESIGN.md`). Unlike the
/// retired v3 dynamic-tab model, every module is always present on the rail; there
/// are no closeable module tabs. Pure state — no SwiftUI — so it is unit-tested
/// directly. Views observe it through `TermyStore` forwarders (M2c-3 pattern).
@MainActor
@Observable
final class ShellNavigationModel {
    /// The eight modules, in stable rail order (Home is separate, above the rail).
    enum Module: String, CaseIterable, Identifiable, Equatable {
        case shell, agents, workspaces, connections, git, editor, files, settings
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
        case home
        case module(Module)
    }

    private(set) var activeTab: ActiveTab = .home

    /// A stable string key for `.animation(value:)` driving the stage transition.
    var activeTabKey: String {
        switch activeTab {
        case .home: "home"
        case .module(let m): m.rawValue
        }
    }

    /// The currently active module, if any (nil on Home).
    var activeModule: Module? {
        if case .module(let m) = activeTab { return m }
        return nil
    }

    /// Open / focus a module (rail is fixed — this just activates it).
    func open(_ m: Module) { activeTab = .module(m) }

    /// Switch to a tab.
    func goTo(_ tab: ActiveTab) { activeTab = tab }

    func goHome() { activeTab = .home }

    /// 1-based rail lookup for ⌘1..8 (fixed order, not dynamic).
    func module(at index: Int) -> Module? {
        let i = index - 1
        guard Module.allCases.indices.contains(i) else { return nil }
        return Module.allCases[i]
    }
}
