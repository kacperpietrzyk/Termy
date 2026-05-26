import Foundation

/// Dedicated role palette for the command-spec highlighter, decoupled from `TerminalTheme`.
/// option-argument/argument intentionally have NO style so `main` keeps strings/paths.
public struct SpecHighlightPalette: Sendable, Equatable {
    public var command: String      // truecolor "#RRGGBB"
    public var subcommand: String
    public var option: String
    public var error: String

    public init(command: String, subcommand: String, option: String, error: String) {
        self.command = command
        self.subcommand = subcommand
        self.option = option
        self.error = error
    }

    public static let `default` = SpecHighlightPalette(
        command: "#30D158", subcommand: "#5AC8FA", option: "#98989D", error: "#FF453A")

    /// Emits the `typeset -gA TERMY_SPEC_STYLES …` block for the generated `.zshrc`.
    /// CONTRACT: each value must be a bare `#RRGGBB` literal (no single-quotes or backslashes)
    /// — it is interpolated verbatim into a single-quoted zsh assignment, so a quote/backslash
    /// would break the assignment. Today the fields are fixed constants; this guards a future caller.
    public func zshStylesBlock() -> String {
        """
        typeset -gA TERMY_SPEC_STYLES
        TERMY_SPEC_STYLES[command]='fg=\(command)'
        TERMY_SPEC_STYLES[subcommand]='fg=\(subcommand)'
        TERMY_SPEC_STYLES[option]='fg=\(option)'
        TERMY_SPEC_STYLES[error]='fg=\(error)'
        """
    }
}
