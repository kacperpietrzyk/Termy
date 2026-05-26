import Foundation
import TermyCore
import TermySync

@MainActor
final class PrivateSyncBackgroundScheduler {
    private let configuration: PrivateSyncBackgroundTaskConfiguration
    private var activityScheduler: NSBackgroundActivityScheduler?

    init(configuration: PrivateSyncBackgroundTaskConfiguration = .termDefault) {
        self.configuration = configuration
    }

    func register(store: TermyStore) {
        guard activityScheduler == nil else { return }

        let scheduler = NSBackgroundActivityScheduler(identifier: configuration.appRefreshIdentifier)
        scheduler.interval = 15 * 60
        scheduler.tolerance = 5 * 60
        scheduler.repeats = true
        scheduler.qualityOfService = .utility
        scheduler.schedule { [weak store] completion in
            Task { @MainActor in
                guard let store else {
                    completion(.deferred)
                    return
                }
                _ = await store.runPrivateSyncEvent(.silentRemoteNotification)
                completion(.finished)
            }
        }
        activityScheduler = scheduler
    }

    func scheduleAppRefresh(after delay: TimeInterval = 15 * 60) {
        activityScheduler?.interval = delay
    }
}
