import Foundation

/// Builds the per-launch Claude Code `--settings` payload and maps the
/// helper's one-word state keywords to `AgentHookSignal`s (FB-3-2).
///
/// Hook command shape (one per event):
///   '<helper>' '<state-dir>' '<session-uuid>' <keyword>
/// The helper writes `<state-dir>/<session-uuid>.state` = <keyword>, which the
/// store consumes (see `AgentStateFiles`). Fields are single-quoted so paths
/// containing spaces (e.g. "Application Support") survive the shell.
public enum AgentHookProtocol {
    public static let keywordWorking = "working"
    public static let keywordWaiting = "waiting"
    public static let keywordTool = "tool"

    public static func signal(forKeyword keyword: String) -> AgentHookSignal? {
        switch keyword {
        case keywordWorking: return .active
        case keywordWaiting: return .waiting
        default: return nil
        }
    }

    /// Launch arguments that make Claude Code report lifecycle state into
    /// `stateDir`. Returns `[]` when no helper is available (→ passive baseline).
    public static func claudeCodeLaunchArguments(helperPath: String?,
                                                 stateDir: String,
                                                 sessionID: UUID) -> [String] {
        guard let helperPath, let json = settingsJSON(
            helperPath: helperPath, stateDir: stateDir, sessionID: sessionID) else { return [] }
        return ["--settings", json]
    }

    static func settingsJSON(helperPath: String, stateDir: String, sessionID: UUID) -> String? {
        func command(_ keyword: String) -> String {
            // `keyword` is a hardcoded ASCII constant (`keywordWorking` /
            // `keywordWaiting`), so it's safe to leave unquoted — unlike the
            // path/uuid args, which are shell-quoted to survive spaces.
            "\(shellQuote(helperPath)) \(shellQuote(stateDir)) "
                + "\(shellQuote(sessionID.uuidString)) \(keyword)"
        }
        let settings = HookSettings(hooks: [
            "SessionStart": [HookMatcher(matcher: nil, hooks: [HookCommand(command: command(keywordWorking))])],
            "Stop":         [HookMatcher(matcher: nil, hooks: [HookCommand(command: command(keywordWaiting))])],
            "Notification": [HookMatcher(matcher: nil, hooks: [HookCommand(command: command(keywordWaiting))])],
            "PostToolUse":  [HookMatcher(matcher: "TaskCreate|TaskUpdate|Edit|Write|MultiEdit",
                                         hooks: [HookCommand(command: command(keywordTool))])],
        ])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]   // deterministic output
        guard let data = try? encoder.encode(settings) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

private struct HookSettings: Encodable { let hooks: [String: [HookMatcher]] }
private struct HookMatcher: Encodable {
    let matcher: String?
    let hooks: [HookCommand]
}
private struct HookCommand: Encodable {
    let type = "command"
    let command: String
}
