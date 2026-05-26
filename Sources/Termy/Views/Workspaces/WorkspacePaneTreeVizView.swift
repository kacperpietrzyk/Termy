import SwiftUI
import TermyCore

/// DESIGN.md §5.12 pane-tree visualization. Recursive over the live
/// `paneLayout.renderPlan`; structural leaves (no live PTY — that's a later slice).
/// Drives the existing focus/close/resize mutators via TermyStore (live mirror).
struct WorkspacePaneTreeVizView: View {
    let node: WorkspacePaneTree
    let path: [WorkspacePaneTreeBranch]
    let focused: WorkspacePaneKind
    @ObservedObject var store: TermyStore

    init(node: WorkspacePaneTree, path: [WorkspacePaneTreeBranch] = [],
         focused: WorkspacePaneKind, store: TermyStore) {
        self.node = node
        self.path = path
        self.focused = focused
        self.store = store
    }

    var body: some View {
        switch node {
        case let .leaf(pane):
            WorkspaceVizPaneView(pane: pane, focused: pane == focused, store: store)
        case let .split(axis, ratio, first, second):
            GeometryReader { proxy in
                switch axis {
                case .horizontal:
                    HStack(spacing: 0) {
                        WorkspacePaneTreeVizView(node: first, path: path + [.first], focused: focused, store: store)
                            .frame(width: max(80, proxy.size.width * ratio))
                        WorkspacePaneResizeHandle(axis: axis, path: path,
                                                  containerLength: proxy.size.width, store: store, showsGrip: true)
                        WorkspacePaneTreeVizView(node: second, path: path + [.second], focused: focused, store: store)
                            .frame(maxWidth: .infinity)
                    }
                case .vertical:
                    VStack(spacing: 0) {
                        WorkspacePaneTreeVizView(node: first, path: path + [.first], focused: focused, store: store)
                            .frame(height: max(60, proxy.size.height * ratio))
                        WorkspacePaneResizeHandle(axis: axis, path: path,
                                                  containerLength: proxy.size.height, store: store, showsGrip: true)
                        WorkspacePaneTreeVizView(node: second, path: path + [.second], focused: focused, store: store)
                            .frame(maxHeight: .infinity)
                    }
                }
            }
        }
    }
}

/// A structural leaf card: 30px header (kind label + ×) over a body of icon +
/// name + one honest one-liner. No live process is rendered.
private struct WorkspaceVizPaneView: View {
    let pane: WorkspacePaneKind
    let focused: Bool
    @ObservedObject var store: TermyStore

    private var meta: WorkspacesModuleModel.PaneMeta { WorkspacesModuleModel.meta(for: pane) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(Color(DesignTokens.hair))
            VStack(spacing: 8) {
                Image(systemName: meta.icon).font(.system(size: 22)).foregroundStyle(Color(meta.hue))
                Text(meta.label).font(Typography.ui(13, weight: .medium)).foregroundStyle(Color(DesignTokens.fg1))
                Text(descriptor).font(Typography.mono(11)).foregroundStyle(Color(DesignTokens.fg4))
                    .lineLimit(1).padding(.horizontal, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(DesignTokens.bg0))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                .stroke(focused ? Color(DesignTokens.primary) : Color(DesignTokens.hair2),
                        lineWidth: focused ? 1.5 : 1)
        )
        .shadow(color: focused ? Color(DesignTokens.primary).opacity(0.35) : .clear, radius: 8)
        .padding(3)
        .contentShape(Rectangle())
        .onTapGesture { store.focusPane(pane) }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(meta.label.uppercased()).font(Typography.ui(9.5, weight: .semibold)).tracking(0.4)
                .foregroundStyle(Color(meta.hue))
            Spacer()
            if pane != .terminal {
                Button { store.closePane(pane) } label: {
                    Image(systemName: "xmark").font(.system(size: 9, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color(DesignTokens.fg5))
                .help("Close \(meta.label) pane")
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 30)
        .background(Color(DesignTokens.bg1))
    }

    /// One honest, real-or-label one-liner. Never fabricated content.
    private var descriptor: String {
        switch pane {
        case .terminal:
            return store.selectedSession?.currentWorkingDirectory ?? "local shell"
        case .editor:
            return "editor"
        case .git:
            return store.selectedGitBranch ?? "repository"
        case .files:
            return "file browser"
        case .ai:
            return "built-in AI · local"
        case .rdp:
            return "remote desktop"
        }
    }
}
