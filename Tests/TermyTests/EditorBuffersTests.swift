import XCTest
@testable import Termy
import TermyCore

/// M3 multi-file editor buffers: proves the new `openBuffers`/`activeBufferID`
/// model preserves the single-buffer projection contract (scratchText /
/// editorFilePath / editorVimState project the active buffer) and that the
/// open/select/close/new mutations behave per spec.
@MainActor
final class EditorBuffersTests: XCTestCase {

    // MARK: - Projection invariant

    func testSeededModelHasSingleScratchBuffer() {
        let model = EditorModel()
        XCTAssertEqual(model.openBuffers.count, 1)
        let buffer = model.openBuffers[0]
        XCTAssertEqual(model.activeBufferID, buffer.id)
        XCTAssertNil(buffer.filePath)
        XCTAssertFalse(buffer.isDirty)
        // Projections equal the active buffer's fields.
        XCTAssertEqual(model.scratchText, buffer.text)
        XCTAssertEqual(model.editorFilePath, buffer.filePath)
        XCTAssertEqual(model.editorVimState, buffer.vimState)
        XCTAssertEqual(model.scratchText, EditorModel.scratchSeed)
    }

    func testWritingScratchTextMutatesOnlyActiveBufferAndSetsDirty() {
        let model = EditorModel()
        let firstID = model.activeBufferID
        // Add a second buffer and keep the first active.
        let second = EditorBuffer(filePath: "/tmp/other.swift", text: "second")
        model.openBuffers.append(second)
        XCTAssertEqual(model.activeBufferID, firstID)

        model.scratchText = "changed"
        XCTAssertEqual(model.openBuffers[0].text, "changed")
        XCTAssertTrue(model.openBuffers[0].isDirty)
        // The non-active buffer is untouched.
        XCTAssertEqual(model.openBuffers[1].text, "second")
        XCTAssertFalse(model.openBuffers[1].isDirty)
    }

    func testEditorBufferEquatableWithDefaults() {
        let a = EditorBuffer(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, text: "hi")
        let b = EditorBuffer(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, text: "hi")
        XCTAssertEqual(a, b)
    }

    // MARK: - ED-2 language / selection / Codable

    func testLanguageDerivedFromFileExtension() {
        XCTAssertEqual(EditorLanguage(path: "src/App.swift"), .swift)
        XCTAssertEqual(EditorLanguage(path: "main.ts"), .typescript)
        XCTAssertEqual(EditorLanguage(path: "index.jsx"), .javascript)
        XCTAssertEqual(EditorLanguage(path: "deploy.yaml"), .yaml)
        XCTAssertEqual(EditorLanguage(path: "Cargo.toml"), .toml)
        XCTAssertEqual(EditorLanguage(path: "main.go"), .go)
        XCTAssertEqual(EditorLanguage(path: "run.sh"), .shell)
        // Unknown extension and the unnamed scratch buffer both fall back to plain.
        XCTAssertEqual(EditorLanguage(path: "data.xyz"), .plain)
        XCTAssertEqual(EditorLanguage(path: nil), .plain)
    }

    func testBufferLanguageDefaultsFromPathAndTracksPathChange() {
        var buffer = EditorBuffer(filePath: "notes/readme.md", text: "# hi")
        XCTAssertEqual(buffer.language, .markdown)
        // Scratch buffer (no path) is plain.
        let scratch = EditorBuffer(text: "scratch")
        XCTAssertEqual(scratch.language, .plain)
        // didSet keeps language in sync when the path changes.
        buffer.filePath = "lib/util.py"
        XCTAssertEqual(buffer.language, .python)
    }

    func testSelectionDefaultsToCollapsedCaretAtZero() {
        let buffer = EditorBuffer(text: "abc")
        XCTAssertEqual(buffer.selection, EditorSelection(location: 0, length: 0))
        XCTAssertEqual(EditorSelection().location, 0)
        XCTAssertEqual(EditorSelection().length, 0)
        // Negative inputs clamp to zero (never an invalid offset).
        XCTAssertEqual(EditorSelection(location: -5, length: -3), EditorSelection())
    }

    func testSelectionDecodeClampsNegativeOffsets() throws {
        let blob = Data(#"{"location":-7,"length":-2}"#.utf8)
        let decoded = try JSONDecoder().decode(EditorSelection.self, from: blob)
        XCTAssertEqual(decoded, EditorSelection())
    }

    func testBufferCodableRoundTripPreservesPersistedFieldsAndRebuildsVimState() throws {
        let original = EditorBuffer(filePath: "src/App.swift",
                                    text: "let x = 1\nlet y = 2\n",
                                    isDirty: true,
                                    selection: EditorSelection(location: 4, length: 3))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EditorBuffer.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.filePath, original.filePath)
        XCTAssertEqual(decoded.text, original.text)
        XCTAssertEqual(decoded.isDirty, original.isDirty)
        XCTAssertEqual(decoded.language, .swift)
        XCTAssertEqual(decoded.selection, original.selection)
        // vimState is excluded from coding and rebuilt from text on decode.
        XCTAssertEqual(decoded.vimState, VimEditorState(buffer: original.text))
        // Full equality holds because the rebuilt vimState matches.
        XCTAssertEqual(decoded, original)
    }

    func testModelSnapshotRoundTrip() throws {
        let model = EditorModel()
        model.openBuffers.append(EditorBuffer(filePath: "a.go", text: "package main"))
        let fileID = model.openBuffers[1].id
        model.activeBufferID = fileID

        let data = try JSONEncoder().encode(model.snapshot)
        let snapshot = try JSONDecoder().decode(EditorBuffersSnapshot.self, from: data)

        let restored = EditorModel()
        restored.restore(from: snapshot)
        XCTAssertEqual(restored.openBuffers.count, 2)
        XCTAssertEqual(restored.activeBufferID, fileID)
        XCTAssertEqual(restored.openBuffers[1].language, .go)
        XCTAssertEqual(restored.scratchText, "package main")
    }

    func testRestoreFromEmptySnapshotIsRejected() {
        let model = EditorModel()
        let originalID = model.activeBufferID
        model.restore(from: EditorBuffersSnapshot(openBuffers: [], activeBufferID: UUID()))
        // Invariant preserved: never zero buffers, active id unchanged.
        XCTAssertEqual(model.openBuffers.count, 1)
        XCTAssertEqual(model.activeBufferID, originalID)
    }

    func testRestoreClampsStaleActiveID() {
        let model = EditorModel()
        let buffer = EditorBuffer(filePath: "x.rs", text: "fn main() {}")
        let snapshot = EditorBuffersSnapshot(openBuffers: [buffer], activeBufferID: UUID())
        model.restore(from: snapshot)
        // Active id pointed at no buffer → clamped to the first real buffer.
        XCTAssertEqual(model.activeBufferID, buffer.id)
    }

    func testOpenFileDerivesLanguageInStore() throws {
        let dir = try makeTempFile(name: "alpha.swift", contents: "let a = 1\n")
        let store = TermyStore(startInitialPTY: false, projectRoot: dir.root)
        store.openFileInEditorBuffer("alpha.swift")
        let active = try XCTUnwrap(store.openBuffers.first { $0.id == store.activeBufferID })
        XCTAssertEqual(active.language, .swift)
    }

    // MARK: - Store mutations

    func testOpenFileInEditorBufferAppendsAndActivates() throws {
        let dir = try makeTempFile(name: "alpha.swift", contents: "let a = 1\n")
        let store = TermyStore(startInitialPTY: false, projectRoot: dir.root)
        let before = store.openBuffers.count

        store.openFileInEditorBuffer("alpha.swift")
        XCTAssertEqual(store.openBuffers.count, before + 1)
        let active = try XCTUnwrap(store.openBuffers.first { $0.id == store.activeBufferID })
        XCTAssertEqual(active.filePath, "alpha.swift")
        XCTAssertEqual(store.scratchText, "let a = 1\n")
    }

    func testOpenSamePathReusesBuffer() throws {
        let dir = try makeTempFile(name: "alpha.swift", contents: "let a = 1\n")
        let store = TermyStore(startInitialPTY: false, projectRoot: dir.root)
        store.openFileInEditorBuffer("alpha.swift")
        let afterFirst = store.openBuffers.count
        store.openFileInEditorBuffer("alpha.swift")
        XCTAssertEqual(store.openBuffers.count, afterFirst, "same path must not duplicate a tab")
    }

    func testSelectEditorBufferSwitchesActiveAndProjection() throws {
        let dir = try makeTempFile(name: "alpha.swift", contents: "AAA")
        let store = TermyStore(startInitialPTY: false, projectRoot: dir.root)
        let scratchID = store.activeBufferID
        store.openFileInEditorBuffer("alpha.swift")
        let fileID = store.activeBufferID
        XCTAssertNotEqual(scratchID, fileID)

        store.selectEditorBuffer(scratchID)
        XCTAssertEqual(store.activeBufferID, scratchID)
        XCTAssertEqual(store.scratchText, EditorModel.scratchSeed)

        store.selectEditorBuffer(fileID)
        XCTAssertEqual(store.scratchText, "AAA")
    }

    func testCloseNonActiveBufferRemovesIt() throws {
        let dir = try makeTempFile(name: "alpha.swift", contents: "AAA")
        let store = TermyStore(startInitialPTY: false, projectRoot: dir.root)
        let scratchID = store.activeBufferID
        store.openFileInEditorBuffer("alpha.swift")
        let fileID = store.activeBufferID
        store.selectEditorBuffer(scratchID) // make scratch active, close the file buffer

        store.closeEditorBuffer(fileID)
        XCTAssertFalse(store.openBuffers.contains { $0.id == fileID })
        XCTAssertEqual(store.activeBufferID, scratchID)
    }

    func testClosingActiveBufferPicksNeighbor() throws {
        let dir = try makeTempFile(name: "alpha.swift", contents: "AAA")
        let store = TermyStore(startInitialPTY: false, projectRoot: dir.root)
        store.openFileInEditorBuffer("alpha.swift")
        let fileID = store.activeBufferID
        XCTAssertEqual(store.openBuffers.count, 2)

        store.closeEditorBuffer(fileID) // active
        XCTAssertEqual(store.openBuffers.count, 1)
        XCTAssertNotEqual(store.activeBufferID, fileID)
        XCTAssertTrue(store.openBuffers.contains { $0.id == store.activeBufferID })
    }

    func testClosingLastBufferIsNoOp() {
        let store = TermyStore(startInitialPTY: false)
        XCTAssertEqual(store.openBuffers.count, 1)
        let only = store.activeBufferID
        store.closeEditorBuffer(only)
        XCTAssertEqual(store.openBuffers.count, 1, "never zero buffers")
        XCTAssertEqual(store.activeBufferID, only)
    }

    func testNewScratchBufferAddsUnsavedAndActivates() {
        let store = TermyStore(startInitialPTY: false)
        let before = store.openBuffers.count
        store.newScratchBuffer()
        XCTAssertEqual(store.openBuffers.count, before + 1)
        let active = store.openBuffers.first { $0.id == store.activeBufferID }
        XCTAssertNil(active?.filePath)
    }

    func testSaveEditorFileClearsDirtyForActiveBuffer() throws {
        let dir = try makeTempFile(name: "alpha.swift", contents: "AAA")
        let store = TermyStore(startInitialPTY: false, projectRoot: dir.root)
        store.openFileInEditorBuffer("alpha.swift")
        store.scratchText = "AAA changed"
        XCTAssertTrue(store.openBuffers.first { $0.id == store.activeBufferID }!.isDirty)

        store.saveEditorFile()
        XCTAssertFalse(store.openBuffers.first { $0.id == store.activeBufferID }!.isDirty)
    }

    // MARK: - ED-5 blame gutter read guard

    func testEditorBlameHiddenForScratchBuffer() throws {
        let store = TermyStore(startInitialPTY: false)
        // Pretend a fetch cached blame for some path; the active buffer is the
        // scratch (filePath == nil), so the read guard must still hide it.
        store.editorBlame = GitBlame(lines: [GitBlameLine(lineNumber: 1, sha: "abc", author: "x", date: nil)])
        store.editorBlamePath = "/somewhere/file.swift"
        XCTAssertNil(store.editorBlameForActiveBuffer)
    }

    func testEditorBlameHiddenWhenBufferDirty() throws {
        let dir = try makeTempFile(name: "alpha.swift", contents: "AAA")
        let store = TermyStore(startInitialPTY: false, projectRoot: dir.root)
        store.openFileInEditorBuffer("alpha.swift")
        // Simulate a fetch that landed for this path…
        store.editorBlame = GitBlame(lines: [GitBlameLine(lineNumber: 1, sha: "abc", author: "x", date: nil)])
        store.editorBlamePath = "alpha.swift"
        XCTAssertNotNil(store.editorBlameForActiveBuffer, "clean buffer with matching blame shows it")
        // …then the user types: a dirty buffer must hide blame (offsets drift).
        store.scratchText = "AAA changed"
        XCTAssertNil(store.editorBlameForActiveBuffer)
    }

    func testEditorBlameHiddenWhenCachedPathDiffersFromActive() throws {
        let dir = try makeTempFile(name: "alpha.swift", contents: "AAA")
        let store = TermyStore(startInitialPTY: false, projectRoot: dir.root)
        store.openFileInEditorBuffer("alpha.swift")
        // Blame cached for a stale (now-closed) path must not leak into this buffer.
        store.editorBlame = GitBlame(lines: [GitBlameLine(lineNumber: 1, sha: "abc", author: "x", date: nil)])
        store.editorBlamePath = "other.swift"
        XCTAssertNil(store.editorBlameForActiveBuffer)
    }

    // MARK: - Helpers

    private func makeTempFile(name: String, contents: String) throws -> (root: URL, file: URL) {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("termy-editor-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent(name)
        try contents.write(to: file, atomically: true, encoding: .utf8)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return (root, file)
    }
}
