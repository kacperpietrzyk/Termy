import Foundation
import TermyCore

struct TermySession: Identifiable {
    enum InteractionMode {
        case commandLine
        case rawPTY
    }

    let id: UUID
    var title: String
    var profile: ConnectionProfile
    var lines: [TerminalLine]
    var currentWorkingDirectory: String?
    var lastExitCode: Int32?
    var interactionMode: InteractionMode
    var agentType: CLIAgent?
    /// FB-3-2 activity state. Default `.idle`; set to `.working` at agent launch.
    /// Only meaningful when `agentType != nil`.
    var agentActivity: AgentActivityState = .idle
    /// FB-3-4: when this session was launched (drives "started / 32m ago").
    var startedAt: Date = Date()
    /// FB-3-4: when `agentActivity` last changed (drives "waiting 24s"). Stamped in
    /// `TermyStore.feedAgentEvent`.
    var stateChangedAt: Date = Date()

    init(
        id: UUID = UUID(),
        title: String,
        profile: ConnectionProfile,
        lines: [TerminalLine] = [],
        currentWorkingDirectory: String? = nil,
        lastExitCode: Int32? = nil,
        interactionMode: InteractionMode = .commandLine,
        agentType: CLIAgent? = nil
    ) {
        self.id = id
        self.title = title
        self.profile = profile
        self.lines = lines
        self.currentWorkingDirectory = currentWorkingDirectory
        self.lastExitCode = lastExitCode
        self.interactionMode = interactionMode
        self.agentType = agentType
    }
}

struct TerminalLine: Identifiable {
    enum Role {
        case prompt
        case stdout
        case stderr
        case system
    }

    let id = UUID()
    let role: Role
    let text: String
}

struct TerminalRenderedLine: Identifiable {
    let index: Int
    let line: TerminalLine
    let isBlockStart: Bool
    let isSelectedBlock: Bool
    let isFoldedBlock: Bool

    var id: UUID { line.id }
}

struct TerminalRenderedCommandBlock: Identifiable {
    let command: String
    let startLine: Int
    let endLine: Int
    let exitCode: Int32?
    /// v3 block terminal: wall-clock seconds from commandStarted to commandFinished.
    /// Nil when timing data is unavailable (e.g. session restored from disk, or
    /// commandFinished arrived before commandStarted was recorded).
    let duration: TimeInterval?
    let outputLines: [TerminalLine]
    let isSelected: Bool
    let isFolded: Bool

    var id: Int { startLine }
}

enum CommandCenterItem: Identifiable, Equatable {
    case action(CommandAction)
    case profile(ConnectionProfile)
    case agentSession(AgentSessionVitals)

    var id: String {
        switch self {
        case .action(let action):
            return "action-\(action.id)"
        case .profile(let profile):
            return "profile-\(profile.id.uuidString)"
        case .agentSession(let vitals):
            return "agent-\(vitals.id.uuidString)"
        }
    }

    var title: String {
        switch self {
        case .action(let action):
            return action.title
        case .profile(let profile):
            return profile.name
        case .agentSession(let vitals):
            return vitals.name
        }
    }

    var subtitle: String {
        switch self {
        case .action(let action):
            return action.subtitle
        case .profile(let profile):
            return profile.commandCenterSubtitle
        case .agentSession(let vitals):
            var parts = [vitals.state.label]
            if let branch = vitals.branch { parts.append(branch) }
            if vitals.dirtyCount > 0 { parts.append("●\(vitals.dirtyCount) dirty") }
            return parts.joined(separator: " · ")
        }
    }

    var shortcut: ShortcutDescriptor? {
        switch self {
        case .action(let action):
            return action.shortcut
        case .profile:
            return nil
        case .agentSession:
            return nil
        }
    }

    var systemImage: String {
        switch self {
        case .action(let action):
            switch action.area {
            case .terminal: return "terminal"
            case .commandCenter: return "command"
            case .ai: return "cpu"
            case .files: return "folder"
            case .git: return "point.3.connected.trianglepath.dotted"
            case .editor: return "square.and.pencil"
            case .ssh: return "network"
            case .rdp: return "display"
            case .sync: return "icloud"
            }
        case .profile(let profile):
            switch profile.kind {
            case .local: return "terminal"
            case .ssh: return "network"
            case .rdp: return "display"
            }
        case .agentSession:
            return "cpu"
        }
    }
}

private extension ConnectionProfile {
    var commandCenterSubtitle: String {
        let userHost = user.map { "\($0)@\(host)" } ?? host
        var endpoint = "\(kind.rawValue.uppercased()) \(userHost)"
        if let gateway, !gateway.isEmpty {
            endpoint += " via \(gateway)"
        }
        var parts = [endpoint]
        if let groupPath, !groupPath.isEmpty {
            parts.append(groupPath)
        }
        return parts.joined(separator: " - ")
    }
}

enum OverlayPanel: String, CaseIterable, Identifiable {
    case ai
    case files
    case git
    case editor
    case connections

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ai: "Local AI"
        case .files: "Files"
        case .git: "Git"
        case .editor: "Editor"
        case .connections: "Connections"
        }
    }

    var systemImage: String {
        switch self {
        case .ai: "cpu"
        case .files: "folder"
        case .git: "point.3.connected.trianglepath.dotted"
        case .editor: "square.and.pencil"
        case .connections: "network"
        }
    }
}
