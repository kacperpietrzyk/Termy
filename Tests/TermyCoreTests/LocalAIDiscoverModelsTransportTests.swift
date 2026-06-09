import XCTest
@testable import TermyCore

/// Transport-level test for `discoverModels()` against a stubbed `/api/tags`.
/// Plain JSON (not NDJSON); never hits the network.
final class LocalAIDiscoverModelsTransportTests: XCTestCase {

    func testDiscoverModelsGetsTagsEndpointAndParsesPayload() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TagsStubURLProtocol.self]
        TagsStubURLProtocol.reset()
        TagsStubURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.absoluteString, "http://localhost:11434/api/tags")
            XCTAssertEqual(request.httpMethod, "GET")
            let body = """
            {
              "models": [
                { "name": "qwen2.5-coder:1.5b", "size": 1000000000, "details": { "parameter_size": "1.5B" } },
                { "name": "llama3.1:8b", "size": 4700000000, "details": { "parameter_size": "8B" } }
              ]
            }
            """
            return TagsStubURLProtocol.jsonResponse(for: request, body: body)
        }
        defer { TagsStubURLProtocol.reset() }

        let client = LocalAIClient(
            endpoint: try LocalAIEndpoint(urlString: "http://localhost:11434"),
            model: "qwen2.5-coder",
            session: URLSession(configuration: configuration)
        )

        let models = try await client.discoverModels()
        XCTAssertEqual(models.map(\.name), ["qwen2.5-coder:1.5b", "llama3.1:8b"])
        XCTAssertEqual(models[1].parameterSize, "8B")
    }

    func testDiscoverModelsThrowsOnNonSuccessStatus() async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TagsStubURLProtocol.self]
        TagsStubURLProtocol.reset()
        TagsStubURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        defer { TagsStubURLProtocol.reset() }

        let client = LocalAIClient(
            endpoint: try! LocalAIEndpoint(urlString: "http://localhost:11434"),
            model: "qwen2.5-coder",
            session: URLSession(configuration: configuration)
        )

        do {
            _ = try await client.discoverModels()
            XCTFail("Expected requestFailed")
        } catch {
            XCTAssertEqual(error as? LocalAIClientError, .requestFailed(500))
        }
    }
}

// MARK: - JSON stub

private final class TagsStubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    private static let lock = NSLock()

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        handler = nil
    }

    static func jsonResponse(for request: URLRequest, body: String) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        return (response, Data(body.utf8))
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            guard let handler = Self.handler else {
                throw URLError(.badServerResponse)
            }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
