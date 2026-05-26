import XCTest
@testable import TermyCore

final class HistoryStoreNextComponentTests: XCTestCase {
    func test_empty_returnsNil() {
        XCTAssertNil(HistoryStore.nextComponent(of: ""))
    }

    func test_singleToken_returnsWholeToken() {
        XCTAssertEqual(HistoryStore.nextComponent(of: "checkout"), "checkout")
    }

    func test_whitespaceBoundedToken() {
        XCTAssertEqual(HistoryStore.nextComponent(of: "checkout main"), "checkout")
    }

    func test_leadingWhitespace_returnedAlone() {
        XCTAssertEqual(HistoryStore.nextComponent(of: " main"), " ")
    }

    func test_leadingWhitespaceRun_collapsedAsSingleReturn() {
        XCTAssertEqual(HistoryStore.nextComponent(of: "   main"), "   ")
    }

    func test_pathSegment_includesSlash() {
        XCTAssertEqual(HistoryStore.nextComponent(of: "src/foo/bar.swift"), "src/")
    }

    func test_pathReachedBeforeSpace() {
        XCTAssertEqual(HistoryStore.nextComponent(of: "feature/foo branch"), "feature/")
    }

    func test_flagToken_noSlash_behavesAsPlainToken() {
        XCTAssertEqual(HistoryStore.nextComponent(of: "-b feature/foo"), "-b")
    }

    func test_singleCharacter() {
        XCTAssertEqual(HistoryStore.nextComponent(of: "a"), "a")
    }

    func test_tabAsLeadingWhitespace() {
        XCTAssertEqual(HistoryStore.nextComponent(of: "\tmain"), "\t")
    }
}
