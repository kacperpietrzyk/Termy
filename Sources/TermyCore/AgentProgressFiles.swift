import Foundation

/// File-based delivery for FB-3-5 tool payloads, parallel to `AgentStateFiles`.
/// The bundled helper (keyword "tool") writes the raw `PostToolUse` JSON to
/// `<dir>/<uuid>.<pid>.<epoch>.tool.json` via temp-file + atomic `mv`. Files are
/// consumed once (read + deleted), in content-modification-date order so that a
/// `TaskCreate` is always folded before its later `TaskUpdate`.
public enum AgentProgressFiles {
    static let suffix = ".tool.json"

    public static func consume(in directory: URL)
        -> [(sessionID: UUID, event: AgentToolEvent)] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey])
        else { return [] }
        let ours = entries.filter { $0.lastPathComponent.hasSuffix(suffix) }
        func mtime(_ url: URL) -> Date {
            (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
        }
        let ordered = ours.sorted {
            let a = mtime($0), b = mtime($1)
            return a == b ? $0.lastPathComponent < $1.lastPathComponent : a < b
        }
        var out: [(sessionID: UUID, event: AgentToolEvent)] = []
        let decoder = JSONDecoder()
        for url in ordered {
            let head = url.lastPathComponent.components(separatedBy: ".").first ?? ""
            guard let id = UUID(uuidString: head) else { continue }   // not ours; leave it
            if let data = try? Data(contentsOf: url),
               let event = try? decoder.decode(AgentToolEvent.self, from: data) {
                out.append((id, event))
            }
            try? fm.removeItem(at: url)   // consume-once, even on decode failure
        }
        return out
    }

    /// Deletes `*.tool.json` whose leading uuid is not in `liveIDs` (launch-time
    /// orphan sweep — at startup `liveIDs` is empty, so all are removed).
    public static func sweepOrphans(in directory: URL, keeping liveIDs: Set<UUID>) {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil) else { return }
        for url in entries where url.lastPathComponent.hasSuffix(suffix) {
            let head = url.lastPathComponent.components(separatedBy: ".").first ?? ""
            guard let id = UUID(uuidString: head) else { continue }
            if !liveIDs.contains(id) { try? fm.removeItem(at: url) }
        }
    }

    /// Deletes every `<id>.*.tool.json` for one session (restart purge: the
    /// dead run's pending tool events must not fold into the fresh `agentProgress`).
    /// The per-session counterpart of `sweepOrphans` (which keeps a live set).
    public static func removeAll(forSession id: UUID, in directory: URL) {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil) else { return }
        for url in entries where url.lastPathComponent.hasSuffix(suffix) {
            let head = url.lastPathComponent.components(separatedBy: ".").first ?? ""
            if head == id.uuidString { try? fm.removeItem(at: url) }
        }
    }
}
