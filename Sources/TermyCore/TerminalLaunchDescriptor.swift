import Foundation

/// Foundation-only description of one terminal process launch. Captures any
/// of Termy's five launch shapes (local zsh w/ OSC 133 integration; ssh;
/// ssh -L tunnel; CLI agent; tool) uniformly so the SwiftTerm-owned terminal
/// view can start it — the single launch contract every M3-2 PTY-owner site
/// registers and `SwiftTermTerminalView` consumes to start the child.
public struct TerminalLaunchDescriptor: Equatable, Sendable {
    public let executable: String
    public let arguments: [String]
    public let environment: [String: String]
    public let workingDirectory: String?
    /// Only true for the local zsh shell: injects a ZDOTDIR `.zshrc` emitting
    /// OSC 133. Remote/tool launches never had shell integration (unchanged).
    public let usesZshIntegration: Bool
    /// FB-1: `ZSH_HIGHLIGHT_STYLES[...]` lines (from `SyntaxHighlightStyleMap`) baked into
    /// the generated `.zshrc`. Empty for non-zsh / remote / tool launches.
    public let highlightStyles: [String]
    /// Spec-HL: `typeset -gA TERMY_SPEC_STYLES …` block from `SpecHighlightPalette`, baked into
    /// the generated `.zshrc`. Empty string when not applicable (non-zsh / integration disabled).
    /// `$TERMY_SPEC_DIR` itself is carried env-only (in `environment`), mirroring FB-1's
    /// `TERMY_SYNTAX_HL_DIR` — there is intentionally no separate dir field.
    public var specStylesBlock: String

    public init(
        executable: String,
        arguments: [String],
        environment: [String: String],
        workingDirectory: String?,
        usesZshIntegration: Bool,
        highlightStyles: [String] = [],
        specStylesBlock: String = ""
    ) {
        self.executable = executable
        self.arguments = arguments
        self.environment = environment
        self.workingDirectory = workingDirectory
        self.usesZshIntegration = usesZshIntegration
        self.highlightStyles = highlightStyles
        self.specStylesBlock = specStylesBlock
    }
}
