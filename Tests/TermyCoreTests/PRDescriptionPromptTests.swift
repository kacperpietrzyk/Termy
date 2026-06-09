import XCTest
@testable import TermyCore

final class PRDescriptionPromptTests: XCTestCase {
    func testBuildIncludesBranchesAndInstruction() {
        let prompt = PRDescriptionPrompt.build(
            .init(headBranch: "agent/foo", baseBranch: "main"))
        XCTAssertTrue(prompt.contains(PRDescriptionPrompt.instruction))
        XCTAssertTrue(prompt.contains("Branch: agent/foo → main"))
    }

    func testBuildIncludesCommitsAndFilesWhenPresent() {
        let prompt = PRDescriptionPrompt.build(.init(
            headBranch: "h", baseBranch: "main",
            commitSubjects: ["Add X", "  ", "Fix Y"],
            touchedFiles: ["a.swift", "b.swift"]))
        XCTAssertTrue(prompt.contains("Commits:\n- Add X\n- Fix Y"))
        XCTAssertFalse(prompt.contains("-  \n"))           // blank subject dropped
        XCTAssertTrue(prompt.contains("Changed files:\n- a.swift\n- b.swift"))
    }

    func testBuildOmitsEmptySections() {
        let prompt = PRDescriptionPrompt.build(.init(headBranch: "h", baseBranch: "main"))
        XCTAssertFalse(prompt.contains("Commits:"))
        XCTAssertFalse(prompt.contains("Changed files:"))
        XCTAssertFalse(prompt.contains("Diff:"))
    }

    func testDiffTruncatedToBudgetWithMarker() {
        let big = String(repeating: "x", count: 100)
        let out = PRDescriptionPrompt.truncatedDiff(big, budget: 40)
        XCTAssertTrue(out.hasPrefix(String(repeating: "x", count: 40)))
        XCTAssertTrue(out.contains("diff truncated"))
        XCTAssertLessThan(out.count, big.count + 50)
    }

    func testDiffUnderBudgetNotTruncated() {
        XCTAssertEqual(PRDescriptionPrompt.truncatedDiff("short", budget: 100), "short")
    }

    func testBuildTruncatesDiffInPrompt() {
        let prompt = PRDescriptionPrompt.build(
            .init(headBranch: "h", baseBranch: "main", diff: String(repeating: "z", count: 50)),
            diffCharBudget: 10)
        XCTAssertTrue(prompt.contains("diff truncated"))
    }

    func testParseResponseTitleAndBody() {
        let (title, body) = PRDescriptionPrompt.parseResponse("""
        Add foo support

        Implements the foo path.

        - wires X
        - tests Y
        """)
        XCTAssertEqual(title, "Add foo support")
        XCTAssertTrue(body.hasPrefix("Implements the foo path."))
        XCTAssertTrue(body.contains("- wires X"))
    }

    func testParseResponseStripsHeadingMarker() {
        let (title, _) = PRDescriptionPrompt.parseResponse("# Add foo\n\nbody")
        XCTAssertEqual(title, "Add foo")
    }

    func testParseResponseStripsQuotedTitle() {
        let (title, _) = PRDescriptionPrompt.parseResponse("\"Add foo\"\n\nbody")
        XCTAssertEqual(title, "Add foo")
    }

    func testParseResponseSkipsLeadingBlankLines() {
        let (title, body) = PRDescriptionPrompt.parseResponse("\n\nTitle here\n\nthe body")
        XCTAssertEqual(title, "Title here")
        XCTAssertEqual(body, "the body")
    }

    func testParseResponseTitleOnlyYieldsEmptyBody() {
        let (title, body) = PRDescriptionPrompt.parseResponse("Just a title")
        XCTAssertEqual(title, "Just a title")
        XCTAssertEqual(body, "")
    }

    func testParseResponseUnwrapsOuterCodeFence() {
        let (title, body) = PRDescriptionPrompt.parseResponse("""
        ```
        Add foo

        body line
        ```
        """)
        XCTAssertEqual(title, "Add foo")
        XCTAssertEqual(body, "body line")
    }

    func testParseResponseEmpty() {
        let (title, body) = PRDescriptionPrompt.parseResponse("   \n  \n")
        XCTAssertEqual(title, "")
        XCTAssertEqual(body, "")
    }
}
