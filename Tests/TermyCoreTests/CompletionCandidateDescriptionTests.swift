import XCTest
@testable import TermyCore

final class CompletionCandidateDescriptionTests: XCTestCase {
    func test_init_withoutDescription_isNil() {
        let c = CompletionCandidate(title: "push", replacement: "git push", kind: .command)
        XCTAssertNil(c.description)
    }

    func test_init_withDescription_round_trips() {
        let c = CompletionCandidate(
            title: "push",
            replacement: "git push",
            kind: .command,
            description: "Update remote refs along with associated objects"
        )
        XCTAssertEqual(c.description, "Update remote refs along with associated objects")
    }

    func test_equality_includesDescription() {
        let a = CompletionCandidate(title: "x", replacement: "x", kind: .command, description: "A")
        let b = CompletionCandidate(title: "x", replacement: "x", kind: .command, description: "B")
        let c = CompletionCandidate(title: "x", replacement: "x", kind: .command, description: "A")
        XCTAssertNotEqual(a, b)
        XCTAssertEqual(a, c)
    }

    func test_newKindCases_exist() {
        // Compile-time assertion via switch exhaustiveness.
        let kinds: [CompletionKind] = [
            .history, .command, .flag, .file, .sshHost, .gitBranch,
            .builtin, .alias, .directory, .option
        ]
        XCTAssertEqual(kinds.count, 10)
    }
}
