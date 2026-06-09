import XCTest
@testable import TermyCore

/// M2: lazy per-commit diff. Proves `diff(commit:)` runs `git show <hash>` and
/// returns that commit's patch, and that the no-arg `diff()` still maps to the
/// working-tree diff (regression guard that the overload didn't change it).
final class GitRepositoryDiffArgsTests: XCTestCase {
    private var cleanupURLs: [URL] = []

    override func tearDown() {
        for url in cleanupURLs { try? FileManager.default.removeItem(at: url) }
        cleanupURLs = []
        super.tearDown()
    }

    func testDiffForCommitShowsThatCommitsChanges() throws {
        let repoURL = try makeTempGitRepo()
        // Second commit adds a distinctive line.
        try "alpha line\n".write(to: repoURL.appendingPathComponent("feature.txt"),
                                 atomically: true, encoding: .utf8)
        runGit(["add", "."], in: repoURL)
        runGit(["commit", "-q", "-m", "add feature"], in: repoURL)

        let repo = GitRepository(root: repoURL)
        let head = try repo.resolveHEAD()
        let shown = try repo.diff(commit: head)

        XCTAssertTrue(shown.contains("add feature"), "git show should include the commit subject")
        XCTAssertTrue(shown.contains("alpha line"), "git show should include the added line")
    }

    func testDiffNoArgStillReportsWorkingTreeDiff() throws {
        let repoURL = try makeTempGitRepo()
        // Modify the tracked seed file WITHOUT committing — working-tree diff only.
        try "seed-modified\n".write(to: repoURL.appendingPathComponent("seed.txt"),
                                    atomically: true, encoding: .utf8)

        let repo = GitRepository(root: repoURL)
        let working = try repo.diff()

        XCTAssertTrue(working.contains("seed-modified"),
                      "working-tree diff() should reflect the uncommitted change")
    }

    // MARK: - Helpers

    private func makeTempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("M2Diff-\(UUID().uuidString)")
        cleanupURLs.append(url)
        return url
    }

    private func makeTempGitRepo() throws -> URL {
        let dir = makeTempDir()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        runGit(["init", "-q", "-b", "main"], in: dir)
        runGit(["config", "user.email", "test@termy.test"], in: dir)
        runGit(["config", "user.name", "Termy Test"], in: dir)
        try "seed\n".write(to: dir.appendingPathComponent("seed.txt"), atomically: true, encoding: .utf8)
        runGit(["add", "."], in: dir)
        runGit(["commit", "-q", "-m", "seed"], in: dir)
        return dir
    }

    @discardableResult
    private func runGit(_ args: [String], in dir: URL) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = dir
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }
}
