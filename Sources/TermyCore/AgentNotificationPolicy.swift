import Foundation

/// FB-3-3: pure decision — does an agent state transition warrant a native
/// notification, and what does it say? No I/O, no clock, no app types, so it is
/// unit-testable like `AgentStateMachine`. The store calls this *only* for a
/// genuine transition (`changed == true`), so no "previous state" is needed.
public enum AgentNotificationPolicy {
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
                body = "Finished (status \(code))"
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
