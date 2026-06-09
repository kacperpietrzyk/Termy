import XCTest
@testable import TermyCore

final class LocalAIStreamingTests: XCTestCase {

    // MARK: - Pure NDJSON line parser

    func testParserDecodesIncrementalResponseToken() {
        let outcome = LocalAINDJSONLineParser.parse(#"{"model":"qwen","response":"ls","done":false}"#)
        XCTAssertEqual(outcome, .token(LocalAIToken(response: "ls", done: false)))
    }

    func testParserDecodesTerminalTokenWithDoneReason() {
        let outcome = LocalAINDJSONLineParser.parse(
            #"{"model":"qwen","response":"!","done":true,"done_reason":"stop"}"#
        )
        XCTAssertEqual(outcome, .token(LocalAIToken(response: "!", done: true, doneReason: "stop")))
    }

    func testParserDecodesTerminalTokenWithEmptyResponse() {
        let outcome = LocalAINDJSONLineParser.parse(#"{"model":"qwen","response":"","done":true}"#)
        XCTAssertEqual(outcome, .token(LocalAIToken(response: "", done: true)))
    }

    func testParserSurfacesMidStreamError() {
        let outcome = LocalAINDJSONLineParser.parse(#"{"error":"an error was encountered while running the model"}"#)
        XCTAssertEqual(outcome, .error("an error was encountered while running the model"))
    }

    func testParserIgnoresBlankLine() {
        XCTAssertEqual(LocalAINDJSONLineParser.parse("   "), .ignored)
        XCTAssertEqual(LocalAINDJSONLineParser.parse(""), .ignored)
    }

    func testParserIgnoresNonGenerateJSON() {
        XCTAssertEqual(LocalAINDJSONLineParser.parse(#"{"unrelated":1}"#), .ignored)
        XCTAssertEqual(LocalAINDJSONLineParser.parse("not json"), .ignored)
    }

    // MARK: - Options passthrough

    func testGenerateOptionsBuildsJSONObjectOmittingNilFields() {
        XCTAssertNil(LocalAIGenerateOptions().jsonObject)

        let options = LocalAIGenerateOptions(temperature: 0.2, numPredict: 64)
        let object = options.jsonObject
        XCTAssertEqual(object?["temperature"] as? Double, 0.2)
        XCTAssertEqual(object?["num_predict"] as? Int, 64)
        XCTAssertEqual(object?.count, 2)
    }

    // MARK: - Transport: happy path

    func testGenerateStreamYieldsTokensFromNDJSONAndRequestsStreaming() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StreamingURLProtocol.self]
        StreamingURLProtocol.reset()
        StreamingURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.absoluteString, "http://localhost:11434/api/generate")
            XCTAssertEqual(request.httpMethod, "POST")
            let body = try XCTUnwrap(request.streamingBodyData)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["model"] as? String, "qwen2.5-coder")
            XCTAssertEqual(json["stream"] as? Bool, true)
            XCTAssertEqual(json["prompt"] as? String, "say hi")
            // suffix and options are not threaded when nil/absent.
            XCTAssertNil(json["suffix"])
            XCTAssertNil(json["options"])

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/x-ndjson"]
            )!
            let ndjson = """
            {"model":"qwen2.5-coder","response":"Hi","done":false}
            {"model":"qwen2.5-coder","response":" there","done":false}
            {"model":"qwen2.5-coder","response":"!","done":true,"done_reason":"stop"}

            """
            return .complete(response, Data(ndjson.utf8))
        }
        defer { StreamingURLProtocol.reset() }

        let client = LocalAIClient(
            endpoint: try LocalAIEndpoint(urlString: "http://localhost:11434"),
            model: "qwen2.5-coder",
            session: URLSession(configuration: configuration)
        )

        var tokens: [LocalAIToken] = []
        for try await token in client.generateStream(prompt: "say hi") {
            tokens.append(token)
        }

        XCTAssertEqual(tokens.map(\.response), ["Hi", " there", "!"])
        XCTAssertEqual(tokens.last?.done, true)
        XCTAssertEqual(tokens.last?.doneReason, "stop")
    }

    func testGenerateStreamThreadsSuffixAndOptionsIntoRequestBody() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StreamingURLProtocol.self]
        StreamingURLProtocol.reset()
        StreamingURLProtocol.handler = { request in
            let body = try XCTUnwrap(request.streamingBodyData)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["suffix"] as? String, "\nreturn x")
            let options = try XCTUnwrap(json["options"] as? [String: Any])
            XCTAssertEqual(options["temperature"] as? Double, 0.1)

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/x-ndjson"]
            )!
            return .complete(response, Data((#"{"response":"x = 1","done":true}"# + "\n").utf8))
        }
        defer { StreamingURLProtocol.reset() }

        let client = LocalAIClient(
            endpoint: try LocalAIEndpoint(urlString: "http://localhost:11434"),
            model: "qwen2.5-coder",
            session: URLSession(configuration: configuration)
        )

        var tokens: [LocalAIToken] = []
        for try await token in client.generateStream(
            prompt: "def f():",
            suffix: "\nreturn x",
            role: .completion,
            options: LocalAIGenerateOptions(temperature: 0.1)
        ) {
            tokens.append(token)
        }
        XCTAssertEqual(tokens.map(\.response), ["x = 1"])
    }

    // MARK: - Transport: error surfaces

    func testGenerateStreamSurfacesMidStreamErrorAfterPartialTokens() async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StreamingURLProtocol.self]
        StreamingURLProtocol.reset()
        StreamingURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/x-ndjson"]
            )!
            let ndjson = """
            {"response":"Yes","done":false}
            {"error":"an error was encountered while running the model"}

            """
            return .complete(response, Data(ndjson.utf8))
        }
        defer { StreamingURLProtocol.reset() }

        let client = LocalAIClient(
            endpoint: try! LocalAIEndpoint(urlString: "http://localhost:11434"),
            model: "qwen2.5-coder",
            session: URLSession(configuration: configuration)
        )

        var tokens: [LocalAIToken] = []
        do {
            for try await token in client.generateStream(prompt: "go") {
                tokens.append(token)
            }
            XCTFail("Expected a stream error to be thrown")
        } catch {
            XCTAssertEqual(error as? LocalAIClientError, .streamError("an error was encountered while running the model"))
        }
        XCTAssertEqual(tokens.map(\.response), ["Yes"])
    }

    func testGenerateStreamThrowsRequestFailedOnNon2xx() async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StreamingURLProtocol.self]
        StreamingURLProtocol.reset()
        StreamingURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            return .complete(response, Data(#"{"error":"boom"}"#.utf8))
        }
        defer { StreamingURLProtocol.reset() }

        let client = LocalAIClient(
            endpoint: try! LocalAIEndpoint(urlString: "http://localhost:11434"),
            model: "qwen2.5-coder",
            session: URLSession(configuration: configuration)
        )

        do {
            for try await _ in client.generateStream(prompt: "go") {}
            XCTFail("Expected requestFailed to be thrown")
        } catch {
            XCTAssertEqual(error as? LocalAIClientError, .requestFailed(500))
        }
    }

    // MARK: - Cancellation

    func testGenerateStreamCancellationStopsTheUnderlyingTransfer() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StreamingURLProtocol.self]
        StreamingURLProtocol.reset()
        // Emit one token then keep the connection open forever (never finishes).
        StreamingURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/x-ndjson"]
            )!
            return .openEnded(response, Data((#"{"response":"partial","done":false}"# + "\n").utf8))
        }
        defer { StreamingURLProtocol.reset() }

        let client = LocalAIClient(
            endpoint: try LocalAIEndpoint(urlString: "http://localhost:11434"),
            model: "qwen2.5-coder",
            session: URLSession(configuration: configuration)
        )

        let firstToken = expectation(description: "received first token")
        let consumer = Task { () -> Int in
            var count = 0
            for try await _ in client.generateStream(prompt: "go") {
                count += 1
                if count == 1 { firstToken.fulfill() }
            }
            return count
        }

        await fulfillment(of: [firstToken], timeout: 5.0)
        consumer.cancel()

        // The consuming task must finish (not hang), and the transport must be
        // told to stop loading.
        _ = try? await consumer.value
        let stopExpectation = expectation(description: "transport stopped loading")
        Task {
            while !StreamingURLProtocol.didStopLoading {
                try? await Task.sleep(nanoseconds: 5_000_000)
            }
            stopExpectation.fulfill()
        }
        await fulfillment(of: [stopExpectation], timeout: 5.0)
        XCTAssertTrue(StreamingURLProtocol.didStopLoading)
    }
}

// MARK: - Streaming stub

/// A URLProtocol stub that can deliver an NDJSON body either fully (`.complete`)
/// or partially while keeping the connection open (`.openEnded`) so that
/// mid-stream cancellation can be exercised deterministically.
private final class StreamingURLProtocol: URLProtocol {
    enum Response {
        case complete(HTTPURLResponse, Data)
        case openEnded(HTTPURLResponse, Data)
    }

    nonisolated(unsafe) static var handler: ((URLRequest) throws -> Response)?
    nonisolated(unsafe) static var didStopLoading = false
    private static let lock = NSLock()

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        handler = nil
        didStopLoading = false
    }

    private var cancelled = false

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            guard let handler = Self.handler else {
                throw URLError(.badServerResponse)
            }
            let outcome = try handler(request)
            switch outcome {
            case .complete(let response, let data):
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            case .openEnded(let response, let data):
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                // Intentionally never call urlProtocolDidFinishLoading — the
                // connection stays open until stopLoading() (cancellation).
            }
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {
        cancelled = true
        Self.lock.lock()
        Self.didStopLoading = true
        Self.lock.unlock()
    }
}

private extension URLRequest {
    var streamingBodyData: Data? {
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
