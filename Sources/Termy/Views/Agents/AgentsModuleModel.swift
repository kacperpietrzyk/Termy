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

    // MARK: M7 — pre-launch "where the agent launches" hint.
    /// Names the concrete directory a spawn will run in, BEFORE launch. For `.here`
    /// this is the selected session's cwd (else projectRoot); for `.worktree` the
    /// exact path uses a random shortID generated at launch, so we name only the
    /// source repo ("new worktree from …") rather than fabricate a leaf. Paths under
    /// $HOME render with `~` so the label never leaks a raw /Users/<name>.
    static func resolvedLaunchTarget(selectedCwd: String?, projectRoot: String, isolation: AgentIsolationKind) -> String {
        func abbrev(_ p: String) -> String { (p as NSString).abbreviatingWithTildeInPath }
        switch isolation {
        case .here:
            let cwd = (selectedCwd?.isEmpty == false) ? selectedCwd! : projectRoot
            return abbrev(cwd)
        case .worktree:
            return "new worktree from \(abbrev(projectRoot))"
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
        case hook, pty, osc, proc, transcript
        var label: String {
            switch self {
            case .hook: return "hook"; case .pty: return "pty"
            case .osc:  return "osc 133"; case .proc: return "proc"
            case .transcript: return "transcript"
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
            .init(key: "context", value: contextUsageLabel(v),
                  tag: v.usage == nil ? nil : .transcript),
        ]
    }

    // MARK: AD-6 — token / context-window indicator (CC transcript, read-only).

    /// The signals-card "context" value. Honest CC/Codex asymmetry: Codex (no
    /// transcript) shows "n/a"; a CC session with no parsed usage yet shows "—";
    /// otherwise "57.6k / 200k · 29%", or "57.6k tokens" when the model's window
    /// is unknown (no fabricated denominator). Never invents a number.
    static func contextUsageLabel(_ v: AgentSessionVitals) -> String {
        guard v.agentType == .claudeCode else { return "n/a" }
        guard let usage = v.usage else { return "—" }
        let used = compactTokens(usage.contextTokens)
        if let window = usage.contextWindow, let frac = usage.fraction {
            return "\(used) / \(compactTokens(window)) · \(Int((frac * 100).rounded()))%"
        }
        return "\(used) tokens"
    }

    /// Compact token count: 57609 → "57.6k", 1_000_000 → "1M", 950 → "950".
    static func compactTokens(_ n: Int) -> String {
        switch n {
        case 1_000_000...:
            let m = Double(n) / 1_000_000
            return m == m.rounded() ? "\(Int(m))M" : String(format: "%.1fM", m)
        case 1_000...:
            let k = Double(n) / 1_000
            return k == k.rounded() ? "\(Int(k))k" : String(format: "%.1fk", k)
        default:
            return "\(n)"
        }
    }

    // MARK: §5.8 — plan progress.
    static func planProgress(_ plan: [AgentPlanStep]) -> (done: Int, total: Int) {
        (plan.filter { $0.state == .done }.count, plan.count)
    }

    // MARK: AD-1 — dense dashboard row.
    /// The honest "last action" line for a dashboard row. Prefers the live plan
    /// signal (the active step's secondary `activeForm`, else its subject), then
    /// the most recently touched file, and finally falls back to the state label.
    /// NEVER fabricates an action: Codex sessions (no PostToolUse hooks → empty
    /// plan/touched) correctly degrade to the bare state label.
    static func lastAction(_ v: AgentSessionVitals) -> String {
        if let active = v.plan.first(where: { $0.state == .active }) {
            if let sub = active.sub, !sub.isEmpty { return sub }
            if !active.text.isEmpty { return active.text }
        }
        if let file = v.touched.last, !file.isEmpty {
            return "edited \((file as NSString).lastPathComponent)"
        }
        return stateLabel(v.state)
    }

    /// Compact "±files" signal for a dashboard row: working-tree dirty count if
    /// any, else the count of files the agent has touched this session, else nil
    /// (render nothing rather than a fabricated zero).
    static func dirtySummary(_ v: AgentSessionVitals) -> String? {
        if v.dirtyCount > 0 { return "±\(v.dirtyCount)" }
        if !v.touched.isEmpty { return "±\(v.touched.count)" }
        return nil
    }

    /// Waiting-first dashboard ordering (reuses the shared flat order).
    static func dashboardOrder(_ vitals: [AgentSessionVitals]) -> [AgentSessionVitals] {
        agentVitalsFlatOrder(vitals)
    }

    /// Clamp a keyboard-driven selection index into the current row range.
    /// Returns nil when there are no rows.
    static func clampedSelection(_ index: Int, count: Int) -> Int? {
        guard count > 0 else { return nil }
        return max(0, min(index, count - 1))
    }
}
