import Foundation

public struct LocalAIEndpoint: Equatable, Sendable {
    public enum ValidationError: Error, Equatable {
        case invalidURL
        case remoteHostsAreOutOfScope
    }

    public let url: URL

    public init(urlString: String) throws {
        guard let url = URL(string: urlString), let host = url.host(percentEncoded: false) else {
            throw ValidationError.invalidURL
        }

        // Shared loopback allowlist (AI-S8): the same source of truth the
        // transport redirect guard uses, so the two zero-remote layers can
        // never drift apart.
        guard LocalAILoopbackHost.isLoopback(host) else {
            throw ValidationError.remoteHostsAreOutOfScope
        }

        self.url = url
    }
}
