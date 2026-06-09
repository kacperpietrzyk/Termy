import XCTest
@testable import TermyCore

/// AD-3: `GitRepository.fileDiffs()` against a real temp repo. Proves it surfaces
/// (a) unstaged tracked edits, (b) staged tracked edits, and (c) untracked files
/// — the last WITHOUT mutating the index (a `git add -N` would have leaked into
/// `git status`), since a live agent's worktree must not be disturbed.
final class GitRepositoryFileDiffTests: XCTestCase {
    private var cleanupURLs: [URL] = []

    override func tearDown() {
        for url in cleanupURLs { try? FileManager.default.removeItem(at: url) }
        cleanupURLs = []
        super.tearDown()
    }

    func testUnstagedTrackedEditIsSurfaced() throws {
        let repoURL = try makeTempGitRepo()
        try "seed-modified\n".write(to: repoURL.appendingPathComponent("seed.txt"),
                                    atomically: true, encoding: .utf8)

        let diffs = try GitRepository(root: repoURL).fileDiffs()
        let seed = try XCTUnwrap(diffs.first { $0.path == "seed.txt" })
        XCTAssertEqual(seed.status, .modified)
        XCTAssertTrue(seed.lines.contains { $0.kind == .added && $0.content == "seed-modified" })
    }

    func testStagedTrackedEditIsSurfaced() throws {
        let repoURL = try makeTempGitRepo()
        try "staged-change\n".write(to: repoURL.appendingPathComponent("seed.txt"),
                                    atomically: true, encoding: .utf8)
        runGit(["add", "seed.txt"], in: repoURL)

        // bare diff() (unstaged only) would MISS this; fileDiffs() uses `diff HEAD`.
        let diffs = try GitRepository(root: repoURL).fileDiffs()
        let seed = try XCTUnwrap(diffs.first { $0.path == "seed.txt" })
        XCTAssertTrue(seed.lines.contains { $0.kind == .added && $0.content == "staged-change" })
    }

    func testUntrackedFileSurfacedReadOnly() throws {
        let repoURL = try makeTempGitRepo()
        try "brand new agent output\n".write(to: repoURL.appendingPathComponent("created.txt"),
                                             atomically: true, encoding: .utf8)

        let repo = GitRepository(root: repoURL)
        let diffs = try repo.fileDiffs()
        let created = try XCTUnwrap(diffs.first { $0.path == "created.txt" })
        XCTAssertTrue(created.untracked)
        XCTAssertEqual(created.status, .untracked)
        XCTAssertTrue(created.lines.contains { $0.kind == .added && $0.content == "brand new agent output" })

        // READ-ONLY invariant: the file is still untracked (no intent-to-add).
        let stillUntracked = try repo.changes().first { $0.path == "created.txt" }
        XCTAssertEqual(stillUntracked?.isUntracked, true)
    }

    func testCleanRepoYieldsNoDiffs() throws {
        let repoURL = try makeTempGitRepo()
        XCTAssertTrue(try GitRepository(root: repoURL).fileDiffs().isEmpty)
    }

    func testDiffsScopedToWorktreeRoot() throws {
        // A linked worktree sees only its own working-tree changes.
        let repoURL = try makeTempGitRepo()
        let repo = GitRepository(root: repoURL)
        let base = try repo.resolveHEAD()
        let wtURL = makeTempDir()
        try repo.addWorktree(branch: "termy/diff-scope", base: base, path: wtURL)
        try "in-worktree\n".write(to: wtURL.appendingPathComponent("seed.txt"),
                                  atomically: true, encoding: .utf8)

        XCTAssertTrue(try repo.fileDiffs().isEmpty, "main worktree is clean")
        XCTAssertFalse(try GitRepository(root: wtURL).fileDiffs().isEmpty, "linked worktree has the edit")
    }

    // MARK: - Helpers

    private func makeTempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("AD3Diff-\(UUID().uuidString)")
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
