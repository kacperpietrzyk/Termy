import XCTest
import TermyCore
@testable import Termy

@MainActor
final class MenuTUISmokeTests: XCTestCase {
    /// While an alt-screen app is foregrounded, the engine cannot open the
    /// F-3 menu because no `T` event fires. With NO buffer cached for the
    /// session, `terminalMenuOpen` returns false unconditionally.
    /// After a fresh T (i.e., the user returned to a real zsh prompt) the
    /// menu can be re-opened — the alt-screen gate is structural, not sticky.
    func test_inAltScreen_menuOpenReturnsFalse_thenRoundTripsAfterFreshT() async throws {
        let store = TermyStore(startInitialPTY: false)
        let session = TermySession(
            title: "Test",
            profile: ConnectionProfile.local(),
            interactionMode: .rawPTY
        )
        store.sessions = [session]
        store.selectedSessionID = session.id
        let id = session.id

        // No T event delivered → no cached buffer → menuOpen returns false.
        // (Simulates the alt-screen lifetime: vim/less/htop don't emit
        // OSC 133 T because their zle isn't active.)
        XCTAssertFalse(store.terminalMenuOpen(for: id))
        XCTAssertNil(store.terminalMenuSnapshot(for: id))

        // After the alt-screen app exits, a fresh T arrives → menu can open.
        // "gi" hits the command-name branch (avoid the "ls" expectsPath trap).
        store.ingestShellIntegrationEvents(
            [.inputBufferChanged(text: "gi", cursor: 2, length: 2)],
            for: id
        )
        XCTAssertTrue(store.terminalMenuOpen(for: id))
        XCTAssertNotNil(store.terminalMenuSnapshot(for: id))
    }
}
