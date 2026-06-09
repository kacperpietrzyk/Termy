import XCTest
@testable import TermyCore

final class LocalAIFIMTests: XCTestCase {

    // MARK: - Capability classifier

    func testIsFIMCapableMatchesKnownCodeModels() {
        XCTAssertTrue(LocalAIClient.isFIMCapable("qwen2.5-coder"))
        XCTAssertTrue(LocalAIClient.isFIMCapable("qwen2.5-coder:7b"))
        XCTAssertTrue(LocalAIClient.isFIMCapable("Qwen2.5-Coder")) // case-insensitive
        XCTAssertTrue(LocalAIClient.isFIMCapable("codellama:13b"))
        XCTAssertTrue(LocalAIClient.isFIMCapable("deepseek-coder-v2"))
        XCTAssertTrue(LocalAIClient.isFIMCapable("starcoder2:3b"))
        XCTAssertTrue(LocalAIClient.isFIMCapable("codestral:latest"))
    }

    func testIsFIMCapableRejectsNonFIMChatModels() {
        XCTAssertFalse(LocalAIClient.isFIMCapable("llama3.1"))
        XCTAssertFalse(LocalAIClient.isFIMCapable("mistral"))
        XCTAssertFalse(LocalAIClient.isFIMCapable("phi3"))
        XCTAssertFalse(LocalAIClient.isFIMCapable("gemma2")) // not codegemma
        XCTAssertFalse(LocalAIClient.isFIMCapable(""))
    }

    // MARK: - FIM request shape

    func testCompleteFIMSendsSuffixFieldAndBarePrefixPromptForFIMModel() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FIMStubURLProtocol.self]
        FIMStubURLProtocol.reset()
        FIMStubURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.absoluteString, "http://localhost:11434/api/generate")
            let body = try XCTUnwrap(request.fimBodyData)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["model"] as? String, "qwen2.5-coder")
            // Native FIM: prompt is the bare prefix, suffix is present, no prose wrapper.
            XCTAssertEqual(json["prompt"] as? String, "def add(a, b):\n    return ")
            XCTAssertEqual(json["suffix"] as? String, "\n\nprint(add(1, 2))")
            let prompt = try XCTUnwrap(json["prompt"] as? String)
            XCTAssertFalse(prompt.contains("Complete this editor buffer"))

            return FIMStubURLProtocol.ndjsonResponse(
                for: request,
                lines: [#"{"response":"a + b","done":true,"done_reason":"stop"}"#]
            )
        }
        defer { FIMStubURLProtocol.reset() }

        let client = LocalAIClient(
            endpoint: try LocalAIEndpoint(urlString: "http://localhost:11434"),
            model: "qwen2.5-coder",
            session: URLSession(configuration: configuration)
        )

        let suggestion = try await client.completeFIM(
            prefix: "def add(a, b):\n    return ",
            suffix: "\n\nprint(add(1, 2))"
        )
        XCTAssertEqual(suggestion.text, "a + b")
    }

    // MARK: - Fallback request shape

    func testCompleteFIMFallsBackToProsePromptWithoutSuffixForNonFIMModel() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FIMStubURLProtocol.self]
        FIMStubURLProtocol.reset()
        FIMStubURLProtocol.handler = { request in
            let body = try XCTUnwrap(request.fimBodyData)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["model"] as? String, "llama3.1")
            // Fallback: no suffix field, prose prompt carries prefix + suffix + guidance.
            XCTAssertNil(json["suffix"])
            let prompt = try XCTUnwrap(json["prompt"] as? String)
            XCTAssertTrue(prompt.contains("Complete this editor buffer"))
            XCTAssertTrue(prompt.contains("def add(a, b):"))
            XCTAssertTrue(prompt.contains("print(add(1, 2))"))
            XCTAssertTrue(prompt.contains("Use 4-space indent"))

            return FIMStubURLProtocol.ndjsonResponse(
                for: request,
                lines: [#"{"response":"    return a + b","done":true}"#]
            )
        }
        defer { FIMStubURLProtocol.reset() }

        let client = LocalAIClient(
            endpoint: try LocalAIEndpoint(urlString: "http://localhost:11434"),
            model: "llama3.1",
            session: URLSession(configuration: configuration)
        )

        let suggestion = try await client.completeFIM(
            prefix: "def add(a, b):\n    return ",
            suffix: "\n\nprint(add(1, 2))",
            projectGuidance: "Use 4-space indent"
        )
        XCTAssertEqual(suggestion.text, "return a + b")
    }

    // MARK: - suggestEditorCompletion re-point

    func testSuggestEditorCompletionRoutesThroughFIMForFIMModel() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FIMStubURLProtocol.self]
        FIMStubURLProtocol.reset()
        FIMStubURLProtocol.handler = { request in
            let body = try XCTUnwrap(request.fimBodyData)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            // Re-pointed onto FIM: suffix present, bare-prefix prompt.
            XCTAssertEqual(json["suffix"] as? String, " end")
            XCTAssertEqual(json["prompt"] as? String, "start ")
            return FIMStubURLProtocol.ndjsonResponse(
                for: request,
                lines: [#"{"response":"middle","done":true}"#]
            )
        }
        defer { FIMStubURLProtocol.reset() }

        let client = LocalAIClient(
            endpoint: try LocalAIEndpoint(urlString: "http://localhost:11434"),
            model: "qwen2.5-coder",
            session: URLSession(configuration: configuration)
        )

        let suggestion = try await client.suggestEditorCompletion(prefix: "start ", suffix: " end")
        XCTAssertEqual(suggestion.text, "middle")
    }

    // MARK: - Empty-suggestion guard

    func testCompleteFIMThrowsEmptySuggestionWhenModelReturnsBlank() async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FIMStubURLProtocol.self]
        FIMStubURLProtocol.reset()
        FIMStubURLProtocol.handler = { request in
            FIMStubURLProtocol.ndjsonResponse(
                for: request,
                lines: [#"{"response":"   ","done":true}"#]
            )
        }
        defer { FIMStubURLProtocol.reset() }

        let client = LocalAIClient(
            endpoint: try! LocalAIEndpoint(urlString: "http://localhost:11434"),
            model: "qwen2.5-coder",
            session: URLSession(configuration: configuration)
        )

        do {
            _ = try await client.completeFIM(prefix: "x", suffix: "y")
            XCTFail("Expected emptySuggestion")
        } catch {
            XCTAssertEqual(error as? LocalAIClientError, .emptySuggestion)
        }
    }
}

// MARK: - NDJSON stub

private final class FIMStubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    private static let lock = NSLock()

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        handler = nil
    }

    static func ndjsonResponse(for request: URLRequest, lines: [String]) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/x-ndjson"]
        )!
        let body = lines.joined(separator: "\n") + "\n"
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

private extension URLRequest {
    var fimBodyData: Data? {
        if let httpBody {
            return httpBody
        }
        guard let stream = httpBodyStream else {
            return nil
        }
        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let count = stream.read(buffer, maxLength: bufferSize)
            if count > 0 {
                data.append(buffer, count: count)
            } else {
                break
            }
        }
        return data
    }
}
