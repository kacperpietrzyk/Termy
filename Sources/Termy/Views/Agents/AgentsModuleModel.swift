import Foundation
import TermyCore

/// Pure, view-free helpers for the v3 Agents module (DESIGN.md §6.2). Unit-tested
/// directly; the SwiftUI views stay thin. Reuses `DesktopModel.relativeAge` for
/// compact ages. Honest-by-construction: no field here can fabricate an
/// unmodelled value (no model string, no ports, no tool version).
enum AgentsModuleModel {

    // MARK: §4.4 — which agent the module shows.
    /// Keeps a still-valid current selection; otherwise the highest-priority
    /// agent (waiting → running → idle → recent). `nil` when there are no agents.
    static func activeAgentID(vitals: [AgentSessionVitals], selected: UUID?) -> UUID? {
        if let selected, vitals.contains(where: { $0.id == selected }) { return selected }
        return agentVitalsFlatOrder(vitals).first?.id
    }

    // MARK: §5.6 — live-chip / state labels.
    enum ChipKind: Equatable { case waiting, running, idle, ended }

    static func chipKind(_ state: AgentActivityState) -> ChipKind {
        switch state {
        case .waitingForInput: return .waiting
        case .working:         return .running
        case .idle:            return .idle
        case .exited:          return .ended
        }
    }

    static func stateLabel(_ state: AgentActivityState) -> String {
        switch state {
        case .waitingForInput: return "waiting for input"
        case .working:         return "running"
        case .idle:            return "idle"
        case .exited:          return "ended"
        }
    }

    // MARK: §4.3 — dt-header sub-text spans.
    enum SubtitleAccent: Equatable { case plain, branch }
    struct SubtitleSpan: Equatable { let text: String; let accent: SubtitleAccent }

    static func headerSubtitle(_ v: AgentSessionVitals, now: Date = Date()) -> [SubtitleSpan] {
        var spans: [SubtitleSpan] = [
            .init(text: v.agentType.displayName, accent: .plain),
            .init(text: " · your auth", accent: .plain),
        ]
        if let branch = v.branch, !branch.isEmpty {
            spans.append(.init(text: " · ", accent: .plain))
            spans.append(.init(text: branch, accent: .branch))
        }
        spans.append(.init(
            text: " · started \(DesktopModel.relativeAge(now.timeIntervalSince(v.startedAt))) ago",
            accent: .plain))
        return spans
    }

    // MARK: §5.5 — vitals strip chips.
    enum ChipHue: Equatable { case neutral, git, agent }
    struct VitalsChip: Equatable {
        let key: String?        // small dim leading key (e.g. "cwd"); nil = none
        let value: String
        let hue: ChipHue
        let icon: String?       // SF symbol; nil = none
    }

    static func isolationLabel(_ kind: AgentIsolationKind) -> String {
        switch kind {
        case .here:     return "here"
        case .worktree: return "worktree"
        }
    }

    static func vitalsChips(_ v: AgentSessionVitals, now: Date = Date()) -> [VitalsChip] {
        var chips: [VitalsChip] = []
        if let branch = v.branch, !branch.isEmpty {
            chips.append(.init(key: nil, value: branch, hue: .git, icon: "arrow.triangle.branch"))
        }
        if let cwd = v.cwd, !cwd.isEmpty {
            chips.append(.init(key: "cwd", value: cwd, hue: .neutral, icon: nil))
        }
        if v.dirtyCount > 0 {
            chips.append(.init(key: nil, value: "●\(v.dirtyCount) dirty", hue: .agent, icon: nil))
        } else {
            chips.append(.init(key: nil, value: "clean", hue: .neutral, icon: "checkmark"))
        }
        chips.append(.init(key: "isolation", value: isolationLabel(v.isolation), hue: .neutral, icon: nil))
        chips.append(.init(key: "started",
                           value: "\(DesktopModel.relativeAge(now.timeIntervalSince(v.startedAt))) ago",
                           hue: .neutral, icon: nil))
        chips.append(.init(key: nil, value: "your auth", hue: .neutral, icon: "lock"))
        return chips
    }

    // MARK: signals card — value + truthful source tag.
    enum SourceTag: Equatable {
        case hook, pty, osc, proc
        var label: String {
            switch self {
            case .hook: return "hook"; case .pty: return "pty"
            case .osc:  return "osc 133"; case .proc: return "proc"
            }
        }
    }
    struct SignalRow: Equatable { let key: String; let value: String; let tag: SourceTag? }

    private static func detection(_ state: AgentActivityState) -> (String, SourceTag) {
        switch state {
        case .waitingForInput: return ("awaiting-input hook", .hook)
        case .working:         return ("live byte-tap", .pty)
        case .idle:            return ("quiescence elapsed", .pty)
        case .exited:          return ("process exited", .proc)
        }
    }

    static func signalRows(_ v: AgentSessionVitals, now: Date = Date()) -> [SignalRow] {
        let det = detection(v.state)
        return [
            .init(key: "tool", value: v.agentType.displayName, tag: .proc),
            .init(key: "started",
                  value: "\(DesktopModel.relativeAge(now.timeIntervalSince(v.startedAt))) ago", tag: .proc),
            .init(key: "last activity",
                  value: "\(DesktopModel.relativeAge(now.timeIntervalSince(v.stateChangedAt))) ago", tag: .pty),
            .init(key: "state", value: "\(stateLabel(v.state)) · \(det.0)", tag: det.1),
            .init(key: "isolation", value: isolationLabel(v.isolation), tag: nil),
            .init(key: "touched",
                  value: "\(v.touched.count) \(v.touched.count == 1 ? "file" : "files")", tag: .hook),
        ]
    }

    // MARK: §5.8 — plan progress.
    static func planProgress(_ plan: [AgentPlanStep]) -> (done: Int, total: Int) {
        (plan.filter { $0.state == .done }.count, plan.count)
    }
}
