import Foundation

/// Transport-layer zero-remote hardening for the local-AI client (AI-S8).
///
/// Termy's built-in AI is local-only — the StatusBar "0 net" claim is a real
/// invariant, not a slogan. Two independent layers enforce it:
///
/// 1. **Construction:** ``LocalAIEndpoint/init(urlString:)`` rejects any
///    non-loopback host up front (the only host the AI client ever targets).
/// 2. **Transport (this file):** the AI `URLSession` is built from a
///    proxy-disabled configuration with a redirect guard so that even a
///    mis-set endpoint — or a malicious `3xx Location:` pointing off-box —
///    cannot egress. Both layers share the SAME loopback allowlist
///    (``LocalAILoopbackHost``) so they can never drift apart.
public enum LocalAILoopbackHost {
    /// The exact set of hosts treated as loopback. Deliberately strict —
    /// exact `127.0.0.1` rather than the whole `127.0.0.0/8` block — and the
    /// single source of truth shared by the endpoint validator and the
    /// transport redirect guard.
    public static let allowed: Set<String> = ["localhost", "127.0.0.1", "::1"]

    /// Whether `host` is one of the permitted loopback hosts (case-insensitive).
    public static func isLoopback(_ host: String) -> Bool {
        allowed.contains(host.lowercased())
    }

    /// Whether `url` targets a permitted loopback host.
    public static func isLoopback(_ url: URL) -> Bool {
        guard let host = url.host(percentEncoded: false) else { return false }
        return isLoopback(host)
    }
}

/// Builds the loopback-pinned `URLSession` used by every local-AI request.
public enum LocalAITransport {
    /// A `URLSession` hardened so AI traffic can only ever reach loopback.
    ///
    /// - Uses an `.ephemeral` configuration (no on-disk cache/cookies — nothing
    ///   to persist or leak) with `connectionProxyDictionary` set to an empty
    ///   dictionary, opting the session out of any system/PAC HTTP(S) proxy so
    ///   a request can't be silently tunnelled off-box.
    /// - Installs ``LocalAIRedirectGuard`` as the session delegate so any
    ///   redirect whose target is not loopback is refused (the redirect is not
    ///   followed; the originating request surfaces its `3xx` status instead),
    ///   a defence-in-depth complement to the construction-time host check.
    public static func makeLoopbackPinnedSession() -> URLSession {
        URLSession(
            configuration: makeLoopbackPinnedConfiguration(),
            delegate: LocalAIRedirectGuard(),
            delegateQueue: nil
        )
    }

    /// The hardened configuration, exposed so tests can assert the pinning
    /// (proxies disabled, ephemeral) without standing up a real proxy.
    public static func makeLoopbackPinnedConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        // Disable any system/PAC proxy: AI traffic must hit loopback directly,
        // never be relayed through a configured HTTP(S) proxy.
        configuration.connectionProxyDictionary = [:]
        return configuration
    }
}

/// Session delegate that refuses to follow any redirect off loopback.
///
/// `URLSession` consults the task delegate before following a `3xx` redirect.
/// If the redirect target is not a permitted loopback host we pass `nil` to the
/// completion handler, which tells `URLSession` NOT to follow it: no second
/// connection is opened to the off-box host, and the original request returns
/// its redirect response (e.g. `requestFailed(302)` through the existing
/// status-code check) rather than egressing. Loopback→loopback redirects are
/// followed unchanged so legitimate behaviour is preserved.
///
/// Stateless `final class` → Sendable-clean under Swift 6 strict concurrency.
public final class LocalAIRedirectGuard: NSObject, URLSessionTaskDelegate, Sendable {
    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        if let url = request.url, LocalAILoopbackHost.isLoopback(url) {
            completionHandler(request)
        } else {
            // Refuse the redirect: do not open a connection to a non-loopback
            // host. The original request returns the 3xx response unfollowed.
            completionHandler(nil)
        }
    }
}
