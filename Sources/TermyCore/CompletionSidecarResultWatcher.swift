import Foundation

/// Pure consumer of sidecar result files. Each call scans
/// `directoryURL` for `__boot__.flag`, `req-<id>.tsv`, and `req-<id>.err`
/// files (ignoring `*.tmp` mid-write artifacts and unrelated files),
/// parses them via `CompletionSidecarTransport`, **deletes** the consumed
/// files, and returns an ordered list of `Event` values.
///
/// Stateless from the caller's perspective: idempotent across calls
/// (a second call on an already-consumed dir returns `[]`).
public enum CompletionSidecarResultWatcher {
    public enum Event: Equatable {
        case boot
        case result(id: Int, items: [CompletionCandidate])
        case error(id: Int, code: String)
    }

    public static func consumeResultFiles(
        in directoryURL: URL,
        fileManager: FileManager = .default
    ) -> [Event] {
        guard let entries = try? fileManager.contentsOfDirectory(atPath: directoryURL.path) else {
            return []
        }

        var bootSeen = false
        var resultPaths: [(id: Int, url: URL)] = []
        var errorPaths: [(id: Int, url: URL)] = []

        for name in entries {
            // Skip mid-write artifacts.
            if name.hasSuffix(".tmp") { continue }
            let url = directoryURL.appendingPathComponent(name)

            if name == "__boot__.flag" {
                bootSeen = true
                try? fileManager.removeItem(at: url)
                continue
            }
            if let parsed = parseReqFilename(name) {
                if parsed.kind == .result {
                    resultPaths.append((parsed.id, url))
                } else {
                    errorPaths.append((parsed.id, url))
                }
            }
            // Unrelated files ignored, NOT deleted.
        }

        resultPaths.sort { $0.id < $1.id }
        errorPaths.sort { $0.id < $1.id }

        var events: [Event] = []
        if bootSeen { events.append(.boot) }

        for (id, url) in resultPaths {
            if let body = try? String(contentsOf: url, encoding: .utf8) {
                let items = CompletionSidecarTransport.decodeTSVBody(body)
                events.append(.result(id: id, items: items))
            }
            try? fileManager.removeItem(at: url)
        }
        for (id, url) in errorPaths {
            let body = try? String(contentsOf: url, encoding: .utf8)
            if let body, let code = CompletionSidecarTransport.decodeErrBody(body) {
                events.append(.error(id: id, code: code))
            } else if body != nil {
                // Body readable but unparseable as `err=<code>` — surface diagnostically.
                events.append(.error(id: id, code: "malformed"))
            }
            // If body itself was unreadable (try? returned nil), file disappeared
            // mid-scan — silently skip per existing convention.
            try? fileManager.removeItem(at: url)
        }
        return events
    }

    // MARK: - private

    private enum ReqKind { case result, error }
    private struct ReqFilename { let id: Int; let kind: ReqKind }

    private static func parseReqFilename(_ name: String) -> ReqFilename? {
        // Expect "req-<digits>.tsv" or "req-<digits>.err"
        guard name.hasPrefix("req-") else { return nil }
        let after = name.dropFirst("req-".count)
        let kind: ReqKind
        let idPart: Substring
        if after.hasSuffix(".tsv") {
            kind = .result
            idPart = after.dropLast(".tsv".count)
        } else if after.hasSuffix(".err") {
            kind = .error
            idPart = after.dropLast(".err".count)
        } else {
            return nil
        }
        guard let id = Int(idPart), id >= 0 else { return nil }
        return ReqFilename(id: id, kind: kind)
    }
}
