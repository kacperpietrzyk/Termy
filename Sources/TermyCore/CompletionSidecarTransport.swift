import Foundation

public enum CompletionSidecarTransport {
    // ----- Encoding -----

    public static func encodeComplete(
        buffer: String,
        cursor: Int,
        cwd: String,
        reqId: Int
    ) -> String {
        let b64 = Data(buffer.utf8).base64EncodedString()
        return "__termy_complete \(b64) \(cursor) \(cwd) \(reqId)\n"
    }

    public static func encodeCd(cwd: String) -> String {
        return "__termy_cd \(cwd)\n"
    }

    // ----- TSV body decoding (post-spike) -----

    public static func decodeTSVBody(_ body: String) -> [CompletionCandidate] {
        var items: [CompletionCandidate] = []
        // Normalize CRLF → LF first; Swift's Character-level split treats \r\n as a
        // single grapheme cluster and won't split on \n alone inside a CRLF pair.
        let normalized = body.replacingOccurrences(of: "\r\n", with: "\n")
        // Use omittingEmptySubsequences: false to keep the 4-column shape on trailing-tab lines.
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false)
        for raw in lines {
            // Belt-and-suspenders: strip any lone trailing CR still present.
            var line = raw
            if line.hasSuffix("\r") { line = line.dropLast() }
            if line.isEmpty { continue }
            let cols = line.split(separator: "\t", maxSplits: 3, omittingEmptySubsequences: false)
            guard cols.count == 4 else { continue }
            let kindRaw = String(cols[0])
            let title = String(cols[1])
            let replacement = String(cols[2])
            let descriptionRaw = String(cols[3])
            // First two columns must be non-empty for a well-formed candidate.
            guard !kindRaw.isEmpty, !title.isEmpty else { continue }
            let description = descriptionRaw.isEmpty ? nil : descriptionRaw
            items.append(CompletionCandidate(
                title: title,
                replacement: replacement,
                kind: kindFromZshTag(kindRaw),
                description: description
            ))
        }
        return items
    }

    // ----- Err body decoding -----

    public static func decodeErrBody(_ body: String) -> String? {
        // Body shape: "err=<code>" possibly with trailing newline.
        let first = body.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? ""
        guard first.hasPrefix("err=") else { return nil }
        let code = String(first.dropFirst("err=".count))
        return code.isEmpty ? nil : code
    }

    // ----- Tag mapping -----

    /// Maps a zsh completion tag (the `compstate[tag]` or `curtag` set by completion
    /// scripts) to a `CompletionKind` for menu rendering. Unknown tags fall back to
    /// `.command` silently — if the sidecar protocol grows to emit a new tag without
    /// extending this switch, the menu will mis-group those items as commands with
    /// no diagnostic signal. Add new cases here when extending the protocol.
    public static func kindFromZshTag(_ tag: String) -> CompletionKind {
        switch tag {
        case "commands": return .command
        case "builtins": return .builtin
        case "aliases":  return .alias
        case "files":    return .file
        case "directories": return .directory
        case "options":  return .option
        case "flags":    return .flag
        default:         return .command
        }
    }
}
