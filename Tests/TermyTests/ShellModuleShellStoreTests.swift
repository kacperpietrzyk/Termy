import XCTest
@testable import Termy
import TermyCore

@MainActor
final class ShellModuleShellStoreTests: XCTestCase {

    func testNewTabShortcutInShellSpawnsLocalSession() {
        let store = TermyStore(startInitialPTY: false)
        store.openModuleTab(.shell)
        let before = store.sessions.count
        store.handleNewTabShortcut()
        XCTAssertEqual(store.sessions.count, before + 1, "Shell ⌘T spawns a new local session")
        XCTAssertEqual(store.activeTab, .module(.shell), "stays in Shell")
        XCTAssertEqual(store.sessions.last?.profile.kind, .local)
    }

    func testNewTabShortcutOutsideShellGoesToDesktop() {
        let store = TermyStore(startInitialPTY: false)
        store.openModuleTab(.git)
        let before = store.sessions.count
        store.handleNewTabShortcut()
        XCTAssertEqual(store.sessions.count, before, "no session spawned outside Shell")
        XCTAssertEqual(store.activeTab, .desktop)
    }

    func testNewLocalShellSessionSelectsTheNewSession() {
        let store = TermyStore(startInitialPTY: false)
        store.newLocalShellSession()
        XCTAssertEqual(store.selectedSessionID, store.sessions.last?.id)
        XCTAssertEqual(store.sessions.last?.profile.kind, .local)
    }

    func testTerminalCommandBlocksForSessionMatchesSelectedAccessor() {
        let store = TermyStore(startInitialPTY: false)
        guard let id = store.selectedSessionID,
              let idx = store.sessions.firstIndex(where: { $0.id == id }) else {
            return XCTFail("expected an initial session")
        }
        store.sessions[idx].lines.append(TerminalLine(role: .prompt, text: "echo hi"))
        XCTAssertEqual(store.terminalCommandBlocks(forSession: id).count,
                       store.terminalCommandBlocks().count)
        XCTAssertGreaterThanOrEqual(store.terminalCommandBlocks(forSession: id).count, 1)
    }

    func testRequestTerminalSearchFocusBumpsToken() {
        let store = TermyStore(startInitialPTY: false)
        let before = store.terminalSearchFocusToken
        store.requestTerminalSearchFocus()
        XCTAssertEqual(store.terminalSearchFocusToken, before + 1)
    }
}
