import XCTest
@testable import TermyCore

/// AI-S8 — transport zero-remote hardening.
///
/// Proves the "0 net" StatusBar claim is a real two-layer invariant:
///   • Layer 1 — `LocalAIEndpoint` refuses a non-loopback host at construction.
///   • Layer 2 — the hardened `URLSession` (proxy-disabled config + redirect
///     guard) refuses to egress even if a request is somehow pointed off-box
///     mid-flight via a `3xx Location:`.
/// Nothing here hits the real network: the redirect is synthesised by a stub
/// `URLProtocol` that records every host it is actually asked to load.
final class LocalAIZeroRemoteTests: XCTestCase {

    // MARK: - Layer 1: construction-time host validation

    func testEndpointRefusesNonLoopbackHost() {
        XCTAssertThrowsError(try LocalAIEndpoint(urlString: "http://10.0.0.5:11434")) { error in
            XCTAssertEqual(error as? LocalAIEndpoint.ValidationError, .remoteHostsAreOutOfScope)
        }
        XCTAssertThrowsError(try LocalAIEndpoint(urlString: "https://api.openai.com/v1")) { error in
            XCTAssertEqual(error as? LocalAIEndpoint.ValidationError, .remoteHostsAreOutOfScope)
        }
    }

    func testEndpointAcceptsLoopbackHosts() {
        XCTAssertNoThrow(try LocalAIEndpoint(urlString: "http://localhost:11434"))
        XCTAssertNoThrow(try LocalAIEndpoint(urlString: "http://127.0.0.1:1234"))
        XCTAssertNoThrow(try LocalAIEndpoint(urlString: "http://[::1]:11434"))
    }

    // MARK: - Shared classifier (single source of truth across both layers)

    func testLoopbackClassifierMatchesEndpointAllowlist() {
        XCTAssertTrue(LocalAILoopbackHost.isLoopback("localhost"))
        XCTAssertTrue(LocalAILoopbackHost.isLoopback("LocalHost")) // case-insensitive
        XCTAssertTrue(LocalAILoopbackHost.isLoopback("127.0.0.1"))
        XCTAssertTrue(LocalAILoopbackHost.isLoopback("::1"))
        // Strictness: only the exact loopback address, not the whole /8.
        XCTAssertFalse(LocalAILoopbackHost.isLoopback("127.0.0.2"))
        XCTAssertFalse(LocalAILoopbackHost.isLoopback("10.0.0.5"))
        XCTAssertFalse(LocalAILoopbackHost.isLoopback("api.openai.com"))
        XCTAssertTrue(LocalAILoopbackHost.isLoopback(URL(string: "http://127.0.0.1:11434/api/generate")!))
        XCTAssertFalse(LocalAILoopbackHost.isLoopback(URL(string: "https://api.openai.com/v1")!))
    }

    // MARK: - Layer 2: hardened configuration (proxy-disabled, ephemeral)

    func testHardenedConfigurationDisablesProxies() {
        let configuration = LocalAITransport.makeLoopbackPinnedConfiguration()
        // Load-bearing: an empty proxy dictionary opts the session out of any
        // system/PAC proxy — AI traffic can't be relayed off-box.
        XCTAssertEqual(configuration.connectionProxyDictionary?.count, 0)
    }

    // MARK: - Layer 2: redirect guard decision (refuse off loopback)

    /// The guard's decision is the transport-layer invariant: it tells
    /// `URLSession` whether to follow a redirect. We exercise its one method
    /// directly (synchronous, deterministic) — a remote target yields a `nil`
    /// follow-up request (not followed), a loopback target yields the request.
    func testRedirectGuardRefusesNonLoopbackTarget() {
        let guard0 = LocalAIRedirectGuard()
        let session = URLSession(configuration: .ephemeral)
        let task = session.dataTask(with: URLRequest(url: URL(string: "http://localhost:11434/api/generate")!))
        let response = HTTPURLResponse(
            url: URL(string: "http://localhost:11434/api/generate")!,
            statusCode: 302,
            httpVersion: nil,
            headerFields: ["Location": "https://api.openai.com/v1/api/generate"]
        )!

        var captured: URLRequest?? = nil // outer nil = handler not called
        guard0.urlSession(
            session,
            task: task,
            willPerformHTTPRedirection: response,
            newRequest: URLRequest(url: URL(string: "https://api.openai.com/v1/api/generate")!),
            completionHandler: { captured = .some($0) }
        )
        XCTAssertTrue(captured != nil, "guard must invoke the completion handler")
        XCTAssertNil(captured!, "a non-loopback redirect target must NOT be followed")
        session.invalidateAndCancel()
    }

    func testRedirectGuardFollowsLoopbackTarget() {
        let guard0 = LocalAIRedirectGuard()
        let session = URLSession(configuration: .ephemeral)
        let task = session.dataTask(with: URLRequest(url: URL(string: "http://localhost:11434/api/generate")!))
        let target = URL(string: "http://127.0.0.1:11434/api/generate")!
        let response = HTTPURLResponse(
            url: URL(string: "http://localhost:11434/api/generate")!,
            statusCode: 307,
            httpVersion: nil,
            headerFields: ["Location": target.absoluteString]
        )!

        var captured: URLRequest?? = nil
        guard0.urlSession(
            session,
            task: task,
            willPerformHTTPRedirection: response,
            newRequest: URLRequest(url: target),
            completionHandler: { captured = .some($0) }
        )
        XCTAssertTrue(captured != nil, "guard must invoke the completion handler")
        XCTAssertEqual(captured??.url, target, "a loopback redirect target must be followed unchanged")
        session.invalidateAndCancel()
    }

    func testRedirectToLoopbackIsFollowed() async throws {
        let configuration = LocalAITransport.makeLoopbackPinnedConfiguration()
        configuration.protocolClasses = [RedirectStubURLProtocol.self]
        RedirectStubURLProtocol.reset()
        // A loopback→loopback redirect IS legitimate and must be followed so the
        // guard doesn't break normal Ollama behaviour.
        RedirectStubURLProtocol.redirectLocation = "http://127.0.0.1:11434/api/generate"
        defer { RedirectStubURLProtocol.reset() }

        let session = URLSession(
            configuration: configuration,
            delegate: LocalAIRedirectGuard(),
            delegateQueue: nil
        )
        let client = LocalAIClient(
            endpoint: try LocalAIEndpoint(urlString: "http://localhost:11434"),
            model: "qwen2.5-coder",
            session: session
        )

        let suggestion = try await client.answerQuestion("hi")
        XCTAssertEqual(suggestion.text, "ok")
        // Both the original loopback host and the loopback redirect target were
        // loaded — and still nothing off-box.
        XCTAssertTrue(RedirectStubURLProtocol.loadedHosts.contains("localhost"))
        XCTAssertTrue(RedirectStubURLProtocol.loadedHosts.contains("127.0.0.1"))
        XCTAssertFalse(RedirectStubURLProtocol.loadedHosts.contains("api.openai.com"))
    }
}

// MARK: - Redirect stub

/// Stub that emits one 302 redirect on the first (loopback) request, then a
/// successful `{"response":"ok"}` body on any subsequent request — and records
/// every host it is asked to load so a test can assert no off-box egress.
private final class RedirectStubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var redirectLocation: String?
    nonisolated(unsafe) static var loadedHosts: [String] = []
    nonisolated(unsafe) private static var firstRequestServed = false
    private static let lock = NSLock()

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        redirectLocation = nil
        loadedHosts = []
        firstRequestServed = false
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        if let host = request.url?.host(percentEncoded: false) {
            Self.loadedHosts.append(host)
        }
        let isFirst = !Self.firstRequestServed
        Self.firstRequestServed = true
        let location = Self.redirectLocation
        Self.lock.unlock()

        if isFirst, let location, let target = URL(string: location) {
            // Emit a 302 with a Location header → URLSession asks the delegate
            // whether to follow it.
            let redirect = HTTPURLResponse(
                url: request.url!,
                statusCode: 302,
                httpVersion: nil,
                headerFields: ["Location": location]
            )!
            var followup = URLRequest(url: target)
            followup.httpMethod = request.httpMethod
            client?.urlProtocol(self, wasRedirectedTo: followup, redirectResponse: redirect)
            return
        }

        // Followed (loopback) request — return a normal success body.
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(#"{"response":"ok"}"#.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
