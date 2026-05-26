import XCTest
@testable import TermyCore

final class AgentProgressFilesTests: XCTestCase {
    private var dir: URL!
    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("AgentProgress-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    // Writes a .tool.json file and bumps its mtime so ordering is deterministic.
    private func writeTool(_ id: UUID, seq: Int, json: String) throws {
        let url = dir.appendingPathComponent("\(id.uuidString).\(seq).\(seq).tool.json")
        try json.write(to: url, atomically: true, encoding: .utf8)
        let when = Date(timeIntervalSince1970: 1000 + Double(seq))
        try FileManager.default.setAttributes([.modificationDate: when], ofItemAtPath: url.path)
    }

    func testConsumeReturnsEventsInMtimeOrderAndDeletes() throws {
        let id = UUID()
        try writeTool(id, seq: 2, json: #"{"tool_name":"TaskUpdate","tool_input":{"taskId":"t1","status":"completed"}}"#)
        try writeTool(id, seq: 1, json: #"{"tool_name":"TaskCreate","tool_input":{"subject":"A"},"tool_response":{"task":{"id":"t1"}}}"#)

        let events = AgentProgressFiles.consume(in: dir)

        XCTAssertEqual(events.map { $0.event.toolName }, ["TaskCreate", "TaskUpdate"])  // mtime order
        XCTAssertEqual(events.map { $0.sessionID }, [id, id])
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: dir.path).isEmpty)  // consumed
    }

    func testConsumeDeletesUndecodableFileButYieldsNoEvent() throws {
        let id = UUID()
        try writeTool(id, seq: 1, json: "not json")
        let events = AgentProgressFiles.consume(in: dir)
        XCTAssertTrue(events.isEmpty)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: dir.path).isEmpty)
    }

    func testConsumeIgnoresNonUuidAndNonToolFiles() throws {
        try "x".write(to: dir.appendingPathComponent("notes.tool.json"), atomically: true, encoding: .utf8)
        try "x".write(to: dir.appendingPathComponent("\(UUID().uuidString).state"), atomically: true, encoding: .utf8)
        let events = AgentProgressFiles.consume(in: dir)
        XCTAssertTrue(events.isEmpty)
        // The .state file and the bad-name .tool.json are left untouched.
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: dir.path).count, 2)
    }

    func testSweepOrphansRemovesNonLiveOnly() throws {
        let live = UUID(); let dead = UUID()
        try writeTool(live, seq: 1, json: #"{"tool_name":"Edit","tool_input":{"file_path":"/a"}}"#)
        try writeTool(dead, seq: 1, json: #"{"tool_name":"Edit","tool_input":{"file_path":"/b"}}"#)
        AgentProgressFiles.sweepOrphans(in: dir, keeping: [live])
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        XCTAssertTrue(names.contains { $0.hasPrefix(live.uuidString) })
        XCTAssertFalse(names.contains { $0.hasPrefix(dead.uuidString) })
    }

    func testRemoveAllForSessionRemovesOnlyThatSession() throws {
        let keep = UUID(); let drop = UUID()
        try writeTool(keep, seq: 1, json: #"{"tool_name":"Edit","tool_input":{"file_path":"/a"}}"#)
        try writeTool(drop, seq: 1, json: #"{"tool_name":"Edit","tool_input":{"file_path":"/b"}}"#)
        try writeTool(drop, seq: 2, json: #"{"tool_name":"Edit","tool_input":{"file_path":"/c"}}"#)

        AgentProgressFiles.removeAll(forSession: drop, in: dir)

        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        XCTAssertTrue(names.contains { $0.hasPrefix(keep.uuidString) })
        XCTAssertFalse(names.contains { $0.hasPrefix(drop.uuidString) })
    }
}
