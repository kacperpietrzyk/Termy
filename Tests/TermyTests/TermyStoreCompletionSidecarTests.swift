import XCTest
import TermyCore
@testable import Termy

/// F-4 Task 9: store-level tests for CompletionSidecar wiring.
///
/// Uses fake-sidecar seam (no real Process). All tests are @MainActor so they
/// run on the main queue — same isolation as TermyStore.
@MainActor
final class TermyStoreCompletionSidecarTests: XCTestCase {

    private func makeStore() -> TermyStore {
        TermyStore(startInitialPTY: false)
    }

    // MARK: - 1. Debounce scheduling

    func test_inputBufferChanged_withSidecar_schedulesDebounce() async throws {
        let store = makeStore()
        let sid = store.testAddRawPtySession(cwd: "/tmp")
        _ = await store.testInstallFakeSidecar(for: sid)

        // Before any event, debounce flag is absent.
        XCTAssertFalse(store.testDebounceElapsed(sid))

        // Inject a buffer change.
        store.ingestShellIntegrationEvents(
            [.inputBufferChanged(text: "git p", cursor: 5, length: 5)],
            for: sid
        )

        // Immediately after: debounce not yet elapsed (80 ms wall time).
        XCTAssertFalse(store.testDebounceElapsed(sid),
            "Debounce flag must not be set before the timer fires.")

        // After > 80 ms: flag should be set.
        try await Task.sleep(nanoseconds: 110_000_000)   // 110 ms
        XCTAssertTrue(store.testDebounceElapsed(sid),
            "Debounce flag must be set after the 80 ms timer fires.")
    }

    // MARK: - 2. Zero items closes menu

    func test_zeroItems_closesOpenMenu() async {
        let store = makeStore()
        let sid = store.testAddRawPtySession(cwd: "/tmp")
        // Open menu manually with an item.
        store.testOpenMenu(sid, items: [
            CompletionCandidate(title: "push", replacement: "push", kind: .command)
        ])
        XCTAssertTrue(store.testMenuIsOpen(for: sid), "Precondition: menu is open.")

        store.testMarkDebounceElapsed(sid)
        // Inject a result with zero items — menu should close.
        store.applySidecarEventForTesting(.result(id: 1, items: []), sessionID: sid)

        XCTAssertFalse(store.testMenuIsOpen(for: sid),
            "Zero-item result must close the menu.")
    }

    // MARK: - 3. Non-empty items after debounce opens menu

    func test_nonEmptyItems_afterDebounce_opensMenu() async {
        let store = makeStore()
        let sid = store.testAddRawPtySession(cwd: "/tmp")
        store.testMarkDebounceElapsed(sid)

        store.applySidecarEventForTesting(.result(id: 1, items: [
            CompletionCandidate(title: "push", replacement: "push", kind: .command,
                                description: "Update remote refs")
        ]), sessionID: sid)

        XCTAssertTrue(store.testMenuIsOpen(for: sid),
            "Non-empty result after debounce must auto-open the menu.")
        // B4 (Warp parity): the user-facing auto-open (the menu popping open
        // WHILE TYPING after the 80 ms debounce) must select NOTHING — pressing
        // Enter then runs the typed text verbatim, never the highlighted row.
        XCTAssertEqual(store.terminalMenuSnapshot(for: sid)?.selection, -1,
            "Auto-opened menu must have no default selection (sentinel -1).")
        XCTAssertNil(store.terminalMenuAcceptedSuffix(for: sid),
            "With nothing selected, accept yields nil so Enter submits verbatim.")
    }

    // MARK: - 3a. B4: sentinel survives a second sidecar result (refresh)

    func test_autoOpen_noSelectionSentinel_survivesRefresh() {
        let store = makeStore()
        let sid = store.testAddRawPtySession(cwd: "/tmp")
        store.testMarkDebounceElapsed(sid)
        // First result auto-opens with nothing selected.
        store.applySidecarEventForTesting(.result(id: 1, items: [
            CompletionCandidate(title: "status", replacement: "status", kind: .command)
        ]), sessionID: sid)
        XCTAssertEqual(store.terminalMenuSnapshot(for: sid)?.selection, -1)
        // A SECOND result refreshes the open menu — the -1 sentinel must persist
        // (a naive max(0,…) clamp here would reset to 0 and re-hijack Enter).
        store.applySidecarEventForTesting(.result(id: 2, items: [
            CompletionCandidate(title: "status", replacement: "status", kind: .command),
            CompletionCandidate(title: "stash", replacement: "stash", kind: .command)
        ]), sessionID: sid)
        XCTAssertEqual(store.terminalMenuSnapshot(for: sid)?.selection, -1,
            "Refreshing an auto-opened menu must preserve the -1 sentinel.")
        // After the user explicitly enters the list, a further refresh clamps
        // the real selection (no reset to -1).
        store.terminalMenuMoveSelection(for: sid, by: 1)   // -1 → row 0
        store.applySidecarEventForTesting(.result(id: 3, items: [
            CompletionCandidate(title: "status", replacement: "status", kind: .command)
        ]), sessionID: sid)
        XCTAssertEqual(store.terminalMenuSnapshot(for: sid)?.selection, 0,
            "An explicit selection must be clamped into range, not reset to -1.")
    }

    // MARK: - 3b. Accepting a token-shaped sidecar candidate (regression)

    func test_acceptSuffix_sidecarTokenShapedCandidate_completesLastToken() {
        let store = makeStore()
        let sid = store.testAddRawPtySession(cwd: "/tmp")
        store.testMarkDebounceElapsed(sid)
        // User typed "git s"; the sidecar offers a token-shaped candidate
        // ("status"), NOT a full-buffer-shaped one ("git status").
        store.ingestShellIntegrationEvents(
            [.inputBufferChanged(text: "git s", cursor: 5, length: 5)], for: sid)
        store.applySidecarEventForTesting(.result(id: 1, items: [
            CompletionCandidate(title: "status", replacement: "status", kind: .command)
        ]), sessionID: sid)
        XCTAssertTrue(store.testMenuIsOpen(for: sid))
        // B4: auto-open selects nothing; the user enters the list (↓/Tab) first.
        store.terminalMenuMoveSelection(for: sid, by: 1)   // -1 → row 0 ("status")
        // Accept must complete the last token ("s" → "status"); the previous
        // full-buffer prefix check returned nil here (repl "status" is not a
        // prefix of "git s"), so Tab/Enter silently failed to insert.
        XCTAssertEqual(store.terminalMenuAcceptedSuffix(for: sid), "tatus")
    }

    func test_acceptSuffix_trailingSpace_insertsWholeCandidate() {
        let store = makeStore()
        let sid = store.testAddRawPtySession(cwd: "/tmp")
        store.testMarkDebounceElapsed(sid)
        store.ingestShellIntegrationEvents(
            [.inputBufferChanged(text: "git status ", cursor: 11, length: 11)], for: sid)
        store.applySidecarEventForTesting(.result(id: 1, items: [
            CompletionCandidate(title: "README.md", replacement: "README.md", kind: .file)
        ]), sessionID: sid)
        XCTAssertTrue(store.testMenuIsOpen(for: sid))
        store.terminalMenuMoveSelection(for: sid, by: 1)   // B4: enter list (-1 → row 0)
        // Trailing space → last token is "", so the whole candidate is inserted.
        XCTAssertEqual(store.terminalMenuAcceptedSuffix(for: sid), "README.md")
    }

    func test_lastWhitespaceToken() {
        XCTAssertEqual(TermyStore.lastWhitespaceToken("git s"), "s")
        XCTAssertEqual(TermyStore.lastWhitespaceToken("git status "), "")
        XCTAssertEqual(TermyStore.lastWhitespaceToken("git"), "git")
        XCTAssertEqual(TermyStore.lastWhitespaceToken(""), "")
    }

    // MARK: - 4. Stale response is dropped

    func test_staleResponse_isDropped() async {
        let store = makeStore()
        let sid = store.testAddRawPtySession(cwd: "/tmp")
        store.testMarkDebounceElapsed(sid)

        // Apply a fresh result (id=5) first.
        store.applySidecarEventForTesting(.result(id: 5, items: [
            CompletionCandidate(title: "a", replacement: "a", kind: .command)
        ]), sessionID: sid)
        XCTAssertTrue(store.testMenuIsOpen(for: sid))

        // Now apply a stale result (id=3 < 5) with zero items — must be dropped.
        store.applySidecarEventForTesting(.result(id: 3, items: []), sessionID: sid)

        XCTAssertTrue(store.testMenuIsOpen(for: sid),
            "Stale (lower id) response must be dropped; menu must remain open.")
    }

    // MARK: - 5. commandFinished propagates cwd (no crash)

    func test_commandFinished_propagatesCwd_noCrash() async {
        let store = makeStore()
        let sid = store.testAddRawPtySession(cwd: "/tmp")
        _ = await store.testInstallFakeSidecar(for: sid)

        // Inject commandFinished with a new cwd.
        store.ingestShellIntegrationEvents(
            [.commandFinished(exitCode: 0, workingDirectory: "/var")],
            for: sid
        )

        // cwd should be updated in session state.
        let cwd = store.sessions.first(where: { $0.id == sid })?.currentWorkingDirectory
        XCTAssertEqual(cwd, "/var",
            "commandFinished must update session cwd.")
    }

    // MARK: - 6. Sidecar ghost: history absent, menu closed → top item becomes ghost

    func test_sidecarGhost_noHistoryNoMenu_topItemBecomesGhost() async {
        let store = makeStore()
        let sid = store.testAddRawPtySession(cwd: "/tmp")
        // Set buffer to "pu" — no history → historyGhost is nil.
        store.testSetInputBuffer(sid, text: "pu", cursor: 2)

        // Deliver items with menu closed (no debounce set → menu won't auto-open).
        store.applySidecarEventForTesting(.result(id: 1, items: [
            CompletionCandidate(title: "push", replacement: "push", kind: .command)
        ]), sessionID: sid)

        // Menu should not have opened (debounce not elapsed).
        XCTAssertFalse(store.testMenuIsOpen(for: sid))

        // Ghost should be the suffix after "pu" prefix: "sh".
        XCTAssertEqual(store.terminalSidecarGhost(for: sid), "sh",
            "Top sidecar item should contribute ghost suffix when menu is closed and history ghost absent.")
    }

    // MARK: - 7. History ghost suppresses sidecar ghost

    func test_historyGhost_suppressesSidecarGhost() async {
        let store = makeStore()
        let sid = store.testAddRawPtySession(cwd: "/tmp")

        // Seed history so a ghost-text match exists.
        store.historyStore.record(command: "git push origin main", cwd: nil)
        store.testSetInputBuffer(sid, text: "git", cursor: 3)

        // Verify history ghost would normally fire.
        XCTAssertNotNil(store.terminalInlineSuggestionSuffix(for: sid),
            "Precondition: history ghost must be present.")

        // Deliver a sidecar result.
        store.applySidecarEventForTesting(.result(id: 1, items: [
            CompletionCandidate(title: "pop", replacement: "pop", kind: .command)
        ]), sessionID: sid)

        // Sidecar ghost must be nil when history ghost wins.
        XCTAssertNil(store.terminalSidecarGhost(for: sid),
            "History ghost takes priority; sidecar ghost must be nil.")
    }

    // MARK: - 8. Open menu suppresses sidecar ghost

    func test_openMenu_suppressesSidecarGhost() async {
        let store = makeStore()
        let sid = store.testAddRawPtySession(cwd: "/tmp")
        store.testSetInputBuffer(sid, text: "pu", cursor: 2)
        store.testMarkDebounceElapsed(sid)

        // Deliver items — menu auto-opens (debounce elapsed).
        store.applySidecarEventForTesting(.result(id: 1, items: [
            CompletionCandidate(title: "push", replacement: "push", kind: .command)
        ]), sessionID: sid)

        XCTAssertTrue(store.testMenuIsOpen(for: sid),
            "Precondition: menu must be open.")

        // Ghost must be nil when menu is open.
        XCTAssertNil(store.terminalSidecarGhost(for: sid),
            "Open menu suppresses sidecar ghost.")
    }

    // MARK: - 9. Disabled sidecar updates sidecarDisabledSessions

    func test_sidecarStateChange_disabledFlagUpdates() async throws {
        let store = makeStore()
        let sid = store.testAddRawPtySession(cwd: "/tmp")
        let sidecar = await store.testInstallFakeSidecar(for: sid)
        XCTAssertFalse(store.sidecarDisabledSessions.contains(sid),
            "Precondition: sidecar is ready, not disabled.")

        // Trigger terminate(), which fires onStateChange(.disabled).
        await sidecar.terminate()

        // Give the MainActor task a chance to apply.
        try await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertTrue(store.sidecarDisabledSessions.contains(sid),
            "After sidecar termination, session must appear in sidecarDisabledSessions.")
    }

    // MARK: - 10. commandStarted clears sidecar caches

    func test_commandStarted_clearsSidecarGhost() async {
        let store = makeStore()
        let sid = store.testAddRawPtySession(cwd: "/tmp")
        _ = await store.testInstallFakeSidecar(for: sid)
        store.testSetInputBuffer(sid, text: "pu", cursor: 2)

        // Deliver a sidecar result — ghost should appear (no history, no menu).
        store.applySidecarEventForTesting(.result(id: 1, items: [
            CompletionCandidate(title: "push", replacement: "push", kind: .command)
        ]), sessionID: sid)
        XCTAssertNotNil(store.terminalSidecarGhost(for: sid),
            "Precondition: sidecar ghost must be present.")

        // commandStarted clears ghost.
        store.ingestShellIntegrationEvents(
            [.commandStarted("pu")],
            for: sid
        )
        XCTAssertNil(store.terminalSidecarGhost(for: sid),
            "commandStarted must clear the sidecar ghost.")
    }
}
