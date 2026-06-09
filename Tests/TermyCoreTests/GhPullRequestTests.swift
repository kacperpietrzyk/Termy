import XCTest
@testable import TermyCore

final class GhPullRequestTests: XCTestCase {
    private func req(
        base: String = "main",
        head: String = "agent/foo",
        title: String = "Add foo",
        body: String = "Body text",
        draft: Bool = false,
        repo: String? = nil
    ) -> GhPullRequest.CreateRequest {
        GhPullRequest.CreateRequest(base: base, head: head, title: title, body: body, draft: draft, repo: repo)
    }

    private func ok(_ stdout: String, _ stderr: String = "") -> GhPullRequest.RunResult {
        GhPullRequest.RunResult(exitCode: 0, stdout: stdout, stderr: stderr)
    }

    private func fail(_ stderr: String, code: Int32 = 1) -> GhPullRequest.RunResult {
        GhPullRequest.RunResult(exitCode: code, stdout: "", stderr: stderr)
    }

    // MARK: - argument construction

    func testCreateArgumentsBasic() {
        let args = GhPullRequest.createArguments(req())
        XCTAssertEqual(args, [
            "gh", "pr", "create",
            "--base", "main",
            "--head", "agent/foo",
            "--title", "Add foo",
            "--body", "Body text"
        ])
    }

    func testCreateArgumentsTrimsTitleAndDropsBlank() {
        let args = GhPullRequest.createArguments(req(title: "   "))
        XCTAssertFalse(args.contains("--title"))
        // body is always present (avoids gh's interactive editor)
        XCTAssertTrue(args.contains("--body"))
    }

    func testCreateArgumentsDraftAndRepo() {
        let args = GhPullRequest.createArguments(req(draft: true, repo: "owner/repo"))
        XCTAssertTrue(args.contains("--draft"))
        let i = args.firstIndex(of: "--repo")!
        XCTAssertEqual(args[args.index(after: i)], "owner/repo")
    }

    func testCreateArgumentsBodyAlwaysPresentEvenWhenEmpty() {
        let args = GhPullRequest.createArguments(req(body: ""))
        let i = args.firstIndex(of: "--body")!
        XCTAssertEqual(args[args.index(after: i)], "")
    }

    func testAuthStatusArguments() {
        XCTAssertEqual(GhPullRequest.authStatusArguments(), ["gh", "auth", "status"])
    }

    // MARK: - create parsing

    func testParseCreateSuccessExtractsURLAndNumber() {
        let outcome = GhPullRequest.parseCreate(
            ok("https://github.com/owner/repo/pull/42\n"))
        XCTAssertEqual(outcome, .created(url: "https://github.com/owner/repo/pull/42", number: 42))
    }

    func testParseCreateSuccessURLOnStderr() {
        let outcome = GhPullRequest.parseCreate(
            ok("", "Warning: 3 uncommitted changes\nhttps://github.com/o/r/pull/7"))
        XCTAssertEqual(outcome, .created(url: "https://github.com/o/r/pull/7", number: 7))
    }

    func testParseCreateSuccessNoURLStillSucceeds() {
        let outcome = GhPullRequest.parseCreate(ok("done"))
        XCTAssertEqual(outcome, .created(url: nil, number: nil))
    }

    func testParseCreateAlreadyExists() {
        let outcome = GhPullRequest.parseCreate(
            fail("a pull request for branch \"agent/foo\" into branch \"main\" already exists:\nhttps://github.com/o/r/pull/9"))
        if case .alreadyExists(let detail) = outcome {
            XCTAssertTrue(detail.contains("already exists"))
        } else {
            XCTFail("expected alreadyExists, got \(outcome)")
        }
    }

    func testParseCreateNotAuthenticated() {
        let outcome = GhPullRequest.parseCreate(
            fail("To get started with GitHub CLI, please run: gh auth login"))
        XCTAssertEqual(outcome, .failed(reason: .notAuthenticated,
                                        detail: "To get started with GitHub CLI, please run: gh auth login"))
    }

    func testParseCreateNoCommits() {
        let outcome = GhPullRequest.parseCreate(
            fail("pull request create failed: No commits between main and agent/foo"))
        if case .failed(let reason, _) = outcome {
            XCTAssertEqual(reason, .noCommits)
        } else {
            XCTFail("expected noCommits failure, got \(outcome)")
        }
    }

    func testParseCreateOtherFailure() {
        let outcome = GhPullRequest.parseCreate(fail("GraphQL: something broke"))
        if case .failed(let reason, let detail) = outcome {
            XCTAssertEqual(reason, .other)
            XCTAssertEqual(detail, "GraphQL: something broke")
        } else {
            XCTFail("expected other failure, got \(outcome)")
        }
    }

    func testFirstPullRequestURLIgnoresNonPullLinks() {
        XCTAssertNil(GhPullRequest.firstPullRequestURL(in: "see https://github.com/o/r/issues/3"))
        XCTAssertEqual(
            GhPullRequest.firstPullRequestURL(in: "x https://github.com/o/r/pull/12 y"),
            "https://github.com/o/r/pull/12")
    }

    func testPullRequestNumberParsing() {
        XCTAssertEqual(GhPullRequest.pullRequestNumber(in: "https://github.com/o/r/pull/123"), 123)
        XCTAssertNil(GhPullRequest.pullRequestNumber(in: "https://github.com/o/r/tree/main"))
    }

    // MARK: - run via stubbed runner (NEVER a real gh)

    func testCreateRunsConstructedArgsAndParses() {
        var captured: [String] = []
        let gh = GhPullRequest { args in
            captured = args
            return self.ok("https://github.com/o/r/pull/5")
        }
        let outcome = gh.create(req(head: "agent/bar"))
        XCTAssertEqual(captured.first, "gh")
        XCTAssertTrue(captured.contains("agent/bar"))
        XCTAssertEqual(outcome, .created(url: "https://github.com/o/r/pull/5", number: 5))
    }

    func testCreateGhMissingWhenRunnerThrows() {
        struct NotFound: Error {}
        let gh = GhPullRequest { _ in throw NotFound() }
        XCTAssertEqual(gh.create(req()), .ghMissing)
    }

    func testCheckAuthAuthenticated() {
        let gh = GhPullRequest { args in
            XCTAssertEqual(args, ["gh", "auth", "status"])
            return self.ok("Logged in to github.com as octocat")
        }
        XCTAssertEqual(gh.checkAuth(), .authenticated)
    }

    func testCheckAuthNotAuthenticated() {
        let gh = GhPullRequest { _ in self.fail("You are not logged into any GitHub hosts.") }
        XCTAssertEqual(gh.checkAuth(),
                       .notAuthenticated(detail: "You are not logged into any GitHub hosts."))
    }

    func testCheckAuthGhMissing() {
        struct NotFound: Error {}
        let gh = GhPullRequest { _ in throw NotFound() }
        XCTAssertEqual(gh.checkAuth(), .ghMissing)
    }
}
