import AppKit
import Foundation
import TermyCore
import UserNotifications

final class NativeRemoteNotificationCenter: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NativeRemoteNotificationCenter.makeShared()

    private let center: UNUserNotificationCenter?

    /// FB-3-3: invoked (main actor) when the user clicks an agent-state
    /// notification; wired by `TermyApp` to `TermyStore.focusAgentSession`.
    var onAgentNotificationActivated: ((UUID) -> Void)?

    init(center: UNUserNotificationCenter?) {
        self.center = center
        super.init()
        center?.delegate = self
    }

    private static func makeShared() -> NativeRemoteNotificationCenter {
        guard Bundle.main.bundlePath.hasSuffix(".app") else {
            return NativeRemoteNotificationCenter(center: nil)
        }
        return NativeRemoteNotificationCenter(center: .current())
    }

    func requestAuthorization() {
        center?.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func deliver(_ notification: RemoteSessionNotification) {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.categoryIdentifier = notification.category.rawValue
        if let sessionID = notification.sessionID {
            content.userInfo["sessionID"] = sessionID.uuidString
        }
        let request = UNNotificationRequest(
            identifier: notification.identifier,
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Show banners even when Termy is frontmost (default behaviour suppresses
    /// them while the app is foreground, which would make agent banners useless).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if notification.request.content.categoryIdentifier == RemoteSessionNotificationCategory.agentState.rawValue {
            completionHandler([.banner, .sound])
        } else {
            completionHandler([])
        }
    }

    /// Click-to-focus: route the embedded session UUID back to the store.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier,
              let raw = response.notification.request.content.userInfo["sessionID"] as? String,
              let id = UUID(uuidString: raw) else { return }
        Task { @MainActor in self.onAgentNotificationActivated?(id) }
    }
}
