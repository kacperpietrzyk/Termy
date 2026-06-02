import XCTest
import TermyCore
@testable import Termy

/// P2a follow-up: when a full-screen TUI (claude/vim) leaves the alternate screen,
/// its command block must not capture the alt↔normal transition residue (e.g.
/// `787878%`). `.output` is suppressed from alt-screen exit until the next command.
@MainActor
final class TermyStoreAltScreenSuppressTests: XCTestCase {
    private func makeStore() -> (TermyStore, UUID) {
        let store = TermyStore(startInitialPTY: false)
        let s = TermySession(
            title: "S",
            profile: ConnectionProfile.local(),
            currentWorkingDirectory: nil,
            interactionMode: .rawPTY
        )
        store.sessions = [s]
        return (store, s.id)
    }

    func test_altScreenExit_suppressesOutputUntilNextCommand() {
        let (store, id) = makeStore()
        let before = store.sessions[0].lines.count

        store.setTerminalAltScreen(true, for: id)
        store.setTerminalAltScreen(false, for: id)                 // exit → suppress armed
        store.ingestShellIntegrationEvents([.output("787878%")], for: id)
        XCTAssertEqual(store.sessions[0].lines.count, before,
                       "post-alt-screen transition residue must be suppressed")

        store.ingestShellIntegrationEvents([.commandStarted("ls")], for: id)
        store.ingestShellIntegrationEvents([.output("real output")], for: id)
        let texts = store.sessions[0].lines.map(\.text)
        XCTAssertTrue(texts.contains("real output"), "capture resumes after a fresh command")
        XCTAssertFalse(texts.contains("787878%"), "suppressed residue never appears")
    }

    func test_normalOutput_notSuppressed_withoutAltScreen() {
        let (store, id) = makeStore()
        store.ingestShellIntegrationEvents([.output("hello")], for: id)
        XCTAssertTrue(store.sessions[0].lines.map(\.text).contains("hello"),
                      "plain output (no alt-screen) is captured normally")
    }
}
