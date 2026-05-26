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
    public let ports: [Int]          // FB-3-4 deferred — always empty this slice
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
