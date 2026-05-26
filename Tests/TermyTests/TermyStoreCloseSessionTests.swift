import XCTest
@testable import Termy
import TermyCore

/// Coverage for `TermyStore.closeSession(sessionID:)` and the
/// `close-session` command action introduced in the M3 follow-up after
/// SwiftTerm became the sole terminal engine. The closeSession primitive
/// resolves the registry-clear TODO at TermyStore.swift:548 — every
/// per-session registry must be freed when a session is closed, and
/// `selectedSessionID` must advance to a neighbour.
///
/// Notes on registry coverage:
/// - `terminalLaunchDescriptors`, `terminalLaunchGenerations`, and
///   `terminalScreenTextProviders` are internal (forwarded to `appModel`)
///   so tests can read them directly.
/// - `terminalCaretOriginProviders` is private but observable via
///   `terminalCaretOrigin(for:)`.
/// - `terminalInputBuffers`, `tunnelReconnectContexts`, and
///   `tunnelReconnectAttempts` are private with no internal reader. These
///   are cleared by symmetric assignment in `closeSession` alongside the
///   observable ones; covering them by adding accessors would expand
///   scope, so they are not directly asserted here.
@MainActor
final class TermyStoreCloseSessionTests: XCTestCase {

    // MARK: - helpers

    private func makeStore() -> TermyStore {
        TermyStore(startInitialPTY: false)
    }

    private func makeLocalSession(named: String) -> TermySession {
        TermySession(
            title: named,
            profile: ConnectionProfile.local(name: named),
            lines: [],
            interactionMode: .rawPTY
        )
    }

    private func descriptor() -> TerminalLaunchDescriptor {
        TerminalLaunchDescriptor(
            executable: "/bin/zsh",
            arguments: [],
            environment: [:],
            workingDirectory: nil,
            usesZshIntegration: true
        )
    }

    // MARK: - no-op on unknown ID

    func testCloseSessionWithUnknownIDIsNoOp() throws {
        let store = makeStore()
        let original = store.sessions
        let originalDescriptors = store.terminalLaunchDescriptors
        let originalSelected = store.selectedSessionID

        store.closeSession(sessionID: UUID())

        XCTAssertEqual(store.sessions.map(\.id), original.map(\.id),
                       "unknown ID must not mutate sessions[]")
        XCTAssertEqual(store.terminalLaunchDescriptors.keys.sorted(by: { $0.uuidString < $1.uuidString }),
                       originalDescriptors.keys.sorted(by: { $0.uuidString < $1.uuidString }),
                       "unknown ID must not mutate the launch-descriptor registry")
        XCTAssertEqual(store.selectedSessionID, originalSelected,
                       "unknown ID must not change selectedSessionID")
    }

    // MARK: - removes from sessions[]

    func testCloseSessionRemovesSessionFromSessionsArray() throws {
        let store = makeStore()
        let a = makeLocalSession(named: "A")
        let b = makeLocalSession(named: "B")
        store.sessions = [a, b]
        store.selectedSessionID = a.id

        store.closeSession(sessionID: a.id)

        XCTAssertEqual(store.sessions.map(\.id), [b.id])
    }

    // MARK: - clears all observable registries for the closed session

    func testCloseSessionClearsAllObservablePerSessionRegistries() throws {
        let store = makeStore()
        let a = makeLocalSession(named: "A")
        let b = makeLocalSession(named: "B")
        store.sessions = [a, b]
        store.selectedSessionID = a.id

        store.registerTerminalLaunch(descriptor(), for: a.id)
        store.bumpTerminalLaunchGeneration(for: a.id)        // -> generation 1
        store.registerTerminalScreenTextProvider({ "screen-a" }, for: a.id)
        store.registerTerminalCaretOriginProvider({ (x: 11, y: 22) }, for: a.id)

        // sanity pre-conditions
        XCTAssertNotNil(store.terminalLaunchDescriptor(for: a.id))
        XCTAssertEqual(store.terminalLaunchGeneration(for: a.id), 1)
        XCTAssertEqual(store.terminalScreenTextProviders[a.id]?(), "screen-a")
        XCTAssertNotNil(store.terminalCaretOrigin(for: a.id))

        store.closeSession(sessionID: a.id)

        XCTAssertNil(store.terminalLaunchDescriptor(for: a.id),
                     "terminalLaunchDescriptors must be cleared for the closed session")
        XCTAssertNil(store.terminalLaunchDescriptors[a.id])
        XCTAssertNil(store.terminalLaunchGenerations[a.id],
                     "terminalLaunchGenerations must be cleared (not retained at default 0)")
        XCTAssertNil(store.terminalScreenTextProviders[a.id],
                     "terminalScreenTextProviders must be cleared for the closed session")
        XCTAssertNil(store.terminalCaretOrigin(for: a.id),
                     "terminalCaretOriginProviders must be cleared for the closed session")
    }

    // MARK: - does NOT clear registries for OTHER sessions

    func testCloseSessionDoesNotTouchOtherSessionsRegistries() throws {
        let store = makeStore()
        let a = makeLocalSession(named: "A")
        let b = makeLocalSession(named: "B")
        store.sessions = [a, b]
        store.selectedSessionID = a.id

        store.registerTerminalLaunch(descriptor(), for: a.id)
        store.registerTerminalLaunch(descriptor(), for: b.id)
        store.bumpTerminalLaunchGeneration(for: b.id)        // generation 1 on b
        store.registerTerminalScreenTextProvider({ "screen-b" }, for: b.id)
        store.registerTerminalCaretOriginProvider({ (x: 7, y: 8) }, for: b.id)

        store.closeSession(sessionID: a.id)

        XCTAssertNotNil(store.terminalLaunchDescriptor(for: b.id),
                        "closing A must not clear B's launch descriptor")
        XCTAssertEqual(store.terminalLaunchGeneration(for: b.id), 1,
                       "closing A must not reset B's generation")
        XCTAssertEqual(store.terminalScreenTextProviders[b.id]?(), "screen-b",
                       "closing A must not clear B's screen-text provider")
        let bOrigin = store.terminalCaretOrigin(for: b.id)
        XCTAssertEqual(bOrigin?.x, 7)
        XCTAssertEqual(bOrigin?.y, 8)
    }

    // MARK: - selectedSessionID adjustment

    func testCloseSessionAdvancesSelectionToPreviousSiblingWhenClosingMiddleSession() throws {
        let store = makeStore()
        let a = makeLocalSession(named: "A")
        let b = makeLocalSession(named: "B")
        let c = makeLocalSession(named: "C")
        store.sessions = [a, b, c]
        store.selectedSessionID = b.id

        store.closeSession(sessionID: b.id)

        // After removing index=1, sessions becomes [a, c]. The neighbour
        // policy picks sessions[max(0, 1 - 1)] = sessions[0] = a.
        XCTAssertEqual(store.selectedSessionID, a.id)
    }

    func testCloseSessionAdvancesSelectionToFirstWhenClosingHead() throws {
        let store = makeStore()
        let a = makeLocalSession(named: "A")
        let b = makeLocalSession(named: "B")
        let c = makeLocalSession(named: "C")
        store.sessions = [a, b, c]
        store.selectedSessionID = a.id

        store.closeSession(sessionID: a.id)

        // After removing index=0, sessions becomes [b, c]. The neighbour
        // policy picks sessions[max(0, 0 - 1)] = sessions[0] = b.
        XCTAssertEqual(store.selectedSessionID, b.id)
    }

    func testCloseSessionClearsSelectionWhenLastSessionClosed() throws {
        let store = makeStore()
        let only = makeLocalSession(named: "Only")
        store.sessions = [only]
        store.selectedSessionID = only.id

        store.closeSession(sessionID: only.id)

        XCTAssertTrue(store.sessions.isEmpty)
        XCTAssertNil(store.selectedSessionID)
    }

    func testCloseSessionLeavesSelectionUnchangedWhenClosingNonSelected() throws {
        let store = makeStore()
        let a = makeLocalSession(named: "A")
        let b = makeLocalSession(named: "B")
        store.sessions = [a, b]
        store.selectedSessionID = a.id

        store.closeSession(sessionID: b.id)

        XCTAssertEqual(store.selectedSessionID, a.id)
    }

    // MARK: - perform("close-session") dispatch

    func testPerformCloseSessionClosesTheSelectedSession() throws {
        let store = makeStore()
        let a = makeLocalSession(named: "A")
        let b = makeLocalSession(named: "B")
        store.sessions = [a, b]
        store.selectedSessionID = a.id
        store.registerTerminalLaunch(descriptor(), for: a.id)

        store.perform("close-session")

        XCTAssertEqual(store.sessions.map(\.id), [b.id],
                       "perform(close-session) must close the selected session A")
        XCTAssertNil(store.terminalLaunchDescriptor(for: a.id))
    }

    func testPerformCloseSessionIsNoOpWhenNoSessionSelected() throws {
        let store = makeStore()
        let a = makeLocalSession(named: "A")
        store.sessions = [a]
        store.selectedSessionID = nil

        store.perform("close-session")

        XCTAssertEqual(store.sessions.map(\.id), [a.id],
                       "perform(close-session) with no selection must be a no-op")
        XCTAssertNil(store.selectedSessionID)
    }
}
