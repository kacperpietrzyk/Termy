import XCTest
@testable import Termy
import TermyCore

final class FB32AgentStateTests: XCTestCase {
    private var cleanupURLs: [URL] = []

    override func tearDown() {
        for url in cleanupURLs { try? FileManager.default.removeItem(at: url) }
        cleanupURLs = []
        super.tearDown()
    }

    private func makeTempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FB32-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        cleanupURLs.append(url)
        return url
    }

    @MainActor
    func testInitSweepsOrphanStateFiles() throws {
        let stateRoot = makeTempDir()
        let orphan = stateRoot.appendingPathComponent("\(UUID().uuidString).state")
        try "waiting".write(to: orphan, atomically: true, encoding: .utf8)

        _ = TermyStore(startInitialPTY: false, agentStateRoot: stateRoot)

        XCTAssertFalse(FileManager.default.fileExists(atPath: orphan.path),
                       "init must sweep orphan agent-state files")
    }

    @MainActor
    func testClaudeCodeLaunchInjectsSettingsAndStartsWorking() throws {
        let store = TermyStore(startInitialPTY: false,
                               agentStateRoot: makeTempDir(),
                               agentHookHelperPath: "/tmp/termy-agent-hook.sh")
        store.launchCLIAgent(.claudeCode, isolation: .here, baseCwd: "/tmp/cc")

        let session = try XCTUnwrap(store.sessions.last)
        XCTAssertEqual(session.agentActivity, .working)
        let args = try XCTUnwrap(store.terminalLaunchDescriptors[session.id]?.arguments)
        XCTAssertTrue(args.contains("--settings"))
        XCTAssertTrue(args.contains { $0.contains(session.id.uuidString) })
    }

    @MainActor
    func testCodexLaunchHasNoSettingsButStillTracksState() throws {
        let store = TermyStore(startInitialPTY: false,
                               agentStateRoot: makeTempDir(),
                               agentHookHelperPath: "/tmp/termy-agent-hook.sh")
        store.launchCLIAgent(.codex, isolation: .here, baseCwd: "/tmp/cx")

        let session = try XCTUnwrap(store.sessions.last)
        let args = store.terminalLaunchDescriptors[session.id]?.arguments ?? []
        XCTAssertFalse(args.contains("--settings"))
        XCTAssertEqual(session.agentActivity, .working)
    }

    @MainActor
    func testStateTransitions() throws {
        let store = TermyStore(startInitialPTY: false,
                               agentStateRoot: makeTempDir(),
                               agentHookHelperPath: "/tmp/termy-agent-hook.sh")
        store.launchCLIAgent(.claudeCode, isolation: .here, baseCwd: "/tmp/cc")
        let id = try XCTUnwrap(store.sessions.last?.id)

        store.agentQuiescenceFired(for: id)
        XCTAssertEqual(store.sessions.last?.agentActivity, .idle)

        store.applyAgentHookSignal(.waiting, for: id)
        XCTAssertEqual(store.sessions.last?.agentActivity, .waitingForInput)

        store.agentQuiescenceFired(for: id)   // must NOT demote a hook waiting
        XCTAssertEqual(store.sessions.last?.agentActivity, .waitingForInput)

        store.noteAgentActivity(for: id)
        XCTAssertEqual(store.sessions.last?.agentActivity, .working)

        store.noteSessionProcessExited(exitCode: 0, for: id)
        XCTAssertEqual(store.sessions.last?.agentActivity, .exited)

        store.noteAgentActivity(for: id)      // terminal — stays exited
        XCTAssertEqual(store.sessions.last?.agentActivity, .exited)
    }

    @MainActor
    func testIngestShellIntegrationFeedsActivityTickForAgentSessions() throws {
        // Pins the load-bearing wiring: the byte-tap (ingestShellIntegrationEvents
        // → applyShellIntegration) must feed an activity tick for agent sessions.
        // This is the entire passive baseline (the only layer Codex gets).
        let store = TermyStore(startInitialPTY: false,
                               agentStateRoot: makeTempDir(),
                               agentHookHelperPath: "/tmp/termy-agent-hook.sh")
        store.launchCLIAgent(.claudeCode, isolation: .here, baseCwd: "/tmp/cc")
        let id = try XCTUnwrap(store.sessions.last?.id)

        store.applyAgentHookSignal(.waiting, for: id)
        XCTAssertEqual(store.sessions.last?.agentActivity, .waitingForInput)

        // A byte-tap event must flip it back to .working (verifies the insertion
        // fires and the `agentType != nil` guard is correct).
        store.ingestShellIntegrationEvents([.output("hello")], for: id)
        XCTAssertEqual(store.sessions.last?.agentActivity, .working)
    }
}
