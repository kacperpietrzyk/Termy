import XCTest
@testable import Termy
import TermyCore

final class FB3AgentWorktreeCleanupTests: XCTestCase {
    private var cleanupURLs: [URL] = []

    override func tearDown() {
        for url in cleanupURLs { try? FileManager.default.removeItem(at: url) }
        cleanupURLs = []
        super.tearDown()
    }

    @MainActor
    func testCleanWorktreeRemovedOnProcessExit() throws {
        let store = try makeStoreInRepo()
        store.launchCLIAgent(.claudeCode, isolation: .newWorktree, baseCwd: nil)
        let session = try XCTUnwrap(store.sessions.last)
        let workingDirectory = try XCTUnwrap(store.terminalLaunchDescriptors[session.id]?.workingDirectory)
        XCTAssertTrue(FileManager.default.fileExists(atPath: workingDirectory))

        store.noteSessionProcessExited(exitCode: 0, for: session.id)

        XCTAssertFalse(FileManager.default.fileExists(atPath: workingDirectory),
                       "a clean worktree must be removed on exit")
    }

    @MainActor
    func testDirtyWorktreeKeptWithSystemLineOnProcessExit() throws {
        let store = try makeStoreInRepo()
        store.launchCLIAgent(.codex, isolation: .newWorktree, baseCwd: nil)
        let session = try XCTUnwrap(store.sessions.last)
        let workingDirectory = try XCTUnwrap(store.terminalLaunchDescriptors[session.id]?.workingDirectory)
        try "wip".write(to: URL(fileURLWithPath: workingDirectory).appendingPathComponent("out.txt"),
                        atomically: true, encoding: .utf8)

        store.noteSessionProcessExited(exitCode: 0, for: session.id)

        XCTAssertTrue(FileManager.default.fileExists(atPath: workingDirectory),
                      "a dirty worktree must be kept")
        let kept = store.sessions.first(where: { $0.id == session.id })?
            .lines.contains { $0.text.contains("Worktree kept") } ?? false
        XCTAssertTrue(kept, "a system line must report the kept worktree")
    }

    @MainActor
    func testCleanWorktreeRemovedOnCloseSession() throws {
        let store = try makeStoreInRepo()
        store.launchCLIAgent(.claudeCode, isolation: .newWorktree, baseCwd: nil)
        let session = try XCTUnwrap(store.sessions.last)
        let workingDirectory = try XCTUnwrap(store.terminalLaunchDescriptors[session.id]?.workingDirectory)

        store.closeSession(sessionID: session.id)

        XCTAssertFalse(FileManager.default.fileExists(atPath: workingDirectory))
    }

    @MainActor
    func testInitSweepsCleanOrphanWorktree() throws {
        let repoURL = try makeTempGitRepo()
        let repo = GitRepository(root: repoURL)
        let base = try repo.resolveHEAD()
        let wtRoot = makeTempDir()
        try FileManager.default.createDirectory(at: wtRoot, withIntermediateDirectories: true)
        let orphan = wtRoot.appendingPathComponent("agent-codex-deadbeef")
        try repo.addWorktree(branch: "termy/agent-codex-deadbeef", base: base, path: orphan)
        XCTAssertTrue(FileManager.default.fileExists(atPath: orphan.path))

        // Instantiating the store triggers the launch-time sweep (runs in a detached task).
        _ = TermyStore(startInitialPTY: false, projectRoot: repoURL, agentWorktreeRoot: wtRoot)

        let deadline = Date().addingTimeInterval(5)
        while FileManager.default.fileExists(atPath: orphan.path), Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: orphan.path),
                       "TermyStore.init must sweep clean orphan worktrees")
    }

    // MARK: - Helpers

    @MainActor
    private func makeStoreInRepo() throws -> TermyStore {
        let repoURL = try makeTempGitRepo()
        return TermyStore(startInitialPTY: false, projectRoot: repoURL, agentWorktreeRoot: makeTempDir())
    }

    private func makeTempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FB3Cleanup-\(UUID().uuidString)")
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
