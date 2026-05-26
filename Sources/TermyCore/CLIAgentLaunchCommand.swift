import Foundation

public enum CLIAgent: String, CaseIterable, Sendable {
    case codex
    case claudeCode

    public var displayName: String {
        switch self {
        case .codex: "Codex"
        case .claudeCode: "Claude Code"
        }
    }

    public var defaultExecutableName: String {
        switch self {
        case .codex: "codex"
        case .claudeCode: "claude"
        }
    }
}

public struct CLIAgentLaunchCommand: Equatable, Sendable {
    public let agent: CLIAgent
    public let executablePath: String
    public let arguments: [String]
    public let workingDirectory: URL
    public let environmentOverrides: [String: String]

    public init(
        agent: CLIAgent,
        executablePath: String? = nil,
        arguments: [String] = [],
        workingDirectory: URL,
        environmentOverrides: [String: String] = [:]
    ) {
        self.agent = agent
        if let executablePath {
            self.executablePath = executablePath
            self.arguments = arguments
        } else {
            self.executablePath = "/usr/bin/env"
            self.arguments = [agent.defaultExecutableName] + arguments
        }
        self.workingDirectory = workingDirectory
        self.environmentOverrides = environmentOverrides
    }
}
