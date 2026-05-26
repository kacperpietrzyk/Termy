import Foundation

/// A live terminal surface the model keeps alive across SwiftUI mounts. The
/// pool retains it; the only thing the pool ever asks of it is to tear itself
/// down (close the PTY + free the launch temp).
protocol PooledSurface: AnyObject {
    func terminateSurface()
}

/// Slice 5: model-owned-PTY keep-alive. Keyed by the existing
/// `"<sessionID>#<generation>"` string (the same identity SwiftUI uses at
/// `TerminalStageView.swift`'s `.id(...)`). Holds AppKit-backed surfaces, so it
/// is a plain reference type — NOT `@Observable`, never synced.
///
/// `terminate(forKey:)` is remove-then-tear-down so a re-entrant lookup (a
/// teardown that fires `processTerminated` → `noteSessionProcessExited` → back
/// into the pool) finds nothing and is a no-op.
final class TerminalSurfacePool<Surface: PooledSurface> {
    private var entries: [String: Surface] = [:]

    var count: Int { entries.count }

    func surface(forKey key: String) -> Surface? { entries[key] }

    func store(_ surface: Surface, forKey key: String) { entries[key] = surface }

    func terminate(forKey key: String) {
        entries.removeValue(forKey: key)?.terminateSurface()
    }

    /// Terminate + evict every generation of one session. Keys are
    /// `"<sessionID>#<generation>"`, so we match the `"<uuid>#"` prefix.
    func terminate(forSession sessionID: UUID) {
        let prefix = "\(sessionID.uuidString)#"
        // Snapshot the matching keys before mutating (symmetric with `drain()`):
        // clearer than removing during a live `keys`-view iteration.
        let matching = entries.keys.filter { $0.hasPrefix(prefix) }
        for key in matching {
            entries.removeValue(forKey: key)?.terminateSurface()
        }
    }

    /// Window close / app quit: tear down everything.
    func drain() {
        let all = entries
        entries.removeAll()
        all.values.forEach { $0.terminateSurface() }
    }
}
