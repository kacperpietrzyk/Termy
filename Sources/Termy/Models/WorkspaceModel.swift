import Foundation
import Observation
import TermyCore

/// Workspace-layout-domain state, extracted from the `TermyStore` god-object
/// as part of the strangler-facade decomposition (M2c-2). `@Observable` +
/// `@MainActor`: the future state is views observing this model directly via
/// `@Environment(AppModel.self)`; until then `TermyStore` forwards to it.
@MainActor
@Observable
final class WorkspaceModel {
    var workspaceStore = WorkspaceStore()
    var paneLayout = WorkspacePaneLayout()
    var selectedWorkspaceID: String?

    init() {}
}
