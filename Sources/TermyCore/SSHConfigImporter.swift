import Foundation

public enum SSHConfigImporterError: Error, Equatable {
    case invalidPort(String)
}

public struct SSHConfigImporter: Sendable {
    public init() {}

    public func importProfiles(from config: String) throws -> [ConnectionProfile] {
        let stanzas = parseStanzas(config)
        var profiles: [ConnectionProfile] = []

        for stanza in stanzas {
            for alias in stanza.aliases where !alias.contains("*") && !alias.contains("?") {
                let host = stanza.options["hostname"] ?? alias
                let user = stanza.options["user"] ?? NSUserName()
                let port = try parsePort(stanza.options["port"])
                let identityFile = stanza.options["identityfile"]
                let secretAccount = identityFile.map { "ssh.identity.\($0)" } ?? "ssh.identity.\(alias)"

                profiles.append(
                    .ssh(
                        name: alias,
                        host: host,
                        user: user,
                        port: port,
                        identity: .keychain(secretAccount),
                        proxyJump: stanza.options["proxyjump"],
                        sshOptions: sshOptions(from: stanza.options)
                    )
                )
            }
        }

        return profiles
    }

    private func parsePort(_ value: String?) throws -> Int {
        guard let value else { return 22 }
        guard let port = Int(value) else {
            throw SSHConfigImporterError.invalidPort(value)
        }
        return port
    }

    private func sshOptions(from options: [String: String]) -> [String: String] {
        let profileKeys: Set<String> = ["host", "hostname", "user", "port", "identityfile", "proxyjump"]
        return ConnectionProfile.normalizedSSHOptions(
            options.filter { !profileKeys.contains($0.key.lowercased()) }
        )
    }

    private func parseStanzas(_ config: String) -> [SSHConfigStanza] {
        var stanzas: [SSHConfigStanza] = []
        var current: SSHConfigStanza?

        for rawLine in config.split(whereSeparator: \.isNewline) {
            let line = stripComment(String(rawLine)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            let parts = line.split(whereSeparator: \.isWhitespace).map(String.init)
            guard let key = parts.first?.lowercased() else { continue }
            let values = Array(parts.dropFirst())

            if key == "host" {
                if let current {
                    stanzas.append(current)
                }
                current = SSHConfigStanza(aliases: values, options: [:])
            } else if var stanza = current, let value = values.first {
                stanza.options[key] = value
                current = stanza
            }
        }

        if let current {
            stanzas.append(current)
        }

        return stanzas
    }

    private func stripComment(_ line: String) -> String {
        guard let index = line.firstIndex(of: "#") else {
            return line
        }
        return String(line[..<index])
    }
}

private struct SSHConfigStanza: Sendable {
    var aliases: [String]
    var options: [String: String]
}
