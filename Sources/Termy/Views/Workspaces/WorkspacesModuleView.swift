import SwiftUI
import TermyCore

/// DESIGN.md §6.7 Workspaces module (Phase 2 Slice 4). Live mirror over the
/// shared `paneLayout` + `WorkspaceStore`. Own ModulePageView (breadcrumb
/// actions + New-pane kind-picker), sub-rail, and 2-col body.
struct WorkspacesModuleView: View {
    @ObservedObject var store: TermyStore

    var body: some View {
        ModulePageView(store: store, module: .workspaces, actions: { actions }) {
            HStack(spacing: 0) {
                WorkspacesSubRailView(store: store)
                WorkspacesBodyView(store: store)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder private var actions: some View {
        let addable = WorkspacesModuleModel.addablePaneKinds(present: store.paneLayout.visiblePanes)
        Menu {
            ForEach(addable, id: \.self) { kind in
                Button("Add \(WorkspacesModuleModel.meta(for: kind).label) →") {
                    store.splitPane(kind, edge: .trailing)
                }
                Button("Add \(WorkspacesModuleModel.meta(for: kind).label) ↓") {
                    store.splitPane(kind, edge: .bottom)
                }
            }
        } label: {
            Label("New pane", systemImage: "plus")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .disabled(addable.isEmpty)
        // Note: this Menu's label style won't perfectly match the sibling
        // TermyCommandButtonStyle "Save workspace" button — accept the minor
        // breadcrumb inconsistency for Slice 4; polish is a visual-gate follow-up.

        // A named "Save as…" (name-prompt dialog) is a deferred follow-up; for now
        // this saves/updates the current workspace layout, same as the hero button.
        Button { store.saveCurrentWorkspaceLayout() } label: {
            Label("Save workspace", systemImage: "square.and.arrow.down")
        }
        .buttonStyle(TermyCommandButtonStyle())
    }
}
