import XCTest
@testable import TermyCore

final class AgentTranscriptUsageTests: XCTestCase {

    // MARK: - parse: context = LAST assistant turn's input + cache fields.

    func testParsesLastAssistantUsageNotASum() {
        // Two assistant turns. The LAST one's input + cache_creation + cache_read
        // is the context occupancy; we must NOT sum across turns (cache_read
        // re-counts the same context each turn).
        let transcript = """
        {"type":"user","message":{"role":"user","content":"hi"}}
        {"type":"assistant","message":{"role":"assistant","model":"claude-opus-4-7","usage":{"input_tokens":5,"cache_creation_input_tokens":1000,"cache_read_input_tokens":40000,"output_tokens":200}}}
        {"type":"user","message":{"role":"user","content":"more"}}
        {"type":"assistant","message":{"role":"assistant","model":"claude-opus-4-7","usage":{"input_tokens":1,"cache_creation_input_tokens":1295,"cache_read_input_tokens":56313,"output_tokens":189}}}
        """
        let usage = AgentTranscriptParser.parse(transcript)
        XCTAssertEqual(usage?.contextTokens, 1 + 1295 + 56313)   // 57609, last turn only
        XCTAssertEqual(usage?.model, "claude-opus-4-7")
        XCTAssertEqual(usage?.contextWindow, 200_000)
    }

    func testFractionFromWindow() {
        let transcript = """
        {"type":"assistant","message":{"role":"assistant","model":"claude-opus-4-7","usage":{"input_tokens":0,"cache_creation_input_tokens":0,"cache_read_input_tokens":100000,"output_tokens":10}}}
        """
        let usage = AgentTranscriptParser.parse(transcript)
        XCTAssertEqual(usage?.fraction ?? 0, 0.5, accuracy: 0.0001)   // 100k / 200k
    }

    func testFractionClampsToOne() {
        let transcript = """
        {"type":"assistant","message":{"role":"assistant","model":"claude-opus-4-7","usage":{"input_tokens":0,"cache_creation_input_tokens":0,"cache_read_input_tokens":250000,"output_tokens":10}}}
        """
        XCTAssertEqual(AgentTranscriptParser.parse(transcript)?.fraction, 1.0)
    }

    // MARK: - resilience.

    func testToleratesTrailingTruncatedLine() {
        // The transcript is written live; the last line may be a partial write.
        let transcript = """
        {"type":"assistant","message":{"role":"assistant","model":"claude-opus-4-7","usage":{"input_tokens":2,"cache_creation_input_tokens":100,"cache_read_input_tokens":5000,"output_tokens":50}}}
        {"type":"assistant","message":{"role":"assistant","model":"clau
        """
        let usage = AgentTranscriptParser.parse(transcript)
        XCTAssertEqual(usage?.contextTokens, 2 + 100 + 5000)   // skips truncated tail, uses prior turn
    }

    func testSkipsNonAssistantAndGarbageLines() {
        let transcript = """
        {"type":"assistant","message":{"role":"assistant","model":"claude-opus-4-7","usage":{"input_tokens":1,"cache_creation_input_tokens":10,"cache_read_input_tokens":90,"output_tokens":5}}}
        not json at all
        {"type":"ai-title","title":"something"}
        {"type":"user","message":{"role":"user","content":"q"}}
        """
        let usage = AgentTranscriptParser.parse(transcript)
        XCTAssertEqual(usage?.contextTokens, 1 + 10 + 90)
    }

    func testNoUsageReturnsNil() {
        let transcript = """
        {"type":"user","message":{"role":"user","content":"hi"}}
        {"type":"assistant","message":{"role":"assistant","model":"claude-opus-4-7"}}
        """
        XCTAssertNil(AgentTranscriptParser.parse(transcript))
    }

    func testEmptyTranscriptReturnsNil() {
        XCTAssertNil(AgentTranscriptParser.parse(""))
        XCTAssertNil(AgentTranscriptParser.parse("\n\n   \n"))
    }

    func testMissingCacheFieldsTreatedAsZero() {
        // A first turn may omit the cache fields entirely.
        let transcript = """
        {"type":"assistant","message":{"role":"assistant","model":"claude-opus-4-7","usage":{"input_tokens":1234,"output_tokens":50}}}
        """
        XCTAssertEqual(AgentTranscriptParser.parse(transcript)?.contextTokens, 1234)
    }

    // MARK: - model → window mapping (never-fabricate a denominator).

    func testUnknownModelHasNoWindowAndNoFraction() {
        let transcript = """
        {"type":"assistant","message":{"role":"assistant","model":"some-local-llm","usage":{"input_tokens":10,"cache_creation_input_tokens":0,"cache_read_input_tokens":90,"output_tokens":5}}}
        """
        let usage = AgentTranscriptParser.parse(transcript)
        XCTAssertEqual(usage?.contextTokens, 100)
        XCTAssertNil(usage?.contextWindow)    // unknown model → no denominator
        XCTAssertNil(usage?.fraction)         // → raw count, no percentage
    }

    func testMissingModelHasNoWindow() {
        let transcript = """
        {"type":"assistant","message":{"role":"assistant","usage":{"input_tokens":10,"cache_creation_input_tokens":0,"cache_read_input_tokens":90,"output_tokens":5}}}
        """
        let usage = AgentTranscriptParser.parse(transcript)
        XCTAssertEqual(usage?.contextTokens, 100)
        XCTAssertNil(usage?.model)
        XCTAssertNil(usage?.contextWindow)
    }

    func testKnownModelWindows() {
        // Real ids observed in ~/.claude/projects transcripts.
        XCTAssertEqual(AgentTranscriptParser.contextWindow(forModel: "claude-opus-4-7"), 200_000)
        XCTAssertEqual(AgentTranscriptParser.contextWindow(forModel: "claude-opus-4-8"), 200_000)
        XCTAssertEqual(AgentTranscriptParser.contextWindow(forModel: "claude-3-5-sonnet-20241022"), 200_000)
        // Bare family aliases also occur in real transcripts.
        XCTAssertEqual(AgentTranscriptParser.contextWindow(forModel: "opus"), 200_000)
        XCTAssertEqual(AgentTranscriptParser.contextWindow(forModel: "sonnet"), 200_000)
        XCTAssertEqual(AgentTranscriptParser.contextWindow(forModel: "haiku"), 200_000)
        // 1M is a hypothetical future id tag (request-time beta header today).
        XCTAssertEqual(AgentTranscriptParser.contextWindow(forModel: "claude-sonnet-4-5-1m"), 1_000_000)
        // The synthetic placeholder and non-Claude models → no denominator.
        XCTAssertNil(AgentTranscriptParser.contextWindow(forModel: "<synthetic>"))
        XCTAssertNil(AgentTranscriptParser.contextWindow(forModel: "gpt-4o"))
        XCTAssertNil(AgentTranscriptParser.contextWindow(forModel: nil))
        XCTAssertNil(AgentTranscriptParser.contextWindow(forModel: ""))
    }

    // MARK: - project-dir encoding (mirror CC's real scheme).

    func testEncodedProjectDirName() {
        XCTAssertEqual(
            AgentTranscriptLocator.encodedProjectDirName(forCwd: "/Users/kacper/Projects/Termy"),
            "-Users-kacper-Projects-Termy")
        // Leading dot ("/Users/kacper/.okta") → the slash AND the dot each map to "-".
        XCTAssertEqual(
            AgentTranscriptLocator.encodedProjectDirName(forCwd: "/Users/kacper/.okta"),
            "-Users-kacper--okta")
        // Dots in a path component, like com.apple.CloudDocs.
        XCTAssertEqual(
            AgentTranscriptLocator.encodedProjectDirName(forCwd: "/a/com.apple.x"),
            "-a-com-apple-x")
        // Non-ASCII (e.g. Poznań) munges to "-" too.
        XCTAssertEqual(
            AgentTranscriptLocator.encodedProjectDirName(forCwd: "/x/Poznań"),
            "-x-Pozna-")
    }

    // MARK: - locate + tail-read against a temp projects root.

    func testNewestTranscriptPicksMostRecent() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let cwd = "/Users/test/Proj"
        let dir = root.appendingPathComponent(
            AgentTranscriptLocator.encodedProjectDirName(forCwd: cwd))
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let older = dir.appendingPathComponent("older.jsonl")
        let newer = dir.appendingPathComponent("newer.jsonl")
        try "old".write(to: older, atomically: true, encoding: .utf8)
        try "new".write(to: newer, atomically: true, encoding: .utf8)
        // Force a deterministic ordering on modification date.
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 1_000)], ofItemAtPath: older.path)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 2_000)], ofItemAtPath: newer.path)

        let found = AgentTranscriptLocator.newestTranscript(forCwd: cwd, projectsRoot: root)
        XCTAssertEqual(found?.lastPathComponent, "newer.jsonl")
    }

    func testNewestTranscriptNilWhenDirAbsent() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertNil(AgentTranscriptLocator.newestTranscript(forCwd: "/nope/here", projectsRoot: root))
    }

    func testTailReadEndToEnd() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("t.jsonl")
        let line = #"{"type":"assistant","message":{"role":"assistant","model":"claude-opus-4-7","usage":{"input_tokens":3,"cache_creation_input_tokens":7,"cache_read_input_tokens":90,"output_tokens":1}}}"#
        try (String(repeating: "x\n", count: 100) + line + "\n").write(
            to: url, atomically: true, encoding: .utf8)
        let tail = AgentTranscriptLocator.tailRead(url, maxBytes: 4096)
        XCTAssertNotNil(tail)
        XCTAssertEqual(AgentTranscriptParser.parse(tail ?? "")?.contextTokens, 100)
    }

    private func makeTempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ad6-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
