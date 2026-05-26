import Foundation

public enum SSHKeyCommandError: Error, Equatable {
    case emptyPath
    case emptyComment
}

public enum SSHPrivateKeyVaultError: Error, Equatable {
    case emptyIdentityPath
    case invalidPrivateKey
    case missingPrivateKey(SecretReference)
    case restoreFailed
}

public struct SSHPrivateKeyVault: Sendable {
    private let secretStore: KeychainSecretStore

    public init(secretStore: KeychainSecretStore = KeychainSecretStore()) {
        self.secretStore = secretStore
    }

    public func savePrivateKey(_ privateKey: Data, identityPath: String) throws -> SecretReference {
        let reference = try Self.reference(forIdentityPath: identityPath)
        guard Self.isSupportedPrivateKey(privateKey) else {
            throw SSHPrivateKeyVaultError.invalidPrivateKey
        }

        try secretStore.save(privateKey, for: reference)
        return reference
    }

    public func restorePrivateKey(_ reference: SecretReference, to url: URL) throws {
        guard let privateKey = try secretStore.load(reference) else {
            throw SSHPrivateKeyVaultError.missingPrivateKey(reference)
        }

        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        let created = FileManager.default.createFile(
            atPath: url.path,
            contents: privateKey,
            attributes: [.posixPermissions: NSNumber(value: 0o600)]
        )
        guard created else { throw SSHPrivateKeyVaultError.restoreFailed }
        try FileManager.default.setAttributes([.posixPermissions: NSNumber(value: 0o600)], ofItemAtPath: url.path)
    }

    public static func reference(forIdentityPath identityPath: String) throws -> SecretReference {
        let path = identityPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { throw SSHPrivateKeyVaultError.emptyIdentityPath }
        return .keychain("ssh.identity.\(path)")
    }

    private static func isSupportedPrivateKey(_ data: Data) -> Bool {
        guard let text = String(data: data, encoding: .utf8) else { return false }
        let supportedMarkers = [
            ("-----BEGIN OPENSSH PRIVATE KEY-----", "-----END OPENSSH PRIVATE KEY-----"),
            ("-----BEGIN RSA PRIVATE KEY-----", "-----END RSA PRIVATE KEY-----"),
            ("-----BEGIN EC PRIVATE KEY-----", "-----END EC PRIVATE KEY-----"),
            ("-----BEGIN DSA PRIVATE KEY-----", "-----END DSA PRIVATE KEY-----")
        ]
        return supportedMarkers.contains { begin, end in
            text.contains(begin) && text.contains(end)
        }
    }
}

public struct SSHKeyGenerationCommand: Equatable, Sendable {
    public let executablePath: String
    public let arguments: [String]

    public init(keyPath: String, comment: String, executablePath: String = "/usr/bin/ssh-keygen") throws {
        let path = keyPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let comment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { throw SSHKeyCommandError.emptyPath }
        guard !comment.isEmpty else { throw SSHKeyCommandError.emptyComment }

        self.executablePath = executablePath
        self.arguments = ["-t", "ed25519", "-C", comment, "-f", path]
    }
}

public struct SSHAgentAddCommand: Equatable, Sendable {
    public let executablePath: String
    public let arguments: [String]

    public init(keyPath: String, executablePath: String = "/usr/bin/ssh-add") throws {
        let path = keyPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { throw SSHKeyCommandError.emptyPath }

        self.executablePath = executablePath
        self.arguments = ["--apple-use-keychain", path]
    }
}
