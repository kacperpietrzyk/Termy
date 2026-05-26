import Foundation
import Observation

/// Coordinator that owns every extracted domain model as the `TermyStore`
/// god-object is strangled (M2c series). Minimal by design: each
/// author-sequenced sub-plan adds the sibling models for the domains it
/// extracts (no coordinator methods or speculative slots are pre-built).
/// With M2c-3 every `TermyStore.@Published` has been extracted into a
/// sibling model; the property-extraction phase is complete and the final
/// M2c sub-plan migrates views to `@Environment(AppModel.self)` and deletes
/// the transient `TermyStore` facade.
@MainActor
@Observable
final class AppModel {
    let update: SparkleUpdateController
    let ai: AIModel
    let git: GitModel
    let editor: EditorModel
    let files: FilesModel
    let connections: ConnectionsModel
    let workspace: WorkspaceModel
    let sync: SyncModel
    let terminal: TerminalModel
    let keymap: KeymapModel
    let coordinator: CoordinatorModel
    let agents: AgentsModel
    let shellNav: ShellNavigationModel

    init() {
        self.update = SparkleUpdateController()
        self.ai = AIModel()
        self.git = GitModel()
        self.editor = EditorModel()
        self.files = FilesModel()
        self.connections = ConnectionsModel()
        self.workspace = WorkspaceModel()
        self.sync = SyncModel()
        self.terminal = TerminalModel()
        self.keymap = KeymapModel()
        self.coordinator = CoordinatorModel()
        self.agents = AgentsModel()
        self.shellNav = ShellNavigationModel()
    }
}
