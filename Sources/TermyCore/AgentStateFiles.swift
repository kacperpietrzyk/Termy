import Foundation

/// File-based delivery for agent hook signals (FB-3-2), mirroring F-4's sidecar
/// pattern. The bundled helper writes `<state-dir>/<uuid>.state` = <keyword>;
/// the store consumes these. A state file is a **one-shot** signal: it is read
/// and deleted, so a stale keyword can never override a session that resumed.
public enum AgentStateFiles {
    public static let fileExtension = "state"

    /// Reads `<uuid>.state` files in `directory`, returning the recognized
    /// (session, signal) pairs. Files whose name is not a bare `<uuid>.state`
    /// (bad names) are left untouched — they aren't ours. A UUID-named `.state`
    /// file is always deleted (consume-once) even when its keyword is
    /// unrecognized, in which case it yields no signal.
    public static func consume(in directory: URL)
        -> [(sessionID: UUID, signal: AgentHookSignal)] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil) else { return [] }
        var out: [(sessionID: UUID, signal: AgentHookSignal)] = []
        for url in entries where url.pathExtension == fileExtension {
            guard let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent)
            else { continue }   // leave files that aren't ours
            let keyword = (try? String(contentsOf: url, encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            try? fm.removeItem(at: url)
            if let signal = AgentHookProtocol.signal(forKeyword: keyword) {
                out.append((id, signal))
            }
        }
        return out
    }

    /// Deletes `<uuid>.state` files whose id is not in `liveIDs` (launch-time
    /// orphan sweep — at startup `liveIDs` is empty, so all are removed).
    public static func sweepOrphans(in directory: URL, keeping liveIDs: Set<UUID>) {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil) else { return }
        for url in entries where url.pathExtension == fileExtension {
            guard let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent)
            else { continue }
            if !liveIDs.contains(id) { try? fm.removeItem(at: url) }
        }
    }
}
