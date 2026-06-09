import XCTest
@testable import Termy
import TermyCore

/// AD-4: `TermyStore.sendSteeringInstruction` routes a composed review into the
/// live agent PTY via the registered input sink — mirrors the FB36 lifecycle test
/// harness (no real process; a captured sink stands in for the PTY).
final class AgentSteeringStoreTests: XCTestCase {
    private var dirs: [URL] = []
    override func tearDown() {
        for d in dirs { try? FileManager.default.removeItem(at: d) }
        dirs = []; super.tearDown()
    }
    private func tempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ADSteer-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        dirs.append(url); return url
    }

    @MainActor
    private func makeAgentStore() -> (TermyStore, UUID) {
        let store = TermyStore(startInitialPTY: false,
                               agentStateRoot: tempDir(),
                               agentHookHelperPath: "/tmp/termy-agent-hook.sh")
        store.sessions.removeAll()
        store.launchCLIAgent(.claudeCode, isolation: .here, baseCwd: "/tmp/cc")
        return (store, store.sessions.last!.id)
    }

    @MainActor
    func testSteeringSendsComposedLineWithCarriageReturn() throws {
        let (store, id) = makeAgentStore()
        var sent: [String] = []
        store.registerTerminalInputSink({ sent.append($0) }, for: id)

        let ok = store.sendSteeringInstruction([
            AgentSteering.Comment(filePath: "Foo.swift", body: "rename this"),
            AgentSteering.Comment(filePath: "Bar.swift", body: "handle nil"),
        ], to: id)

        XCTAssertTrue(ok)
        XCTAssertEqual(sent.count, 1)
        let line = try XCTUnwrap(sent.first)
        XCTAssertTrue(line.hasSuffix("\r"))
        XCTAssertTrue(line.contains("Foo.swift: rename this"))
        XCTAssertTrue(line.contains("Bar.swift: handle nil"))
        // A multi-comment steer must arrive as exactly ONE line (one \r), never
        // partial turns.
        XCTAssertEqual(line.filter { $0 == "\r" }.count, 1)
        XCTAssertFalse(line.dropLast().contains("\n"))
    }

    @MainActor
    func testSteeringNoOpsWhenAgentExited() throws {
        let (store, id) = makeAgentStore()
        store.noteSessionProcessExited(exitCode: 0, for: id)
        XCTAssertEqual(store.sessions.first { $0.id == id }?.agentActivity, .exited)

        var sent: [String] = []
        store.registerTerminalInputSink({ sent.append($0) }, for: id)

        let ok = store.sendSteeringInstruction(
            [AgentSteering.Comment(filePath: "Foo.swift", body: "do this")], to: id)

        XCTAssertFalse(ok)
        XCTAssertTrue(sent.isEmpty)
    }

    @MainActor
    func testSteeringNoOpsForEmptyComposition() throws {
        let (store, id) = makeAgentStore()
        var sent: [String] = []
        store.registerTerminalInputSink({ sent.append($0) }, for: id)

        let ok = store.sendSteeringInstruction(
            [AgentSteering.Comment(filePath: "Foo.swift", body: "   ")], to: id)

        XCTAssertFalse(ok)
        XCTAssertTrue(sent.isEmpty)
    }

    @MainActor
    func testSteeringNoOpsForNonAgentSession() throws {
        let store = TermyStore(startInitialPTY: false)
        store.sessions.removeAll()
        store.sessions.append(TermySession(title: "plain", profile: .local()))
        let id = try XCTUnwrap(store.sessions.last?.id)
        var sent: [String] = []
        store.registerTerminalInputSink({ sent.append($0) }, for: id)

        let ok = store.sendSteeringInstruction(
            [AgentSteering.Comment(filePath: "Foo.swift", body: "do this")], to: id)

        XCTAssertFalse(ok)
        XCTAssertTrue(sent.isEmpty)
    }
}
