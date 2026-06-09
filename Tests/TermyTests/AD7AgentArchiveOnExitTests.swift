import XCTest
@testable import Termy
import TermyCore

/// AD-7: archive-on-exit wiring in TermyStore — a finished agent session is
/// persisted to the local JSONL archive, with its worktree/cwd diff captured
/// BEFORE worktree cleanup, and non-agent sessions are not archived.
final class AD7AgentArchiveOnExitTests: XCTestCase {
    private var dirs: [URL] = []

    override func tearDown() {
        for d in dirs { try? FileManager.default.removeItem(at: d) }
        dirs = []; super.tearDown()
    }

    private func tempDir(_ tag: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("AD7-\(tag)-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        dirs.append(url); return url
    }

    @MainActor
    private func makeStore(archiveFile: URL, stateRoot: URL) -> TermyStore {
        TermyStore(
            startInitialPTY: false,
            agentStateRoot: stateRoot,
            agentHookHelperPath: "/tmp/termy-agent-hook.sh",
            agentArchiveStore: AgentArchiveStore(fileURL: archiveFile))
    }

    @discardableResult
    private func run(_ args: [String], in dir: URL) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = args
        p.currentDirectoryURL = dir
        p.standardOutput = nil; p.standardError = nil
        try? p.run(); p.waitUntilExit()
        return p.terminationStatus
    }

    /// A throwaway git repo with one committed file and one uncommitted change,
    /// so `git diff` is non-empty. Skips the test if git is unavailable.
    private func makeDirtyRepo() throws -> URL {
        let dir = tempDir("repo")
        guard run(["git", "init", "-q"], in: dir) == 0 else {
            throw XCTSkip("git unavailable")
        }
        _ = run(["git", "config", "user.email", "t@t.test"], in: dir)
        _ = run(["git", "config", "user.name", "t"], in: dir)
        let file = dir.appendingPathComponent("file.txt")
        try "one\n".write(to: file, atomically: true, encoding: .utf8)
        _ = run(["git", "add", "."], in: dir)
        _ = run(["git", "commit", "-q", "-m", "init"], in: dir)
        try "one\ntwo\n".write(to: file, atomically: true, encoding: .utf8)  // uncommitted
        return dir
    }

    @MainActor
    func testAgentExitArchivesSessionWithDiff() throws {
        let repo = try makeDirtyRepo()
        let archiveFile = tempDir("arch").appendingPathComponent("agent-archive.jsonl")
        let store = makeStore(archiveFile: archiveFile, stateRoot: tempDir("state"))
        store.sessions.removeAll()
        store.launchCLIAgent(.claudeCode, isolation: .here, baseCwd: repo.path)
        let id = try XCTUnwrap(store.sessions.last?.id)
        // PTY is not launched in tests; set the cwd the way registerTerminalLaunch would.
        let index = try XCTUnwrap(store.sessions.firstIndex { $0.id == id })
        store.sessions[index].currentWorkingDirectory = repo.path

        store.noteSessionProcessExited(exitCode: 0, for: id, generation: 0)

        let archived = store.archivedAgentSessions
        XCTAssertEqual(archived.count, 1)
        let record = try XCTUnwrap(archived.first)
        XCTAssertEqual(record.id, id.uuidString)
        XCTAssertEqual(record.agentType, .claudeCode)
        XCTAssertEqual(record.exitCode, 0)
        XCTAssertEqual(record.cwd, repo.path)
        XCTAssertTrue(record.diff.contains("+two"), "captured worktree diff should include the uncommitted change")
    }

    @MainActor
    func testDoubleExitArchivesOnce() throws {
        let archiveFile = tempDir("arch").appendingPathComponent("agent-archive.jsonl")
        let store = makeStore(archiveFile: archiveFile, stateRoot: tempDir("state"))
        store.sessions.removeAll()
        store.launchCLIAgent(.claudeCode, isolation: .here, baseCwd: tempDir("cwd").path)
        let id = try XCTUnwrap(store.sessions.last?.id)

        store.noteSessionProcessExited(exitCode: 1, for: id, generation: 0)
        store.noteSessionProcessExited(exitCode: 1, for: id, generation: 0)
        XCTAssertEqual(store.archivedAgentSessions.count, 1)
    }

    @MainActor
    func testNonAgentSessionIsNotArchived() throws {
        let archiveFile = tempDir("arch").appendingPathComponent("agent-archive.jsonl")
        let store = makeStore(archiveFile: archiveFile, stateRoot: tempDir("state"))
        store.sessions.removeAll()
        store.sessions.append(TermySession(title: "plain", profile: .local()))
        let id = try XCTUnwrap(store.sessions.last?.id)

        store.noteSessionProcessExited(exitCode: 0, for: id, generation: 0)
        XCTAssertTrue(store.archivedAgentSessions.isEmpty)
    }

    @MainActor
    func testArchivedRecordIsSyncStaged() throws {
        let archiveFile = tempDir("arch").appendingPathComponent("agent-archive.jsonl")
        let store = makeStore(archiveFile: archiveFile, stateRoot: tempDir("state"))
        store.sessions.removeAll()
        store.launchCLIAgent(.claudeCode, isolation: .here, baseCwd: tempDir("cwd").path)
        let id = try XCTUnwrap(store.sessions.last?.id)

        store.noteSessionProcessExited(exitCode: 0, for: id, generation: 0)
        // Archive metadata must be staged into the private-sync record set, with the
        // full diff EXCLUDED (local-only) — verifies the planner wiring end-to-end.
        let record = try XCTUnwrap(
            store.privateSyncRecords.first { $0.recordName == "agent-archive-\(id.uuidString)" })
        XCTAssertEqual(record.recordType, "AgentArchive")
        XCTAssertNil(record.fields["diff"])
        // D1: a real per-record edit stamp rides in modifiedAt (stamped at the
        // mutation, not at stage/adoption time).
        XCTAssertNotNil(record.fields["modifiedAt"])
    }
}
