import Foundation
import Observation
import TermyCore

/// FB-3-4: the redesign's named agent-orchestration model. Holds only the
/// *expensive* git facts (cached per session id); the cheap live facts
/// (state / cwd / isolation / timestamps) are merged in by `TermyStore` at read
/// time, so observers always see live state while git lags at most one refresh.
@MainActor
@Observable
final class AgentsModel {
    private(set) var gitCache: [UUID: GitVitals] = [:]
    /// AD-6: per-session CC transcript token/context usage, refreshed off-main
    /// alongside git. Keyed only for Claude Code sessions with a parseable
    /// transcript; Codex / not-yet-started sessions have no entry (→ honest n/a).
    private(set) var usageCache: [UUID: AgentTranscriptUsage] = [:]
    private var refreshTask: Task<Void, Never>?

    /// Cancel-and-restart debounce (mirrors `TermyStore.scheduleSidecarQuery`):
    /// a burst of transitions costs one git sweep.
    func refresh(snapshots: [AgentVitalsSnapshot]) {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            await self?.deriveAndStore(snapshots: snapshots)
        }
    }

    /// Awaitable seam (used by tests): probes git AND (for CC sessions) parses
    /// the transcript token/context usage off the main actor for each snapshot's
    /// cwd, then replaces both caches with exactly the live id set (pruning
    /// vanished sessions).
    func deriveAndStore(snapshots: [AgentVitalsSnapshot]) async {
        let targets = snapshots.map { (id: $0.id, cwd: $0.cwd, type: $0.agentType) }
        var derivedGit: [UUID: GitVitals] = [:]
        var derivedUsage: [UUID: AgentTranscriptUsage] = [:]
        for target in targets {
            if Task.isCancelled { return }
            let (git, usage) = await Task.detached(priority: .utility) {
                () -> (GitVitals, AgentTranscriptUsage?) in
                let git = target.cwd.map { gitVitals(forCwd: $0) } ?? .unknown
                // Honest asymmetry: only Claude Code has an on-disk transcript.
                let usage: AgentTranscriptUsage? = (target.type == .claudeCode)
                    ? AgentsModel.transcriptUsage(forCwd: target.cwd) : nil
                return (git, usage)
            }.value
            derivedGit[target.id] = git
            if let usage { derivedUsage[target.id] = usage }
        }
        if Task.isCancelled { return }
        gitCache = derivedGit
        usageCache = derivedUsage
    }

    /// Locate the newest CC transcript for `cwd`, tail-read it, and parse the last
    /// assistant turn's context occupancy. nil when there's no cwd, no transcript,
    /// or no assistant usage yet — never throws, never fabricates.
    nonisolated static func transcriptUsage(forCwd cwd: String?) -> AgentTranscriptUsage? {
        guard let cwd, let url = AgentTranscriptLocator.newestTranscript(forCwd: cwd),
              let tail = AgentTranscriptLocator.tailRead(url) else { return nil }
        return AgentTranscriptParser.parse(tail)
    }
}
