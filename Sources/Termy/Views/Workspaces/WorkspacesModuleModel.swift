import Foundation
import TermyCore

/// Pure, SwiftUI-free helpers for the §6.7 Workspaces module (precedent:
/// AgentsModuleModel / DesktopModel). Unit-tested directly.
enum WorkspacesModuleModel {
    struct PaneMeta {
        let label: String
        let icon: String
        let hue: OKLCH
    }

    /// Display metadata for each pane kind (label, SF symbol, status hue).
    static func meta(for kind: WorkspacePaneKind) -> PaneMeta {
        switch kind {
        case .terminal:
            return PaneMeta(label: "Shell", icon: "terminal", hue: DesignTokens.neutral.base)
        case .ai:
            return PaneMeta(label: "AI", icon: "sparkles", hue: DesignTokens.ai.base)
        case .files:
            return PaneMeta(label: "Files", icon: "folder", hue: DesignTokens.neutral.base)
        case .git:
            return PaneMeta(label: "Git", icon: "point.3.connected.trianglepath.dotted",
                            hue: DesignTokens.git.base)
        case .editor:
            return PaneMeta(label: "Editor", icon: "chevron.left.forwardslash.chevron.right",
                            hue: DesignTokens.ai.base)
        case .rdp:
            return PaneMeta(label: "RDP", icon: "display", hue: DesignTokens.host.base)
        }
    }

    /// Number of leaf panes in the tree.
    static func leafCount(_ tree: WorkspacePaneTree) -> Int { tree.panes.count }

    /// Number of split nodes in the tree.
    static func splitCount(_ tree: WorkspacePaneTree) -> Int {
        switch tree {
        case .leaf:
            return 0
        case let .split(_, _, first, second):
            return 1 + splitCount(first) + splitCount(second)
        }
    }

    /// A short human description of the layout, e.g. "single pane", "h",
    /// "v ↳ (h × 2)", "v ↳ mixed".
    static func layoutShape(_ tree: WorkspacePaneTree) -> String {
        switch tree {
        case .leaf:
            return "single pane"
        case let .split(axis, _, first, second):
            let a = axis == .vertical ? "v" : "h"
            let childAxes: [String] = [first, second].compactMap { node in
                if case let .split(childAxis, _, _, _) = node {
                    return childAxis == .vertical ? "v" : "h"
                }
                return nil
            }
            if childAxes.count == 2 && childAxes[0] == childAxes[1] {
                return "\(a) ↳ (\(childAxes[0]) × 2)"
            }
            if childAxes.isEmpty {
                return a
            }
            return "\(a) ↳ mixed"
        }
    }

    /// Pane kinds not yet present — drives the New-pane picker (the model holds
    /// one of each kind, so a present kind can't be added again).
    static func addablePaneKinds(present: [WorkspacePaneKind]) -> [WorkspacePaneKind] {
        WorkspacePaneKind.allCases.filter { !present.contains($0) }
    }
}
