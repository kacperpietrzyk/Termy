import XCTest
@testable import Termy
import TermyCore

/// CK-S6 wiring tests: the pure `PalettePrefix`/`PaletteFallback` types are
/// unit-tested in TermyCore; these assert the store actually scopes the feed,
/// emits fallbacks on an empty scoped feed, and dispatches each fallback to the
/// right seam — including the B4 invariant that "Ask local AI" only seeds the
/// surface and never fires a model request.
@MainActor
final class CommandCenterPrefixFallbackStoreTests: XCTestCase {

    private func fallbackKinds(_ items: [CommandCenterItem]) -> [PaletteFallback] {
        items.compactMap { if case .fallback(let f) = $0 { return f } else { return nil } }
    }

    // MARK: - Scope filtering

    func testCommandsScopeYieldsOnlyActions() {
        let store = TermyStore(startInitialPTY: false)
        store.commandQuery = ">terminal"
        let items = store.rankedCommandCenterFeed.items
        XCTAssertFalse(items.isEmpty)
        XCTAssertTrue(items.allSatisfy {
            if case .action = $0 { return true } else { return false }
        })
    }

    func testHelpScopeYieldsOnlyActionsWithShortcut() {
        let store = TermyStore(startInitialPTY: false)
        store.commandQuery = "?"
        let items = store.rankedCommandCenterFeed.items
        XCTAssertFalse(items.isEmpty)
        for item in items {
            guard case .action(let action) = item else {
                return XCTFail("help scope should only contain actions")
            }
            XCTAssertNotNil(action.shortcut, "\(action.id) has no shortcut")
        }
    }

    // MARK: - Empty-state fallbacks

    func testNonMatchingQueryYieldsFallbacks() {
        let store = TermyStore(startInitialPTY: false)
        store.commandQuery = "zzzxqnotacommand"
        let items = store.rankedCommandCenterFeed.items
        let kinds = fallbackKinds(items)
        XCTAssertEqual(items.count, kinds.count, "feed should be ALL fallbacks")
        XCTAssertEqual(kinds.first, .runInSession("zzzxqnotacommand"))
        XCTAssertTrue(kinds.contains(.askLocalAI("zzzxqnotacommand")))
    }

    func testBareSigilDoesNotYieldFallbacks() {
        let store = TermyStore(startInitialPTY: false)
        store.commandQuery = ">"
        let items = store.rankedCommandCenterFeed.items
        XCTAssertTrue(fallbackKinds(items).isEmpty, "bare sigil shows in-scope items, not fallbacks")
        XCTAssertFalse(items.isEmpty)
    }

    func testFallbacksSeedStrippedRemainderNotRawQuery() {
        let store = TermyStore(startInitialPTY: false)
        store.commandQuery = "@nonexistenthost123"
        let kinds = fallbackKinds(store.rankedCommandCenterFeed.items)
        // `@` scope leads with SSH and the sigil is stripped from the seed.
        XCTAssertEqual(kinds.first, .sshTo("nonexistenthost123"))
    }

    // MARK: - Fallback dispatch (B4 + real seams)

    func testRunInSessionFallbackClosesPalette() {
        let store = TermyStore(startInitialPTY: false)
        store.isCommandCenterPresented = true
        store.performPaletteFallback(.runInSession("echo hi"))
        XCTAssertFalse(store.isCommandCenterPresented)
    }

    func testAskLocalAIFallbackSeedsSurfaceWithoutFiringRequest() {
        let store = TermyStore(startInitialPTY: false)
        store.isCommandCenterPresented = true
        store.performPaletteFallback(.askLocalAI("why did it fail"))

        // B4: the assistant is seeded + revealed, but NO model request runs —
        // a fired request would populate aiExplanation / aiSuggestedCommand.
        XCTAssertEqual(store.aiPrompt, "why did it fail")
        XCTAssertEqual(store.activePanel, .ai)
        XCTAssertTrue(store.aiExplanation.isEmpty)
        XCTAssertTrue(store.aiSuggestedCommand.isEmpty)
        XCTAssertFalse(store.isCommandCenterPresented)
    }

    func testSSHToFallbackSeedsConnectionsDraftWithoutLaunching() {
        let store = TermyStore(startInitialPTY: false)
        let sessionsBefore = store.sessions.count
        store.performPaletteFallback(.sshTo("prod-box"))

        XCTAssertEqual(store.sshProfileHostDraft, "prod-box")
        // No live session is launched (that is S7 inline-args territory).
        XCTAssertEqual(store.sessions.count, sessionsBefore)
    }

    func testSearchScrollbackFallbackSeedsQueryAndShowsToolbar() {
        let store = TermyStore(startInitialPTY: false)
        store.performPaletteFallback(.searchScrollback("error"))
        XCTAssertEqual(store.terminalSearchQuery, "error")
        XCTAssertTrue(store.terminalSearchVisible)
    }
}
