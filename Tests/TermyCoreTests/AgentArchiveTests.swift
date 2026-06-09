import XCTest
@testable import TermyCore
import TermySync

@MainActor
final class AgentArchiveTests: XCTestCase {
    private var tempDir: URL!
    private var fileURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("AD7Archive-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        fileURL = tempDir.appendingPathComponent("agent-archive.jsonl")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
        try await super.tearDown()
    }

    private func makeStore(cap: Int = 500) -> AgentArchiveStore {
        AgentArchiveStore(fileURL: fileURL, cap: cap)
    }

    private func sampleRecord(
        id: UUID = UUID(),
        name: String = "Fix the parser",
        archivedAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
        diff: String = "diff --git a/x b/x\n@@ -1 +1 @@\n-old\n+new\n"
    ) -> AgentArchiveRecord {
        AgentArchiveRecord(
            id: id, name: name, agentType: .claudeCode, finalState: .exited,
            cwd: "/work/repo", branch: "feature/x",
            worktreePath: "/work/.worktrees/x",
            startedAt: Date(timeIntervalSince1970: 1_699_999_000),
            archivedAt: archivedAt, exitCode: 0,
            plan: [
                AgentPlanStep(id: "1", text: "Read parser", state: .done, sub: nil),
                AgentPlanStep(id: "2", text: "Patch it", state: .active, sub: "Patching it")
            ],
            touched: ["Sources/Parser.swift", "Tests/ParserTests.swift"],
            diff: diff)
    }

    // MARK: - model

    func test_typedAccessors_fromRaw() {
        let r = sampleRecord()
        XCTAssertEqual(r.agentType, .claudeCode)
        XCTAssertEqual(r.finalState, .exited)
        XCTAssertEqual(r.agentTypeRaw, "claudeCode")
        XCTAssertEqual(r.finalStateRaw, "exited")
    }

    func test_unknownRawValues_degradeGracefully() {
        let r = AgentArchiveRecord(
            id: "abc", name: "x", agentTypeRaw: "martian", finalStateRaw: "unknown",
            cwd: nil, branch: nil, worktreePath: nil,
            startedAt: Date(), archivedAt: Date(), exitCode: nil,
            plan: [], touched: [], diff: "")
        XCTAssertEqual(r.agentType, .claudeCode)   // forward-compat default
        XCTAssertEqual(r.finalState, .exited)
    }

    func test_planStepFlattening() {
        let r = sampleRecord()
        XCTAssertEqual(r.plan.map(\.state), ["done", "active"])
        XCTAssertEqual(r.plan[1].sub, "Patching it")
    }

    func test_codableRoundTrip() throws {
        let r = sampleRecord()
        let data = try JSONEncoder.agentArchive.encode(r)
        let decoded = try JSONDecoder.agentArchive.decode(AgentArchiveRecord.self, from: data)
        XCTAssertEqual(decoded, r)
    }

    // MARK: - store persistence (mirrors HistoryStore)

    func test_archiveAndRead() {
        let store = makeStore()
        let r = sampleRecord()
        store.archive(r)
        XCTAssertEqual(store.record(id: r.id), r)
        XCTAssertEqual(store.allRecords(), [r])
    }

    func test_allRecords_newestArchivedFirst() {
        let store = makeStore()
        let older = sampleRecord(archivedAt: Date(timeIntervalSince1970: 1000))
        let newer = sampleRecord(archivedAt: Date(timeIntervalSince1970: 2000))
        store.archive(older)
        store.archive(newer)
        XCTAssertEqual(store.allRecords().map(\.id), [newer.id, older.id])
    }

    func test_persistsAcrossReload() {
        let r = sampleRecord()
        do {
            let store = makeStore()
            store.archive(r)
            store.flushPendingWrites()
        }
        let reloaded = makeStore()
        XCTAssertEqual(reloaded.allRecords(), [r])
    }

    func test_lastLineWinsForSameID() {
        let id = UUID()
        do {
            let store = makeStore()
            store.archive(sampleRecord(id: id, name: "first"))
            store.archive(sampleRecord(id: id, name: "second"))
            store.flushPendingWrites()
        }
        let reloaded = makeStore()
        XCTAssertEqual(reloaded.allRecords().count, 1)
        XCTAssertEqual(reloaded.record(id: id.uuidString)?.name, "second")
    }

    func test_malformedLineIsSkipped() throws {
        try "{ not json }\n".write(to: fileURL, atomically: true, encoding: .utf8)
        let store = makeStore()
        XCTAssertEqual(store.allRecords(), [])  // no crash; bad line dropped
        let r = sampleRecord()
        store.archive(r)
        XCTAssertEqual(store.allRecords(), [r])
    }

    func test_capEvictsOldestArchived() {
        let store = makeStore(cap: 2)
        store.archive(sampleRecord(archivedAt: Date(timeIntervalSince1970: 100)))
        store.archive(sampleRecord(archivedAt: Date(timeIntervalSince1970: 200)))
        let newest = sampleRecord(archivedAt: Date(timeIntervalSince1970: 300))
        store.archive(newest)
        let kept = store.allRecords()
        XCTAssertEqual(kept.count, 2)
        XCTAssertEqual(kept.first?.id, newest.id)               // newest kept
        XCTAssertFalse(kept.contains { $0.archivedAt.timeIntervalSince1970 == 100 })  // oldest dropped
    }

    // MARK: - merge (synced-in records, diff kept local)

    func test_merge_keepsLocalDiffWhenIncomingHasNone() {
        let store = makeStore()
        let id = UUID()
        let local = sampleRecord(id: id, diff: "LOCAL DIFF")
        store.archive(local)
        // A synced-in record carries metadata but an empty diff (diff is local-only).
        let synced = AgentArchiveRecord(
            id: id.uuidString, name: "renamed-elsewhere", agentTypeRaw: "claudeCode",
            finalStateRaw: "exited", cwd: "/work/repo", branch: "feature/x",
            worktreePath: nil, startedAt: local.startedAt, archivedAt: local.archivedAt,
            exitCode: 0, plan: [], touched: [], diff: "")
        store.merge([synced])
        let merged = try! XCTUnwrap(store.record(id: id.uuidString))
        XCTAssertEqual(merged.diff, "LOCAL DIFF")          // local diff preserved
        XCTAssertEqual(merged.name, "renamed-elsewhere")   // metadata adopted
    }

    func test_merge_addsNewSyncedRecord() {
        let store = makeStore()
        let incoming = sampleRecord(diff: "")
        store.merge([incoming])
        XCTAssertEqual(store.allRecords(), [incoming])
    }

    // MARK: - sync DTO round-trip (the one real sync verification — no network)

    func test_syncRecord_plannerRestorerRoundTrip_metadataOnly() throws {
        let archive = sampleRecord()
        let snapshot = PrivateSyncSnapshot(
            profiles: [],
            terminalThemeID: "default-dark",
            terminalFontSize: 14,
            terminalUsesLigatures: false,
            snippets: [],
            workspaces: [],
            agentArchives: [AgentArchiveSyncRecord(archive: archive)],
            terminalScrollback: [],
            aiConversationHistory: [])

        let plan = PrivateSyncPlanner().plan(for: snapshot)
        let record = try XCTUnwrap(plan.records.first { $0.recordType == "AgentArchive" })
        XCTAssertEqual(record.recordName, "agent-archive-\(archive.id)")
        // Diff is LOCAL-only: it must NOT be serialized into the synced record.
        XCTAssertNil(record.fields["diff"])
        XCTAssertFalse(record.fields.values.contains { $0.contains("old") || $0.contains("new") })

        let restored = PrivateSyncSnapshotRestorer().restore(from: plan.records)
        let back = try XCTUnwrap(restored.agentArchives.first).archive
        XCTAssertEqual(back.id, archive.id)
        XCTAssertEqual(back.name, archive.name)
        XCTAssertEqual(back.agentType, .claudeCode)
        XCTAssertEqual(back.finalState, .exited)
        XCTAssertEqual(back.branch, "feature/x")
        XCTAssertEqual(back.exitCode, 0)
        XCTAssertEqual(back.plan.map { [$0.id, $0.text, $0.state, $0.sub ?? ""] },
                       [["1", "Read parser", "done", ""], ["2", "Patch it", "active", "Patching it"]])
        XCTAssertEqual(back.touched, ["Sources/Parser.swift", "Tests/ParserTests.swift"])
        XCTAssertEqual(back.diff, "")  // honest: diff absent on the synced-in record
    }

    func test_syncRecord_missingPrefix_doesNotDecode() {
        let bad = PrivateSyncRecord(
            recordType: "AgentArchive", recordName: "snippet-x",
            fields: ["agentType": "codex", "finalState": "exited"])
        XCTAssertNil(AgentArchiveSyncRecord(record: bad))
    }
}
