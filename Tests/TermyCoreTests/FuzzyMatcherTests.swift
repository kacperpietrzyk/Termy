import XCTest
@testable import TermyCore

final class FuzzyMatcherTests: XCTestCase {

    // MARK: - Subsequence semantics

    func testEmptyQueryMatchesWithZeroScoreAndNoRanges() {
        let match = FuzzyMatcher.match("", in: "Messages")
        XCTAssertEqual(match, FuzzyMatch(score: 0, ranges: []))
    }

    func testEmptyCandidateNeverMatchesNonEmptyQuery() {
        XCTAssertNil(FuzzyMatcher.match("a", in: ""))
    }

    func testNonSubsequenceDoesNotMatch() {
        // 'z' is absent; order must be preserved so "sm" cannot match "ms".
        XCTAssertNil(FuzzyMatcher.match("z", in: "Messages"))
        XCTAssertNil(FuzzyMatcher.match("sm", in: "ms"))
    }

    // MARK: - msg -> Messages (named test)

    func testAbbreviationMatchesMessages() {
        let match = FuzzyMatcher.match("msg", in: "Messages")
        XCTAssertNotNil(match)
    }

    func testMatchedRangesAreCorrect() {
        // "msg" against "Messages": M(0) e s(2) s a g(5) e s -> indices 0,2,5.
        let match = FuzzyMatcher.match("msg", in: "Messages")
        XCTAssertEqual(match?.ranges, [0..<1, 2..<3, 5..<6])
    }

    func testContiguousMatchProducesSingleRange() {
        let match = FuzzyMatcher.match("mess", in: "Messages")
        XCTAssertEqual(match?.ranges, [0..<4])
    }

    func testRangesAreCaseInsensitiveAgainstOriginalCandidate() {
        // Query lowercased, ranges reported against the original candidate.
        let match = FuzzyMatcher.match("CON", in: "Connect SSH")
        XCTAssertEqual(match?.ranges, [0..<3])
    }

    // MARK: - Contiguous beats scattered (named test)

    func testContiguousBeatsScattered() {
        // "abc" contiguous in "abcxyz" should outscore the scattered run in "axbxc".
        let contiguous = FuzzyMatcher.match("abc", in: "abcxyz")
        let scattered = FuzzyMatcher.match("abc", in: "axbxcx")
        let c = try? XCTUnwrap(contiguous)
        let s = try? XCTUnwrap(scattered)
        XCTAssertGreaterThan(c?.score ?? -1, s?.score ?? .infinity)
    }

    // MARK: - Prefix beats mid-word (named test)

    func testPrefixBeatsMidWord() {
        // "se" as a prefix of "session" outscores "se" appearing mid-word.
        let prefix = FuzzyMatcher.match("se", in: "session")
        let midWord = FuzzyMatcher.match("se", in: "browse")
        let p = try? XCTUnwrap(prefix)
        let m = try? XCTUnwrap(midWord)
        XCTAssertGreaterThan(p?.score ?? -1, m?.score ?? .infinity)
    }

    func testExactMatchBeatsPrefixOfLongerCandidate() {
        let exact = FuzzyMatcher.match("git", in: "git")
        let prefix = FuzzyMatcher.match("git", in: "github")
        XCTAssertGreaterThan(exact?.score ?? -1, prefix?.score ?? .infinity)
    }

    // MARK: - Word / camelCase boundary bonus

    func testCamelCaseBoundaryMatchOutscoresInteriorMatch() {
        // "op" hitting the camelCase hump in "openPanel" should beat the same
        // letters buried mid-word in "stopwatch".
        let hump = FuzzyMatcher.match("op", in: "openPanel")
        let interior = FuzzyMatcher.match("op", in: "stopwatch")
        XCTAssertNotNil(hump)
        XCTAssertNotNil(interior)
        // Both match; the leading/contiguous prefix in "openPanel" wins.
        XCTAssertGreaterThan(hump?.score ?? -1, interior?.score ?? .infinity)
    }

    func testSeparatorIsTreatedAsBoundary() {
        // "cs" matching word starts across a space in "Connect SSH".
        let match = FuzzyMatcher.match("cs", in: "Connect SSH")
        XCTAssertEqual(match?.ranges, [0..<1, 8..<9])
    }

    // MARK: - Multi-token, multi-field scorer

    func testMultiTokenRequiresEveryTokenToMatchSomeField() {
        let fields = ["explain-last-error", "Explain Last Error",
                      "Use local AI context", "ai", "error", "fix"]
        XCTAssertNotNil(FuzzyMatcher.score(query: "ai error", againstAnyOf: fields))
        XCTAssertNil(FuzzyMatcher.score(query: "ai missingtoken", againstAnyOf: fields))
    }

    func testMultiTokenEmptyQueryReturnsNil() {
        XCTAssertNil(FuzzyMatcher.score(query: "   ", againstAnyOf: ["anything"]))
    }

    func testPreferredFieldHitOutranksSameMatchInNonPreferredField() {
        // Identical substring present once in the title (preferred, index 1)
        // and once only in a keyword (non-preferred) — the preferred-field
        // bonus must break the tie toward the visible title hit.
        let titleHit = FuzzyMatcher.score(
            query: "open",
            againstAnyOf: ["id", "Open Panel", "subtitle", "unrelated"],
            preferredFieldIndex: 1)
        let keywordHit = FuzzyMatcher.score(
            query: "open",
            againstAnyOf: ["id", "Unrelated Title", "subtitle", "Open Panel"],
            preferredFieldIndex: 1)
        XCTAssertNotNil(titleHit)
        XCTAssertNotNil(keywordHit)
        XCTAssertGreaterThan(titleHit ?? -1, keywordHit ?? .infinity)
    }
}
