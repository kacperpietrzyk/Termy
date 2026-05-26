import XCTest
@testable import Termy
import TermyCore

final class FB35AgentProgressStoreTests: XCTestCase {
    private var dirs: [URL] = []
    override func tearDown() {
        for d in dirs { try? FileManager.default.removeItem(at: d) }
        dirs = []; super.tearDown()
    }
    private func tempDir() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("FB35-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        dirs.append(url); return url
    }
    private func writeTool(_ id: UUID, seq: Int, dir: URL, json: String) throws {
        let url = dir.appendingPathComponent("\(id.uuidString).\(seq).\(seq).tool.json")
        try json.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 1000 + Double(seq))],
            ofItemAtPath: url.path)
    }

    @MainActor
    func testConsumeFoldsPlanAndTouchedIntoSnapshot() throws {
        let root = tempDir()
        let store = TermyStore(startInitialPTY: false,
                               agentStateRoot: root,
                               agentHookHelperPath: "/tmp/termy-agent-hook.sh")
        store.sessions.removeAll()
        store.launchCLIAgent(.claudeCode, isolation: .here, baseCwd: "/tmp/cc")
        let id = try XCTUnwrap(store.sessions.last?.id)

        try writeTool(id, seq: 1, dir: root,
            json: #"{"tool_name":"TaskCreate","tool_input":{"subject":"A"},"tool_response":{"task":{"id":"t1"}}}"#)
        try writeTool(id, seq: 2, dir: root,
            json: #"{"tool_name":"TaskUpdate","tool_input":{"taskId":"t1","status":"in_progress"}}"#)
        try writeTool(id, seq: 3, dir: root,
            json: #"{"tool_name":"Edit","tool_input":{"file_path":"/tmp/cc/A.swift"}}"#)

        store.consumeAgentProgressFiles()

        let vitals = try XCTUnwrap(store.agentVitals.first { $0.id == id })
        XCTAssertEqual(vitals.plan.map(\.text), ["A"])
        XCTAssertEqual(vitals.plan.first?.state, .active)
        XCTAssertEqual(vitals.touched, ["/tmp/cc/A.swift"])
    }

    @MainActor
    func testProgressForNonLiveSessionIsDropped() throws {
        let root = tempDir()
        let store = TermyStore(startInitialPTY: false,
                               agentStateRoot: root,
                               agentHookHelperPath: "/tmp/termy-agent-hook.sh")
        store.sessions.removeAll()
        let ghost = UUID()
        try writeTool(ghost, seq: 1, dir: root,
            json: #"{"tool_name":"Edit","tool_input":{"file_path":"/x"}}"#)

        store.consumeAgentProgressFiles()   // no live session with that id

        XCTAssertTrue(store.agentVitals.allSatisfy { $0.touched.isEmpty })
        // File still consumed (deleted), even though no session matched.
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: root.appendingPathComponent("\(ghost.uuidString).1.1.tool.json").path))
    }

    @MainActor
    func testClosingAgentSessionClearsProgress() throws {
        let root = tempDir()
        let store = TermyStore(startInitialPTY: false,
                               agentStateRoot: root,
                               agentHookHelperPath: "/tmp/termy-agent-hook.sh")
        store.sessions.removeAll()
        store.launchCLIAgent(.claudeCode, isolation: .here, baseCwd: "/tmp/cc")
        let id = try XCTUnwrap(store.sessions.last?.id)
        try writeTool(id, seq: 1, dir: root,
            json: #"{"tool_name":"Edit","tool_input":{"file_path":"/tmp/cc/A.swift"}}"#)
        store.consumeAgentProgressFiles()
        XCTAssertEqual(store.agentVitals.first { $0.id == id }?.touched, ["/tmp/cc/A.swift"])

        store.closeSession(sessionID: id)

        XCTAssertNil(store.agentVitals.first { $0.id == id })
    }
}
