import Foundation
import Observation
import TermyCore

/// One open file (or unsaved scratch) buffer in the lightweight editor (M3).
/// A pure value type so the multi-buffer model is trivially testable; the
/// editor-scoped AI buffers stay GLOBAL on `EditorModel` and apply to whichever
/// buffer is active (they are deliberately NOT folded in here).
struct EditorBuffer: Identifiable, Equatable {
    let id: UUID
    var filePath: String?
    var text: String
    var vimState: VimEditorState
    var isDirty: Bool

    init(id: UUID = UUID(),
         filePath: String? = nil,
         text: String,
         vimState: VimEditorState? = nil,
         isDirty: Bool = false) {
        self.id = id
        self.filePath = filePath
        self.text = text
        self.vimState = vimState ?? VimEditorState(buffer: text)
        self.isDirty = isDirty
    }
}

/// Editor-domain state (including editor-scoped AI edit/completion buffers),
/// extracted from the `TermyStore` god-object as part of the strangler-facade
/// decomposition (M2c-1). `@Observable` + `@MainActor`: the future state is
/// views observing this model directly via `@Environment(AppModel.self)`;
/// until then `TermyStore` forwards to it.
///
/// M3: the model now holds `openBuffers` + `activeBufferID` for multi-file
/// tabs. `scratchText`/`editorFilePath`/`editorVimState` remain as COMPUTED
/// projections over the active buffer so every store forwarder, file-open/save
/// path, vim path, and editor-AI method stays byte-unchanged (single-buffer
/// contract preserved).
@MainActor
@Observable
final class EditorModel {
    /// The seed scratch buffer's content — preserved verbatim as the legacy default.
    static let scratchSeed = "# Termy Scratch\n\nUse this lightweight editor beside terminal sessions.\n"

    var openBuffers: [EditorBuffer]
    var activeBufferID: UUID

    var editorAIInstruction = ""
    var editorAIProposal = ""
    var editorAICompletion = ""
    var editorAIDiff = ""
    var editorAIMultiFilePatch = ""
    var editorAIMultiFilePatchPaths: [String] = []
    var editorVimEnabled = false

    init() {
        let seed = EditorBuffer(filePath: nil, text: Self.scratchSeed)
        self.openBuffers = [seed]
        self.activeBufferID = seed.id
    }

    // MARK: - Active-buffer projections (single-buffer contract)

    /// Index of the active buffer, falling back to 0 if the id somehow drifted
    /// (invariants prevent this, but never crash on a stale read).
    private var activeIndex: Int {
        openBuffers.firstIndex { $0.id == activeBufferID } ?? 0
    }

    var scratchText: String {
        get { openBuffers.indices.contains(activeIndex) ? openBuffers[activeIndex].text : Self.scratchSeed }
        set {
            guard openBuffers.indices.contains(activeIndex) else { return }
            if openBuffers[activeIndex].text != newValue {
                openBuffers[activeIndex].text = newValue
                openBuffers[activeIndex].isDirty = true
            }
        }
    }

    var editorFilePath: String? {
        get { openBuffers.indices.contains(activeIndex) ? openBuffers[activeIndex].filePath : nil }
        set {
            guard openBuffers.indices.contains(activeIndex) else { return }
            openBuffers[activeIndex].filePath = newValue
        }
    }

    var editorVimState: VimEditorState {
        get { openBuffers.indices.contains(activeIndex) ? openBuffers[activeIndex].vimState : VimEditorState(buffer: Self.scratchSeed) }
        set {
            guard openBuffers.indices.contains(activeIndex) else { return }
            openBuffers[activeIndex].vimState = newValue
        }
    }
}
