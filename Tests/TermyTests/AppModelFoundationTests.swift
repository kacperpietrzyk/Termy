import XCTest
import Combine
@testable import Termy
import TermyCore

final class AppModelFoundationTests: XCTestCase {
    @MainActor
    func testAIModelDefaultsMatchLegacyPublishedDefaults() {
        let model = AIModel()
        XCTAssertEqual(model.aiEndpoint, "http://localhost:11434")
        XCTAssertEqual(model.aiModel, "qwen2.5-coder")
        XCTAssertEqual(model.aiPrompt, "")
        XCTAssertEqual(model.aiSuggestedCommand, "")
        XCTAssertEqual(model.aiExplanation, "")
        XCTAssertEqual(model.aiConversationHistory, [])
        XCTAssertEqual(model.userPromptSnippets, [])
        XCTAssertEqual(model.promptSnippetTitle, "Deploy")
        XCTAssertEqual(model.promptSnippetBody, "Use make deploy")
    }

    @MainActor
    func testGitModelDefaultsMatchLegacyPublishedDefaults() {
        let model = GitModel()
        XCTAssertEqual(model.gitStatus, "Run Git Status to inspect the current repository.")
        XCTAssertEqual(model.gitCommitMessage, "")
        XCTAssertEqual(model.gitDiff, "")
        XCTAssertEqual(model.gitConflictExplanation, "")
        XCTAssertEqual(model.gitBranchDraft, "")
        XCTAssertNil(model.selectedGitBranch)
        XCTAssertNil(model.gitDivergence)
        XCTAssertEqual(model.gitBranches, [])
    }

    @MainActor
    func testEditorModelDefaultsMatchLegacyPublishedDefaults() {
        let model = EditorModel()
        XCTAssertEqual(model.scratchText, "# Termy Scratch\n\nUse this lightweight editor beside terminal sessions.\n")
        XCTAssertNil(model.editorFilePath)
        XCTAssertEqual(model.editorAIInstruction, "")
        XCTAssertEqual(model.editorAIProposal, "")
        XCTAssertEqual(model.editorAICompletion, "")
        XCTAssertEqual(model.editorAIDiff, "")
        XCTAssertEqual(model.editorAIMultiFilePatch, "")
        XCTAssertEqual(model.editorAIMultiFilePatchPaths, [])
        XCTAssertFalse(model.editorVimEnabled)
        XCTAssertEqual(model.editorVimState, VimEditorState(buffer: "# Termy Scratch\n\nUse this lightweight editor beside terminal sessions.\n"))
    }

    @MainActor
    func testAppModelExposesAIGitEditorModels() {
        let app = AppModel()
        app.ai.aiPrompt = "ai-changed"
        app.git.gitCommitMessage = "git-changed"
        app.editor.scratchText = "editor-changed"
        XCTAssertEqual(app.ai.aiPrompt, "ai-changed")
        XCTAssertEqual(app.git.gitCommitMessage, "git-changed")
        XCTAssertEqual(app.editor.scratchText, "editor-changed")
    }

    @MainActor
    func testStoreAIForwardersReadAndWriteAppModel() {
        let store = TermyStore(startInitialPTY: false)

        store.aiEndpoint = "http://ai.test"
        store.aiModel = "model-x"
        store.aiPrompt = "prompt-x"
        store.aiSuggestedCommand = "cmd-x"
        store.aiExplanation = "why-x"
        store.aiConversationHistory = ["a", "b"]
        store.userPromptSnippets = [UserPromptSnippet(id: "1", title: "T", body: "B")]
        store.promptSnippetTitle = "Title-x"
        store.promptSnippetBody = "Body-x"

        XCTAssertEqual(store.appModel.ai.aiEndpoint, "http://ai.test")
        XCTAssertEqual(store.appModel.ai.aiModel, "model-x")
        XCTAssertEqual(store.appModel.ai.aiPrompt, "prompt-x")
        XCTAssertEqual(store.appModel.ai.aiSuggestedCommand, "cmd-x")
        XCTAssertEqual(store.appModel.ai.aiExplanation, "why-x")
        XCTAssertEqual(store.appModel.ai.aiConversationHistory, ["a", "b"])
        XCTAssertEqual(store.appModel.ai.userPromptSnippets, [UserPromptSnippet(id: "1", title: "T", body: "B")])
        XCTAssertEqual(store.appModel.ai.promptSnippetTitle, "Title-x")
        XCTAssertEqual(store.appModel.ai.promptSnippetBody, "Body-x")

        store.appModel.ai.aiPrompt = "back-prop"
        XCTAssertEqual(store.aiPrompt, "back-prop")
    }

    @MainActor
    func testStoreGitForwardersReadAndWriteAppModel() {
        let store = TermyStore(startInitialPTY: false)

        store.gitStatus = "status-x"
        store.gitCommitMessage = "msg-x"
        store.gitDiff = "diff-x"
        store.gitConflictExplanation = "conflict-x"
        store.gitBranchDraft = "branch-x"
        store.selectedGitBranch = "main"
        store.gitDivergence = GitDivergence(ahead: 2, behind: 3)
        store.gitBranches = ["main", "dev"]

        XCTAssertEqual(store.appModel.git.gitStatus, "status-x")
        XCTAssertEqual(store.appModel.git.gitCommitMessage, "msg-x")
        XCTAssertEqual(store.appModel.git.gitDiff, "diff-x")
        XCTAssertEqual(store.appModel.git.gitConflictExplanation, "conflict-x")
        XCTAssertEqual(store.appModel.git.gitBranchDraft, "branch-x")
        XCTAssertEqual(store.appModel.git.selectedGitBranch, "main")
        XCTAssertEqual(store.appModel.git.gitDivergence, GitDivergence(ahead: 2, behind: 3))
        XCTAssertEqual(store.appModel.git.gitBranches, ["main", "dev"])

        store.appModel.git.gitStatus = "back-prop"
        XCTAssertEqual(store.gitStatus, "back-prop")
    }

    @MainActor
    func testStoreEditorForwardersReadAndWriteAppModel() {
        let store = TermyStore(startInitialPTY: false)

        store.scratchText = "scratch-x"
        store.editorFilePath = "/tmp/x.swift"
        store.editorAIInstruction = "instr-x"
        store.editorAIProposal = "prop-x"
        store.editorAICompletion = "compl-x"
        store.editorAIDiff = "diff-x"
        store.editorAIMultiFilePatch = "patch-x"
        store.editorAIMultiFilePatchPaths = ["/a", "/b"]
        store.editorVimEnabled = true
        store.editorVimState = VimEditorState(buffer: "vim-x")

        XCTAssertEqual(store.appModel.editor.scratchText, "scratch-x")
        XCTAssertEqual(store.appModel.editor.editorFilePath, "/tmp/x.swift")
        XCTAssertEqual(store.appModel.editor.editorAIInstruction, "instr-x")
        XCTAssertEqual(store.appModel.editor.editorAIProposal, "prop-x")
        XCTAssertEqual(store.appModel.editor.editorAICompletion, "compl-x")
        XCTAssertEqual(store.appModel.editor.editorAIDiff, "diff-x")
        XCTAssertEqual(store.appModel.editor.editorAIMultiFilePatch, "patch-x")
        XCTAssertEqual(store.appModel.editor.editorAIMultiFilePatchPaths, ["/a", "/b"])
        XCTAssertTrue(store.appModel.editor.editorVimEnabled)
        XCTAssertEqual(store.appModel.editor.editorVimState, VimEditorState(buffer: "vim-x"))

        store.appModel.editor.scratchText = "back-prop"
        XCTAssertEqual(store.scratchText, "back-prop")
    }

    @MainActor
    func testStoreAIForwardersFireObjectWillChangePerProperty() {
        let store = TermyStore(startInitialPTY: false)
        var fireCount = 0
        let cancellable = store.objectWillChange.sink { fireCount += 1 }
        defer { cancellable.cancel() }

        func assertOneFire(_ label: String, _ mutate: () -> Void) {
            fireCount = 0
            mutate()
            XCTAssertEqual(fireCount, 1, "\(label): exactly one objectWillChange must fire so @ObservedObject views re-render")
        }

        assertOneFire("aiEndpoint") { store.aiEndpoint = "e" }
        assertOneFire("aiModel") { store.aiModel = "m" }
        assertOneFire("aiPrompt") { store.aiPrompt = "p" }
        assertOneFire("aiSuggestedCommand") { store.aiSuggestedCommand = "c" }
        assertOneFire("aiExplanation") { store.aiExplanation = "x" }
        assertOneFire("aiConversationHistory") { store.aiConversationHistory = ["h"] }
        assertOneFire("userPromptSnippets") { store.userPromptSnippets = [UserPromptSnippet(id: "i", title: "t", body: "b")] }
        assertOneFire("promptSnippetTitle") { store.promptSnippetTitle = "t" }
        assertOneFire("promptSnippetBody") { store.promptSnippetBody = "b" }
    }

    @MainActor
    func testStoreGitForwardersFireObjectWillChangePerProperty() {
        let store = TermyStore(startInitialPTY: false)
        var fireCount = 0
        let cancellable = store.objectWillChange.sink { fireCount += 1 }
        defer { cancellable.cancel() }

        func assertOneFire(_ label: String, _ mutate: () -> Void) {
            fireCount = 0
            mutate()
            XCTAssertEqual(fireCount, 1, "\(label): exactly one objectWillChange must fire so @ObservedObject views re-render")
        }

        assertOneFire("gitStatus") { store.gitStatus = "s" }
        assertOneFire("gitCommitMessage") { store.gitCommitMessage = "m" }
        assertOneFire("gitDiff") { store.gitDiff = "d" }
        assertOneFire("gitConflictExplanation") { store.gitConflictExplanation = "c" }
        assertOneFire("gitBranchDraft") { store.gitBranchDraft = "b" }
        assertOneFire("selectedGitBranch") { store.selectedGitBranch = "main" }
        assertOneFire("gitDivergence") { store.gitDivergence = GitDivergence(ahead: 1, behind: 0) }
        assertOneFire("gitBranches") { store.gitBranches = ["main"] }
    }

    @MainActor
    func testStoreEditorForwardersFireObjectWillChangePerProperty() {
        let store = TermyStore(startInitialPTY: false)
        var fireCount = 0
        let cancellable = store.objectWillChange.sink { fireCount += 1 }
        defer { cancellable.cancel() }

        func assertOneFire(_ label: String, _ mutate: () -> Void) {
            fireCount = 0
            mutate()
            XCTAssertEqual(fireCount, 1, "\(label): exactly one objectWillChange must fire so @ObservedObject views re-render")
        }

        assertOneFire("scratchText") { store.scratchText = "s" }
        assertOneFire("editorFilePath") { store.editorFilePath = "/p" }
        assertOneFire("editorAIInstruction") { store.editorAIInstruction = "i" }
        assertOneFire("editorAIProposal") { store.editorAIProposal = "pr" }
        assertOneFire("editorAICompletion") { store.editorAICompletion = "co" }
        assertOneFire("editorAIDiff") { store.editorAIDiff = "df" }
        assertOneFire("editorAIMultiFilePatch") { store.editorAIMultiFilePatch = "pa" }
        assertOneFire("editorAIMultiFilePatchPaths") { store.editorAIMultiFilePatchPaths = ["/x"] }
        assertOneFire("editorVimEnabled") { store.editorVimEnabled = true }
        assertOneFire("editorVimState") { store.editorVimState = VimEditorState(buffer: "v") }
    }
}
