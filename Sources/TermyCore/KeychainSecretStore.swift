import Foundation
import Security

public enum KeychainSecretStoreError: Error, Equatable {
    case unexpectedStatus(OSStatus)
    case invalidReference
}

public final class KeychainSecretStore: @unchecked Sendable {
    private let service: String
    public let synchronizesWithICloudKeychain: Bool

    public init(service: String = "pl.kacper.Termy", synchronizesWithICloudKeychain: Bool = true) {
        self.service = service
        self.synchronizesWithICloudKeychain = synchronizesWithICloudKeychain
    }

    public func save(_ secret: Data, for reference: SecretReference) throws {
        let query = baseQuery(for: reference)
        let attributes: [String: Any] = [
            kSecValueData as String: secret,
            kSecAttrAccessible as String: accessibility
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainSecretStoreError.unexpectedStatus(updateStatus)
        }

        var addQuery = query
        addQuery[kSecValueData as String] = secret
        addQuery[kSecAttrAccessible as String] = accessibility

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainSecretStoreError.unexpectedStatus(addStatus)
        }
    }

    public func load(_ reference: SecretReference) throws -> Data? {
        var query = baseQuery(for: reference)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainSecretStoreError.unexpectedStatus(status)
        }
        return result as? Data
    }

    public func delete(_ reference: SecretReference) throws {
        let status = SecItemDelete(baseQuery(for: reference) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainSecretStoreError.unexpectedStatus(status)
        }
    }

    private func baseQuery(for reference: SecretReference) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: reference.account
        ]
        .withSynchronizableFlag(synchronizesWithICloudKeychain)
    }

    internal func makeAddQueryForTesting(secret: Data, reference: SecretReference) -> [String: Any] {
        var query = baseQuery(for: reference)
        query[kSecValueData as String] = secret
        query[kSecAttrAccessible as String] = accessibility
        return query
    }

    private var accessibility: CFString {
        synchronizesWithICloudKeychain ? kSecAttrAccessibleAfterFirstUnlock : kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    }
}

private extension Dictionary where Key == String, Value == Any {
    func withSynchronizableFlag(_ synchronizable: Bool) -> [String: Any] {
        guard synchronizable else { return self }
        var query = self
        query[kSecAttrSynchronizable as String] = true
        return query
    }
}

private extension SecretReference {
    var account: String {
        switch self {
        case .keychain(let account):
            account
        }
    }
}
