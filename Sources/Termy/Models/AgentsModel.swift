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
    private var refreshTask: Task<Void, Never>?

    /// Cancel-and-restart debounce (mirrors `TermyStore.scheduleSidecarQuery`):
    /// a burst of transitions costs one git sweep.
    func refresh(snapshots: [AgentVitalsSnapshot]) {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            await self?.deriveAndStore(snapshots: snapshots)
        }
    }

    /// Awaitable seam (used by tests): probes git off the main actor for each
    /// snapshot's cwd, then replaces the cache with exactly the live id set
    /// (pruning vanished sessions).
    func deriveAndStore(snapshots: [AgentVitalsSnapshot]) async {
        let targets = snapshots.map { (id: $0.id, cwd: $0.cwd) }
        var derived: [UUID: GitVitals] = [:]
        for target in targets {
            if Task.isCancelled { return }
            let vitals = await Task.detached(priority: .utility) {
                target.cwd.map { gitVitals(forCwd: $0) } ?? .unknown
            }.value
            derived[target.id] = vitals
        }
        if Task.isCancelled { return }
        gitCache = derived
    }
}
