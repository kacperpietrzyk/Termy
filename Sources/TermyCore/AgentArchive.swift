import Foundation

/// AD-7: a finished/archived agent session, persisted locally as one JSONL line
/// keyed by the session id. Captures the agent's plan, touched files, worktree
/// diff, and metadata at exit so the History view can show it after the live
/// session (and its worktree) are gone. Pure value type — `AgentArchiveStore`
/// owns persistence; `TermyStore` computes the diff/metadata and hands it in
/// (no shell-out here, so this is unit-testable without git or a PTY).
public struct AgentArchiveRecord: Codable, Sendable, Equatable, Identifiable {
    /// Stable identity = the original session UUID string. Last JSONL line for a
    /// given id wins on load (append-only, mirroring `HistoryStore`).
    public let id: String
    public let name: String
    /// `CLIAgent.rawValue` ("codex" / "claudeCode"). Stored raw so the shared
    /// `CLIAgent` enum needs no `Codable` conformance; typed via `agentType`.
    public let agentTypeRaw: String
    /// `AgentActivityState.rawValue` (last known, typically "exited").
    public let finalStateRaw: String
    public let cwd: String?
    public let branch: String?
    /// nil = ran in the active cwd (no worktree); otherwise the worktree path.
    public let worktreePath: String?
    public let startedAt: Date
    public let archivedAt: Date
    /// Process exit status when known (nil = I/O error / unknown).
    public let exitCode: Int?
    public let plan: [AgentArchivePlanStep]
    public let touched: [String]
    /// The worktree's `git diff` captured BEFORE worktree cleanup. May be empty
    /// (clean tree, or a non-worktree agent). Kept LOCAL-only — never synced to
    /// CloudKit (it can be hundreds of KB → field/CKRecord limits; and the
    /// worktree it came from does not exist on another Mac anyway).
    public let diff: String

    /// Raw-string designated init — used by Codable synthesis and by callers that
    /// already hold raw values (e.g. the sync-layer decoder, forward-compat tests).
    public init(
        id: String, name: String, agentTypeRaw: String, finalStateRaw: String,
        cwd: String?, branch: String?, worktreePath: String?,
        startedAt: Date, archivedAt: Date, exitCode: Int?,
        plan: [AgentArchivePlanStep], touched: [String], diff: String
    ) {
        self.id = id; self.name = name; self.agentTypeRaw = agentTypeRaw
        self.finalStateRaw = finalStateRaw; self.cwd = cwd; self.branch = branch
        self.worktreePath = worktreePath; self.startedAt = startedAt
        self.archivedAt = archivedAt; self.exitCode = exitCode
        self.plan = plan; self.touched = touched; self.diff = diff
    }

    /// Typed convenience — flattens the enums to their raw values.
    public init(
        id: String, name: String, agentType: CLIAgent, finalState: AgentActivityState,
        cwd: String?, branch: String?, worktreePath: String?,
        startedAt: Date, archivedAt: Date, exitCode: Int?,
        plan: [AgentArchivePlanStep], touched: [String], diff: String
    ) {
        self.init(
            id: id, name: name, agentTypeRaw: agentType.rawValue,
            finalStateRaw: finalState.rawValue, cwd: cwd, branch: branch,
            worktreePath: worktreePath, startedAt: startedAt, archivedAt: archivedAt,
            exitCode: exitCode, plan: plan, touched: touched, diff: diff)
    }

    /// Typed agent kind; defaults to `.claudeCode` if a record carries an unknown
    /// raw value (forward-compat — never throws).
    public var agentType: CLIAgent { CLIAgent(rawValue: agentTypeRaw) ?? .claudeCode }
    /// Typed final state; defaults to `.exited` for an unknown raw value.
    public var finalState: AgentActivityState {
        AgentActivityState(rawValue: finalStateRaw) ?? .exited
    }
}

/// A plan step snapshot in an archived session — a flattened, Codable mirror of
/// `AgentPlanStep` (whose `State` is not Codable and lives in the live layer).
public struct AgentArchivePlanStep: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let text: String
    public let state: String   // "todo" / "active" / "done"
    public let sub: String?

    public init(id: String, text: String, state: String, sub: String?) {
        self.id = id; self.text = text; self.state = state; self.sub = sub
    }
}

public extension AgentArchiveRecord {
    /// Build an archive record from the live plan + captured exit facts. Keeps the
    /// flattening of `AgentPlanStep` in one place.
    init(
        id: UUID, name: String, agentType: CLIAgent, finalState: AgentActivityState,
        cwd: String?, branch: String?, worktreePath: String?,
        startedAt: Date, archivedAt: Date, exitCode: Int?,
        plan: [AgentPlanStep], touched: [String], diff: String
    ) {
        self.init(
            id: id.uuidString, name: name, agentType: agentType, finalState: finalState,
            cwd: cwd, branch: branch, worktreePath: worktreePath,
            startedAt: startedAt, archivedAt: archivedAt, exitCode: exitCode,
            plan: plan.map {
                AgentArchivePlanStep(
                    id: $0.id, text: $0.text,
                    state: AgentArchiveRecord.planStateRaw($0.state), sub: $0.sub)
            },
            touched: touched, diff: diff)
    }

    static func planStateRaw(_ state: AgentPlanStep.State) -> String {
        switch state {
        case .todo: "todo"
        case .active: "active"
        case .done: "done"
        }
    }
}

/// AD-7: append-only JSONL store of archived agent sessions under Application
/// Support/Termy. Mirrors `HistoryStore`'s persistence shape exactly: a serial
/// `ioQueue` for appends, last-line-wins load keyed by record id, and atomic
/// compaction once appends exceed the live set. Restore = read; this slice does
/// NOT re-spawn a PTY (the worktree is gone) — History is a read-only surface.
@MainActor
public final class AgentArchiveStore {
    private let fileURL: URL
    private let cap: Int
    private var records: [String: AgentArchiveRecord] = [:]
    private let ioQueue = DispatchQueue(label: "termy.agentarchive.io", qos: .utility)
    private var appendsSinceCompaction = 0
    private var loadHadMalformedLines = false

    public init(fileURL: URL, cap: Int = 500) {
        self.fileURL = fileURL
        self.cap = cap
        loadFromDisk()
        evictIfNeeded()
        if loadHadMalformedLines {
            scheduleCompaction()
        }
    }

    /// Persist (or replace, by id) one archived session. Past `cap`, the
    /// oldest-archived records are dropped (mirrors `HistoryStore`'s cap) — this
    /// bounds both the local JSONL and the metadata that rides the sync snapshot.
    public func archive(_ record: AgentArchiveRecord) {
        records[record.id] = record
        scheduleAppend(record)
        if records.count > cap {
            evictIfNeeded()
            scheduleCompaction()
        }
    }

    /// Drop the oldest-archived records beyond `cap`.
    private func evictIfNeeded() {
        guard records.count > cap else { return }
        let losers = records.values
            .sorted { $0.archivedAt < $1.archivedAt }
            .prefix(records.count - cap)
            .map(\.id)
        for id in losers { records.removeValue(forKey: id) }
    }

    /// All archived sessions, newest-archived first.
    public func allRecords() -> [AgentArchiveRecord] {
        records.values.sorted { $0.archivedAt > $1.archivedAt }
    }

    public func record(id: String) -> AgentArchiveRecord? {
        records[id]
    }

    /// Adopt records merged in from sync (CloudKit private DB). Local diff is kept
    /// when this Mac already has the fuller (local-only diff) copy; otherwise the
    /// synced metadata-only record is stored so it still appears in History.
    public func merge(_ incoming: [AgentArchiveRecord]) {
        for record in incoming {
            if let existing = records[record.id], !existing.diff.isEmpty, record.diff.isEmpty {
                // Keep our local copy's diff; refresh the rest from the synced record.
                records[record.id] = AgentArchiveRecord(
                    id: record.id, name: record.name, agentType: record.agentType,
                    finalState: record.finalState, cwd: record.cwd, branch: record.branch,
                    worktreePath: record.worktreePath, startedAt: record.startedAt,
                    archivedAt: record.archivedAt, exitCode: record.exitCode,
                    plan: record.plan, touched: record.touched, diff: existing.diff)
            } else {
                records[record.id] = record
            }
        }
        evictIfNeeded()
        scheduleCompaction()
    }

    // MARK: - Persistence (mirrors HistoryStore)

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let text = String(decoding: data, as: UTF8.self)
        let decoder = JSONDecoder.agentArchive
        var loaded: [String: AgentArchiveRecord] = [:]
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let record = try? decoder.decode(AgentArchiveRecord.self, from: Data(line.utf8)) else {
                loadHadMalformedLines = true
                continue
            }
            loaded[record.id] = record  // last line for id wins (append-only)
        }
        self.records = loaded
    }

    private func scheduleAppend(_ record: AgentArchiveRecord) {
        let encoder = JSONEncoder.agentArchive
        guard let line = try? encoder.encode(record) else { return }
        let fileURL = self.fileURL
        ioQueue.async {
            Self.appendLine(line, to: fileURL)
        }
        appendsSinceCompaction += 1
        if appendsSinceCompaction >= records.count, records.count > 0 {
            scheduleCompaction()
        }
    }

    public func flushPendingWrites() {
        let snapshot = Array(records.values)
        let fileURL = self.fileURL
        ioQueue.sync {
            Self.writeCompacted(snapshot, to: fileURL)
        }
        appendsSinceCompaction = 0
    }

    private func scheduleCompaction() {
        let snapshot = Array(records.values)
        let fileURL = self.fileURL
        ioQueue.async {
            Self.writeCompacted(snapshot, to: fileURL)
        }
        appendsSinceCompaction = 0
    }

    private nonisolated static func writeCompacted(_ snapshot: [AgentArchiveRecord], to url: URL) {
        let encoder = JSONEncoder.agentArchive
        let fm = FileManager.default
        try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let tmpURL = url.appendingPathExtension("tmp")
        var buffer = Data()
        for record in snapshot {
            guard let line = try? encoder.encode(record) else { continue }
            buffer.append(line)
            buffer.append(UInt8(ascii: "\n"))
        }
        try? buffer.write(to: tmpURL, options: .atomic)
        do {
            _ = try fm.replaceItemAt(url, withItemAt: tmpURL)
        } catch {
            try? buffer.write(to: url, options: .atomic)
            try? fm.removeItem(at: tmpURL)
        }
    }

    private nonisolated static func appendLine(_ jsonLine: Data, to url: URL) {
        let fm = FileManager.default
        try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var payload = Data()
        payload.append(jsonLine)
        payload.append(UInt8(ascii: "\n"))
        if fm.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: payload)
            }
        } else {
            try? payload.write(to: url, options: .atomic)
        }
    }
}

// MARK: - Coders

extension JSONEncoder {
    /// AD-7 canonical encoder. ISO-8601 dates (matches the F-2 history shape).
    static var agentArchive: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }
}

extension JSONDecoder {
    static var agentArchive: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
