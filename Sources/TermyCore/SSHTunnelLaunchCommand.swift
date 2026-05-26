import Foundation

public enum SSHTunnelSpec: Equatable, Sendable {
    case local(localPort: Int, remoteHost: String, remotePort: Int)
    case remote(remotePort: Int, localHost: String, localPort: Int)
    case dynamic(localPort: Int)

    var arguments: [String] {
        switch self {
        case .local(let localPort, let remoteHost, let remotePort):
            ["-L", "\(localPort):\(remoteHost):\(remotePort)"]
        case .remote(let remotePort, let localHost, let localPort):
            ["-R", "\(remotePort):\(localHost):\(localPort)"]
        case .dynamic(let localPort):
            ["-D", String(localPort)]
        }
    }
}

public enum SSHTunnelKind: String, CaseIterable, Identifiable, Equatable, Sendable {
    case local
    case remote
    case dynamic

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .local: "Local"
        case .remote: "Remote"
        case .dynamic: "Dynamic SOCKS"
        }
    }
}

public enum SSHTunnelDraftError: Error, Equatable {
    case invalidPort
    case missingHost
}

public struct SSHTunnelDraft: Equatable, Sendable {
    public let kind: SSHTunnelKind
    public let bindPort: String
    public let targetHost: String
    public let targetPort: String

    public init(kind: SSHTunnelKind, bindPort: String, targetHost: String, targetPort: String) {
        self.kind = kind
        self.bindPort = bindPort
        self.targetHost = targetHost
        self.targetPort = targetPort
    }

    public func spec() throws -> SSHTunnelSpec {
        guard let bindPort = Int(bindPort.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw SSHTunnelDraftError.invalidPort
        }

        switch kind {
        case .local:
            guard let targetPort = Int(targetPort.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                throw SSHTunnelDraftError.invalidPort
            }
            let host = targetHost.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !host.isEmpty else { throw SSHTunnelDraftError.missingHost }
            return .local(localPort: bindPort, remoteHost: host, remotePort: targetPort)
        case .remote:
            guard let targetPort = Int(targetPort.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                throw SSHTunnelDraftError.invalidPort
            }
            let host = targetHost.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !host.isEmpty else { throw SSHTunnelDraftError.missingHost }
            return .remote(remotePort: bindPort, localHost: host, localPort: targetPort)
        case .dynamic:
            return .dynamic(localPort: bindPort)
        }
    }
}

public struct SSHTunnelLaunchCommand: Equatable, Sendable {
    public let executablePath: String
    public let arguments: [String]

    public init(
        profile: ConnectionProfile,
        tunnels: [SSHTunnelSpec],
        executablePath: String = "/usr/bin/ssh"
    ) throws {
        guard profile.kind == .ssh else {
            throw SSHLaunchCommandError.unsupportedProfileKind(profile.kind)
        }
        guard !profile.host.isEmpty else {
            throw SSHLaunchCommandError.missingHost
        }

        var arguments = ["-N"]
        if let port = profile.port {
            arguments.append(contentsOf: ["-p", String(port)])
        }
        if let gateway = profile.gateway, !gateway.isEmpty {
            arguments.append(contentsOf: ["-J", gateway])
        }
        arguments.append(contentsOf: profile.sshOptionArguments)
        for tunnel in tunnels {
            arguments.append(contentsOf: tunnel.arguments)
        }

        if let user = profile.user, !user.isEmpty {
            arguments.append(contentsOf: ["--", "\(user)@\(profile.host)"])
        } else {
            arguments.append(contentsOf: ["--", profile.host])
        }

        self.executablePath = executablePath
        self.arguments = arguments
    }
}

public struct SavedSSHTunnel: Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let profileName: String
    public let profileHost: String
    public let tunnels: [SSHTunnelSpec]
    public let autoReconnect: Bool

    public init(
        id: String = UUID().uuidString,
        name: String,
        profile: ConnectionProfile,
        tunnels: [SSHTunnelSpec],
        autoReconnect: Bool
    ) throws {
        guard profile.kind == .ssh else {
            throw SSHLaunchCommandError.unsupportedProfileKind(profile.kind)
        }
        self.id = id
        self.name = name
        self.profileName = profile.name
        self.profileHost = profile.host
        self.tunnels = tunnels
        self.autoReconnect = autoReconnect
    }

    public var secretReferences: [SecretReference] {
        []
    }

    public func launchCommand(profile: ConnectionProfile) throws -> SSHTunnelLaunchCommand {
        try SSHTunnelLaunchCommand(profile: profile, tunnels: tunnels)
    }
}

public struct SSHTunnelReconnectPolicy: Equatable, Sendable {
    public let maxAttempts: Int

    public init(maxAttempts: Int = 3) {
        self.maxAttempts = max(0, maxAttempts)
    }

    public func shouldReconnect(exitStatus: Int32, completedAttempts: Int, autoReconnect: Bool) -> Bool {
        autoReconnect && exitStatus != 0 && completedAttempts < maxAttempts
    }
}

public enum SSHTunnelHealthStatus: Equatable, Sendable {
    case starting
    case running
    case reconnecting(attempt: Int)
    case stopped(exitStatus: Int32)
    case failed(exitStatus: Int32)
}

public struct SSHTunnelHealth: Equatable, Sendable {
    public let tunnelName: String
    public private(set) var status: SSHTunnelHealthStatus

    public init(tunnelName: String, status: SSHTunnelHealthStatus = .starting) {
        self.tunnelName = tunnelName
        self.status = status
    }

    public var summary: String {
        switch status {
        case .starting:
            return "\(tunnelName): starting"
        case .running:
            return "\(tunnelName): running"
        case .reconnecting(let attempt):
            return "\(tunnelName): reconnecting attempt \(attempt)"
        case .stopped:
            return "\(tunnelName): stopped"
        case .failed(let exitStatus):
            return "\(tunnelName): failed with exit \(exitStatus)"
        }
    }

    public mutating func markRunning() {
        status = .running
    }

    public mutating func markReconnecting(attempt: Int) {
        status = .reconnecting(attempt: attempt)
    }

    public mutating func markExited(status exitStatus: Int32, willReconnect: Bool) {
        if willReconnect {
            status = .reconnecting(attempt: 1)
        } else if exitStatus == 0 {
            status = .stopped(exitStatus: exitStatus)
        } else {
            status = .failed(exitStatus: exitStatus)
        }
    }
}

public enum SSHTunnelProbeError: Error, Equatable {
    case unsupportedRemoteForward
    case missingRemoteProfile
}

public struct SSHTunnelProbeCommand: Equatable, Sendable {
    public let executablePath: String
    public let arguments: [String]

    public init(
        tunnel: SSHTunnelSpec,
        profile: ConnectionProfile? = nil,
        executablePath: String = "/usr/bin/nc",
        sshExecutablePath: String = "/usr/bin/ssh"
    ) throws {
        switch tunnel {
        case .local(let port, _, _), .dynamic(let port):
            self.executablePath = executablePath
            self.arguments = ["-z", "127.0.0.1", String(port)]
        case .remote(let remotePort, _, _):
            guard let profile else {
                throw SSHTunnelProbeError.missingRemoteProfile
            }
            let launch = try SSHLaunchCommand(profile: profile, executablePath: sshExecutablePath)
            self.executablePath = launch.executablePath
            self.arguments = launch.arguments + [executablePath, "-z", "127.0.0.1", String(remotePort)]
        }
    }
}
