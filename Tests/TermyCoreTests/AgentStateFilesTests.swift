import XCTest
@testable import TermyCore

final class AgentStateFilesTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("AgentState-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func writeState(_ id: UUID, _ keyword: String) throws {
        try keyword.write(to: dir.appendingPathComponent("\(id.uuidString).state"),
                          atomically: true, encoding: .utf8)
    }

    func testConsumeReturnsSignalsAndDeletesFiles() throws {
        let a = UUID(), b = UUID()
        try writeState(a, "waiting")
        try writeState(b, "working\n")   // trailing newline must be tolerated

        let result = AgentStateFiles.consume(in: dir)
        XCTAssertEqual(Set(result.map { $0.sessionID }), [a, b])
        XCTAssertEqual(result.first { $0.sessionID == a }?.signal, .waiting)
        XCTAssertEqual(result.first { $0.sessionID == b }?.signal, .active)

        // Consume-once: files are gone, a second consume yields nothing.
        XCTAssertTrue(AgentStateFiles.consume(in: dir).isEmpty)
    }

    func testConsumeIgnoresNonStateAndBadNames() throws {
        try "x".write(to: dir.appendingPathComponent("not-a-uuid.state"),
                      atomically: true, encoding: .utf8)
        try "y".write(to: dir.appendingPathComponent("\(UUID().uuidString).txt"),
                      atomically: true, encoding: .utf8)
        XCTAssertTrue(AgentStateFiles.consume(in: dir).isEmpty)
    }

    func testConsumeDeletesUUIDFileWithUnknownKeyword() throws {
        let id = UUID()
        try writeState(id, "crashed")   // valid name, unrecognized keyword

        // Unknown keyword → no signal, but consume-once still removes the file.
        XCTAssertTrue(AgentStateFiles.consume(in: dir).isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: dir.appendingPathComponent("\(id.uuidString).state").path))
    }

    func testSweepRemovesOrphansKeepsLive() throws {
        let live = UUID(), orphan = UUID()
        try writeState(live, "waiting")
        try writeState(orphan, "waiting")

        AgentStateFiles.sweepOrphans(in: dir, keeping: [live])

        XCTAssertTrue(FileManager.default.fileExists(
            atPath: dir.appendingPathComponent("\(live.uuidString).state").path))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: dir.appendingPathComponent("\(orphan.uuidString).state").path))
    }
}
