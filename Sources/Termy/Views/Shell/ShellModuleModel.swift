import Foundation
import TermyCore

/// Pure, view-free helpers for the v3 Shell module (DESIGN.md §6.1). Unit-tested
/// directly; the SwiftUI views stay thin. Honest-by-construction — no field here
/// can fabricate an unmodelled value (cwd is omitted when nil; the live-chip
/// version falls back to "zsh", never an invented number). Reuses
/// `DesktopModel.relativeAge` for compact ages.
enum ShellModuleModel {

    // MARK: §6.1 sub-rail — Local (zsh) vs Remote (SSH/RDP).
    /// Local = `.local` profiles that are NOT CLI agents (agents are `.local`
    /// with an `agentType` and live in §6.2 Agents). Remote = `.ssh` + `.rdp`.
    /// Both groups are ordered oldest-first (creation order).
    static func partition(_ sessions: [TermySession]) -> (local: [TermySession], remote: [TermySession]) {
        let sorted = sessions.sorted { $0.startedAt < $1.startedAt }
        let local  = sorted.filter { $0.profile.kind == .local && $0.agentType == nil }
        let remote = sorted.filter { $0.profile.kind == .ssh || $0.profile.kind == .rdp }
        return (local, remote)
    }

    // MARK: §4.3 dt-header live-chip — "live · {label}".
    /// Local chip mirrors the handoff's `s.shell` ("zsh 5.9"): the probe yields
    /// the bare version ("5.9"), so prefix "zsh " — idempotent if already prefixed,
    /// and a plain "zsh" when the version is unknown (never an invented number).
    static func liveChipLabel(kind: ConnectionKind, zshVersion: String?) -> String {
        switch kind {
        case .local:
            guard let v = zshVersion, !v.isEmpty else { return "zsh" }
            return v.hasPrefix("zsh") ? v : "zsh \(v)"
        case .ssh:   return "ssh"
        case .rdp:   return "rdp"
        }
    }

    // MARK: §6.1 sub-rail count — "{N} local · {M} remote".
    /// Always shows both halves (matches the handoff's dual count); honest by
    /// construction since both numbers come from `partition`.
    static func sessionCountSummary(local: Int, remote: Int) -> String {
        "\(local) local · \(remote) remote"
    }

    // MARK: §6.1 AI-context — endpoint display ("http://localhost:11434" → "localhost:11434").
    /// Strips the scheme for compactness (matches the handoff); leaves everything
    /// else untouched, so an unschemed value passes through unchanged.
    static func endpointDisplay(_ raw: String) -> String {
        for scheme in ["https://", "http://"] where raw.hasPrefix(scheme) {
            return String(raw.dropFirst(scheme.count))
        }
        return raw
    }

    // MARK: §4.3 dt-header sub-text spans.
    enum SubtitleAccent: Equatable { case plain, dim }
    struct SubtitleSpan: Equatable { let text: String; let accent: SubtitleAccent }

    /// `user@host:cwd · started HH:mm · {N} command(s) today`.
    /// Local sessions display the real machine short name (the profile stores the
    /// loopback identity "localhost", but the handoff — and the live prompt — show
    /// the actual host). `cwd` is tilde-abbreviated and omitted when unknown. The
    /// start time is the absolute 24h clock, matching the handoff's "started 13:50".
    static func headerSubtitle(_ s: TermySession, commandsToday: Int,
                               localHostName: String = machineShortName) -> [SubtitleSpan] {
        var spans: [SubtitleSpan] = []
        let host = s.profile.kind == .local ? localHostName : s.profile.host
        let userHost = s.profile.user.map { "\($0)@\(host)" } ?? host
        spans.append(.init(text: userHost, accent: .plain))
        if let cwd = s.currentWorkingDirectory, !cwd.isEmpty {
            spans.append(.init(text: ":", accent: .dim))
            spans.append(.init(text: abbreviateTilde(cwd), accent: .plain))
        }
        spans.append(.init(text: " · ", accent: .dim))
        spans.append(.init(text: "started \(clockTime(s.startedAt))", accent: .plain))
        spans.append(.init(text: " · ", accent: .dim))
        let noun = commandsToday == 1 ? "command" : "commands"
        spans.append(.init(text: "\(commandsToday) \(noun) today", accent: .plain))
        return spans
    }

    // MARK: §6.1 sub-rail card meta.
    /// Local: "{cwd} · {N} cmds" (cwd tilde-abbreviated, "~" when unknown).
    /// Remote (SSH/RDP): "{user}@{host}" — the connection identity, not a cwd.
    static func subCardMeta(_ s: TermySession, blockCount: Int) -> String {
        switch s.profile.kind {
        case .local:
            let cwd = s.currentWorkingDirectory.map { abbreviateTilde($0) } ?? "~"
            return "\(cwd) · \(blockCount) cmds"
        case .ssh, .rdp:
            return s.profile.user.map { "\($0)@\(s.profile.host)" } ?? s.profile.host
        }
    }

    /// §6.1 sub-rail card right-side status text (the handoff's "now" / "2h").
    /// Local: relative age since start. Remote: rtt isn't tracked yet → nil
    /// (honest — the status dot still renders).
    static func subCardStatusText(_ s: TermySession, now: Date = Date()) -> String? {
        switch s.profile.kind {
        case .local: return DesktopModel.relativeAge(now.timeIntervalSince(s.startedAt))
        case .ssh, .rdp: return nil
        }
    }

    // MARK: real-source display helpers.
    /// Machine short name (zsh `%m`) for local sessions — first label of the host
    /// name, matching what the live shell prompt shows.
    static var machineShortName: String {
        let full = ProcessInfo.processInfo.hostName
        return full.split(separator: ".").first.map(String.init) ?? full
    }

    /// Abbreviate the home directory to `~` (handoff shows `~/code/termy`, not the
    /// absolute path). Anything outside home passes through unchanged.
    static func abbreviateTilde(_ path: String, home: String = NSHomeDirectory()) -> String {
        if path == home { return "~" }
        if path.hasPrefix(home + "/") { return "~" + path.dropFirst(home.count) }
        return path
    }

    private static let clockFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()
    /// dt-header start time as an absolute 24h clock ("13:50"), matching the handoff.
    static func clockTime(_ date: Date) -> String { clockFormatter.string(from: date) }

    // MARK: §6.1 AI-context card — "Last explain" string.
    /// `nil` when no explain has run. Else "block {N} · {command} · {dur}s" with
    /// the ordinal omitted when unknown and the command omitted when empty —
    /// honest, never fabricated. Duration is fixed 2-decimal seconds.
    static func lastExplainSummary(_ record: TerminalExplainRecord?) -> String? {
        guard let record else { return nil }
        var parts: [String] = []
        if let ordinal = record.blockOrdinal { parts.append("block \(ordinal)") }
        if !record.command.isEmpty { parts.append(record.command) }
        parts.append(String(format: "%.2fs", record.durationSeconds))
        return parts.joined(separator: " · ")
    }

    // MARK: §6.1 Session-stats card — sidecar status string.
    static func sidecarSummary(disabled: Bool, crashCount: Int) -> String {
        if disabled { return "disabled" }
        let noun = crashCount == 1 ? "crash" : "crashes"
        return "healthy · \(crashCount) \(noun) / 60s"
    }

    // MARK: §12.2 Slice-2a Warp context header.
    /// The muted per-block context line — `node · cwd · branch · gitStatus · duration`
    /// with `·` separators, omitting every field that is nil/empty. cwd is
    /// tilde-abbreviated; duration formatted via `formatBlockDuration`. Returns ""
    /// when nothing is present (caller hides the line). branch/gitStatus/node are
    /// nil until Slice-2c, so the 2a header reads as "cwd · duration".
    static func blockContextHeader(
        node: String?,
        cwd: String?,
        branch: String?,
        gitStatus: String?,
        duration: TimeInterval?
    ) -> String {
        var parts: [String] = []
        if let node, !node.isEmpty { parts.append(node) }
        if let cwd, !cwd.isEmpty { parts.append(abbreviateTilde(cwd)) }
        if let branch, !branch.isEmpty { parts.append(branch) }
        if let gitStatus, !gitStatus.isEmpty { parts.append(gitStatus) }
        if let duration { parts.append(formatBlockDuration(duration)) }
        return parts.joined(separator: " · ")
    }

    // MARK: §12.2 T1 — Warp context PILLS (folder / branch / ±N diff / node / duration).

    /// The semantic class of a context pill — drives icon choice and (in the view)
    /// tinting. Pure data; no SwiftUI here so the builder stays unit-testable.
    enum ContextPillKind: Equatable { case folder, branch, diff, node, duration }

    /// One capsule chip in the input-block context row. `icon` is an SF Symbol name
    /// (nil = text-only, e.g. duration). `label` is the rendered text.
    struct ContextPill: Equatable {
        let icon: String?
        let label: String
        let kind: ContextPillKind
    }

    /// T1: the pure pill model behind the input-block context row, in fixed order
    /// folder → branch → diff → node → duration, omitting every absent field.
    /// cwd is tilde-abbreviated. The diff pill parses the counted git status
    /// (`gitStatus` carries a decimal count post-Slice-T1: "3" → `±3`, "0" → `±0`
    /// for Warp in-repo parity) and tolerates the legacy `*` flag (→ bare `±`,
    /// never crashes). `blockContextHeader` (the flat String) stays the source of
    /// truth for copy/tests; this lives alongside it for the chip render.
    static func blockContextPills(
        node: String?,
        cwd: String?,
        branch: String?,
        gitStatus: String?,
        duration: TimeInterval?
    ) -> [ContextPill] {
        var pills: [ContextPill] = []
        if let cwd, !cwd.isEmpty {
            pills.append(.init(icon: "folder", label: abbreviateTilde(cwd), kind: .folder))
        }
        if let branch, !branch.isEmpty {
            pills.append(.init(icon: "arrow.triangle.branch", label: branch, kind: .branch))
        }
        if let gitStatus, !gitStatus.isEmpty {
            let label: String
            if let n = Int(gitStatus) { label = "±\(n)" }   // counted form (Warp ±N)
            else { label = "±" }                            // legacy "*"/unknown → bare marker
            pills.append(.init(icon: "plusminus", label: label, kind: .diff))
        }
        if let node, !node.isEmpty {
            pills.append(.init(icon: "cube", label: node, kind: .node))
        }
        if let duration {
            pills.append(.init(icon: nil, label: formatBlockDuration(duration), kind: .duration))
        }
        return pills
    }

    // MARK: §6.1 block footer — duration display.
    /// Block footer duration: sub-second → "Nms"; under a minute → "N.Ns";
    /// else "Xm Ys". Matches the handoff's "8ms" / "4.2s".
    static func formatBlockDuration(_ seconds: TimeInterval) -> String {
        let s = max(0, seconds)
        if s < 1 { return "\(Int((s * 1000).rounded(.down)))ms" }
        if s < 60 { return String(format: "%.1fs", s) }
        let whole = Int(s)
        return "\(whole / 60)m \(whole % 60)s"
    }
}
