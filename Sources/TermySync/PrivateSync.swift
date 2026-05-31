import Foundation
import TermyCore

public enum PrivateSyncDataset: String, Hashable, Sendable {
    case connectionProfiles
    case appearanceAndKeymap
    case snippetsAndPrompts
    case workspaces
    case secrets
    case terminalScrollback
    case projectFiles
    case aiConversationHistory
}

public enum PrivateSyncDestination: String, Equatable, Sendable {
    case cloudKitPrivateDatabase
    case iCloudKeychain
    case localOnly
}

/// D3: collision-free encoding for fields that hold lists/maps whose values may
/// themselves contain the legacy delimiters (` `, `|`, `;`, `=`). The old scheme
/// `joined(separator:)` corrupted any value containing its delimiter (e.g. a shell
/// arg `--rcfile "/My Files/rc"` split on the space; a theme name with `|`/`;`; a
/// keymap binding with `=`/`;`). These encode to a deterministic JSON array;
/// decoding prefers JSON and falls back to the legacy split so records written by
/// an older build still restore correctly.
enum PrivateSyncFieldCodec {
    static func encode(_ value: [String]) -> String {
        encodeJSON(value) ?? value.joined(separator: " ")
    }

    static func encode(matrix: [[String]]) -> String {
        encodeJSON(matrix) ?? ""
    }

    /// JSON `[String]`, falling back to splitting on `legacySeparator`.
    static func decodeArray(_ raw: String, legacySeparator: Character) -> [String] {
        if let data = raw.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            return decoded
        }
        return raw.split(separator: legacySeparator).map(String.init)
    }

    /// JSON `[[String]]` (rows), falling back to nil so the caller can run its
    /// bespoke legacy parse.
    static func decodeMatrix(_ raw: String) -> [[String]]? {
        guard let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([[String]].self, from: data) else {
            return nil
        }
        return decoded
    }

    private static func encodeJSON<T: Encodable>(_ value: T) -> String? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

public struct SyncSnippet: Equatable, Sendable {
    public let id: String
    public let title: String
    public let body: String

    public init(id: String, title: String, body: String) {
        self.id = id
        self.title = title
        self.body = body
    }

    public init?(record: PrivateSyncRecord) {
        guard record.recordType == "Snippet",
              record.recordName.hasPrefix("snippet-"),
              let title = record.fields["title"],
              let body = record.fields["body"] else {
            return nil
        }
        self.init(
            id: String(record.recordName.dropFirst("snippet-".count)),
            title: title,
            body: body
        )
    }
}

public struct SyncWorkspace: Equatable, Sendable {
    public let id: String
    public let name: String
    public let panelIDs: [String]
    public let paneTree: WorkspacePaneTree?

    public init(id: String, name: String, panelIDs: [String], paneTree: WorkspacePaneTree? = nil) {
        self.id = id
        self.name = name
        self.panelIDs = panelIDs
        self.paneTree = paneTree
    }

    public init?(record: PrivateSyncRecord) {
        guard record.recordType == "Workspace",
              record.recordName.hasPrefix("workspace-") else {
            return nil
        }

        let id = String(record.recordName.dropFirst("workspace-".count))
        let paneTree: WorkspacePaneTree?
        if let paneTreeValue = record.fields["paneTree"], !paneTreeValue.isEmpty {
            guard let parsedPaneTree = WorkspacePaneTree(storageValue: paneTreeValue) else {
                return nil
            }
            paneTree = parsedPaneTree
        } else {
            paneTree = nil
        }

        let panelIDs = record.fields["panelIDs"]?
            .split(separator: ",")
            .map(String.init)
            .filter { !$0.isEmpty } ?? paneTree?.panes.map(\.rawValue) ?? []

        self.init(
            id: id,
            name: record.fields["name"] ?? id,
            panelIDs: panelIDs,
            paneTree: paneTree
        )
    }
}

public struct PrivateSyncSnapshot: Equatable, Sendable {
    public let profiles: [ConnectionProfile]
    public let terminalThemeID: String
    public let terminalFontSize: Double
    public let terminalFontFamily: String?
    public let terminalUsesLigatures: Bool
    public let terminalIncreasedContrast: Bool
    public let interfaceTextScale: InterfaceTextScale
    public let terminalShell: ShellLaunchProfile
    public let terminalOutputMode: TerminalOutputMode
    public let customTerminalThemes: [TerminalTheme]
    public let keymapBindings: [String: ShortcutDescriptor]
    public let snippets: [SyncSnippet]
    public let workspaces: [SyncWorkspace]
    public let terminalScrollback: [String]
    public let aiConversationHistory: [String]

    public init(
        profiles: [ConnectionProfile],
        terminalThemeID: String,
        terminalFontSize: Double,
        terminalFontFamily: String? = nil,
        terminalUsesLigatures: Bool,
        terminalIncreasedContrast: Bool = false,
        interfaceTextScale: InterfaceTextScale = .regular,
        terminalShell: ShellLaunchProfile = .zsh,
        terminalOutputMode: TerminalOutputMode = .stream,
        customTerminalThemes: [TerminalTheme] = [],
        keymapBindings: [String: ShortcutDescriptor] = [:],
        snippets: [SyncSnippet],
        workspaces: [SyncWorkspace],
        terminalScrollback: [String],
        aiConversationHistory: [String]
    ) {
        self.profiles = profiles
        self.terminalThemeID = terminalThemeID
        self.terminalFontSize = terminalFontSize
        let trimmedFontFamily = terminalFontFamily?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.terminalFontFamily = trimmedFontFamily.isEmpty ? nil : trimmedFontFamily
        self.terminalUsesLigatures = terminalUsesLigatures
        self.terminalIncreasedContrast = terminalIncreasedContrast
        self.interfaceTextScale = interfaceTextScale
        self.terminalShell = terminalShell
        self.terminalOutputMode = terminalOutputMode
        self.customTerminalThemes = customTerminalThemes
        self.keymapBindings = keymapBindings
        self.snippets = snippets
        self.workspaces = workspaces
        self.terminalScrollback = terminalScrollback
        self.aiConversationHistory = aiConversationHistory
    }
}

public struct PrivateSyncRestoredSnapshot: Equatable, Sendable {
    public let profiles: [ConnectionProfile]
    public let terminalThemeID: String?
    public let terminalFontSize: Double?
    public let terminalFontFamily: String?
    public let terminalUsesLigatures: Bool?
    public let terminalIncreasedContrast: Bool?
    public let interfaceTextScale: InterfaceTextScale?
    public let terminalShell: ShellLaunchProfile?
    public let terminalOutputMode: TerminalOutputMode?
    public let customTerminalThemes: [TerminalTheme]
    public let keymapBindings: [String: ShortcutDescriptor]
    public let snippets: [SyncSnippet]
    public let workspaces: [SyncWorkspace]
    public let aiConversationHistory: [String]
}

public struct PrivateSyncSnapshotRestorer: Sendable {
    public init() {}

    /// Decodes a synced `PrivateSyncRecord` back into a `ConnectionProfile`.
    /// Symmetric counterpart to `PrivateSyncPlanner.profileRecord(_:)`; lives in
    /// the sync layer so `ConnectionProfile` carries no record-schema knowledge.
    public static func connectionProfile(from record: PrivateSyncRecord) -> ConnectionProfile? {
        guard record.recordType == "ConnectionProfile",
              record.recordName.hasPrefix("connection-"),
              let id = UUID(uuidString: String(record.recordName.dropFirst("connection-".count))),
              let kindValue = record.fields["kind"],
              let kind = ConnectionKind(rawValue: kindValue),
              let name = record.fields["name"],
              let host = record.fields["host"] else {
            return nil
        }

        let secretReferences = record.fields["secretReferences"]?
            .split(separator: ",")
            .map(String.init)
            .filter { !$0.isEmpty }
            .map(SecretReference.keychain) ?? []

        return ConnectionProfile(
            id: id,
            kind: kind,
            name: name,
            host: host,
            user: record.fields["user"],
            port: record.fields["port"].flatMap(Int.init),
            gateway: record.fields["gateway"],
            groupPath: ConnectionProfile.normalizedGroupPath(record.fields["groupPath"]),
            sshOptions: ConnectionProfile.sshOptions(fromSerialized: record.fields["sshOptions"]),
            terminalOutputMode: record.fields["terminalOutputMode"].flatMap(TerminalOutputMode.init(rawValue:)) ?? .stream,
            secretReferences: secretReferences
        )
    }

    public func restore(from records: [PrivateSyncRecord]) -> PrivateSyncRestoredSnapshot {
        let appearanceRecord = records.first { $0.recordType == "Appearance" && $0.recordName == "appearance-default" }
        return PrivateSyncRestoredSnapshot(
            profiles: records.compactMap(Self.connectionProfile(from:)).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending },
            terminalThemeID: appearanceRecord?.fields["terminalThemeID"],
            terminalFontSize: appearanceRecord?.fields["terminalFontSize"].flatMap(Double.init),
            terminalFontFamily: appearanceRecord?.fields["terminalFontFamily"],
            terminalUsesLigatures: appearanceRecord?.fields["terminalUsesLigatures"].flatMap(Bool.init),
            terminalIncreasedContrast: appearanceRecord?.fields["terminalIncreasedContrast"].flatMap(Bool.init),
            interfaceTextScale: appearanceRecord?.fields["interfaceTextScale"].flatMap(InterfaceTextScale.init(rawValue:)),
            terminalShell: appearanceRecord.flatMap(restoreShellProfile),
            terminalOutputMode: appearanceRecord?.fields["terminalOutputMode"].flatMap(TerminalOutputMode.init(rawValue:)),
            customTerminalThemes: restoreThemes(from: appearanceRecord?.fields["customTerminalThemes"] ?? ""),
            keymapBindings: restoreKeymap(from: appearanceRecord?.fields["keymapBindings"] ?? ""),
            snippets: records.compactMap(SyncSnippet.init(record:)).sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending },
            workspaces: records.compactMap(SyncWorkspace.init(record:)).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending },
            aiConversationHistory: records
                .filter { $0.recordType == "AIConversation" }
                // D2: order by the numeric suffix of `ai-history-<offset>`, not
                // lexicographically (`ai-history-10` < `ai-history-2` would scramble any
                // history with ≥10 messages).
                .sorted { Self.aiHistoryOffset($0.recordName) < Self.aiHistoryOffset($1.recordName) }
                .compactMap { $0.fields["message"] }
        )
    }

    private func restoreShellProfile(from record: PrivateSyncRecord) -> ShellLaunchProfile? {
        guard let path = record.fields["terminalShellPath"] else { return nil }
        if path == ShellLaunchProfile.zsh.command.shellPath {
            return .zsh
        }
        if path == ShellLaunchProfile.bash.command.shellPath {
            return .bash
        }
        return .custom(
            path: path,
            // D3: JSON-first (collision-free), legacy space-split fallback.
            arguments: record.fields["terminalShellArguments"].map {
                PrivateSyncFieldCodec.decodeArray($0, legacySeparator: " ")
            } ?? []
        )
    }

    private func restoreThemes(from storageValue: String) -> [TerminalTheme] {
        // D3: JSON `[[String]]` (7 cols each), falling back to the legacy
        // `;`-between / `|`-within scheme for records written by an older build.
        let rows: [[String]]
        if let decoded = PrivateSyncFieldCodec.decodeMatrix(storageValue) {
            rows = decoded
        } else {
            rows = storageValue
                .split(separator: ";")
                .map { $0.split(separator: "|", omittingEmptySubsequences: false).map(String.init) }
        }
        return rows.compactMap { parts in
            guard parts.count == 7 else { return nil }
            return TerminalTheme(
                id: parts[0],
                name: parts[1],
                backgroundHex: parts[2],
                foregroundHex: parts[3],
                promptHex: parts[4],
                errorHex: parts[5],
                mutedHex: parts[6]
            )
        }
    }

    private func restoreKeymap(from storageValue: String) -> [String: ShortcutDescriptor] {
        // D3: JSON `[[key, storageValue]]`, falling back to the legacy
        // `;`-between / `=`-within scheme.
        let pairs: [[String]]
        if let decoded = PrivateSyncFieldCodec.decodeMatrix(storageValue) {
            pairs = decoded
        } else {
            pairs = storageValue
                .split(separator: ";")
                .map { $0.split(separator: "=", maxSplits: 1).map(String.init) }
        }
        return pairs.reduce(into: [String: ShortcutDescriptor]()) { bindings, pair in
            guard pair.count == 2, let shortcut = ShortcutDescriptor(storageValue: pair[1]) else { return }
            bindings[pair[0]] = shortcut
        }
    }

    /// Numeric offset parsed from an `ai-history-<offset>` record name; unparseable
    /// names sort last (defensive — they should not occur).
    private static func aiHistoryOffset(_ recordName: String) -> Int {
        Int(recordName.dropFirst("ai-history-".count)) ?? Int.max
    }
}

public struct PrivateSyncRecord: Equatable, Sendable {
    public let recordType: String
    public let recordName: String
    public let fields: [String: String]
    public let zoneName: String

    public init(
        recordType: String,
        recordName: String,
        fields: [String: String],
        zoneName: String = "TermyPrivateSync"
    ) {
        self.recordType = recordType
        self.recordName = recordName
        self.fields = fields
        self.zoneName = zoneName
    }

    /// Returns a copy with `fields[key]` set to `value` (type/name/zone preserved).
    /// Used to overlay the mutation-stamped `modifiedAt` at stage time without
    /// reaching into every `*Record` encoder.
    public func settingField(_ key: String, _ value: String) -> PrivateSyncRecord {
        var updated = fields
        updated[key] = value
        return PrivateSyncRecord(
            recordType: recordType,
            recordName: recordName,
            fields: updated,
            zoneName: zoneName
        )
    }

    public var cloudKitRecordType: String {
        "Termy\(recordType)"
    }

    public var cloudKitRecordName: String {
        recordName
    }
}

public struct PrivateSyncPlan: Equatable, Sendable {
    public let datasets: [PrivateSyncDataset: PrivateSyncDestination]
    public let records: [PrivateSyncRecord]

    public init(datasets: [PrivateSyncDataset: PrivateSyncDestination], records: [PrivateSyncRecord]) {
        self.datasets = datasets
        self.records = records
    }
}

public enum PrivateSyncOperationKind: Equatable, Sendable {
    case push
    case fetch
}

public enum PrivateSyncScheduleReason: Equatable, Sendable {
    case localChange
    case silentRemoteNotification
    case appLaunch
}

public struct PrivateSyncOperation: Equatable, Sendable {
    public let kind: PrivateSyncOperationKind
    public let reason: PrivateSyncScheduleReason
    public let earliestRunAt: Int

    public init(kind: PrivateSyncOperationKind, reason: PrivateSyncScheduleReason, earliestRunAt: Int) {
        self.kind = kind
        self.reason = reason
        self.earliestRunAt = earliestRunAt
    }
}

public enum PrivateSyncOperationOutcome: Equatable, Sendable {
    case completed
    case failed(String)
}

public struct PrivateSyncOperationResult: Equatable, Sendable {
    public let operation: PrivateSyncOperation
    public let outcome: PrivateSyncOperationOutcome

    public init(operation: PrivateSyncOperation, outcome: PrivateSyncOperationOutcome) {
        self.operation = operation
        self.outcome = outcome
    }
}

public struct PrivateSyncScheduler: Equatable, Sendable {
    public let debounceSeconds: Int
    private var pendingByKind: [PrivateSyncOperationKind: PrivateSyncOperation]

    public init(debounceSeconds: Int = 5, pendingOperations: [PrivateSyncOperation] = []) {
        self.debounceSeconds = max(0, debounceSeconds)
        self.pendingByKind = Dictionary(uniqueKeysWithValues: pendingOperations.map { ($0.kind, $0) })
    }

    public mutating func schedule(reason: PrivateSyncScheduleReason, at now: Int) -> PrivateSyncOperation? {
        let operation = operation(for: reason, at: now)
        guard pendingByKind[operation.kind] == nil else { return nil }
        pendingByKind[operation.kind] = operation
        return operation
    }

    public func pendingOperations() -> [PrivateSyncOperation] {
        pendingByKind.values.sorted {
            if $0.earliestRunAt == $1.earliestRunAt {
                return sortRank($0.kind) < sortRank($1.kind)
            }
            return $0.earliestRunAt < $1.earliestRunAt
        }
    }

    public mutating func markCompleted(kind: PrivateSyncOperationKind) -> PrivateSyncOperation? {
        pendingByKind.removeValue(forKey: kind)
    }

    public mutating func runDueOperations(
        at now: Int,
        perform: (PrivateSyncOperation) -> PrivateSyncOperationOutcome
    ) -> [PrivateSyncOperationResult] {
        dueOperations(at: now).map { operation in
            let outcome = perform(operation)
            if outcome == .completed {
                pendingByKind.removeValue(forKey: operation.kind)
            }
            return PrivateSyncOperationResult(operation: operation, outcome: outcome)
        }
    }

    public func dueOperations(at now: Int) -> [PrivateSyncOperation] {
        pendingOperations().filter { $0.earliestRunAt <= now }
    }

    public mutating func runDueOperationsAsync(
        at now: Int,
        perform: (PrivateSyncOperation) async -> PrivateSyncOperationOutcome
    ) async -> [PrivateSyncOperationResult] {
        var results: [PrivateSyncOperationResult] = []

        for operation in dueOperations(at: now) {
            let outcome = await perform(operation)
            if outcome == .completed {
                pendingByKind.removeValue(forKey: operation.kind)
            }
            results.append(PrivateSyncOperationResult(operation: operation, outcome: outcome))
        }

        return results
    }

    private func operation(for reason: PrivateSyncScheduleReason, at now: Int) -> PrivateSyncOperation {
        switch reason {
        case .localChange:
            return PrivateSyncOperation(kind: .push, reason: reason, earliestRunAt: now + debounceSeconds)
        case .silentRemoteNotification, .appLaunch:
            return PrivateSyncOperation(kind: .fetch, reason: reason, earliestRunAt: now)
        }
    }

    private func sortRank(_ kind: PrivateSyncOperationKind) -> Int {
        switch kind {
        case .fetch:
            return 0
        case .push:
            return 1
        }
    }
}

public enum PrivateSyncEvent: Equatable, Sendable {
    case localChange
    case silentRemoteNotification
    case appLaunch
    case timer
}

public struct PrivateSyncEventLoopStep: Equatable, Sendable {
    public let event: PrivateSyncEvent
    public let scheduledOperation: PrivateSyncOperation?
    public let operationResults: [PrivateSyncOperationResult]
    public let pendingOperations: [PrivateSyncOperation]

    public init(
        event: PrivateSyncEvent,
        scheduledOperation: PrivateSyncOperation?,
        operationResults: [PrivateSyncOperationResult],
        pendingOperations: [PrivateSyncOperation]
    ) {
        self.event = event
        self.scheduledOperation = scheduledOperation
        self.operationResults = operationResults
        self.pendingOperations = pendingOperations
    }
}

public struct PrivateSyncEventLoop: Sendable {
    private var scheduler: PrivateSyncScheduler

    public init(scheduler: PrivateSyncScheduler = PrivateSyncScheduler()) {
        self.scheduler = scheduler
    }

    public mutating func handle(
        event: PrivateSyncEvent,
        at now: Int,
        perform: (PrivateSyncOperation) -> PrivateSyncOperationOutcome
    ) -> PrivateSyncEventLoopStep {
        let scheduledOperation = schedule(event: event, at: now)
        let results = scheduler.runDueOperations(at: now, perform: perform)
        return PrivateSyncEventLoopStep(
            event: event,
            scheduledOperation: scheduledOperation,
            operationResults: results,
            pendingOperations: scheduler.pendingOperations()
        )
    }

    public mutating func handleAsync(
        event: PrivateSyncEvent,
        at now: Int,
        perform: (PrivateSyncOperation) async -> PrivateSyncOperationOutcome
    ) async -> PrivateSyncEventLoopStep {
        let scheduledOperation = schedule(event: event, at: now)
        let results = await scheduler.runDueOperationsAsync(at: now, perform: perform)
        return PrivateSyncEventLoopStep(
            event: event,
            scheduledOperation: scheduledOperation,
            operationResults: results,
            pendingOperations: scheduler.pendingOperations()
        )
    }

    public func pendingOperations() -> [PrivateSyncOperation] {
        scheduler.pendingOperations()
    }

    private mutating func schedule(event: PrivateSyncEvent, at now: Int) -> PrivateSyncOperation? {
        switch event {
        case .localChange:
            return scheduler.schedule(reason: .localChange, at: now)
        case .silentRemoteNotification:
            return scheduler.schedule(reason: .silentRemoteNotification, at: now)
        case .appLaunch:
            return scheduler.schedule(reason: .appLaunch, at: now)
        case .timer:
            return nil
        }
    }
}

public struct PrivateSyncBackgroundTaskResult: Equatable, Sendable {
    public let operationResults: [PrivateSyncOperationResult]
    public let remainingPendingOperations: [PrivateSyncOperation]
    public let nextWakeAt: Int?

    public init(
        operationResults: [PrivateSyncOperationResult],
        remainingPendingOperations: [PrivateSyncOperation],
        nextWakeAt: Int?
    ) {
        self.operationResults = operationResults
        self.remainingPendingOperations = remainingPendingOperations
        self.nextWakeAt = nextWakeAt
    }

    public var completedOperationCount: Int {
        operationResults.filter { $0.outcome == .completed }.count
    }
}

public struct PrivateSyncBackgroundTaskConfiguration: Equatable, Sendable {
    public let appRefreshIdentifier: String
    public let processingIdentifier: String

    public init(appRefreshIdentifier: String, processingIdentifier: String) {
        self.appRefreshIdentifier = appRefreshIdentifier
        self.processingIdentifier = processingIdentifier
    }

    public static let termDefault = PrivateSyncBackgroundTaskConfiguration(
        appRefreshIdentifier: "pl.kacper.Termy.private-sync.refresh",
        processingIdentifier: "pl.kacper.Termy.private-sync.processing"
    )

    public var permittedIdentifiers: [String] {
        [appRefreshIdentifier, processingIdentifier]
    }
}

public struct PrivateSyncBackgroundTaskRunner: Sendable {
    private var scheduler: PrivateSyncScheduler
    private let maxOperationsPerTask: Int

    public init(scheduler: PrivateSyncScheduler = PrivateSyncScheduler(), maxOperationsPerTask: Int = 2) {
        self.scheduler = scheduler
        self.maxOperationsPerTask = max(1, maxOperationsPerTask)
    }

    public mutating func runDueTask(
        at now: Int,
        perform: (PrivateSyncOperation) async -> PrivateSyncOperationOutcome
    ) async -> PrivateSyncBackgroundTaskResult {
        var results: [PrivateSyncOperationResult] = []
        let operations = Array(scheduler.dueOperations(at: now).prefix(maxOperationsPerTask))

        for operation in operations {
            let outcome = await perform(operation)
            if outcome == .completed {
                _ = scheduler.markCompleted(kind: operation.kind)
            }
            results.append(PrivateSyncOperationResult(operation: operation, outcome: outcome))
        }

        let pending = scheduler.pendingOperations()
        return PrivateSyncBackgroundTaskResult(
            operationResults: results,
            remainingPendingOperations: pending,
            nextWakeAt: pending.first?.earliestRunAt
        )
    }
}

public struct PrivateSyncOperationAdapter: Sendable {
    private let push: @Sendable () -> PrivateSyncOperationOutcome
    private let fetch: @Sendable () -> PrivateSyncOperationOutcome

    public init(
        push: @escaping @Sendable () -> PrivateSyncOperationOutcome,
        fetch: @escaping @Sendable () -> PrivateSyncOperationOutcome
    ) {
        self.push = push
        self.fetch = fetch
    }

    public func perform(_ operation: PrivateSyncOperation) -> PrivateSyncOperationOutcome {
        switch operation.kind {
        case .push:
            return push()
        case .fetch:
            return fetch()
        }
    }
}

public struct PrivateSyncAsyncOperationAdapter: Sendable {
    private let push: @Sendable () async -> PrivateSyncOperationOutcome
    private let fetch: @Sendable () async -> PrivateSyncOperationOutcome

    public init(
        push: @escaping @Sendable () async -> PrivateSyncOperationOutcome,
        fetch: @escaping @Sendable () async -> PrivateSyncOperationOutcome
    ) {
        self.push = push
        self.fetch = fetch
    }

    public func perform(_ operation: PrivateSyncOperation) async -> PrivateSyncOperationOutcome {
        switch operation.kind {
        case .push:
            return await push()
        case .fetch:
            return await fetch()
        }
    }
}

public struct PrivateSyncAppEventStep: Equatable, Sendable {
    public let eventLoopStep: PrivateSyncEventLoopStep
    public let records: [PrivateSyncRecord]
    public let savedRecordCount: Int?
    public let fetchedRecordCount: Int?

    public init(
        eventLoopStep: PrivateSyncEventLoopStep,
        records: [PrivateSyncRecord],
        savedRecordCount: Int?,
        fetchedRecordCount: Int?
    ) {
        self.eventLoopStep = eventLoopStep
        self.records = records
        self.savedRecordCount = savedRecordCount
        self.fetchedRecordCount = fetchedRecordCount
    }
}

public struct PrivateSyncAppEventCoordinator: Sendable {
    public static let defaultFetchRecordTypes = [
        "ConnectionProfile",
        "Appearance",
        "Snippet",
        "Workspace",
        "AIConversation"
    ]

    private var eventLoop: PrivateSyncEventLoop
    private let fetchRecordTypes: [String]

    public init(
        eventLoop: PrivateSyncEventLoop = PrivateSyncEventLoop(),
        fetchRecordTypes: [String] = PrivateSyncAppEventCoordinator.defaultFetchRecordTypes
    ) {
        self.eventLoop = eventLoop
        self.fetchRecordTypes = fetchRecordTypes
    }

    public mutating func handle(
        event: PrivateSyncEvent,
        at now: Int,
        records: [PrivateSyncRecord],
        activeLocalSessionRecordNames: Set<String>,
        save: ([PrivateSyncRecord]) async throws -> [PrivateSyncRecord],
        fetch: (String) async throws -> [PrivateSyncRecord]
    ) async -> PrivateSyncAppEventStep {
        var currentRecords = records
        var savedRecordCount: Int?
        var fetchedRecordCount: Int?

        let step = await eventLoop.handleAsync(event: event, at: now) { operation in
            do {
                switch operation.kind {
                case .push:
                    let savedRecords = try await save(currentRecords)
                    currentRecords = savedRecords
                    savedRecordCount = savedRecords.count
                case .fetch:
                    var remoteRecords: [PrivateSyncRecord] = []
                    for recordType in fetchRecordTypes {
                        remoteRecords.append(contentsOf: try await fetch(recordType))
                    }
                    currentRecords = privateSyncMergedRecords(
                        local: currentRecords,
                        remote: remoteRecords,
                        activeLocalSessionRecordNames: activeLocalSessionRecordNames
                    )
                    fetchedRecordCount = remoteRecords.count
                }
                return .completed
            } catch {
                return .failed(error.localizedDescription)
            }
        }

        return PrivateSyncAppEventStep(
            eventLoopStep: step,
            records: currentRecords,
            savedRecordCount: savedRecordCount,
            fetchedRecordCount: fetchedRecordCount
        )
    }

    public func pendingOperations() -> [PrivateSyncOperation] {
        eventLoop.pendingOperations()
    }

    public static func mergeRecords(
        local: [PrivateSyncRecord],
        remote: [PrivateSyncRecord],
        activeLocalSessionRecordNames: Set<String>
    ) -> [PrivateSyncRecord] {
        privateSyncMergedRecords(
            local: local,
            remote: remote,
            activeLocalSessionRecordNames: activeLocalSessionRecordNames
        )
    }
}

public enum PrivateSyncEngineAccountState: Equatable, Sendable {
    case available
    case noAccount
    case restricted
    case unavailable
}

public enum PrivateSyncEngineEvent: Equatable, Sendable {
    case stateUpdated(PrivateSyncChangeToken)
    case localRecordsChanged
    case willFetchChanges
    case willSendChanges
    case fetchedDatabaseChanges(PrivateSyncChangeSet)
    case sentDatabaseChanges([PrivateSyncRecord])
    case accountChanged(PrivateSyncEngineAccountState)
    case timer
}

public struct PrivateSyncEngineRuntimeStep: Equatable, Sendable {
    public let engineEvent: PrivateSyncEngineEvent
    public let appEventStep: PrivateSyncAppEventStep?
    public let records: [PrivateSyncRecord]
    public let changeToken: PrivateSyncChangeToken?
    public let appliedChangeCount: Int
    public let accountState: PrivateSyncEngineAccountState?

    public init(
        engineEvent: PrivateSyncEngineEvent,
        appEventStep: PrivateSyncAppEventStep?,
        records: [PrivateSyncRecord],
        changeToken: PrivateSyncChangeToken?,
        appliedChangeCount: Int,
        accountState: PrivateSyncEngineAccountState?
    ) {
        self.engineEvent = engineEvent
        self.appEventStep = appEventStep
        self.records = records
        self.changeToken = changeToken
        self.appliedChangeCount = appliedChangeCount
        self.accountState = accountState
    }
}

public struct PrivateSyncEngineRuntime: Sendable {
    private var coordinator: PrivateSyncAppEventCoordinator
    private var changeToken: PrivateSyncChangeToken?
    private var accountState: PrivateSyncEngineAccountState?

    public init(
        coordinator: PrivateSyncAppEventCoordinator = PrivateSyncAppEventCoordinator(),
        changeToken: PrivateSyncChangeToken? = nil,
        accountState: PrivateSyncEngineAccountState? = nil
    ) {
        self.coordinator = coordinator
        self.changeToken = changeToken
        self.accountState = accountState
    }

    public func currentChangeToken() -> PrivateSyncChangeToken? {
        changeToken
    }

    public func currentAccountState() -> PrivateSyncEngineAccountState? {
        accountState
    }

    public mutating func handle(
        event: PrivateSyncEngineEvent,
        at now: Int,
        records: [PrivateSyncRecord],
        activeLocalSessionRecordNames: Set<String>,
        save: ([PrivateSyncRecord]) async throws -> [PrivateSyncRecord] = { records in records },
        fetch: (String) async throws -> [PrivateSyncRecord] = { _ in [] }
    ) async -> PrivateSyncEngineRuntimeStep {
        switch event {
        case .stateUpdated(let token):
            changeToken = token
            return PrivateSyncEngineRuntimeStep(
                engineEvent: event,
                appEventStep: nil,
                records: records,
                changeToken: changeToken,
                appliedChangeCount: 0,
                accountState: accountState
            )
        case .fetchedDatabaseChanges(let changeSet):
            let result = PrivateSyncChangeProcessor().process(
                localRecords: records,
                changeSet: changeSet,
                previousChangeToken: changeToken,
                activeLocalSessionRecordNames: activeLocalSessionRecordNames
            )
            changeToken = result.changeToken
            return PrivateSyncEngineRuntimeStep(
                engineEvent: event,
                appEventStep: nil,
                records: result.records,
                changeToken: changeToken,
                appliedChangeCount: result.appliedChangeCount,
                accountState: accountState
            )
        case .sentDatabaseChanges(let savedRecords):
            return PrivateSyncEngineRuntimeStep(
                engineEvent: event,
                appEventStep: nil,
                records: savedRecords,
                changeToken: changeToken,
                appliedChangeCount: 0,
                accountState: accountState
            )
        case .accountChanged(let state):
            accountState = state
            guard state == .available else {
                return PrivateSyncEngineRuntimeStep(
                    engineEvent: event,
                    appEventStep: nil,
                    records: records,
                    changeToken: changeToken,
                    appliedChangeCount: 0,
                    accountState: accountState
                )
            }
            return await handleAppEvent(
                .appLaunch,
                engineEvent: event,
                at: now,
                records: records,
                activeLocalSessionRecordNames: activeLocalSessionRecordNames,
                save: save,
                fetch: fetch
            )
        case .localRecordsChanged:
            return await handleAppEvent(
                .localChange,
                engineEvent: event,
                at: now,
                records: records,
                activeLocalSessionRecordNames: activeLocalSessionRecordNames,
                save: save,
                fetch: fetch
            )
        case .willFetchChanges:
            return await handleAppEvent(
                .silentRemoteNotification,
                engineEvent: event,
                at: now,
                records: records,
                activeLocalSessionRecordNames: activeLocalSessionRecordNames,
                save: save,
                fetch: fetch
            )
        case .willSendChanges, .timer:
            return await handleAppEvent(
                .timer,
                engineEvent: event,
                at: now,
                records: records,
                activeLocalSessionRecordNames: activeLocalSessionRecordNames,
                save: save,
                fetch: fetch
            )
        }
    }

    private mutating func handleAppEvent(
        _ appEvent: PrivateSyncEvent,
        engineEvent: PrivateSyncEngineEvent,
        at now: Int,
        records: [PrivateSyncRecord],
        activeLocalSessionRecordNames: Set<String>,
        save: ([PrivateSyncRecord]) async throws -> [PrivateSyncRecord],
        fetch: (String) async throws -> [PrivateSyncRecord]
    ) async -> PrivateSyncEngineRuntimeStep {
        let step = await coordinator.handle(
            event: appEvent,
            at: now,
            records: records,
            activeLocalSessionRecordNames: activeLocalSessionRecordNames,
            save: save,
            fetch: fetch
        )
        return PrivateSyncEngineRuntimeStep(
            engineEvent: engineEvent,
            appEventStep: step,
            records: step.records,
            changeToken: changeToken,
            appliedChangeCount: 0,
            accountState: accountState
        )
    }
}

private func privateSyncMergedRecords(
    local: [PrivateSyncRecord],
    remote: [PrivateSyncRecord],
    activeLocalSessionRecordNames: Set<String>
) -> [PrivateSyncRecord] {
    let resolver = PrivateSyncConflictResolver()
    var merged = Dictionary(uniqueKeysWithValues: local.map { ($0.recordName, $0) })
    for remoteRecord in remote {
        if let localRecord = merged[remoteRecord.recordName] {
            merged[remoteRecord.recordName] = resolver.resolve(
                local: localRecord,
                remote: remoteRecord,
                activeLocalSessionRecordNames: activeLocalSessionRecordNames
            )
        } else {
            merged[remoteRecord.recordName] = remoteRecord
        }
    }
    return merged.values.sorted {
        if $0.recordType == $1.recordType {
            return $0.recordName < $1.recordName
        }
        return $0.recordType < $1.recordType
    }
}

public struct PrivateSyncChangeToken: Equatable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct PrivateSyncChangeSet: Equatable, Sendable {
    public let changedRecords: [PrivateSyncRecord]
    public let deletedRecordNames: [String]
    public let newChangeToken: PrivateSyncChangeToken?

    public init(
        changedRecords: [PrivateSyncRecord],
        deletedRecordNames: [String],
        newChangeToken: PrivateSyncChangeToken?
    ) {
        self.changedRecords = changedRecords
        self.deletedRecordNames = deletedRecordNames
        self.newChangeToken = newChangeToken
    }
}

public struct PrivateSyncChangeProcessingResult: Equatable, Sendable {
    public let records: [PrivateSyncRecord]
    public let changeToken: PrivateSyncChangeToken?
    public let appliedChangeCount: Int

    public init(records: [PrivateSyncRecord], changeToken: PrivateSyncChangeToken?, appliedChangeCount: Int) {
        self.records = records
        self.changeToken = changeToken
        self.appliedChangeCount = appliedChangeCount
    }
}

public struct PrivateSyncChangeProcessor: Sendable {
    public init() {}

    public func process(
        localRecords: [PrivateSyncRecord],
        changeSet: PrivateSyncChangeSet,
        previousChangeToken: PrivateSyncChangeToken?,
        activeLocalSessionRecordNames: Set<String>
    ) -> PrivateSyncChangeProcessingResult {
        let resolver = PrivateSyncConflictResolver()
        var recordsByName = Dictionary(uniqueKeysWithValues: localRecords.map { ($0.recordName, $0) })
        var appliedChangeCount = 0

        for record in changeSet.changedRecords {
            if let local = recordsByName[record.recordName] {
                recordsByName[record.recordName] = resolver.resolve(
                    local: local,
                    remote: record,
                    activeLocalSessionRecordNames: activeLocalSessionRecordNames
                )
            } else {
                recordsByName[record.recordName] = record
            }
            appliedChangeCount += 1
        }

        for recordName in changeSet.deletedRecordNames where !activeLocalSessionRecordNames.contains(recordName) {
            if recordsByName.removeValue(forKey: recordName) != nil {
                appliedChangeCount += 1
            }
        }

        return PrivateSyncChangeProcessingResult(
            records: recordsByName.values.sorted {
                if $0.recordType == $1.recordType {
                    return $0.recordName < $1.recordName
                }
                return $0.recordType < $1.recordType
            },
            changeToken: changeSet.newChangeToken ?? previousChangeToken,
            appliedChangeCount: appliedChangeCount
        )
    }
}

public struct PrivateSyncPlanner: Sendable {
    public init() {}

    /// Maps a `UserPromptSnippetLibrary`'s active entries into sync DTOs.
    /// Lives in the sync layer (symmetric with the `*Record` encoders) so
    /// `UserPromptSnippetLibrary` in `TermyCore` carries no `SyncSnippet`
    /// knowledge — removes the only remaining `TermyCore`→sync back-edge.
    public static func syncSnippets(from library: UserPromptSnippetLibrary) -> [SyncSnippet] {
        library.activeSnippets().map {
            SyncSnippet(
                id: "user-\($0.id)",
                title: $0.title,
                body: $0.body.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }

    public func plan(for snapshot: PrivateSyncSnapshot) -> PrivateSyncPlan {
        var records: [PrivateSyncRecord] = []
        records.append(contentsOf: snapshot.profiles.map(profileRecord))
        records.append(appearanceRecord(from: snapshot))
        records.append(contentsOf: snapshot.snippets.map(snippetRecord))
        records.append(contentsOf: snapshot.workspaces.map(workspaceRecord))
        records.append(contentsOf: snapshot.aiConversationHistory.enumerated().map(aiHistoryRecord))

        return PrivateSyncPlan(
            datasets: [
                .connectionProfiles: .cloudKitPrivateDatabase,
                .appearanceAndKeymap: .cloudKitPrivateDatabase,
                .snippetsAndPrompts: .cloudKitPrivateDatabase,
                .workspaces: .cloudKitPrivateDatabase,
                .secrets: .iCloudKeychain,
                .terminalScrollback: .localOnly,
                .projectFiles: .localOnly,
                .aiConversationHistory: .cloudKitPrivateDatabase
            ],
            records: records
        )
    }

    private func profileRecord(_ profile: ConnectionProfile) -> PrivateSyncRecord {
        var fields: [String: String] = [
            "kind": profile.kind.rawValue,
            "name": profile.name,
            "host": profile.host,
            "secretReferences": profile.secretReferences.map(secretReferenceID).joined(separator: ",")
        ]
        if let user = profile.user {
            fields["user"] = user
        }
        if let port = profile.port {
            fields["port"] = String(port)
        }
        if let gateway = profile.gateway {
            fields["gateway"] = gateway
        }
        if let groupPath = profile.groupPath {
            fields["groupPath"] = groupPath
        }
        let sshOptions = ConnectionProfile.serializedSSHOptions(profile.sshOptions)
        if !sshOptions.isEmpty {
            fields["sshOptions"] = sshOptions
        }
        fields["terminalOutputMode"] = profile.terminalOutputMode.rawValue
        return PrivateSyncRecord(
            recordType: "ConnectionProfile",
            recordName: "connection-\(profile.id.uuidString)",
            fields: fields
        )
    }

    private func appearanceRecord(from snapshot: PrivateSyncSnapshot) -> PrivateSyncRecord {
        var fields = [
            "terminalThemeID": snapshot.terminalThemeID,
            "terminalFontSize": String(snapshot.terminalFontSize),
            "terminalUsesLigatures": String(snapshot.terminalUsesLigatures),
            "terminalIncreasedContrast": String(snapshot.terminalIncreasedContrast),
            "interfaceTextScale": snapshot.interfaceTextScale.rawValue,
            "terminalShellPath": snapshot.terminalShell.command.shellPath,
            "terminalShellArguments": PrivateSyncFieldCodec.encode(snapshot.terminalShell.command.arguments),
            "terminalOutputMode": snapshot.terminalOutputMode.rawValue,
            "customTerminalThemes": serializeThemes(snapshot.customTerminalThemes),
            "keymapBindings": serializeKeymap(snapshot.keymapBindings)
        ]
        if let terminalFontFamily = snapshot.terminalFontFamily {
            fields["terminalFontFamily"] = terminalFontFamily
        }

        return PrivateSyncRecord(
            recordType: "Appearance",
            recordName: "appearance-default",
            fields: fields
        )
    }

    private func serializeThemes(_ themes: [TerminalTheme]) -> String {
        PrivateSyncFieldCodec.encode(matrix: themes
            .sorted { $0.id < $1.id }
            .map {
                [
                    $0.id,
                    $0.name,
                    $0.backgroundHex,
                    $0.foregroundHex,
                    $0.promptHex,
                    $0.errorHex,
                    $0.mutedHex
                ]
            })
    }

    private func serializeKeymap(_ bindings: [String: ShortcutDescriptor]) -> String {
        PrivateSyncFieldCodec.encode(matrix: bindings
            .sorted { $0.key < $1.key }
            .map { [$0.key, $0.value.storageValue] })
    }

    private func snippetRecord(_ snippet: SyncSnippet) -> PrivateSyncRecord {
        PrivateSyncRecord(
            recordType: "Snippet",
            recordName: "snippet-\(snippet.id)",
            fields: [
                "title": snippet.title,
                "body": snippet.body
            ]
        )
    }

    private func workspaceRecord(_ workspace: SyncWorkspace) -> PrivateSyncRecord {
        var fields = [
            "name": workspace.name,
            "panelIDs": workspace.panelIDs.joined(separator: ",")
        ]
        if let paneTree = workspace.paneTree {
            fields["paneTree"] = paneTree.storageValue
        }
        return PrivateSyncRecord(
            recordType: "Workspace",
            recordName: "workspace-\(workspace.id)",
            fields: fields
        )
    }

    private func aiHistoryRecord(offset: Int, element: String) -> PrivateSyncRecord {
        PrivateSyncRecord(
            recordType: "AIConversation",
            recordName: "ai-history-\(offset)",
            fields: ["message": element]
        )
    }

    private func secretReferenceID(_ reference: SecretReference) -> String {
        switch reference {
        case .keychain(let id):
            return id
        }
    }
}

/// D2 (orphan-resurrect): when the positional `ai-history-<offset>` set shrinks
/// (the user trims/clears AI history), the higher-index records left in CloudKit
/// resurrect on the next fetch (the merge re-adds remote records absent locally).
/// The push must delete them. Scoped to `AIConversation` — the only record family
/// that is positional and replaced as a whole set, so "present before, absent now"
/// unambiguously means "trimmed" (config records use stable ids and are handled by
/// their own future deletion path, not this heuristic).
public enum PrivateSyncDeletionPlanner {
    public static func aiHistoryOrphans(
        previous: [PrivateSyncRecord],
        current: [PrivateSyncRecord]
    ) -> [String] {
        let currentNames = Set(
            current.lazy.filter { $0.recordType == "AIConversation" }.map(\.recordName)
        )
        return previous
            .filter { $0.recordType == "AIConversation" && !currentNames.contains($0.recordName) }
            .map(\.recordName)
    }
}

public struct PrivateSyncConflictResolver: Sendable {
    public init() {}

    public func resolve(
        local: PrivateSyncRecord,
        remote: PrivateSyncRecord,
        activeLocalSessionRecordNames: Set<String>
    ) -> PrivateSyncRecord {
        if activeLocalSessionRecordNames.contains(local.recordName) {
            return local
        }

        // D4: the winner keeps its OWN secretReferences. The previous code force-set
        // them to local's even when remote won — so a credential re-issued on another
        // Mac (new reference id) was discarded here and this Mac kept pointing at the
        // stale Keychain item (auth failure). When local wins it already carries local's
        // refs; when remote wins its refs are the current ones (and the material itself
        // syncs via iCloud Keychain). No override needed.
        return isRemoteNewer(local: local, remote: remote) ? remote : local
    }

    public func resolve(
        local: PrivateSyncRecord,
        remote: PrivateSyncRecord,
        activeLocalSessionRecordNames: [String]
    ) -> PrivateSyncRecord {
        resolve(local: local, remote: remote, activeLocalSessionRecordNames: Set(activeLocalSessionRecordNames))
    }

    private func isRemoteNewer(local: PrivateSyncRecord, remote: PrivateSyncRecord) -> Bool {
        // D1: compare a REAL per-record last-edited timestamp (stamped at mutation time,
        // carried in `modifiedAt`). Missing/legacy → epoch 0 (unknown = old). Strict `>`
        // so equal stamps keep local (no churn) and two unstamped records keep local
        // (conservative: a genuinely newer remote still wins once it carries a stamp).
        let localModifiedAt = Double(local.fields["modifiedAt"] ?? "") ?? 0
        let remoteModifiedAt = Double(remote.fields["modifiedAt"] ?? "") ?? 0
        return remoteModifiedAt > localModifiedAt
    }
}
