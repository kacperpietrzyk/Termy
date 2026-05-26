import Foundation

public struct ShellLaunchCommand: Equatable, Sendable {
    public let shellPath: String
    public let arguments: [String]

    public init(shellPath: String, arguments: [String]) {
        self.shellPath = shellPath
        self.arguments = arguments
    }
}

public enum ShellLaunchProfile: Equatable, Sendable {
    case zsh
    case bash
    case custom(path: String, arguments: [String])

    public var command: ShellLaunchCommand {
        switch self {
        case .zsh:
            return ShellLaunchCommand(shellPath: "/bin/zsh", arguments: [])
        case .bash:
            return ShellLaunchCommand(shellPath: "/bin/bash", arguments: ["--noprofile", "--norc"])
        case .custom(let path, let arguments):
            return ShellLaunchCommand(shellPath: path, arguments: arguments)
        }
    }
}

public enum TerminalOutputMode: String, CaseIterable, Equatable, Sendable {
    case stream
    case blocks
}
