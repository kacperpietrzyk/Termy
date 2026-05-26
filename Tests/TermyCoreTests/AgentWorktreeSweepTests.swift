import XCTest
@testable import TermyCore

final class AgentWorktreeSweepTests: XCTestCase {
    private var cleanupURLs: [URL] = []

    override func tearDown() {
        for url in cleanupURLs { try? FileManager.default.removeItem(at: url) }
        cleanupURLs = []
        super.tearDown()
    }

    func testSweepRemovesCleanWorktreesAndKeepsDirtyOnes() throws {
        let repoURL = try makeTempGitRepo()
        let repo = GitRepository(root: repoURL)
        let base = try repo.resolveHEAD()

        let parent = makeTempDir()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let cleanWT = parent.appendingPathComponent("clean")
        let dirtyWT = parent.appendingPathComponent("dirty")
        try repo.addWorktree(branch: "termy/agent-a-1", base: base, path: cleanWT)
        try repo.addWorktree(branch: "termy/agent-b-2", base: base, path: dirtyWT)
        try "wip".write(to: dirtyWT.appendingPathComponent("wip.txt"), atomically: true, encoding: .utf8)

        GitRepository.sweepCleanAgentWorktrees(in: parent)

        XCTAssertFalse(FileManager.default.fileExists(atPath: cleanWT.path), "clean worktree should be swept")
        XCTAssertTrue(FileManager.default.fileExists(atPath: dirtyWT.path), "dirty worktree should be kept")
    }

    // MARK: - Helpers

    private func makeTempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FB3Sweep-\(UUID().uuidString)")
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
