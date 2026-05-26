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

        let normalizedHost = host.lowercased()
        guard ["localhost", "127.0.0.1", "::1"].contains(normalizedHost) else {
            throw ValidationError.remoteHostsAreOutOfScope
        }

        self.url = url
    }
}
