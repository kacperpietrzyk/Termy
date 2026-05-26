import XCTest
@testable import Termy
import TermyCore

final class FB3AgentCommandCenterTests: XCTestCase {
    private var cleanupURLs: [URL] = []

    override func tearDown() {
        for url in cleanupURLs { try? FileManager.default.removeItem(at: url) }
        cleanupURLs = []
        super.tearDown()
    }

    func testCatalogExposesFourAgentActions() {
        let ids = Set(FeatureCatalog.termDefault.commandCenterActions.map(\.id))
        XCTAssertTrue(ids.isSuperset(of: [
            "run-claude-code-here",
            "run-claude-code-worktree",
            "run-codex-here",
            "run-codex-worktree"
        ]))
        let agentActions = FeatureCatalog.termDefault.commandCenterActions
            .filter { $0.id.hasPrefix("run-claude-code") || $0.id.hasPrefix("run-codex") }
        XCTAssertTrue(agentActions.allSatisfy { $0.area == .ai })
    }

    @MainActor
    func testPerformRunHereLaunchesAgent() {
        let store = TermyStore(startInitialPTY: false)
        store.perform("run-claude-code-here")
        XCTAssertEqual(store.sessions.last?.agentType, .claudeCode)
    }

    @MainActor
    func testPerformRunWorktreeLaunchesAgentInWorktree() throws {
        let repoURL = try makeTempGitRepo()
        let wtRoot = makeTempDir()
        let store = TermyStore(startInitialPTY: false, projectRoot: repoURL, agentWorktreeRoot: wtRoot)

        store.perform("run-codex-worktree")

        let session = try XCTUnwrap(store.sessions.last)
        XCTAssertEqual(session.agentType, .codex)
        let workingDirectory = try XCTUnwrap(store.terminalLaunchDescriptors[session.id]?.workingDirectory)
        XCTAssertTrue(workingDirectory.hasPrefix(wtRoot.path))
    }

    // MARK: - Helpers

    private func makeTempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FB3CC-\(UUID().uuidString)")
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
