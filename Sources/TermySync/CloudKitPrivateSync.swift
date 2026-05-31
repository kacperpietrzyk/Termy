import Foundation
import TermyCore

#if canImport(CloudKit)
import CloudKit

public enum PrivateSyncCloudAccountStatus: Equatable, Sendable {
    case available
    case noAccount
    case restricted
    case couldNotDetermine
    case temporarilyUnavailable
}

public struct CloudKitPrivateSyncMapper: Sendable {
    public init() {}

    public func makeCloudKitRecord(from record: PrivateSyncRecord) -> CKRecord {
        let zoneID = CKRecordZone.ID(zoneName: record.zoneName, ownerName: CKCurrentUserDefaultName)
        let recordID = CKRecord.ID(recordName: record.cloudKitRecordName, zoneID: zoneID)
        let ckRecord = CKRecord(recordType: record.cloudKitRecordType, recordID: recordID)
        for (key, value) in record.fields {
            ckRecord[key] = value as CKRecordValue
        }
        return ckRecord
    }

    public func makePrivateSyncRecord(from record: CKRecord) throws -> PrivateSyncRecord {
        let recordType = String(record.recordType.dropFirst("Termy".count))
        var fields: [String: String] = [:]
        for key in record.allKeys() {
            if let value = record[key] as? String {
                fields[key] = value
            }
        }
        return PrivateSyncRecord(
            recordType: recordType,
            recordName: record.recordID.recordName,
            fields: fields,
            zoneName: record.recordID.zoneID.zoneName
        )
    }

    public func makeZoneSubscription(
        zoneName: String = "TermyPrivateSync",
        subscriptionID: String = "TermyPrivateSyncZoneChanges"
    ) -> CKRecordZoneSubscription {
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        let subscription = CKRecordZoneSubscription(zoneID: zoneID, subscriptionID: subscriptionID)
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        return subscription
    }

    @available(macOS 14.0, *)
    public func makeFetchedRecordZoneChangesEvent(
        modifications: [CKRecord],
        deletedRecordIDs: [CKRecord.ID],
        stateToken: PrivateSyncChangeToken?
    ) throws -> PrivateSyncEngineEvent {
        try .fetchedDatabaseChanges(
            PrivateSyncChangeSet(
                changedRecords: modifications.map(makePrivateSyncRecord),
                deletedRecordNames: deletedRecordIDs.map(\.recordName),
                newChangeToken: stateToken
            )
        )
    }

    @available(macOS 14.0, *)
    public func makeSentRecordZoneChangesEvent(savedRecords: [CKRecord]) throws -> PrivateSyncEngineEvent {
        try .sentDatabaseChanges(savedRecords.map(makePrivateSyncRecord))
    }

    @available(macOS 14.0, *)
    public func makeAccountState(
        from changeType: CKSyncEngine.Event.AccountChange.ChangeType
    ) -> PrivateSyncEngineAccountState {
        switch changeType {
        case .signIn:
            return .available
        case .signOut:
            return .noAccount
        case .switchAccounts:
            return .available
        @unknown default:
            return .unavailable
        }
    }

    @available(macOS 14.0, *)
    public func makeStateToken(
        from stateSerialization: CKSyncEngine.State.Serialization
    ) throws -> PrivateSyncChangeToken {
        let data = try JSONEncoder().encode(stateSerialization)
        return PrivateSyncChangeToken(rawValue: data.base64EncodedString())
    }

    @available(macOS 14.0, *)
    public func makePrivateSyncEngineEvent(
        from event: CKSyncEngine.Event,
        stateToken: PrivateSyncChangeToken? = nil
    ) throws -> PrivateSyncEngineEvent? {
        switch event {
        case .stateUpdate(let update):
            return try .stateUpdated(makeStateToken(from: update.stateSerialization))
        case .accountChange(let change):
            return .accountChanged(makeAccountState(from: change.changeType))
        case .fetchedRecordZoneChanges(let changes):
            return try makeFetchedRecordZoneChangesEvent(
                modifications: changes.modifications.map(\.record),
                deletedRecordIDs: changes.deletions.map(\.recordID),
                stateToken: stateToken
            )
        case .sentRecordZoneChanges(let changes):
            return try makeSentRecordZoneChangesEvent(savedRecords: changes.savedRecords)
        case .willFetchChanges:
            return .willFetchChanges
        case .willSendChanges:
            return .willSendChanges
        case .willFetchRecordZoneChanges, .didFetchChanges, .didFetchRecordZoneChanges, .didSendChanges, .fetchedDatabaseChanges, .sentDatabaseChanges:
            return nil
        @unknown default:
            return nil
        }
    }
}

@available(macOS 14.0, *)
public final class CloudKitPrivateSyncEngineDelegate: NSObject, CKSyncEngineDelegate, @unchecked Sendable {
    private let mapper: CloudKitPrivateSyncMapper
    private let recordsProvider: () async -> [PrivateSyncRecord]
    private let pendingDeletionsProvider: () async -> [String]
    private let deletionZoneName: String
    private let eventHandler: (PrivateSyncEngineEvent) async -> Void

    public init(
        mapper: CloudKitPrivateSyncMapper = CloudKitPrivateSyncMapper(),
        recordsProvider: @escaping () async -> [PrivateSyncRecord],
        pendingDeletionsProvider: @escaping () async -> [String] = { [] },
        deletionZoneName: String = "TermyPrivateSync",
        eventHandler: @escaping (PrivateSyncEngineEvent) async -> Void
    ) {
        self.mapper = mapper
        self.recordsProvider = recordsProvider
        self.pendingDeletionsProvider = pendingDeletionsProvider
        self.deletionZoneName = deletionZoneName
        self.eventHandler = eventHandler
        super.init()
    }

    public func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        guard let runtimeEvent = try? mapper.makePrivateSyncEngineEvent(from: event) else { return }
        await eventHandler(runtimeEvent)
    }

    public func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let records = await recordsProvider()
        let deletions = await pendingDeletionsProvider()
        guard !records.isEmpty || !deletions.isEmpty else { return nil }
        return makeRecordZoneChangeBatch(for: records, deleting: deletions)
    }

    public func makeRecordZoneChangeBatch(
        for records: [PrivateSyncRecord],
        deleting deletedRecordNames: [String] = []
    ) -> CKSyncEngine.RecordZoneChangeBatch {
        // D2: tombstone the locally-removed records (e.g. trimmed ai-history) so they
        // don't resurrect on the next fetch.
        let zoneID = CKRecordZone.ID(zoneName: deletionZoneName, ownerName: CKCurrentUserDefaultName)
        return CKSyncEngine.RecordZoneChangeBatch(
            recordsToSave: records.map(mapper.makeCloudKitRecord),
            recordIDsToDelete: deletedRecordNames.map { CKRecord.ID(recordName: $0, zoneID: zoneID) },
            atomicByZone: true
        )
    }
}

@available(macOS 14.0, *)
public final class CloudKitPrivateSyncEngineSession: @unchecked Sendable {
    public static let defaultSubscriptionID = "TermyPrivateSyncZoneChanges"
    public static let defaultAutomaticallySync = false

    public let syncEngine: CKSyncEngine
    public let delegate: CloudKitPrivateSyncEngineDelegate
    public let automaticallySync: Bool
    public let subscriptionID: String

    public init(
        database: CKDatabase,
        stateSerialization: CKSyncEngine.State.Serialization?,
        delegate: CloudKitPrivateSyncEngineDelegate,
        automaticallySync: Bool = CloudKitPrivateSyncEngineSession.defaultAutomaticallySync,
        subscriptionID: String = CloudKitPrivateSyncEngineSession.defaultSubscriptionID
    ) {
        let configuration = Self.makeConfiguration(
            database: database,
            stateSerialization: stateSerialization,
            delegate: delegate,
            automaticallySync: automaticallySync,
            subscriptionID: subscriptionID
        )

        self.delegate = delegate
        self.automaticallySync = automaticallySync
        self.subscriptionID = subscriptionID
        self.syncEngine = CKSyncEngine(configuration)
    }

    public static func makeConfiguration(
        database: CKDatabase,
        stateSerialization: CKSyncEngine.State.Serialization?,
        delegate: CloudKitPrivateSyncEngineDelegate,
        automaticallySync: Bool = CloudKitPrivateSyncEngineSession.defaultAutomaticallySync,
        subscriptionID: String = CloudKitPrivateSyncEngineSession.defaultSubscriptionID
    ) -> CKSyncEngine.Configuration {
        var configuration = CKSyncEngine.Configuration(
            database: database,
            stateSerialization: stateSerialization,
            delegate: delegate
        )
        configuration.automaticallySync = automaticallySync
        configuration.subscriptionID = subscriptionID
        return configuration
    }

    public func fetchChanges() async throws {
        try await syncEngine.fetchChanges()
    }

    public func sendChanges() async throws {
        try await syncEngine.sendChanges()
    }

    public func cancelOperations() async {
        await syncEngine.cancelOperations()
    }
}

public final class CloudKitPrivateSyncClient {
    private let container: CKContainer
    private let database: CKDatabase
    private let mapper: CloudKitPrivateSyncMapper

    public init(
        containerIdentifier: String? = nil,
        mapper: CloudKitPrivateSyncMapper = CloudKitPrivateSyncMapper()
    ) {
        if let containerIdentifier {
            self.container = CKContainer(identifier: containerIdentifier)
        } else {
            self.container = CKContainer.default()
        }
        self.database = container.privateCloudDatabase
        self.mapper = mapper
    }

    public func accountStatus() async -> PrivateSyncCloudAccountStatus {
        do {
            switch try await container.accountStatus() {
            case .available:
                return .available
            case .noAccount:
                return .noAccount
            case .restricted:
                return .restricted
            case .couldNotDetermine:
                return .couldNotDetermine
            case .temporarilyUnavailable:
                return .temporarilyUnavailable
            @unknown default:
                return .couldNotDetermine
            }
        } catch {
            return .couldNotDetermine
        }
    }

    public func save(_ records: [PrivateSyncRecord]) async throws -> [PrivateSyncRecord] {
        guard let zoneName = records.first?.zoneName else { return [] }
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        _ = try? await database.save(CKRecordZone(zoneID: zoneID))
        let cloudRecords = records.map(mapper.makeCloudKitRecord)
        let result = try await database.modifyRecords(
            saving: cloudRecords,
            deleting: [],
            savePolicy: .changedKeys,
            atomically: true
        )
        return try result.saveResults.values.map { try mapper.makePrivateSyncRecord(from: $0.get()) }
    }

    public func fetch(recordType: String, zoneName: String = "TermyPrivateSync") async throws -> [PrivateSyncRecord] {
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        let query = CKQuery(recordType: "Termy\(recordType)", predicate: NSPredicate(value: true))
        let result = try await database.records(matching: query, inZoneWith: zoneID)
        return try result.matchResults.map { _, recordResult in
            try mapper.makePrivateSyncRecord(from: recordResult.get())
        }
    }

    public func ensureSubscription() async throws {
        _ = try await database.save(mapper.makeZoneSubscription())
    }
}
#endif
