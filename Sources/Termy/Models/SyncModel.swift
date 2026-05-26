import Foundation
import Observation
import TermySync

/// Private-sync-domain state, extracted from the `TermyStore` god-object as
/// part of the strangler-facade decomposition (M2c-2). `@Observable` +
/// `@MainActor`: the future state is views observing this model directly via
/// `@Environment(AppModel.self)`; until then `TermyStore` forwards to it.
@MainActor
@Observable
final class SyncModel {
    var privateSyncRecords: [PrivateSyncRecord] = []
    var privateSyncStatus = "Not checked"
    var privateSyncPendingOperations: [PrivateSyncOperation] = []
    var privateSyncLastOperationResults: [PrivateSyncOperationResult] = []
    var privateSyncChangeToken: PrivateSyncChangeToken?
    var privateSyncEngineAccountState: PrivateSyncEngineAccountState?

    init() {}
}
