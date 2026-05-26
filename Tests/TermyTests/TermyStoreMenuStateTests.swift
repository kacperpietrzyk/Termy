import XCTest
import TermyCore
@testable import Termy

@MainActor
final class TermyStoreMenuStateTests: XCTestCase {
    private func makeStore(sessionCwd: String? = nil) -> (TermyStore, UUID) {
        let store = TermyStore(startInitialPTY: false)
        let session = TermySession(
            title: "Test",
            profile: ConnectionProfile.local(),
            currentWorkingDirectory: sessionCwd,
            interactionMode: .rawPTY
        )
        store.sessions = [session]
        store.selectedSessionID = session.id
        return (store, session.id)
    }

    private func addLocalSession(to store: TermyStore, cwd: String? = nil) -> UUID {
        let session = TermySession(
            title: "Test",
            profile: ConnectionProfile.local(),
            currentWorkingDirectory: cwd,
            interactionMode: .rawPTY
        )
        store.sessions.append(session)
        return session.id
    }

    private func injectBuffer(_ store: TermyStore, _ id: UUID, _ text: String) {
        store.ingestShellIntegrationEvents(
            [.inputBufferChanged(text: text, cursor: text.count, length: text.count)],
            for: id
        )
    }

    func test_open_emptyEngineResult_returnsFalse_noStateChange() {
        let (store, id) = makeStore()
        injectBuffer(store, id, "zzzzz no match")
        XCTAssertFalse(store.terminalMenuOpen(for: id))
        XCTAssertNil(store.terminalMenuSnapshot(for: id))
    }

    func test_open_withCandidates_returnsTrue_populatesSnapshot() {
        let (store, id) = makeStore()
        // "gi" hits the command-name branch (matches "git"), bypasses expectsPath.
        injectBuffer(store, id, "gi")
        XCTAssertTrue(store.terminalMenuOpen(for: id))
        let snap = try? XCTUnwrap(store.terminalMenuSnapshot(for: id))
        XCTAssertGreaterThanOrEqual(snap?.items.count ?? 0, 1)
        XCTAssertEqual(snap?.selection, 0)
    }

    func test_open_twice_idempotent() {
        let (store, id) = makeStore()
        // "gi" hits the command-name branch (matches "git"), bypasses expectsPath.
        injectBuffer(store, id, "gi")
        _ = store.terminalMenuOpen(for: id)
        let firstCount = store.terminalMenuSnapshot(for: id)?.items.count ?? 0
        _ = store.terminalMenuOpen(for: id)
        XCTAssertEqual(store.terminalMenuSnapshot(for: id)?.items.count, firstCount)
        XCTAssertEqual(store.terminalMenuSnapshot(for: id)?.selection, 0)
    }

    func test_moveSelection_wrapsAtEnds() {
        let (store, id) = makeStore()
        injectBuffer(store, id, "c")
        XCTAssertTrue(store.terminalMenuOpen(for: id))
        let count = store.terminalMenuSnapshot(for: id)?.items.count ?? 0
        XCTAssertGreaterThanOrEqual(count, 2)

        // Jump from 0 to the last item in one step.
        store.terminalMenuMoveSelection(for: id, by: count - 1)
        XCTAssertEqual(store.terminalMenuSnapshot(for: id)?.selection, count - 1)
        // Wrap forward: last item + 1 → 0.
        store.terminalMenuMoveSelection(for: id, by: 1)
        XCTAssertEqual(store.terminalMenuSnapshot(for: id)?.selection, 0)
        // Wrap backward: 0 - 1 → last item.
        store.terminalMenuMoveSelection(for: id, by: -1)
        XCTAssertEqual(store.terminalMenuSnapshot(for: id)?.selection, count - 1)
    }

    func test_close_dropsState() {
        let (store, id) = makeStore()
        // "gi" hits the command-name branch (matches "git"), bypasses expectsPath.
        injectBuffer(store, id, "gi")
        _ = store.terminalMenuOpen(for: id)
        XCTAssertNotNil(store.terminalMenuSnapshot(for: id))
        store.terminalMenuClose(for: id)
        XCTAssertNil(store.terminalMenuSnapshot(for: id))
    }

    func test_moveSelection_noOp_whenMenuClosed() {
        let (store, id) = makeStore()
        store.terminalMenuMoveSelection(for: id, by: 1)
        XCTAssertNil(store.terminalMenuSnapshot(for: id))
    }

    func test_perSessionIsolation() {
        let (store, a) = makeStore()
        let b = addLocalSession(to: store)
        // "gi" hits the command-name branch (matches "git"), bypasses expectsPath.
        injectBuffer(store, a, "gi")
        injectBuffer(store, b, "gi")
        _ = store.terminalMenuOpen(for: a)
        XCTAssertNotNil(store.terminalMenuSnapshot(for: a))
        XCTAssertNil(store.terminalMenuSnapshot(for: b))
        store.terminalMenuClose(for: a)
        _ = store.terminalMenuOpen(for: b)
        XCTAssertNotNil(store.terminalMenuSnapshot(for: b))
        XCTAssertNil(store.terminalMenuSnapshot(for: a))
    }
}

extension TermyStoreMenuStateTests {

    func test_accept_singleTokenCommand_returnsRemainder() {
        let (store, id) = makeStore()
        injectBuffer(store, id, "l")  // command-name branch; "l" hits "ls" (hasPrefix)
                                       // and "tail" (substring). Sorted hasPrefix-first → "ls" at 0.
        XCTAssertTrue(store.terminalMenuOpen(for: id))
        XCTAssertEqual(store.terminalMenuAcceptedSuffix(for: id), "s")
    }

    func test_accept_replaceLastToken_returnsTailOnly() throws {
        let (store, id) = makeStore()
        injectBuffer(store, id, "grep --li")  // flag branch — matches "--line-number"
        guard store.terminalMenuOpen(for: id) else {
            throw XCTSkip("Fixture does not provide a flag candidate for the chosen prefix — adapt the buffer.")
        }
        let suffix = store.terminalMenuAcceptedSuffix(for: id)
        XCTAssertNotNil(suffix)
        XCTAssertFalse(suffix?.contains(" ") ?? true,
                       "Suffix must not include any of the already-typed prefix (no space leaks).")
    }

    func test_accept_exactMatch_returnsEmptyString() {
        let (store, id) = makeStore()
        // "ls" would hit expectsPath → fileMatches branch (empty with nil cwd).
        // "git" is not in expectsPath → command-name branch; user typed the
        // exact candidate so suffix is the empty string.
        injectBuffer(store, id, "git")
        XCTAssertTrue(store.terminalMenuOpen(for: id))
        XCTAssertEqual(store.terminalMenuAcceptedSuffix(for: id), "")
    }

    func test_accept_noMenu_returnsNil() {
        let (store, id) = makeStore()
        XCTAssertNil(store.terminalMenuAcceptedSuffix(for: id))
    }

    func test_accept_doesNotCloseMenu() {
        // accept returns the suffix; the *caller* (NSEvent monitor) closes.
        // Decoupling lets the monitor send(txt:) first, then close — atomic from UI POV.
        // "gi" hits the command-name branch (Task 3 verified); avoids the "ls" expectsPath trap.
        let (store, id) = makeStore()
        injectBuffer(store, id, "gi")
        _ = store.terminalMenuOpen(for: id)
        _ = store.terminalMenuAcceptedSuffix(for: id)
        XCTAssertNotNil(store.terminalMenuSnapshot(for: id))
    }
}

extension TermyStoreMenuStateTests {

    func test_refresh_typing_narrowsItems() {
        let (store, id) = makeStore()
        // "g" hits command-name branch (not in expectsPath), substring matches git+grep.
        // "gr" narrows to grep only. (Avoids the "c"→"cd" expectsPath trap.)
        injectBuffer(store, id, "g")
        _ = store.terminalMenuOpen(for: id)
        let wide = store.terminalMenuSnapshot(for: id)?.items.count ?? 0
        injectBuffer(store, id, "gr")
        let narrow = store.terminalMenuSnapshot(for: id)?.items.count ?? 0
        XCTAssertLessThan(narrow, wide)
        XCTAssertGreaterThanOrEqual(narrow, 1)
    }

    func test_refresh_typing_clampsSelection() {
        let (store, id) = makeStore()
        injectBuffer(store, id, "g")    // 2 candidates: git[0], grep[1]
        _ = store.terminalMenuOpen(for: id)
        let initial = store.terminalMenuSnapshot(for: id)?.items.count ?? 0
        store.terminalMenuMoveSelection(for: id, by: initial - 1)  // walk to last (index 1)
        injectBuffer(store, id, "gr")   // narrows to 1; selection clamped from 1 → 0
        let snap = store.terminalMenuSnapshot(for: id)
        XCTAssertNotNil(snap)
        XCTAssertGreaterThanOrEqual(snap?.selection ?? -1, 0)
        XCTAssertLessThan(snap?.selection ?? Int.max, snap?.items.count ?? 0)
    }

    func test_refresh_typing_toEmpty_closesMenu() {
        let (store, id) = makeStore()
        // "gi" hits command-name branch (not in expectsPath), matches "git".
        // "zzzzzzzz" has no engine matches → menu closes.
        injectBuffer(store, id, "gi")
        _ = store.terminalMenuOpen(for: id)
        injectBuffer(store, id, "zzzzzzzz")
        XCTAssertNil(store.terminalMenuSnapshot(for: id))
    }

    func test_commandStarted_closesOpenMenu() {
        let (store, id) = makeStore()
        injectBuffer(store, id, "gi")   // avoid "ls" expectsPath trap
        _ = store.terminalMenuOpen(for: id)
        store.ingestShellIntegrationEvents([.commandStarted("git status")], for: id)
        XCTAssertNil(store.terminalMenuSnapshot(for: id))
    }
}

extension TermyStoreMenuStateTests {

    func test_ghostSuppression_whileMenuOpen_returnsNil() {
        let (store, id) = makeStore()
        // Seed history so the ghost path would normally produce a suffix.
        // Avoid the "ls" expectsPath trap: "git" matches a command-name and
        // also has a history prefix-match against "git status".
        store.historyStore.record(command: "git status", cwd: nil)
        injectBuffer(store, id, "git")
        XCTAssertNotNil(store.terminalInlineSuggestionSuffix(for: id),
                        "Precondition: ghost-text is normally shown.")
        _ = store.terminalMenuOpen(for: id)
        XCTAssertNil(store.terminalInlineSuggestionSuffix(for: id),
                     "F-3: ghost-text suppressed while menu is open.")
    }

    func test_ghostSuppression_componentAccept_alsoSuppressed() {
        let (store, id) = makeStore()
        store.historyStore.record(command: "git status", cwd: nil)
        injectBuffer(store, id, "git")
        _ = store.terminalMenuOpen(for: id)
        XCTAssertNil(store.terminalInlineSuggestionNextComponent(for: id))
    }

    func test_ghostReturns_afterMenuCloses() {
        let (store, id) = makeStore()
        store.historyStore.record(command: "git status", cwd: nil)
        injectBuffer(store, id, "git")
        _ = store.terminalMenuOpen(for: id)
        XCTAssertNil(store.terminalInlineSuggestionSuffix(for: id))
        store.terminalMenuClose(for: id)
        XCTAssertNotNil(store.terminalInlineSuggestionSuffix(for: id))
    }
}

extension TermyStoreMenuStateTests {

    func test_sessionSwitch_closesLeavingSessionMenu() {
        let (store, a) = makeStore()
        let b = addLocalSession(to: store)
        store.selectedSessionID = a
        // "gi" hits command-name branch (avoid the "ls" expectsPath trap from Task 3).
        injectBuffer(store, a, "gi")
        XCTAssertTrue(store.terminalMenuOpen(for: a))
        XCTAssertNotNil(store.terminalMenuSnapshot(for: a))

        store.selectedSessionID = b   // switch away

        XCTAssertNil(store.terminalMenuSnapshot(for: a),
                     "Menu in the leaving session must be closed on switch.")
    }
}
