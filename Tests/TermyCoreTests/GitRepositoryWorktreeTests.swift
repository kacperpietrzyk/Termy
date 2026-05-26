import XCTest
@testable import TermyCore

final class GitRepositoryWorktreeTests: XCTestCase {
    private var cleanupURLs: [URL] = []

    override func tearDown() {
        for url in cleanupURLs { try? FileManager.default.removeItem(at: url) }
        cleanupURLs = []
        super.tearDown()
    }

    func testAddWorktreeCreatesBranchAndDirectory() throws {
        let repoURL = try makeTempGitRepo()
        let repo = GitRepository(root: repoURL)
        let base = try repo.resolveHEAD()
        let wtURL = makeTempDir()

        try repo.addWorktree(branch: "termy/agent-test-1", base: base, path: wtURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: wtURL.path))
        XCTAssertTrue(try repo.localBranches().contains("termy/agent-test-1"))
    }

    func testFreshWorktreeIsDisposable() throws {
        let repoURL = try makeTempGitRepo()
        let repo = GitRepository(root: repoURL)
        let base = try repo.resolveHEAD()
        let wtURL = makeTempDir()
        try repo.addWorktree(branch: "termy/agent-test-2", base: base, path: wtURL)

        XCTAssertTrue(try GitRepository(root: wtURL).isDisposable(baseSHA: base))
    }

    func testUntrackedFileMakesWorktreeNonDisposable() throws {
        let repoURL = try makeTempGitRepo()
        let repo = GitRepository(root: repoURL)
        let base = try repo.resolveHEAD()
        let wtURL = makeTempDir()
        try repo.addWorktree(branch: "termy/agent-test-3", base: base, path: wtURL)
        try "wip".write(to: wtURL.appendingPathComponent("scratch.txt"), atomically: true, encoding: .utf8)

        XCTAssertFalse(try GitRepository(root: wtURL).isDisposable(baseSHA: base))
    }

    func testCommitMakesWorktreeNonDisposable() throws {
        let repoURL = try makeTempGitRepo()
        let repo = GitRepository(root: repoURL)
        let base = try repo.resolveHEAD()
        let wtURL = makeTempDir()
        try repo.addWorktree(branch: "termy/agent-test-4", base: base, path: wtURL)
        try "done".write(to: wtURL.appendingPathComponent("done.txt"), atomically: true, encoding: .utf8)
        runGit(["add", "."], in: wtURL)
        runGit(["commit", "-q", "-m", "work"], in: wtURL)

        XCTAssertFalse(try GitRepository(root: wtURL).isDisposable(baseSHA: base))
    }

    func testRemoveWorktreeAndDeleteBranch() throws {
        let repoURL = try makeTempGitRepo()
        let repo = GitRepository(root: repoURL)
        let base = try repo.resolveHEAD()
        let wtURL = makeTempDir()
        try repo.addWorktree(branch: "termy/agent-test-5", base: base, path: wtURL)

        try repo.removeWorktree(path: wtURL)
        try repo.deleteBranch("termy/agent-test-5")

        XCTAssertFalse(FileManager.default.fileExists(atPath: wtURL.path))
        XCTAssertFalse(try repo.localBranches().contains("termy/agent-test-5"))
    }

    func testIsRepositoryFalseForNonRepo() {
        let plain = makeTempDir()
        XCTAssertFalse(GitRepository(root: plain).isRepository())
    }

    func testMainWorktreeRootResolvesFromLinkedWorktree() throws {
        let repoURL = try makeTempGitRepo()
        let repo = GitRepository(root: repoURL)
        let base = try repo.resolveHEAD()
        let wtURL = makeTempDir()
        try repo.addWorktree(branch: "termy/agent-test-6", base: base, path: wtURL)

        let resolved = try GitRepository(root: wtURL).mainWorktreeRoot()
        XCTAssertEqual(resolved.standardizedFileURL.resolvingSymlinksInPath().path,
                       repoURL.standardizedFileURL.resolvingSymlinksInPath().path)
    }

    // MARK: - Helpers

    private func makeTempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FB3WT-\(UUID().uuidString)")
        cleanupURLs.append(url)
        return url
    }

    private func makeTempGitRepo() throws -> URL {
        let dir = makeTempDir()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        runGit(["init", "-q", "-b", "main"], in: dir)
        runGit(["config", "user.email", "test@termy.test"], in: dir)
        runGit(["config", "user.name", "Termy Test"], in: dir)
        try "seed".write(to: dir.appendingPathComponent("seed.txt"), atomically: true, encoding: .utf8)
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
