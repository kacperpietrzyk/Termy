import XCTest
@testable import Termy
import TermyCore

final class FB36AgentLifecycleTests: XCTestCase {
    private var dirs: [URL] = []
    override func tearDown() {
        for d in dirs { try? FileManager.default.removeItem(at: d) }
        dirs = []; super.tearDown()
    }
    private func tempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FB36-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        dirs.append(url); return url
    }

    @MainActor
    func testStaleGenerationExitIsIgnored() throws {
        let store = TermyStore(startInitialPTY: false,
                               agentStateRoot: tempDir(),
                               agentHookHelperPath: "/tmp/termy-agent-hook.sh")
        store.sessions.removeAll()
        store.launchCLIAgent(.claudeCode, isolation: .here, baseCwd: "/tmp/cc")
        let id = try XCTUnwrap(store.sessions.last?.id)

        store.bumpTerminalLaunchGeneration(for: id)   // current generation -> 1

        // Exit reported for the superseded generation 0 -> must be ignored.
        store.noteSessionProcessExited(exitCode: 0, for: id, generation: 0)
        XCTAssertNotEqual(store.sessions.first { $0.id == id }?.agentActivity, .exited)

        // Exit for the current generation 1 -> handled normally.
        store.noteSessionProcessExited(exitCode: 0, for: id, generation: 1)
        XCTAssertEqual(store.sessions.first { $0.id == id }?.agentActivity, .exited)
    }

    @MainActor
    func testInterruptAgentSendsCtrlCToRegisteredSink() throws {
        let store = TermyStore(startInitialPTY: false,
                               agentStateRoot: tempDir(),
                               agentHookHelperPath: "/tmp/termy-agent-hook.sh")
        store.sessions.removeAll()
        store.launchCLIAgent(.claudeCode, isolation: .here, baseCwd: "/tmp/cc")
        let id = try XCTUnwrap(store.sessions.last?.id)

        var sent: [String] = []
        store.registerTerminalInputSink({ sent.append($0) }, for: id)

        store.interruptAgent(sessionID: id)
        XCTAssertEqual(sent, ["\u{03}"])
    }

    @MainActor
    func testInterruptAgentNoOpsForNonAgentSession() throws {
        let store = TermyStore(startInitialPTY: false)
        store.sessions.removeAll()
        store.sessions.append(TermySession(title: "plain", profile: .local()))
        let id = try XCTUnwrap(store.sessions.last?.id)

        var sent: [String] = []
        store.registerTerminalInputSink({ sent.append($0) }, for: id)

        store.interruptAgent(sessionID: id)   // not an agent -> ignored
        XCTAssertTrue(sent.isEmpty)
    }

    @MainActor
    func testRestartAgentResetsStateProgressFilesAndBumpsGeneration() throws {
        let root = tempDir()
        let store = TermyStore(startInitialPTY: false,
                               agentStateRoot: root,
                               agentHookHelperPath: "/tmp/termy-agent-hook.sh")
        store.sessions.removeAll()
        store.launchCLIAgent(.claudeCode, isolation: .here, baseCwd: "/tmp/cc")
        let id = try XCTUnwrap(store.sessions.last?.id)

        // Seed folded progress (consumed) + a pending unconsumed tool file + a state file.
        let createURL = root.appendingPathComponent("\(id.uuidString).1.1.tool.json")
        try #"{"tool_name":"Edit","tool_input":{"file_path":"/tmp/cc/A.swift"}}"#
            .write(to: createURL, atomically: true, encoding: .utf8)
        store.consumeAgentProgressFiles()
        XCTAssertEqual(store.agentVitals.first { $0.id == id }?.touched, ["/tmp/cc/A.swift"])

        let pendingURL = root.appendingPathComponent("\(id.uuidString).2.2.tool.json")
        try #"{"tool_name":"Edit","tool_input":{"file_path":"/tmp/cc/B.swift"}}"#
            .write(to: pendingURL, atomically: true, encoding: .utf8)
        let stateURL = root.appendingPathComponent("\(id.uuidString).state")
        try "waiting".write(to: stateURL, atomically: true, encoding: .utf8)

        let gen0 = store.terminalLaunchGeneration(for: id)

        store.restartAgent(sessionID: id)

        XCTAssertEqual(store.terminalLaunchGeneration(for: id), gen0 + 1)            // re-spawn
        XCTAssertEqual(store.sessions.first { $0.id == id }?.agentActivity, .working) // fresh
        XCTAssertTrue(store.agentVitals.first { $0.id == id }?.touched.isEmpty == true) // progress wiped
        XCTAssertTrue(store.agentVitals.first { $0.id == id }?.plan.isEmpty == true)
        XCTAssertFalse(FileManager.default.fileExists(atPath: stateURL.path))         // .state purged
        XCTAssertFalse(FileManager.default.fileExists(atPath: pendingURL.path))       // .tool.json purged
        XCTAssertNotNil(store.sessions.first { $0.id == id })                          // session kept
    }

    @MainActor
    func testRestartAgentNoOpsForExitedAgent() throws {
        let store = TermyStore(startInitialPTY: false,
                               agentStateRoot: tempDir(),
                               agentHookHelperPath: "/tmp/termy-agent-hook.sh")
        store.sessions.removeAll()
        store.launchCLIAgent(.claudeCode, isolation: .here, baseCwd: "/tmp/cc")
        let id = try XCTUnwrap(store.sessions.last?.id)
        store.noteSessionProcessExited(exitCode: 0, for: id)   // -> .exited
        let gen0 = store.terminalLaunchGeneration(for: id)

        store.restartAgent(sessionID: id)   // exited -> ignored

        XCTAssertEqual(store.terminalLaunchGeneration(for: id), gen0)
        XCTAssertEqual(store.sessions.first { $0.id == id }?.agentActivity, .exited)
    }

    @MainActor
    func testCatalogExposesLifecycleActions() {
        let ids = Set(FeatureCatalog.termDefault.commandCenterActions.map(\.id))
        XCTAssertTrue(ids.isSuperset(of: ["interrupt-agent", "restart-agent"]))
    }

    @MainActor
    func testLifecycleActionsGatedToLiveAgent() throws {
        let store = TermyStore(startInitialPTY: false,
                               agentStateRoot: tempDir(),
                               agentHookHelperPath: "/tmp/termy-agent-hook.sh")
        store.sessions.removeAll()
        store.commandQuery = ""

        // Non-agent session selected -> hidden.
        let plain = TermySession(title: "plain", profile: .local())
        store.sessions.append(plain)
        store.selectedSessionID = plain.id
        var ids = Set(store.filteredActions.map(\.id))
        XCTAssertFalse(ids.contains("interrupt-agent"))
        XCTAssertFalse(ids.contains("restart-agent"))

        // Live agent selected -> shown.
        store.launchCLIAgent(.claudeCode, isolation: .here, baseCwd: "/tmp/cc")
        let id = try XCTUnwrap(store.sessions.last?.id)
        ids = Set(store.filteredActions.map(\.id))
        XCTAssertTrue(ids.contains("interrupt-agent"))
        XCTAssertTrue(ids.contains("restart-agent"))

        // Exited agent -> hidden again.
        store.noteSessionProcessExited(exitCode: 0, for: id)
        ids = Set(store.filteredActions.map(\.id))
        XCTAssertFalse(ids.contains("interrupt-agent"))
        XCTAssertFalse(ids.contains("restart-agent"))
    }

    @MainActor
    func testPerformInterruptDispatchesToSelectedAgent() throws {
        let store = TermyStore(startInitialPTY: false,
                               agentStateRoot: tempDir(),
                               agentHookHelperPath: "/tmp/termy-agent-hook.sh")
        store.sessions.removeAll()
        store.launchCLIAgent(.claudeCode, isolation: .here, baseCwd: "/tmp/cc")
        let id = try XCTUnwrap(store.sessions.last?.id)   // launch selects it
        var sent: [String] = []
        store.registerTerminalInputSink({ sent.append($0) }, for: id)

        store.perform("interrupt-agent")
        XCTAssertEqual(sent, ["\u{03}"])
    }

    @MainActor
    func testPerformRestartDispatchesToSelectedAgent() throws {
        let store = TermyStore(startInitialPTY: false,
                               agentStateRoot: tempDir(),
                               agentHookHelperPath: "/tmp/termy-agent-hook.sh")
        store.sessions.removeAll()
        store.launchCLIAgent(.claudeCode, isolation: .here, baseCwd: "/tmp/cc")
        let id = try XCTUnwrap(store.sessions.last?.id)
        let gen0 = store.terminalLaunchGeneration(for: id)

        store.perform("restart-agent")
        XCTAssertEqual(store.terminalLaunchGeneration(for: id), gen0 + 1)
    }
}
