import Foundation

public enum RemoteSessionNotificationCategory: String, Equatable, Sendable {
    case remoteSession
    case agentState
}

public struct RemoteSessionNotification: Equatable, Sendable {
    public let identifier: String
    public let title: String
    public let body: String
    public let category: RemoteSessionNotificationCategory
    public let sessionID: UUID?

    public init(
        identifier: String,
        title: String,
        body: String,
        category: RemoteSessionNotificationCategory,
        sessionID: UUID? = nil
    ) {
        self.identifier = identifier
        self.title = title
        self.body = body
        self.category = category
        self.sessionID = sessionID
    }

    public static func rdpReconnectScheduled(
        profileName: String,
        attempt: Int,
        delaySeconds: Int
    ) -> RemoteSessionNotification {
        RemoteSessionNotification(
            identifier: "rdp-reconnect-\(profileName)-\(attempt)",
            title: "RDP reconnect scheduled",
            body: "\(profileName) will retry connection attempt \(attempt) in \(delaySeconds)s.",
            category: .remoteSession
        )
    }

    /// FB-3-3: an agent session changed to an actionable state. `identifier` is
    /// keyed by session UUID so a newer transition *replaces* the prior banner.
    public static func agentStateChanged(
        sessionID: UUID,
        agent: CLIAgent,
        cwdBasename: String?,
        bodyText: String
    ) -> RemoteSessionNotification {
        let title: String
        if let cwdBasename, !cwdBasename.isEmpty {
            title = "\(agent.displayName) — \(cwdBasename)"
        } else {
            title = agent.displayName
        }
        return RemoteSessionNotification(
            identifier: "agent-state-\(sessionID.uuidString)",
            title: title,
            body: bodyText,
            category: .agentState,
            sessionID: sessionID
        )
    }
}
