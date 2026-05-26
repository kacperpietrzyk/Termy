import Foundation
import TermyCore

/// Where a launched CLI agent runs relative to git isolation.
enum AgentIsolation {
    case here
    case newWorktree
}

/// Orchestration bookkeeping for an agent session that owns a git worktree.
/// Kept in a `TermyStore` side map (not on `TermySession`).
struct AgentWorktreeHandle: Equatable {
    /// The worktree checkout directory the agent runs in.
    let path: URL
    /// The branch created for the worktree (`termy/agent-<tool>-<shortid>`).
    let branch: String
    /// The main repository root the worktree was created from.
    let repoRoot: URL
    /// The commit the worktree branched from (captured at create time).
    let baseSHA: String
}
