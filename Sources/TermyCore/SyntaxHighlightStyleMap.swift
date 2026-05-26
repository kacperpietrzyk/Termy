import Foundation

/// FB-1: maps a `TerminalTheme` to `ZSH_HIGHLIGHT_STYLES[...]` assignment lines for the
/// vendored zsh-syntax-highlighting `main` highlighter. Pure + Foundation-only.
///
/// `TerminalTheme` exposes only five colors (background/foreground/prompt/error/muted), so
/// the z-s-h token taxonomy is collapsed onto four foreground roles + an underline affordance
/// for existing paths (spec §4). A richer per-token palette is a deferred follow-up.
public enum SyntaxHighlightStyleMap {
    private enum Role { case command, error, argument, auxiliary }

    /// (token, role, underline) — the FB-1 contract (spec §4). Unlisted z-s-h tokens
    /// inherit the terminal foreground (no line emitted).
    private static let tokens: [(token: String, role: Role, underline: Bool)] = [
        ("unknown-token", .error, false),
        ("reserved-word", .command, false),
        ("alias", .command, false),
        ("suffix-alias", .command, false),
        ("builtin", .command, false),
        ("function", .command, false),
        ("command", .command, false),
        ("precommand", .command, false),
        ("hashed-command", .command, false),
        ("commandseparator", .auxiliary, false),
        ("path", .argument, true),
        ("path_prefix", .argument, false),
        ("globbing", .auxiliary, false),
        ("history-expansion", .auxiliary, false),
        ("single-hyphen-option", .auxiliary, false),
        ("double-hyphen-option", .auxiliary, false),
        ("single-quoted-argument", .argument, false),
        ("double-quoted-argument", .argument, false),
        ("dollar-quoted-argument", .argument, false),
        ("back-quoted-argument", .auxiliary, false),
        ("assign", .argument, false),
        ("redirection", .auxiliary, false),
        ("comment", .auxiliary, false),
    ]

    public static func styles(for theme: TerminalTheme) -> [String] {
        tokens.map { entry in
            let hex = color(for: entry.role, theme: theme)
            let style = entry.underline ? "fg=\(hex),underline" : "fg=\(hex)"
            return "ZSH_HIGHLIGHT_STYLES[\(entry.token)]='\(style)'"
        }
    }

    private static func color(for role: Role, theme: TerminalTheme) -> String {
        switch role {
        case .command:   return theme.promptHex
        case .error:     return theme.errorHex
        case .argument:  return theme.foregroundHex
        case .auxiliary: return theme.mutedHex
        }
    }
}
