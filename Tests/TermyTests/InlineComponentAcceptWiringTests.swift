import XCTest
import TermyCore
@testable import Termy

@MainActor
final class InlineComponentAcceptWiringTests: XCTestCase {
    private func storeWithOneSession() -> (TermyStore, UUID) {
        let isolatedHistory = HistoryStore(
            fileURL: URL(fileURLWithPath: "/dev/null"),
            markerURL: URL(fileURLWithPath: "/dev/null"),
            zshHistoryURL: nil
        )
        let store = TermyStore(startInitialPTY: false, historyStore: isolatedHistory)
        return (store, store.sessions.first!.id)
    }

    func test_terminalInlineSuggestionNextComponent_returnsNextComponentOfPendingSuffix() {
        let (store, id) = storeWithOneSession()
        store.historyStore.record(command: "git status", cwd: nil)
        // Simulate the F-1 input buffer state: user typed "git ", cursor at end.
        store.ingestShellIntegrationEvents(
            [.inputBufferChanged(text: "git ", cursor: 4, length: 4)], for: id)
        // Selected session must match `id` so currentSessionCwd / inlineAutosuggestion target it.
        store.selectedSessionID = id
        XCTAssertEqual(store.terminalInlineSuggestionNextComponent(for: id), "status")
    }

    func test_terminalInlineSuggestionNextComponent_pathSegmentSplit() {
        let (store, id) = storeWithOneSession()
        store.historyStore.record(command: "vim src/foo/bar.swift", cwd: nil)
        store.ingestShellIntegrationEvents(
            [.inputBufferChanged(text: "vim ", cursor: 4, length: 4)], for: id)
        store.selectedSessionID = id
        XCTAssertEqual(store.terminalInlineSuggestionNextComponent(for: id), "src/")
    }

    func test_terminalInlineSuggestionNextComponent_noPending_returnsNil() {
        let (store, id) = storeWithOneSession()
        XCTAssertNil(store.terminalInlineSuggestionNextComponent(for: id))
    }
}
