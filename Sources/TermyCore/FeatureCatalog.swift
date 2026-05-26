import Foundation

public enum ProductArea: String, CaseIterable, Hashable, Sendable {
    case terminal
    case commandCenter
    case ai
    case files
    case git
    case editor
    case ssh
    case rdp
    case sync
}

public struct FeatureSection: Identifiable, Equatable, Sendable {
    public var id: ProductArea { area }

    public let area: ProductArea
    public let title: String
    public let summary: String
}

public enum ShortcutDescriptor: Equatable, Hashable, Sendable {
    case command(String)
    case commandShift(String)
    case commandOption(String)
    case controlCommand(String)
}

public struct CommandAction: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let area: ProductArea
    public let keywords: [String]
    public let shortcut: ShortcutDescriptor?

    public init(
        id: String,
        title: String,
        subtitle: String,
        area: ProductArea,
        keywords: [String],
        shortcut: ShortcutDescriptor?
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.area = area
        self.keywords = keywords
        self.shortcut = shortcut
    }
}

public struct FeatureCatalog: Equatable, Sendable {
    public let sections: [FeatureSection]
    public let commandCenterActions: [CommandAction]

    public static let termDefault = FeatureCatalog(
        sections: [
            FeatureSection(area: .terminal, title: "Terminal", summary: "Local shell sessions with command-aware output."),
            FeatureSection(area: .commandCenter, title: "Command Center", summary: "Keyboard-first launcher for every action."),
            FeatureSection(area: .ai, title: "Local AI", summary: "Offline assistant and CLI-agent orchestration."),
            FeatureSection(area: .files, title: "Files", summary: "Local and remote file navigation surface."),
            FeatureSection(area: .git, title: "Git", summary: "Daily status, staging, commits, and sync."),
            FeatureSection(area: .editor, title: "Editor", summary: "Lightweight code editing beside terminal work."),
            FeatureSection(area: .ssh, title: "SSH", summary: "Connection vault, jump hosts, tunnels, and SFTP."),
            FeatureSection(area: .rdp, title: "RDP", summary: "First-class embedded Windows desktop sessions."),
            FeatureSection(area: .sync, title: "Private Sync", summary: "CloudKit private database plus iCloud Keychain.")
        ],
        commandCenterActions: [
            CommandAction(
                id: "connect-ssh",
                title: "Connect SSH",
                subtitle: "Open a saved SSH session",
                area: .ssh,
                keywords: ["ssh", "remote", "host", "bastion"],
                shortcut: .commandShift("s")
            ),
            CommandAction(
                id: "create-ssh-profile",
                title: "Create SSH Profile",
                subtitle: "Save a new SSH connection profile from the Connections draft",
                area: .ssh,
                keywords: ["ssh", "profile", "connection", "host", "create"],
                shortcut: nil
            ),
            CommandAction(
                id: "connect-rdp",
                title: "Connect RDP",
                subtitle: "Open a saved Windows desktop session",
                area: .rdp,
                keywords: ["rdp", "windows", "desktop", "gateway"],
                shortcut: .commandShift("r")
            ),
            CommandAction(
                id: "create-rdp-profile",
                title: "Create RDP Profile",
                subtitle: "Save a new Windows desktop connection profile",
                area: .rdp,
                keywords: ["rdp", "profile", "windows", "desktop", "create"],
                shortcut: nil
            ),
            CommandAction(
                id: "open-command-center",
                title: "Open Command Center",
                subtitle: "Search every command, session, and setting",
                area: .commandCenter,
                keywords: ["palette", "launcher", "search"],
                shortcut: .command("k")
            ),
            CommandAction(
                id: "new-local-terminal",
                title: "New Local Terminal",
                subtitle: "Create a local shell session",
                area: .terminal,
                keywords: ["terminal", "shell", "zsh"],
                shortcut: .command("n")
            ),
            CommandAction(
                id: "restore-last-session",
                title: "Restore Last Session",
                subtitle: "Restore local terminal context from the previous launch",
                area: .terminal,
                keywords: ["terminal", "restore", "session", "scrollback", "last", "launch"],
                shortcut: nil
            ),
            CommandAction(
                id: "run-claude-code-here",
                title: "Run Claude Code here",
                subtitle: "Launch Claude Code in the current directory",
                area: .ai,
                keywords: ["claude", "agent", "cli", "ai", "code", "run"],
                shortcut: nil
            ),
            CommandAction(
                id: "run-claude-code-worktree",
                title: "Run Claude Code in new worktree",
                subtitle: "Launch Claude Code in a fresh git worktree",
                area: .ai,
                keywords: ["claude", "agent", "cli", "ai", "code", "worktree", "git"],
                shortcut: nil
            ),
            CommandAction(
                id: "run-codex-here",
                title: "Run Codex here",
                subtitle: "Launch Codex in the current directory",
                area: .ai,
                keywords: ["codex", "agent", "cli", "ai", "run"],
                shortcut: nil
            ),
            CommandAction(
                id: "run-codex-worktree",
                title: "Run Codex in new worktree",
                subtitle: "Launch Codex in a fresh git worktree",
                area: .ai,
                keywords: ["codex", "agent", "cli", "ai", "worktree", "git"],
                shortcut: nil
            ),
            CommandAction(
                id: "interrupt-agent",
                title: "Interrupt Agent",
                subtitle: "Send Ctrl-C to the selected agent",
                area: .ai,
                keywords: ["interrupt", "agent", "stop", "ctrl-c", "cancel", "ai"],
                shortcut: nil
            ),
            CommandAction(
                id: "restart-agent",
                title: "Restart Agent",
                subtitle: "Restart the selected agent in the same directory",
                area: .ai,
                keywords: ["restart", "agent", "relaunch", "ai"],
                shortcut: nil
            ),
            CommandAction(
                id: "close-session",
                title: "Close Session",
                subtitle: "Close the active session and free its resources",
                area: .terminal,
                keywords: ["close", "session", "tab", "kill"],
                shortcut: nil
            ),
            CommandAction(
                id: "set-terminal-output-stream",
                title: "Use Stream Output",
                subtitle: "Render terminal output as a classic continuous stream",
                area: .terminal,
                keywords: ["terminal", "output", "stream", "classic"],
                shortcut: nil
            ),
            CommandAction(
                id: "set-terminal-output-blocks",
                title: "Use Block Output",
                subtitle: "Render terminal output as command blocks",
                area: .terminal,
                keywords: ["terminal", "output", "blocks", "warp"],
                shortcut: nil
            ),
            CommandAction(
                id: "copy-selected-command-output",
                title: "Copy Selected Command Output",
                subtitle: "Copy output for the selected terminal command block",
                area: .terminal,
                keywords: ["terminal", "copy", "output", "block", "command"],
                shortcut: nil
            ),
            CommandAction(
                id: "copy-last-command-output",
                title: "Copy Last Command Output",
                subtitle: "Copy output for the most recent terminal command block",
                area: .terminal,
                keywords: ["terminal", "copy", "output", "last", "command"],
                shortcut: nil
            ),
            CommandAction(
                id: "copy-visible-terminal-screen",
                title: "Copy Visible Terminal Screen",
                subtitle: "Copy the current terminal screen buffer and scrollback",
                area: .terminal,
                keywords: ["terminal", "copy", "screen", "scrollback", "buffer"],
                shortcut: nil
            ),
            CommandAction(
                id: "terminal-next-command-block",
                title: "Next Command Block",
                subtitle: "Move selection to the next terminal command block",
                area: .terminal,
                keywords: ["terminal", "next", "block", "command"],
                shortcut: nil
            ),
            CommandAction(
                id: "terminal-previous-command-block",
                title: "Previous Command Block",
                subtitle: "Move selection to the previous terminal command block",
                area: .terminal,
                keywords: ["terminal", "previous", "block", "command"],
                shortcut: nil
            ),
            CommandAction(
                id: "terminal-toggle-command-block-fold",
                title: "Fold Command Block",
                subtitle: "Fold or expand the selected terminal command block",
                area: .terminal,
                keywords: ["terminal", "fold", "expand", "block", "command"],
                shortcut: nil
            ),
            CommandAction(
                id: "toggle-ai-panel",
                title: "Toggle AI Panel",
                subtitle: "Show the offline assistant drawer",
                area: .ai,
                keywords: ["ai", "local", "ollama", "lm studio"],
                shortcut: .commandShift("a")
            ),
            CommandAction(
                id: "explain-last-error",
                title: "Explain Last Error",
                subtitle: "Use local AI context for the last failed command",
                area: .ai,
                keywords: ["ai", "error", "fix", "failure"],
                shortcut: .commandOption("e")
            ),
            CommandAction(
                id: "toggle-file-explorer",
                title: "Toggle File Explorer",
                subtitle: "Open the local or SFTP file drawer",
                area: .files,
                keywords: ["files", "finder", "sftp"],
                shortcut: .commandShift("f")
            ),
            CommandAction(
                id: "file-next-item",
                title: "Select Next File",
                subtitle: "Move selection down in the file explorer",
                area: .files,
                keywords: ["files", "keyboard", "next", "down"],
                shortcut: nil
            ),
            CommandAction(
                id: "file-previous-item",
                title: "Select Previous File",
                subtitle: "Move selection up in the file explorer",
                area: .files,
                keywords: ["files", "keyboard", "previous", "up"],
                shortcut: nil
            ),
            CommandAction(
                id: "sftp-next-item",
                title: "Select Next Remote File",
                subtitle: "Move selection down in the SFTP file list",
                area: .files,
                keywords: ["files", "sftp", "keyboard", "next", "down"],
                shortcut: nil
            ),
            CommandAction(
                id: "sftp-previous-item",
                title: "Select Previous Remote File",
                subtitle: "Move selection up in the SFTP file list",
                area: .files,
                keywords: ["files", "sftp", "keyboard", "previous", "up"],
                shortcut: nil
            ),
            CommandAction(
                id: "sftp-create-directory",
                title: "Create Remote Folder",
                subtitle: "Create a folder in the current SFTP directory",
                area: .files,
                keywords: ["files", "sftp", "remote", "folder", "mkdir"],
                shortcut: nil
            ),
            CommandAction(
                id: "sftp-rename-selected",
                title: "Rename Remote File",
                subtitle: "Rename the selected SFTP item",
                area: .files,
                keywords: ["files", "sftp", "remote", "rename"],
                shortcut: nil
            ),
            CommandAction(
                id: "sftp-move-selected",
                title: "Move Remote File",
                subtitle: "Move the selected SFTP item to another remote folder",
                area: .files,
                keywords: ["files", "sftp", "remote", "move"],
                shortcut: nil
            ),
            CommandAction(
                id: "sftp-delete-selected",
                title: "Delete Remote File",
                subtitle: "Delete the selected SFTP item",
                area: .files,
                keywords: ["files", "sftp", "remote", "delete", "remove"],
                shortcut: nil
            ),
            CommandAction(
                id: "toggle-git-panel",
                title: "Toggle Git Panel",
                subtitle: "Show status, diff, and commit tools",
                area: .git,
                keywords: ["git", "commit", "branch", "diff"],
                shortcut: .commandShift("g")
            ),
            CommandAction(
                id: "toggle-editor",
                title: "Toggle Editor",
                subtitle: "Open the lightweight editor drawer",
                area: .editor,
                keywords: ["editor", "code", "markdown"],
                shortcut: .commandShift("e")
            ),
            CommandAction(
                id: "tile-editor-right",
                title: "Tile Editor Right",
                subtitle: "Split the workspace with the editor on the right",
                area: .commandCenter,
                keywords: ["tile", "split", "pane", "editor"],
                shortcut: .controlCommand("e")
            ),
            CommandAction(
                id: "tile-files-left",
                title: "Tile Files Left",
                subtitle: "Split the workspace with files on the left",
                area: .commandCenter,
                keywords: ["tile", "split", "pane", "files", "left"],
                shortcut: nil
            ),
            CommandAction(
                id: "tile-git-top",
                title: "Tile Git Top",
                subtitle: "Split the workspace with git above the terminal",
                area: .commandCenter,
                keywords: ["tile", "split", "pane", "git", "top"],
                shortcut: nil
            ),
            CommandAction(
                id: "tile-ai-bottom",
                title: "Tile AI Bottom",
                subtitle: "Split the workspace with local AI below",
                area: .commandCenter,
                keywords: ["tile", "split", "pane", "ai"],
                shortcut: .controlCommand("a")
            ),
            CommandAction(
                id: "focus-next-pane",
                title: "Focus Next Pane",
                subtitle: "Move keyboard focus through visible panes",
                area: .commandCenter,
                keywords: ["tile", "focus", "pane", "next"],
                shortcut: .controlCommand("]")
            ),
            CommandAction(
                id: "resize-focused-pane-larger",
                title: "Increase Focused Pane",
                subtitle: "Grow the currently focused split pane",
                area: .commandCenter,
                keywords: ["tile", "resize", "grow", "pane"],
                shortcut: .controlCommand("=")
            ),
            CommandAction(
                id: "resize-focused-pane-smaller",
                title: "Decrease Focused Pane",
                subtitle: "Shrink the currently focused split pane",
                area: .commandCenter,
                keywords: ["tile", "resize", "shrink", "pane"],
                shortcut: .controlCommand("-")
            ),
            CommandAction(
                id: "close-focused-pane",
                title: "Close Focused Pane",
                subtitle: "Close the focused non-terminal split pane",
                area: .commandCenter,
                keywords: ["tile", "close", "pane"],
                shortcut: .controlCommand("w")
            ),
            CommandAction(
                id: "save-workspace",
                title: "Save Workspace",
                subtitle: "Persist current panes and sessions",
                area: .sync,
                keywords: ["workspace", "layout", "cloudkit"],
                shortcut: .command("s")
            )
        ]
    )
}
