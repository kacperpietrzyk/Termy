import XCTest
import TermyCore
@testable import Termy

/// Poziom 1: per-session tab management store methods (rename / color / close-others).
@MainActor
final class TermyStoreTabManagementTests: XCTestCase {
    private func session(_ title: String, cwd: String? = nil) -> TermySession {
        TermySession(
            title: title,
            profile: ConnectionProfile.local(),
            currentWorkingDirectory: cwd,
            interactionMode: .rawPTY
        )
    }

    func test_renameSession_setsTrimmedTitle_ignoresBlank() {
        let store = TermyStore(startInitialPTY: false)
        let s = session("Old")
        store.sessions = [s]

        store.renameSession(s.id, to: "  New name  ")
        XCTAssertEqual(store.sessions.first?.title, "New name")

        store.renameSession(s.id, to: "   ")
        XCTAssertEqual(store.sessions.first?.title, "New name", "blank rename must be ignored")
    }

    func test_setSessionColorTag() {
        let store = TermyStore(startInitialPTY: false)
        let s = session("S")
        store.sessions = [s]
        XCTAssertEqual(store.sessions.first?.colorTag, SessionColorTag.none)

        store.setSessionColorTag(s.id, .blue)
        XCTAssertEqual(store.sessions.first?.colorTag, .blue)

        store.setSessionColorTag(s.id, .none)
        XCTAssertEqual(store.sessions.first?.colorTag, SessionColorTag.none)
    }

    func test_closeOtherSessions_keepsOnlyTarget() {
        let store = TermyStore(startInitialPTY: false)
        let a = session("A"), b = session("B"), c = session("C")
        store.sessions = [a, b, c]
        store.selectedSessionID = b.id

        store.closeOtherSessions(keeping: b.id)
        XCTAssertEqual(store.sessions.map(\.id), [b.id])
    }
}
