import Foundation

/// Live activity state of a CLI-agent session (FB-3-2). Only sessions with a
/// non-nil `agentType` ever carry a meaningful value.
public enum AgentActivityState: String, Sendable, Equatable {
    case working          // just launched, output flowing, or hook reports active
    case idle             // quiescent (heuristic), process alive, no attention signal
    case waitingForInput  // hook signal: the agent finished a turn / wants the user
    case exited           // process terminated

    /// Human-readable label (e.g. for the sidebar status-dot tooltip).
    public var label: String {
        switch self {
        case .working: "Working"
        case .idle: "Idle"
        case .waitingForInput: "Waiting for input"
        case .exited: "Exited"
        }
    }
}

/// A discrete, per-tool "the agent did something" signal delivered out-of-band
/// (Claude Code hooks → state files). Distinct from the passive byte heuristic.
public enum AgentHookSignal: Sendable, Equatable {
    case active   // SessionStart
    case waiting  // Stop / Notification
}

/// Inputs to the state machine. The store feeds these; the reducer holds no clock.
public enum AgentStateEvent: Sendable, Equatable {
    case activityTick       // any parser event observed on the byte-tap
    case quiescenceElapsed  // the store's per-session silence timer fired
    case hook(AgentHookSignal)
    case processExited
}

/// Pure reducer for one agent session's activity state. Hook events are
/// authoritative; the quiescence heuristic may only set `.idle`, never demote a
/// hook-set `.waitingForInput`, and `.exited` is terminal.
public struct AgentStateMachine: Sendable, Equatable {
    public private(set) var state: AgentActivityState

    public init(state: AgentActivityState = .working) {
        self.state = state
    }

    /// Applies an event. Returns `true` when `state` changed.
    @discardableResult
    public mutating func handle(_ event: AgentStateEvent) -> Bool {
        guard state != .exited else { return false }   // terminal
        let previous = state
        switch event {
        case .processExited:
            state = .exited
        case .hook(.waiting):
            state = .waitingForInput
        case .hook(.active), .activityTick:
            state = .working
        case .quiescenceElapsed:
            if state == .working { state = .idle }
        }
        return state != previous
    }
}
