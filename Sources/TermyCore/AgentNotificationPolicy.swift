import Foundation

/// AD-2: the kind of attention an agent transition (or a listed attention-needing
/// agent) represents. Derived purely — NOT an `AgentActivityState`; an agent that
/// `.exited` with a non-zero status is an *error*, but that is a property of the
/// exit, not a new lifecycle state, so it stays in the policy and never ripples
/// into the state machine. Drives per-type icon/color in the in-app popover.
public enum AgentNotificationKind: String, Sendable, Equatable, CaseIterable {
    case waitingForInput   // hook signal: agent finished a turn, wants the user
    case exited            // process terminated cleanly (status 0 / unknown)
    case error             // process terminated with a non-zero status
}

/// FB-3-3: pure decision — does an agent state transition warrant a native
/// notification, and what does it say? No I/O, no clock, no app types, so it is
/// unit-testable like `AgentStateMachine`. The store calls this *only* for a
/// genuine transition (`changed == true`), so no "previous state" is needed.
public enum AgentNotificationPolicy {
    /// AD-2: the userInfo key the native center round-trips the session UUID
    /// through (delivery sets it; the click delegate reads it back).
    public static let sessionUserInfoKey = "sessionID"

    /// AD-2: classify an exited/waiting agent into a notification *kind*. Pure;
    /// shared by the banner policy and the in-app popover so both agree on type.
    /// `state == .working`/`.idle` is not an attention kind → `nil`.
    public static func kind(
        for state: AgentActivityState, lastExitCode: Int32?
    ) -> AgentNotificationKind? {
        switch state {
        case .waitingForInput:
            return .waitingForInput
        case .exited:
            if let code = lastExitCode, code != 0 { return .error }
            return .exited
        case .working, .idle:
            return nil
        }
    }

    /// AD-2: round-trip the deep-link UUID through a notification's userInfo.
    /// Extracted as a pure pair so the deep-link routing is unit-testable without
    /// a signed build / a live `UNUserNotificationCenter`.
    public static func encodeSessionUserInfo(_ sessionID: UUID) -> [String: String] {
        [sessionUserInfoKey: sessionID.uuidString]
    }

    public static func decodeSession(fromUserInfo userInfo: [AnyHashable: Any]) -> UUID? {
        guard let raw = userInfo[sessionUserInfoKey] as? String else { return nil }
        return UUID(uuidString: raw)
    }

    /// Per-transition context the store assembles from the session.
    public struct Context: Sendable {
        public let agent: CLIAgent
        public let cwdBasename: String?
        public let lastExitCode: Int32?
        /// True when the user is already viewing this exact agent
        /// (app active AND it is the selected session) → no banner.
        public let suppressed: Bool

        public init(
            agent: CLIAgent,
            cwdBasename: String?,
            lastExitCode: Int32?,
            suppressed: Bool
        ) {
            self.agent = agent
            self.cwdBasename = cwdBasename
            self.lastExitCode = lastExitCode
            self.suppressed = suppressed
        }
    }

    /// Returns a notification for an actionable transition, else `nil`.
    public static func notification(
        for newState: AgentActivityState,
        sessionID: UUID,
        context: Context
    ) -> RemoteSessionNotification? {
        guard !context.suppressed else { return nil }
        let body: String
        switch newState {
        case .waitingForInput:
            body = "Waiting for your input"
        case .exited:
            if let code = context.lastExitCode {
                // AD-2: a non-zero status is a *failure*, not a neutral finish —
                // word it so the banner alone communicates the kind.
                body = code == 0 ? "Finished (status 0)" : "Failed (status \(code))"
            } else {
                body = "Finished"
            }
        case .working, .idle:
            return nil
        }
        return .agentStateChanged(
            sessionID: sessionID,
            agent: context.agent,
            cwdBasename: context.cwdBasename,
            bodyText: body
        )
    }
}
