import XCTest
@testable import TermyCore

final class AgentSteeringTests: XCTestCase {
    private func c(_ path: String, _ body: String, anchor: String? = nil) -> AgentSteering.Comment {
        AgentSteering.Comment(filePath: path, anchor: anchor, body: body)
    }

    func testEmptySetComposesToNil() {
        XCTAssertNil(AgentSteering.compose([]))
    }

    func testAllBlankBodiesComposeToNil() {
        XCTAssertNil(AgentSteering.compose([c("a.swift", "   "), c("b.swift", "\n\t ")]))
    }

    func testSingleCommentIsNotNumbered() {
        let out = AgentSteering.compose([c("Foo.swift", "rename this var")])
        XCTAssertEqual(out, "\(AgentSteering.preamble) Foo.swift: rename this var")
        XCTAssertFalse(out!.contains("(1)"))
    }

    func testMultipleCommentsKeepOrderAndAreNumbered() {
        let out = AgentSteering.compose([
            c("Foo.swift", "rename this"),
            c("Bar.swift", "handle nil"),
        ])
        XCTAssertEqual(
            out,
            "\(AgentSteering.preamble) (1) Foo.swift: rename this (2) Bar.swift: handle nil"
        )
    }

    func testBlankBodyDroppedButOthersKeptAndRenumbered() {
        let out = AgentSteering.compose([
            c("A.swift", "first"),
            c("B.swift", "   "),
            c("C.swift", "third"),
        ])
        XCTAssertEqual(
            out,
            "\(AgentSteering.preamble) (1) A.swift: first (2) C.swift: third"
        )
    }

    func testAnchorIsRenderedWhenPresent() {
        let out = AgentSteering.compose([c("Foo.swift", "guard here", anchor: "@@ -12,4 +12,6 @@")])
        XCTAssertEqual(out, "\(AgentSteering.preamble) Foo.swift · @@ -12,4 +12,6 @@: guard here")
    }

    // The load-bearing guard: an embedded newline must NEVER survive into the
    // single composed line, or it would submit a partial turn to the agent REPL.
    func testEmbeddedNewlinesAreFlattenedToSingleLine() {
        let out = AgentSteering.compose([c("Foo.swift", "first line\nsecond line\n\nthird")])
        XCTAssertNotNil(out)
        XCTAssertFalse(out!.contains("\n"))
        XCTAssertEqual(out, "\(AgentSteering.preamble) Foo.swift: first line second line third")
    }

    func testTabsAndCollapsedWhitespaceInBodyAndAnchor() {
        let out = AgentSteering.compose([c("Foo.swift", "do\t\tthis   now", anchor: "hunk\t1")])
        XCTAssertFalse(out!.contains("\t"))
        XCTAssertEqual(out, "\(AgentSteering.preamble) Foo.swift · hunk 1: do this now")
    }
}
