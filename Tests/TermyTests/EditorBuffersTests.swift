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
