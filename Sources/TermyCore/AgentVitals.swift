import Foundation

/// How an agent session is isolated from the working tree (FB-3-1).
public enum AgentIsolationKind: Sendable, Equatable {
    case here                       // launched in the active cwd, no worktree
    case worktree(path: String)
}

/// The full per-agent snapshot the v3 redesign's Agents module consumes
/// (vitals strip + sub-rail). Pure value type; formatting (e.g. "waiting 24s")
/// happens at the view edge from the `Date` fields.
public struct AgentSessionVitals: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let name: String
    public let agentType: CLIAgent
    public let state: AgentActivityState
    public let cwd: String?
    public let branch: String?
    public let dirtyCount: Int
    public let ahead: Int
    public let behind: Int
    public let isolation: AgentIsolationKind
    // AD-1 decision: kept deferred-empty + hidden from the UI (no honest live
    // source for per-agent listening ports yet). Field retained — not dropped —
    // because the data layer + FB34 tests reference it and a future slice can
    // fill it; never-fabricate means render nothing rather than invent a value.
    public let ports: [Int]          // always [] until a real probe exists
    public let startedAt: Date
    public let stateChangedAt: Date
    public let plan: [AgentPlanStep]
    public let touched: [String]

    public init(
        id: UUID, name: String, agentType: CLIAgent, state: AgentActivityState,
        cwd: String?, branch: String?, dirtyCount: Int, ahead: Int, behind: Int,
        isolation: AgentIsolationKind, ports: [Int], startedAt: Date, stateChangedAt: Date,
        plan: [AgentPlanStep] = [], touched: [String] = []
    ) {
        self.id = id; self.name = name; self.agentType = agentType; self.state = state
        self.cwd = cwd; self.branch = branch; self.dirtyCount = dirtyCount
        self.ahead = ahead; self.behind = behind; self.isolation = isolation
        self.ports = ports; self.startedAt = startedAt; self.stateChangedAt = stateChangedAt
        self.plan = plan; self.touched = touched
    }
}

public struct GroupedAgentVitals: Sendable, Equatable {
    public let waiting: [AgentSessionVitals]   // .waitingForInput
    public let running: [AgentSessionVitals]   // .working
    public let idle: [AgentSessionVitals]      // .idle
    public let recent: [AgentSessionVitals]    // .exited (in-process only)
}

public func groupAgentVitals(_ vitals: [AgentSessionVitals]) -> GroupedAgentVitals {
    GroupedAgentVitals(
        waiting: vitals.filter { $0.state == .waitingForInput },
        running: vitals.filter { $0.state == .working },
        idle: vitals.filter { $0.state == .idle },
        recent: vitals.filter { $0.state == .exited })
}

/// Flat ⌘K ordering: waiting → running → idle → recent; newest state-change first within a group.
public func agentVitalsFlatOrder(_ vitals: [AgentSessionVitals]) -> [AgentSessionVitals] {
    func rank(_ state: AgentActivityState) -> Int {
        switch state {
        case .waitingForInput: 0
        case .working: 1
        case .idle: 2
        case .exited: 3
        }
    }
    return vitals.sorted {
        let lhs = rank($0.state), rhs = rank($1.state)
        if lhs != rhs { return lhs < rhs }
        return $0.stateChangedAt > $1.stateChangedAt
    }
}

/// AD-5: keyboard-first fleet navigation over the flat, waiting-first order.
///
/// `agentFleetTarget(index:in:)` resolves a 1-based fleet slot (the digit the
/// user pressed) to the session id at that position in `agentVitalsFlatOrder`,
/// or nil when the slot is out of range. `nextAgentInGroup(state:after:in:)`
/// cycles, with wraparound, through the subgroup of a given state relative to
/// the current selection: when the selection is already inside the group it
/// advances to the next member (wrapping past the end), and when it is not (no
/// selection, or selection is in another group) it jumps to the first member.
/// Both are pure so they unit-test without the store or a live PTY.

/// Session id at the 1-based `index` in the flat fleet order, or nil if out of range.
public func agentFleetTarget(index oneBased: Int, in vitals: [AgentSessionVitals]) -> UUID? {
    guard oneBased >= 1 else { return nil }
    let ordered = agentVitalsFlatOrder(vitals)
    let zeroBased = oneBased - 1
    guard zeroBased < ordered.count else { return nil }
    return ordered[zeroBased].id
}

/// Next session id in the `state` subgroup, cycling with wraparound relative to
/// `currentID`. Returns nil when the group is empty.
public func nextAgentInGroup(
    state: AgentActivityState, after currentID: UUID?, in vitals: [AgentSessionVitals]
) -> UUID? {
    let group = agentVitalsFlatOrder(vitals).filter { $0.state == state }
    guard !group.isEmpty else { return nil }
    guard let currentID, let current = group.firstIndex(where: { $0.id == currentID }) else {
        return group[0].id   // selection not in this group → jump to its first member
    }
    return group[(current + 1) % group.count].id
}

/// AD-2: one entry in the in-app notifications popover — an agent that needs
/// attention (waiting for input, or finished/failed), tagged by `kind` so the
/// view renders per-type icon/color. Pure value type; built from the vitals plus
/// a per-session exit-code lookup so the *error* vs clean-*exit* split is honest.
public struct AgentAttentionItem: Sendable, Equatable, Identifiable {
    public let vitals: AgentSessionVitals
    public let kind: AgentNotificationKind
    public var id: UUID { vitals.id }

    public init(vitals: AgentSessionVitals, kind: AgentNotificationKind) {
        self.vitals = vitals
        self.kind = kind
    }
}

/// AD-2: attention list for the popover, in the same waiting-first priority as
/// `agentVitalsFlatOrder`, restricted to agents with an actionable `kind`
/// (waiting / exited / error). `exitCode` resolves a session's last status so an
/// abnormal exit surfaces as `.error`; a missing entry degrades to clean exit.
public func agentAttentionItems(
    _ vitals: [AgentSessionVitals], exitCode: (UUID) -> Int32?
) -> [AgentAttentionItem] {
    agentVitalsFlatOrder(vitals).compactMap { v in
        guard let kind = AgentNotificationPolicy.kind(
            for: v.state, lastExitCode: exitCode(v.id)) else { return nil }
        return AgentAttentionItem(vitals: v, kind: kind)
    }
}

/// Git facts for an agent's cwd. Derived off-main and cached by `AgentsModel`.
public struct GitVitals: Sendable, Equatable {
    public let branch: String?
    public let dirtyCount: Int
    public let ahead: Int
    public let behind: Int

    public init(branch: String?, dirtyCount: Int, ahead: Int, behind: Int) {
        self.branch = branch; self.dirtyCount = dirtyCount
        self.ahead = ahead; self.behind = behind
    }

    /// Not a git repo, or git unavailable.
    public static let unknown = GitVitals(branch: nil, dirtyCount: 0, ahead: 0, behind: 0)
}

/// Synchronous (blocking) git probe for one working directory. Run off the main
/// actor (it shells out via `GitRepository`). Any failure degrades to `.unknown`
/// / zeros — never throws to the caller.
public func gitVitals(forCwd cwd: String) -> GitVitals {
    let repo = GitRepository(root: URL(fileURLWithPath: cwd))
    guard repo.isRepository() else { return .unknown }
    let branch = (try? repo.currentBranch()).flatMap { $0.isEmpty ? nil : $0 }
    let dirtyCount = (try? repo.statusShort())?.entries.count ?? 0
    let divergence = (try? repo.aheadBehind()) ?? GitDivergence(ahead: 0, behind: 0)
    return GitVitals(branch: branch, dirtyCount: dirtyCount,
                     ahead: divergence.ahead, behind: divergence.behind)
}

/// The cheap, always-live per-session facts the store builds each read. Merged
/// with `AgentsModel`'s git cache to produce `AgentSessionVitals`.
public struct AgentVitalsSnapshot: Sendable, Equatable {
    public let id: UUID
    public let name: String
    public let agentType: CLIAgent
    public let state: AgentActivityState
    public let cwd: String?
    public let isolation: AgentIsolationKind
    public let startedAt: Date
    public let stateChangedAt: Date
    public let plan: [AgentPlanStep]
    public let touched: [String]

    public init(
        id: UUID, name: String, agentType: CLIAgent, state: AgentActivityState,
        cwd: String?, isolation: AgentIsolationKind, startedAt: Date, stateChangedAt: Date,
        plan: [AgentPlanStep] = [], touched: [String] = []
    ) {
        self.id = id; self.name = name; self.agentType = agentType; self.state = state
        self.cwd = cwd; self.isolation = isolation
        self.startedAt = startedAt; self.stateChangedAt = stateChangedAt
        self.plan = plan; self.touched = touched
    }
}

/// Combines live snapshots with cached git facts (default `.unknown` when a
/// session has no cache entry yet). Preserves snapshot order.
public func mergeAgentVitals(
    snapshots: [AgentVitalsSnapshot], gitCache: [UUID: GitVitals]
) -> [AgentSessionVitals] {
    snapshots.map { snapshot in
        let git = gitCache[snapshot.id] ?? .unknown
        return AgentSessionVitals(
            id: snapshot.id, name: snapshot.name, agentType: snapshot.agentType,
            state: snapshot.state, cwd: snapshot.cwd, branch: git.branch,
            dirtyCount: git.dirtyCount, ahead: git.ahead, behind: git.behind,
            isolation: snapshot.isolation, ports: [],
            startedAt: snapshot.startedAt, stateChangedAt: snapshot.stateChangedAt,
            plan: snapshot.plan, touched: snapshot.touched)
    }
}
