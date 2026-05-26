import Foundation

/// Foundation-only builder of the shell launch configuration M3-1's
/// SwiftTerm view and its automated gate both need. Reusable and
/// unit-testable; parallels the inputs the live PTY path builds privately in
/// TermyStore (ptyEnvironment / makeShellIntegrationDirectory).
///
/// NOTE: this is intentionally NOT a verbatim mirror of the live path.
/// `TermyStore.startPTY` calls `makeShellIntegrationDirectory`
/// UNCONDITIONALLY, so bash/custom shells there also get a `.zshrc` +
/// `ZDOTDIR` they silently ignore. This builder instead gates on
/// `usesZshIntegration` and provisions the integration directory for zsh
/// only — a deliberate, behaviorally-cleaner, zsh-scoped divergence. A
/// future TermyStore-migration reviewer should treat this gating (not the
/// old unconditional behavior) as the intended contract.
///
/// TermyStore is intentionally NOT migrated to this in M3-1 (future non-goal).
public final class ShellIntegrationLaunch {
    public let shellPath: String
    public let arguments: [String]
    public let environment: [String: String]
    public let zdotdir: URL?
    public let workingDirectory: String?

    /// SwiftTerm.LocalProcessTerminalView.startProcess takes [String] of "KEY=VALUE".
    public var environmentArray: [String] { environment.map { "\($0.key)=\($0.value)" } }

    public init(profile: ShellLaunchProfile, sessionID: UUID) throws {
        let command = profile.command
        self.shellPath = command.shellPath
        self.arguments = command.arguments

        var dir: URL?
        if profile.usesZshIntegration {
            let base = FileManager.default.temporaryDirectory
                .appendingPathComponent("termy-shell-\(sessionID.uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            do {
                try ShellIntegrationScript.zsh().write(
                    to: base.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)
            } catch {
                // init throws before the caller gets an instance to cleanup() —
                // unwind the orphaned temp dir ourselves.
                try? FileManager.default.removeItem(at: base)
                throw error
            }
            dir = base
        }
        self.zdotdir = dir

        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        if let dir { env["ZDOTDIR"] = dir.path }
        self.environment = env
        self.workingDirectory = nil
    }

    /// Generalized launch used by the post-M3-2 live terminal. zsh integration
    /// (ZDOTDIR .zshrc emitting OSC 133) is provisioned iff
    /// `descriptor.usesZshIntegration`; otherwise the descriptor's own
    /// executable/args/env/cwd are used verbatim.
    ///
    /// ENV CONTRACT: unlike `init(profile:sessionID:)`, the caller owns env
    /// composition — no `ProcessInfo.processInfo.environment` inheritance is
    /// applied. `TERM` is defaulted to `xterm-256color` ONLY when the
    /// descriptor omits it; a caller-supplied `TERM` wins.
    public init(descriptor: TerminalLaunchDescriptor, sessionID: UUID) throws {
        self.shellPath = descriptor.executable
        self.arguments = descriptor.arguments
        self.workingDirectory = descriptor.workingDirectory

        var dir: URL?
        if descriptor.usesZshIntegration {
            let base = FileManager.default.temporaryDirectory
                .appendingPathComponent("termy-shell-\(sessionID.uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            do {
                try ShellIntegrationScript.zsh(
                    highlightStyles: descriptor.highlightStyles,
                    specStylesBlock: descriptor.specStylesBlock
                ).write(
                    to: base.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)
            } catch {
                try? FileManager.default.removeItem(at: base)
                throw error
            }
            dir = base
        }
        self.zdotdir = dir

        var env = descriptor.environment
        if env["TERM"] == nil { env["TERM"] = "xterm-256color" }
        if let dir { env["ZDOTDIR"] = dir.path }
        // TERMY_SPEC_DIR (like TERMY_SYNTAX_HL_DIR) is inherited from descriptor.environment.
        self.environment = env
    }

    public func cleanup() {
        if let zdotdir { try? FileManager.default.removeItem(at: zdotdir) }
    }
}

extension ShellLaunchProfile {
    /// Only zsh emits OSC 133 hooks via a ZDOTDIR-injected .zshrc.
    /// bash and custom profiles receive no integration directory.
    public var usesZshIntegration: Bool {
        if case .zsh = self { return true }
        return false
    }
}
