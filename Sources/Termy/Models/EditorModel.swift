import Foundation
import Observation
import TermyCore

/// One open file (or unsaved scratch) buffer in the lightweight editor (M3).
/// A pure value type so the multi-buffer model is trivially testable; the
/// editor-scoped AI buffers stay GLOBAL on `EditorModel` and apply to whichever
/// buffer is active (they are deliberately NOT folded in here).
///
/// ED-2 (EDITOR-CESE Slice 2) adds `language` + `selection` data fields and makes
/// the buffer `Codable` so a later iCloud-sync slice can persist open buffers
/// without rework. `vimState` is a TRANSIENT projection rebuildable from `text`,
/// so it is deliberately EXCLUDED from the coded representation (it is also not
/// `Codable`) and reconstructed from `text` on decode. No persistence/sync is
/// wired up in this slice — only the type is made persistable.
struct EditorBuffer: Identifiable, Equatable, Codable {
    let id: UUID
    var filePath: String? {
        didSet { language = EditorLanguage(path: filePath) }
    }
    var text: String
    /// Transient vim state — projected from `text`, NOT persisted (see `CodingKeys`).
    var vimState: VimEditorState
    var isDirty: Bool
    /// Source language, derived from `filePath`'s extension. Persisted so a sync
    /// slice keeps it; consumed by the editing surface for highlighting.
    var language: EditorLanguage
    /// Persisted cursor/selection (UTF-16 offsets). DATA only in this slice — not
    /// yet wired into the live editing surface (that is Editor Slice 4).
    var selection: EditorSelection

    init(id: UUID = UUID(),
         filePath: String? = nil,
         text: String,
         vimState: VimEditorState? = nil,
         isDirty: Bool = false,
         language: EditorLanguage? = nil,
         selection: EditorSelection = EditorSelection()) {
        self.id = id
        self.filePath = filePath
        self.text = text
        self.vimState = vimState ?? VimEditorState(buffer: text)
        self.isDirty = isDirty
        self.language = language ?? EditorLanguage(path: filePath)
        self.selection = selection
    }

    // MARK: - Codable (vimState excluded; rebuilt from text on decode)

    private enum CodingKeys: String, CodingKey {
        case id, filePath, text, isDirty, language, selection
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let filePath = try container.decodeIfPresent(String.self, forKey: .filePath)
        let text = try container.decode(String.self, forKey: .text)
        let isDirty = try container.decode(Bool.self, forKey: .isDirty)
        let language = try container.decodeIfPresent(EditorLanguage.self, forKey: .language)
        let selection = try container.decodeIfPresent(EditorSelection.self, forKey: .selection)
            ?? EditorSelection()
        self.init(id: id,
                  filePath: filePath,
                  text: text,
                  vimState: nil,
                  isDirty: isDirty,
                  language: language,
                  selection: selection)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(filePath, forKey: .filePath)
        try container.encode(text, forKey: .text)
        try container.encode(isDirty, forKey: .isDirty)
        try container.encode(language, forKey: .language)
        try container.encode(selection, forKey: .selection)
    }
}

/// A `Codable` snapshot of the editor's open-buffer set + active buffer, so a
/// later iCloud-sync slice can persist/restore editor state without conforming
/// the `@MainActor @Observable EditorModel` class itself. ED-2 only DEFINES this
/// (and the `snapshot`/`restore(from:)` seam on `EditorModel`); no sync is wired.
struct EditorBuffersSnapshot: Codable, Equatable {
    var openBuffers: [EditorBuffer]
    var activeBufferID: UUID
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

    /// ED-3: drives the ⌘P fuzzy file/buffer quick-open overlay (open buffers
    /// first, then bounded project files). Transient UI state, never persisted.
    var isQuickOpenPresented = false
    var quickOpenQuery = ""
    /// Project-file paths snapshotted ONCE when the overlay opens (a bounded
    /// `LocalFileService.tree()` walk). Re-ranking per keystroke reads this cache
    /// instead of re-walking the filesystem each keypress (avoids the P0-7
    /// main-thread-walk class). Cleared on dismiss.
    var quickOpenFileCache: [String] = []

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

    // MARK: - Codable snapshot (ED-2 — for a later iCloud-sync slice; no sync wired here)

    /// A `Codable` snapshot of the open-buffer set + active selection. The active
    /// id is clamped to an existing buffer so a restored snapshot can never point
    /// nowhere.
    var snapshot: EditorBuffersSnapshot {
        EditorBuffersSnapshot(openBuffers: openBuffers, activeBufferID: activeBufferID)
    }

    /// Restore the open-buffer set from a decoded snapshot. Empty snapshots are
    /// rejected (the model invariant is at-least-one buffer); the active id is
    /// clamped to a real buffer.
    func restore(from snapshot: EditorBuffersSnapshot) {
        guard !snapshot.openBuffers.isEmpty else { return }
        openBuffers = snapshot.openBuffers
        activeBufferID = openBuffers.contains { $0.id == snapshot.activeBufferID }
            ? snapshot.activeBufferID
            : openBuffers[0].id
    }
}
