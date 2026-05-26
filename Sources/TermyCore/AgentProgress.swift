import Foundation

/// One step in an agent's reconstructed plan (FB-3-5). Built from Claude Code
/// `TaskCreate`/`TaskUpdate` tool calls; `state` mirrors the redesign's stepper.
public struct AgentPlanStep: Sendable, Equatable, Identifiable {
    public enum State: Sendable, Equatable { case todo, active, done }
    public let id: String       // Task id (from the TaskCreate response)
    public let text: String     // subject
    public let state: State
    public let sub: String?     // activeForm — the stepper's secondary line; nil otherwise

    public init(id: String, text: String, state: State, sub: String?) {
        self.id = id; self.text = text; self.state = state; self.sub = sub
    }
}

public extension AgentPlanStep.State {
    /// Maps a Claude Code task `status` string. `nil` for "deleted" (handled by
    /// the caller, which removes the step) and any unknown value.
    init?(claudeStatus: String?) {
        switch claudeStatus {
        case "pending":     self = .todo
        case "in_progress": self = .active
        case "completed":   self = .done
        default:            return nil
        }
    }
}

/// Accumulated per-agent progress: plan steps + touched files (FB-3-5).
public struct AgentProgress: Sendable, Equatable {
    public var plan: [AgentPlanStep]   // creation order
    public var touched: [String]       // deduped, first-seen order

    public init(plan: [AgentPlanStep], touched: [String]) {
        self.plan = plan; self.touched = touched
    }
    public static let empty = AgentProgress(plan: [], touched: [])
}

/// A captured Claude Code `PostToolUse` payload, narrowed to the fields FB-3-5
/// reads. Decoding is lenient on purpose: `tool_input`/`tool_response` shapes
/// vary per tool and the hook's `tool_response` shape is unverified, so a
/// missing or wrong-shaped value yields a default/`nil` rather than throwing —
/// a TaskCreate event must never be dropped just because its response was a
/// string instead of `{task:{id}}`. Only `tool_name` is required.
public struct AgentToolEvent: Decodable, Sendable, Equatable {
    public let toolName: String
    public let input: Input
    public let response: Response?

    enum CodingKeys: String, CodingKey {
        case toolName = "tool_name"
        case input = "tool_input"
        case response = "tool_response"
    }

    public init(toolName: String, input: Input, response: Response?) {
        self.toolName = toolName; self.input = input; self.response = response
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        toolName = try c.decode(String.self, forKey: .toolName)
        input = (try? c.decode(Input.self, forKey: .input)) ?? .empty
        response = try? c.decode(Response.self, forKey: .response)  // nil if absent OR not an object
    }

    public struct Input: Decodable, Sendable, Equatable {
        public let taskId: String?
        public let status: String?
        public let subject: String?
        public let activeForm: String?
        public let filePath: String?
        enum CodingKeys: String, CodingKey {
            case taskId, status, subject, activeForm
            case filePath = "file_path"
        }
        public init(taskId: String?, status: String?, subject: String?,
                    activeForm: String?, filePath: String?) {
            self.taskId = taskId; self.status = status; self.subject = subject
            self.activeForm = activeForm; self.filePath = filePath
        }
        public static let empty = Input(
            taskId: nil, status: nil, subject: nil, activeForm: nil, filePath: nil)
    }
    public struct Response: Decodable, Sendable, Equatable {
        public let task: Task?
        public init(task: Task?) { self.task = task }
        public struct Task: Decodable, Sendable, Equatable {
            public let id: String?
            public init(id: String?) { self.id = id }
        }
    }
}

/// Pure fold of one captured tool event into accumulated progress. Never throws;
/// an unknown tool, a missing field, or an update to an unknown task id leaves
/// `progress` unchanged.
public func reduceAgentProgress(_ progress: AgentProgress,
                                applying event: AgentToolEvent) -> AgentProgress {
    var p = progress
    switch event.toolName {
    case "TaskCreate":
        // Prefer the response's task id; otherwise derive a creation-order ordinal
        // ("1","2",...) — the scheme real transcripts show TaskUpdate.taskId using —
        // computed as max existing numeric id + 1 so it survives a prior deletion.
        let id = event.response?.task?.id
            ?? String((p.plan.compactMap { Int($0.id) }.max() ?? 0) + 1)
        p.plan.append(AgentPlanStep(
            id: id, text: event.input.subject ?? "", state: .todo, sub: event.input.activeForm))
    case "TaskUpdate":
        guard let taskId = event.input.taskId,
              let idx = p.plan.firstIndex(where: { $0.id == taskId }) else { break }
        if event.input.status == "deleted" {
            p.plan.remove(at: idx)
        } else {
            let prev = p.plan[idx]
            p.plan[idx] = AgentPlanStep(
                id: prev.id,
                text: event.input.subject ?? prev.text,
                state: AgentPlanStep.State(claudeStatus: event.input.status) ?? prev.state,
                sub: event.input.activeForm ?? prev.sub)
        }
    case "Edit", "Write", "MultiEdit":
        if let path = event.input.filePath, !p.touched.contains(path) {
            p.touched.append(path)
        }
    default:
        break
    }
    return p
}
