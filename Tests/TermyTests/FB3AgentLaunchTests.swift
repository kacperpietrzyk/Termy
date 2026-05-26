import XCTest
@testable import Termy
import TermyCore

final class FB3AgentLaunchTests: XCTestCase {
    private var cleanupURLs: [URL] = []

    override func tearDown() {
        for url in cleanupURLs { try? FileManager.default.removeItem(at: url) }
        cleanupURLs = []
        super.tearDown()
    }

    @MainActor
    func testLaunchHereSetsAgentIdentityAndWorkingDirectory() {
        let store = TermyStore(startInitialPTY: false)
        store.launchCLIAgent(.claudeCode, isolation: .here, baseCwd: "/tmp/example-here")

        let session = store.sessions.last
        XCTAssertEqual(session?.agentType, .claudeCode)
        XCTAssertEqual(session?.interactionMode, .rawPTY)
        XCTAssertEqual(session?.title.contains("Claude Code"), true)
        XCTAssertEqual(store.terminalLaunchDescriptors[session!.id]?.workingDirectory, "/tmp/example-here")
    }

    @MainActor
    func testLaunchNewWorktreeCreatesWorktreeAndLaunchesThere() throws {
        let repoURL = try makeTempGitRepo()
        let wtRoot = makeTempDir()
        let store = TermyStore(startInitialPTY: false, projectRoot: repoURL, agentWorktreeRoot: wtRoot)

        store.launchCLIAgent(.codex, isolation: .newWorktree, baseCwd: nil)

        let session = try XCTUnwrap(store.sessions.last)
        XCTAssertEqual(session.agentType, .codex)
        let workingDirectory = try XCTUnwrap(store.terminalLaunchDescriptors[session.id]?.workingDirectory)
        XCTAssertTrue(workingDirectory.hasPrefix(wtRoot.path), "agent cwd must be inside the worktree root")
        XCTAssertTrue(FileManager.default.fileExists(atPath: workingDirectory))
    }

    @MainActor
    func testLaunchNewWorktreeInNonRepoIsRefused() {
        let nonRepo = makeTempDir()
        try? FileManager.default.createDirectory(at: nonRepo, withIntermediateDirectories: true)
        let store = TermyStore(startInitialPTY: false, projectRoot: nonRepo, agentWorktreeRoot: makeTempDir())
        let before = store.sessions.count

        store.launchCLIAgent(.codex, isolation: .newWorktree, baseCwd: nil)

        XCTAssertEqual(store.sessions.count, before, "no session should be created when not a git repo")
        XCTAssertTrue(store.statusMessage.contains("not a git repository"))
    }

    // MARK: - Helpers

    private func makeTempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FB3Launch-\(UUID().uuidString)")
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
