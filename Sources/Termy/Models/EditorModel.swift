import Foundation
import Observation
import TermyCore

/// Editor-domain state (including editor-scoped AI edit/completion buffers),
/// extracted from the `TermyStore` god-object as part of the strangler-facade
/// decomposition (M2c-1). `@Observable` + `@MainActor`: the future state is
/// views observing this model directly via `@Environment(AppModel.self)`;
/// until then `TermyStore` forwards to it.
@MainActor
@Observable
final class EditorModel {
    var scratchText = "# Termy Scratch\n\nUse this lightweight editor beside terminal sessions.\n"
    var editorFilePath: String?
    var editorAIInstruction = ""
    var editorAIProposal = ""
    var editorAICompletion = ""
    var editorAIDiff = ""
    var editorAIMultiFilePatch = ""
    var editorAIMultiFilePatchPaths: [String] = []
    var editorVimEnabled = false
    var editorVimState = VimEditorState(buffer: "# Termy Scratch\n\nUse this lightweight editor beside terminal sessions.\n")

    init() {}
}
