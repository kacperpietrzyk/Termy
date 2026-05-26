import Foundation

public enum ConnectionKind: String, Hashable, Sendable {
    case local
    case ssh
    case rdp
}

public enum SecretReference: Hashable, Sendable {
    case keychain(String)
}

public struct ConnectionProfile: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let kind: ConnectionKind
    public let name: String
    public let host: String
    public let user: String?
    public let port: Int?
    public let gateway: String?
    public let groupPath: String?
    public let sshOptions: [String: String]
    public let terminalOutputMode: TerminalOutputMode
    public let secretReferences: [SecretReference]

    public var inlineSecret: String? { nil }

    /// Designated initializer. For normal construction prefer the
    /// `.local` / `.ssh` / `.rdp` factories, which apply connection-kind
    /// defaults; this initializer is for callers that reconstruct a
    /// fully-specified profile (such as sync restore).
    public init(
        id: UUID = UUID(),
        kind: ConnectionKind,
        name: String,
        host: String,
        user: String?,
        port: Int?,
        gateway: String?,
        groupPath: String?,
        sshOptions: [String: String],
        terminalOutputMode: TerminalOutputMode,
        secretReferences: [SecretReference]
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.host = host
        self.user = user
        self.port = port
        self.gateway = gateway
        self.groupPath = groupPath
        self.sshOptions = Self.normalizedSSHOptions(sshOptions)
        self.terminalOutputMode = terminalOutputMode
        self.secretReferences = secretReferences
    }

    public static func local(
        id: UUID = UUID(),
        name: String = "Local Shell",
        terminalOutputMode: TerminalOutputMode = .stream
    ) -> ConnectionProfile {
        ConnectionProfile(
            id: id,
            kind: .local,
            name: name,
            host: "localhost",
            user: NSUserName(),
            port: nil,
            gateway: nil,
            groupPath: nil,
            sshOptions: [:],
            terminalOutputMode: terminalOutputMode,
            secretReferences: []
        )
    }

    public static func ssh(
        id: UUID = UUID(),
        name: String,
        host: String,
        user: String,
        port: Int = 22,
        identity: SecretReference,
        proxyJump: String? = nil,
        groupPath: String? = nil,
        sshOptions: [String: String] = [:],
        terminalOutputMode: TerminalOutputMode = .stream
    ) -> ConnectionProfile {
        ConnectionProfile(
            id: id,
            kind: .ssh,
            name: name,
            host: host,
            user: user,
            port: port,
            gateway: proxyJump,
            groupPath: normalizedGroupPath(groupPath),
            sshOptions: sshOptions,
            terminalOutputMode: terminalOutputMode,
            secretReferences: [identity]
        )
    }

    public static func rdp(
        id: UUID = UUID(),
        name: String,
        host: String,
        user: String,
        gateway: String?,
        credential: SecretReference,
        groupPath: String? = nil,
        terminalOutputMode: TerminalOutputMode = .stream
    ) -> ConnectionProfile {
        ConnectionProfile(
            id: id,
            kind: .rdp,
            name: name,
            host: host,
            user: user,
            port: 3389,
            gateway: gateway,
            groupPath: normalizedGroupPath(groupPath),
            sshOptions: [:],
            terminalOutputMode: terminalOutputMode,
            secretReferences: [credential]
        )
    }

    public func withTerminalOutputMode(_ mode: TerminalOutputMode) -> ConnectionProfile {
        ConnectionProfile(
            id: id,
            kind: kind,
            name: name,
            host: host,
            user: user,
            port: port,
            gateway: gateway,
            groupPath: groupPath,
            sshOptions: sshOptions,
            terminalOutputMode: mode,
            secretReferences: secretReferences
        )
    }

    public func withSSHOptions(_ options: [String: String]) -> ConnectionProfile {
        ConnectionProfile(
            id: id,
            kind: kind,
            name: name,
            host: host,
            user: user,
            port: port,
            gateway: gateway,
            groupPath: groupPath,
            sshOptions: options,
            terminalOutputMode: terminalOutputMode,
            secretReferences: secretReferences
        )
    }

    public var sshOptionArguments: [String] {
        sshOptions
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            .flatMap { ["-o", "\($0.key)=\($0.value)"] }
    }

    public static func serializedSSHOptions(_ options: [String: String]) -> String {
        normalizedSSHOptions(options)
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ";")
    }

    public static func sshOptions(fromSerialized serialized: String?) -> [String: String] {
        guard let serialized else { return [:] }
        let pairs = serialized
            .split(separator: ";")
            .compactMap { part -> (String, String)? in
                let entry = String(part)
                guard let separator = entry.firstIndex(of: "=") else { return nil }
                let key = String(entry[..<separator])
                let value = String(entry[entry.index(after: separator)...])
                return (key, value)
            }
        return normalizedSSHOptions(Dictionary(uniqueKeysWithValues: pairs))
    }

    public static func sshOptions(fromDraft draft: String) -> [String: String] {
        let pairs = draft
            .split(whereSeparator: \.isNewline)
            .compactMap { rawLine -> (String, String)? in
                let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !line.isEmpty, !line.hasPrefix("#") else { return nil }
                if let separator = line.firstIndex(of: "=") {
                    let key = String(line[..<separator])
                    let value = String(line[line.index(after: separator)...])
                    return (key, value)
                }
                let parts = line.split(maxSplits: 1, whereSeparator: \.isWhitespace).map(String.init)
                guard parts.count == 2 else { return nil }
                return (parts[0], parts[1])
            }
        return normalizedSSHOptions(Dictionary(uniqueKeysWithValues: pairs))
    }

    public static func normalizedSSHOptions(_ options: [String: String]) -> [String: String] {
        Dictionary(
            uniqueKeysWithValues: options.compactMap { key, value -> (String, String)? in
                let normalizedKey = canonicalSSHOptionKey(key)
                let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !normalizedKey.isEmpty,
                      !normalizedValue.isEmpty,
                      !forbiddenSSHOptionKeys.contains(normalizedKey.lowercased()) else {
                    return nil
                }
                return (normalizedKey, normalizedValue)
            }
        )
    }

    public static func normalizedGroupPath(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func canonicalSSHOptionKey(_ key: String) -> String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let lookup = trimmed.lowercased()
        return canonicalSSHOptionKeys[lookup] ?? trimmed
    }

    private static let canonicalSSHOptionKeys: [String: String] = [
        "addkeystoagent": "AddKeysToAgent",
        "batchmode": "BatchMode",
        "compression": "Compression",
        "connecttimeout": "ConnectTimeout",
        "forwardagent": "ForwardAgent",
        "forwardx11": "ForwardX11",
        "serveralivecountmax": "ServerAliveCountMax",
        "serveraliveinterval": "ServerAliveInterval",
        "stricthostkeychecking": "StrictHostKeyChecking",
        "tcpkeepalive": "TCPKeepAlive",
        "userknownhostsfile": "UserKnownHostsFile"
    ]

    private static let forbiddenSSHOptionKeys: Set<String> = [
        "certificatefile",
        "identityagent",
        "identityfile",
        "include",
        "localcommand",
        "proxycommand"
    ]
}
