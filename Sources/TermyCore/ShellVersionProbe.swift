import Foundation

/// v3 Shell §6.1 live-chip ("live · zsh 5.9"): parses `zsh --version` output
/// ("zsh 5.9 (x86_64-apple-darwin23.0)") into the short version ("5.9").
/// Returns nil when the output isn't a zsh banner — caller then shows just "zsh".
public enum ShellVersionProbe {
    public static func parseZshVersion(_ output: String) -> String? {
        let tokens = output.split(whereSeparator: { $0 == " " || $0.isNewline })
        guard tokens.count >= 2, tokens[0] == "zsh" else { return nil }
        return String(tokens[1])
    }
}
