import Foundation

public enum SFTPLaunchCommandError: Error, Equatable {
    case requiresSSHProfile
}

public struct SFTPLaunchCommand: Equatable, Sendable {
    public let executablePath: String
    public let arguments: [String]

    public init(profile: ConnectionProfile, executablePath: String = "/usr/bin/sftp") throws {
        guard profile.kind == .ssh else {
            throw SFTPLaunchCommandError.requiresSSHProfile
        }

        self.executablePath = executablePath
        var arguments: [String] = []
        if let port = profile.port {
            arguments.append(contentsOf: ["-P", String(port)])
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
        self.arguments = arguments
    }
}
