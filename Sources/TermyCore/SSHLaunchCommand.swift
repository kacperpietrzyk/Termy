import Foundation

public enum SSHLaunchCommandError: Error, Equatable {
    case unsupportedProfileKind(ConnectionKind)
    case missingHost
}

public struct SSHLaunchCommand: Equatable, Sendable {
    public let executablePath: String
    public let arguments: [String]

    public init(profile: ConnectionProfile, executablePath: String = "/usr/bin/ssh") throws {
        guard profile.kind == .ssh else {
            throw SSHLaunchCommandError.unsupportedProfileKind(profile.kind)
        }
        guard !profile.host.isEmpty else {
            throw SSHLaunchCommandError.missingHost
        }

        var arguments: [String] = []
        if let port = profile.port {
            arguments.append(contentsOf: ["-p", String(port)])
        }
        if let gateway = profile.gateway, !gateway.isEmpty {
            arguments.append(contentsOf: ["-J", gateway])
        }
        arguments.append(contentsOf: profile.sshOptionArguments)

        let destination: String
        if let user = profile.user, !user.isEmpty {
            destination = "\(user)@\(profile.host)"
        } else {
            destination = profile.host
        }
        arguments.append("--")
        arguments.append(destination)

        self.executablePath = executablePath
        self.arguments = arguments
    }
}
