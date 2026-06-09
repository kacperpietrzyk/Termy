import XCTest
@testable import TermyCore

final class PaletteRankerTests: XCTestCase {

    // MARK: - Helpers

    private func action(
        _ id: String,
        _ title: String,
        area: String = "",
        keywords: [String] = [],
        isBlock: Bool = false
    ) -> PaletteRanker.Candidate {
        PaletteRanker.Candidate(
            id: id,
            title: title,
            fields: [id, title, ""] + keywords,
            preferredFieldIndex: 1,
            kind: .action,
            area: area,
            isBlockAction: isBlock
        )
    }

    private func ids(_ ranked: [PaletteRanker.Ranked]) -> [String] {
        ranked.map(\.id)
    }

    // MARK: - Filtering

    func testNonMatchingTokenIsFilteredOut() {
        let cands = [action("a", "Status"), action("b", "Commit")]
        let ranked = PaletteRanker.rank(
            candidates: cands, query: "zzz", frecency: [:], context: .init())
        XCTAssertTrue(ranked.isEmpty)
    }

    func testEveryTokenMustMatch() {
        // "git xyzzy" — second token matches nothing, so the candidate drops.
        let cands = [action("a", "Git Status", keywords: ["git"])]
        let ranked = PaletteRanker.rank(
            candidates: cands, query: "git xyzzy", frecency: [:], context: .init())
        XCTAssertTrue(ranked.isEmpty)
    }

    func testEmptyQueryKeepsEveryCandidate() {
        let cands = [action("a", "Alpha"), action("b", "Beta")]
        let ranked = PaletteRanker.rank(
            candidates: cands, query: "", frecency: [:], context: .init())
        XCTAssertEqual(Set(ids(ranked)), ["a", "b"])
    }

    // MARK: - Typing dominates context (the core invariant)

    func testStrongTitleMatchBeatsContextBoostOnWeakMatch() {
        // "status" is an exact-ish prefix of "Status" (non-git); "Git Stash"
        // only fuzzy-matches "status" weakly AND gets the git context boost.
        // The strong direct match must still win — context only nudges.
        let strong = action("strong", "Status")
        let weakGit = action("weakgit", "Git Stash", area: "git")
        let ranked = PaletteRanker.rank(
            candidates: [weakGit, strong],
            query: "status",
            frecency: [:],
            context: .init(gitRootPresent: true))
        XCTAssertEqual(ids(ranked).first, "strong")
    }

    // MARK: - Context boosts re-order near-ties

    func testGitRootFloatsEquallyFuzzyGitActionAboveNonGit() {
        // Two actions, identical title shape so identical fuzzy score for "co".
        let gitAction = action("git", "Co Git", area: "git")
        let other = action("other", "Co File", area: "files")
        let ranked = PaletteRanker.rank(
            candidates: [other, gitAction],
            query: "co",
            frecency: [:],
            context: .init(gitRootPresent: true))
        XCTAssertEqual(ids(ranked).first, "git")
    }

    func testNoGitRootDoesNotFloatGitAction() {
        // Same inputs, but no git root → the boost is absent, so the equal-score
        // tie-break falls through to supplied order and the git action does NOT
        // jump ahead of the earlier-supplied "other".
        let gitAction = action("git", "Co Git", area: "git")
        let other = action("other", "Co File", area: "files")
        let ranked = PaletteRanker.rank(
            candidates: [other, gitAction],
            query: "co",
            frecency: [:],
            context: .init(gitRootPresent: false))
        XCTAssertEqual(ids(ranked).first, "other")
    }

    func testEqualScoreFallsBackToSuppliedOrderWithinKind() {
        // No query, no signals → both score 0; supplied order is preserved
        // (faithful to the caller's intended order, e.g. waiting-first agents).
        let first = action("first", "Zeta")
        let second = action("second", "Alpha")
        let ranked = PaletteRanker.rank(
            candidates: [first, second], query: "", frecency: [:], context: .init())
        XCTAssertEqual(ids(ranked), ["first", "second"])
    }

    func testSelectedBlockFloatsBlockAction() {
        let block = action("block", "Fold Cmd", area: "terminal", isBlock: true)
        let plain = action("plain", "Fold Cfg", area: "terminal", isBlock: false)
        let ranked = PaletteRanker.rank(
            candidates: [plain, block],
            query: "fold",
            frecency: [:],
            context: .init(blockSelected: true))
        XCTAssertEqual(ids(ranked).first, "block")
    }

    // MARK: - Frecency floats frequently-used items at equal fuzzy

    func testFrequentItemFloatsAboveNeverUsedAtEqualFuzzy() {
        let used = action("used", "Co A")
        let fresh = action("fresh", "Co B")
        let ranked = PaletteRanker.rank(
            candidates: [fresh, used],
            query: "co",
            frecency: ["used": 3.0],   // ~3 recent acceptances
            context: .init())
        XCTAssertEqual(ids(ranked).first, "used")
    }

    func testFrecencyDoesNotOverpowerPrefixMatch() {
        // A frequently-used weak match must not beat a strong direct prefix
        // match on a never-used item — typing still wins.
        let strong = action("strong", "Commit")              // prefix of "co"
        let frequentWeak = action("weak", "Macro Tool")       // "co" only mid-word
        let ranked = PaletteRanker.rank(
            candidates: [frequentWeak, strong],
            query: "co",
            frecency: ["weak": 10.0],
            context: .init())
        XCTAssertEqual(ids(ranked).first, "strong")
    }

    func testLiveAgentsBoostFloatsAIActionsButAgentsStayAbove() {
        // With agents live, `.ai` actions get the boost and float above other
        // actions; agent sessions (boost + resume nudge) still outrank them.
        let agent = PaletteRanker.Candidate(
            id: "agent-1", title: "Agent", fields: ["agent-1", "Agent", ""], kind: .agentSession)
        let aiAction = action("ai", "Explain", area: "ai")
        let fileAction = action("file", "Files", area: "files")
        let ranked = PaletteRanker.rank(
            candidates: [fileAction, aiAction, agent],
            query: "",
            frecency: [:],
            context: .init(hasLiveAgents: true))
        XCTAssertEqual(ids(ranked), ["agent-1", "ai", "file"])
    }

    // MARK: - Empty-query order (zero-signal tie-break)

    func testEmptyQueryPreservesFamilyOrderAgentsActionsProfiles() {
        let agent = PaletteRanker.Candidate(
            id: "agent-1", title: "Agent", fields: ["agent-1", "Agent", ""], kind: .agentSession)
        let act = action("act", "Action")
        let profile = PaletteRanker.Candidate(
            id: "prof-1", title: "Profile", fields: ["prof-1", "Profile", ""], kind: .profile)
        let ranked = PaletteRanker.rank(
            candidates: [profile, act, agent],
            query: "",
            frecency: [:],
            context: .init())
        XCTAssertEqual(ids(ranked), ["agent-1", "act", "prof-1"])
    }

    func testEmptyQueryFrecencyOutranksFamilyOrder() {
        // A heavily-used profile can still float above an agent when frecency
        // dominates — the family order is only a tie-break, not a hard slot.
        let agent = PaletteRanker.Candidate(
            id: "agent-1", title: "Agent", fields: ["agent-1", "Agent", ""], kind: .agentSession)
        let profile = PaletteRanker.Candidate(
            id: "prof-1", title: "Profile", fields: ["prof-1", "Profile", ""], kind: .profile)
        let ranked = PaletteRanker.rank(
            candidates: [agent, profile],
            query: "",
            frecency: ["prof-1": 5.0],
            context: .init())
        XCTAssertEqual(ids(ranked).first, "prof-1")
    }

    // MARK: - Title highlight ranges

    func testTitleRangesUnderlineMatchedGlyphsInTitleOnly() {
        // "msg" → Messages: indices 0,2,5 (same as FuzzyMatcher).
        let cand = action("a", "Messages")
        let ranked = PaletteRanker.rank(
            candidates: [cand], query: "msg", frecency: [:], context: .init())
        XCTAssertEqual(ranked.first?.titleRanges, [0..<1, 2..<3, 5..<6])
    }

    func testKeywordOnlyMatchYieldsNoTitleRanges() {
        // Query matches a keyword but not the visible title → nothing to
        // highlight (we never underline keywords).
        let cand = action("a", "Status", keywords: ["refresh"])
        let ranked = PaletteRanker.rank(
            candidates: [cand], query: "refresh", frecency: [:], context: .init())
        XCTAssertEqual(ranked.count, 1)
        XCTAssertEqual(ranked.first?.titleRanges, [])
    }

    func testContiguousTitleMatchMergesIntoSingleRange() {
        let cand = action("a", "Messages")
        let ranked = PaletteRanker.rank(
            candidates: [cand], query: "mess", frecency: [:], context: .init())
        XCTAssertEqual(ranked.first?.titleRanges, [0..<4])
    }

    func testMultiTokenTitleRangesAreUnioned() {
        // "ne te" against "New Terminal": "ne" → N,e (0,1); "te" → T,e (4,5).
        let cand = action("a", "New Terminal")
        let ranked = PaletteRanker.rank(
            candidates: [cand], query: "ne te", frecency: [:], context: .init())
        XCTAssertEqual(ranked.first?.titleRanges, [0..<2, 4..<6])
    }
}
