import XCTest
@testable import Termy
import TermyCore

final class FB34AgentVitalsStoreTests: XCTestCase {
    func testNewSessionStampsStartedAndStateChanged() {
        let before = Date()
        let session = TermySession(title: "t", profile: ConnectionProfile.local())
        XCTAssertGreaterThanOrEqual(session.startedAt, before)
        XCTAssertGreaterThanOrEqual(session.stateChangedAt, before)
    }

    @MainActor
    func testRefreshPopulatesGitCacheForRepoCwd() async throws {
        let repo = try makeTempGitRepo()
        let model = AgentsModel()
        let id = UUID()
        let snapshot = AgentVitalsSnapshot(
            id: id, name: "a", agentType: .claudeCode, state: .working,
            cwd: repo.path, isolation: .here, startedAt: Date(), stateChangedAt: Date())

        await model.deriveAndStore(snapshots: [snapshot])

        XCTAssertEqual(model.gitCache[id]?.branch, "main")
    }

    @MainActor
    func testRefreshPrunesVanishedSessions() async throws {
        let repo = try makeTempGitRepo()
        let model = AgentsModel()
        let id = UUID()
        let snapshot = AgentVitalsSnapshot(
            id: id, name: "a", agentType: .claudeCode, state: .working,
            cwd: repo.path, isolation: .here, startedAt: Date(), stateChangedAt: Date())
        await model.deriveAndStore(snapshots: [snapshot])
        XCTAssertNotNil(model.gitCache[id])

        await model.deriveAndStore(snapshots: [])

        XCTAssertNil(model.gitCache[id])
    }

    private var cleanupURLs: [URL] = []
    override func tearDown() {
        for url in cleanupURLs { try? FileManager.default.removeItem(at: url) }
        cleanupURLs = []
        super.tearDown()
    }
    private func makeTempDir() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("FB34-\(UUID().uuidString)")
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
    func testAgentSessionCommandItemFields() {
        let id = UUID()
        let vitals = AgentSessionVitals(
            id: id, name: "auth-refactor", agentType: .claudeCode, state: .waitingForInput,
            cwd: "/repo", branch: "agent/auth", dirtyCount: 3, ahead: 0, behind: 0,
            isolation: .here, ports: [], startedAt: Date(), stateChangedAt: Date())
        let item = CommandCenterItem.agentSession(vitals)

        XCTAssertEqual(item.id, "agent-\(id.uuidString)")
        XCTAssertEqual(item.title, "auth-refactor")
        XCTAssertEqual(item.subtitle, "Waiting for input · agent/auth · ●3 dirty")
        XCTAssertEqual(item.area, .ai)
        XCTAssertNil(item.shortcut)
    }

    @MainActor
    func testAgentSessionsAppearInCommandCenterWaitingFirst() {
        let store = TermyStore(startInitialPTY: false)
        store.sessions.removeAll()   // drop the initial local shell seed
        store.perform("run-claude-code-here")
        store.perform("run-codex-here")
        XCTAssertEqual(store.sessions.count, 2)

        store.sessions[0].agentActivity = .working
        store.sessions[1].agentActivity = .waitingForInput

        let agentItems = store.filteredCommandCenterItems.compactMap { item -> AgentSessionVitals? in
            if case .agentSession(let v) = item { return v } else { return nil }
        }
        XCTAssertEqual(agentItems.count, 2)
        XCTAssertEqual(agentItems.first?.state, .waitingForInput)  // waiting-first
    }

    @MainActor
    func testNonAgentSessionsDoNotAppearAsAgentItems() {
        let store = TermyStore(startInitialPTY: false)
        store.sessions.append(TermySession(title: "plain", profile: .local()))
        let agentItems = store.filteredCommandCenterItems.filter {
            if case .agentSession = $0 { return true } else { return false }
        }
        XCTAssertTrue(agentItems.isEmpty)
    }

    @MainActor
    func testPerformAgentItemFocusesSession() {
        let store = TermyStore(startInitialPTY: false)
        store.perform("run-claude-code-here")
        let id = try! XCTUnwrap(store.sessions.last?.id)
        let vitals = try! XCTUnwrap(store.agentVitals.first { $0.id == id })

        store.performCommandCenterItem(.agentSession(vitals))

        XCTAssertEqual(store.selectedSessionID, id)
    }

    @discardableResult
    private func runGit(_ args: [String], in dir: URL) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = dir
        process.standardOutput = Pipe(); process.standardError = Pipe()
        try? process.run(); process.waitUntilExit()
        return process.terminationStatus
    }
}
