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
        // Decode every well-formed line, retaining the raw zsh tag so the B3
        // filter below can reason about completion groups.
        var rows: [(tag: String, candidate: CompletionCandidate)] = []
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
            rows.append((tag: kindRaw, candidate: CompletionCandidate(
                title: title,
                replacement: replacement,
                kind: kindFromZshTag(kindRaw),
                description: description
            )))
        }
        return suppressBroadCommandFallback(rows)
    }

    /// Tags that the sidecar's `compadd` shadow captures from a single
    /// `_main_complete` pass but which zsh's interactive `_requested`/tag-order
    /// gate would only reveal on a *later* Tab. The classic offender is `_git`,
    /// whose subcommand position registers `common-commands` (porcelain:
    /// status/add/commit) AND `all-commands` (every `git-*` PATH executable:
    /// git-cvsserver/git-upload-pack/…). Because the shadow ignores tag-order,
    /// it surfaces the broad fallback group indiscriminately (B3).
    ///
    /// Fix: when a NARROW group fired for the batch, drop the BROAD fallback
    /// group's candidates so the menu shows the curated subcommands the user
    /// expects — matching the interactive zsh menu's first-Tab behaviour. This
    /// generalises to any completer that pairs a curated group with an
    /// `*-all-*` / "all" fallback.
    private static let broadFallbackTags: Set<String> = ["all-commands", "all-files"]
    private static let narrowGroupTags: Set<String> = [
        "common-commands", "alias-commands", "aliases", "commands", "builtins"
    ]

    private static func suppressBroadCommandFallback(
        _ rows: [(tag: String, candidate: CompletionCandidate)]
    ) -> [CompletionCandidate] {
        let tags = Set(rows.map { $0.tag })
        // Only suppress the broad group when a narrower curated group is present
        // in the SAME batch — otherwise the broad group is all the user has.
        guard !tags.isDisjoint(with: narrowGroupTags),
              !tags.isDisjoint(with: broadFallbackTags) else {
            return rows.map { $0.candidate }
        }
        return rows
            .filter { !broadFallbackTags.contains($0.tag) }
            .map { $0.candidate }
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
