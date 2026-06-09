import XCTest
@testable import Termy
import TermyCore

final class TermyStoreAITests: XCTestCase {
    @MainActor
    func testEditorAICompletionCanBeSuggestedAndAcceptedAtCursor() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TermyStoreLocalAIURLProtocol.self]
        TermyStoreLocalAIURLProtocol.handler = { request in
            let body = try XCTUnwrap(request.bodyData)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            // Default model qwen2.5-coder is FIM-capable: native FIM sends the
            // bare prefix prompt plus the suffix field, not the prose wrapper.
            let prompt = try XCTUnwrap(json["prompt"] as? String)
            XCTAssertEqual(prompt, "func deploy()")
            XCTAssertFalse(prompt.contains("Complete this editor buffer at the cursor"))
            XCTAssertEqual(json["suffix"] as? String, "\n")

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/x-ndjson"]
            )!
            return .complete(response, Data((#"{"response":" {\n    runDeploy()\n}","done":true}"# + "\n").utf8))
        }
        defer { TermyStoreLocalAIURLProtocol.handler = nil }

        let store = TermyStore(
            startInitialPTY: false,
            localAISession: URLSession(configuration: configuration)
        )
        store.scratchText = "func deploy()\n"
        store.editorVimEnabled = true
        store.editorVimState = VimEditorState(buffer: store.scratchText, cursorOffset: "func deploy()".count, mode: .insert)

        store.suggestEditorCompletionWithLocalAI()

        try await waitUntil {
            store.editorAICompletion == "{\n    runDeploy()\n}"
        }
        XCTAssertEqual(store.aiConversationHistory.last, "editor-completion: {\n    runDeploy()\n}")

        store.acceptEditorAICompletion()

        XCTAssertEqual(store.scratchText, "func deploy(){\n    runDeploy()\n}\n")
        XCTAssertEqual(store.editorAICompletion, "")
    }

    @MainActor
    func testExplainEditorSelectionUsesLocalAIAndRecordsHistory() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TermyStoreLocalAIURLProtocol.self]
        TermyStoreLocalAIURLProtocol.handler = { request in
            let body = try XCTUnwrap(request.bodyData)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let prompt = try XCTUnwrap(json["prompt"] as? String)
            XCTAssertTrue(prompt.contains("selected editor text"))
            XCTAssertTrue(prompt.contains("deploy()"))

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return .complete(response, Data(#"{"response":"The selection defines a deploy function."}"#.utf8))
        }
        defer { TermyStoreLocalAIURLProtocol.handler = nil }

        let store = TermyStore(
            startInitialPTY: false,
            localAISession: URLSession(configuration: configuration)
        )
        store.scratchText = "func deploy() {\n    run()\n}\n"
        store.editorVimEnabled = true
        store.editorVimState = VimEditorState(
            buffer: store.scratchText,
            mode: .visual,
            visualSelectionRange: 0..<13,
            visualAnchorOffset: 0
        )

        store.explainEditorSelectionWithLocalAI()

        try await waitUntil {
            store.aiExplanation == "The selection defines a deploy function."
        }
        XCTAssertEqual(store.aiConversationHistory.last, "editor-selection: The selection defines a deploy function.")
        XCTAssertTrue(store.privateSyncRecords.contains {
            $0.recordType == "AIConversation" &&
            $0.fields["message"] == "editor-selection: The selection defines a deploy function."
        })
    }

    // MARK: - AI-S5: streaming + Esc-cancel + stale-gen guard

    @MainActor
    func testAskQuestionStreamsTokensIntoExplanationThenFinalizes() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TermyStoreLocalAIURLProtocol.self]
        TermyStoreLocalAIURLProtocol.handler = { request in
            let body = try XCTUnwrap(request.bodyData)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            // Streaming path: stream:true, prompt carries the question.
            XCTAssertEqual(json["stream"] as? Bool, true)
            XCTAssertTrue((json["prompt"] as? String)?.contains("What is git?") == true)

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/x-ndjson"]
            )!
            let ndjson = """
            {"response":"Git ","done":false}
            {"response":"is a ","done":false}
            {"response":"VCS.","done":true}

            """
            return .complete(response, Data(ndjson.utf8))
        }
        defer { TermyStoreLocalAIURLProtocol.handler = nil }

        let store = TermyStore(
            startInitialPTY: false,
            localAISession: URLSession(configuration: configuration)
        )
        store.aiPrompt = "What is git?"
        store.askLocalAIQuestion()

        try await waitUntil { store.aiExplanation == "Git is a VCS." && store.aiStreaming == false }
        XCTAssertEqual(store.aiConversationHistory.last, "answer: Git is a VCS.")
        // (statusMessage is not asserted: the answer history entry schedules a
        //  private-sync push whose own status message races the AI one.)
    }

    @MainActor
    func testCancelAIRequestStopsStreamingAndWritesNoFinalState() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TermyStoreLocalAIURLProtocol.self]
        // Emit one token, then keep the connection open forever.
        TermyStoreLocalAIURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/x-ndjson"]
            )!
            return .openEnded(response, Data((#"{"response":"Git ","done":false}"# + "\n").utf8))
        }
        defer { TermyStoreLocalAIURLProtocol.handler = nil }

        let store = TermyStore(
            startInitialPTY: false,
            localAISession: URLSession(configuration: configuration)
        )
        store.aiPrompt = "What is git?"
        store.askLocalAIQuestion()

        // Wait until the first token has streamed in and the request is in flight.
        try await waitUntil { store.aiExplanation == "Git " && store.aiStreaming == true }

        store.cancelAIRequest()
        XCTAssertFalse(store.aiStreaming)
        XCTAssertEqual(store.statusMessage, "Cancelled the local AI request.")
        // Partial text remains; no "answer:" history entry was recorded.
        XCTAssertEqual(store.aiExplanation, "Git ")
        XCTAssertFalse(store.aiConversationHistory.contains { $0.hasPrefix("answer:") })

        // Give any stale task a moment; it must not finalize after cancel.
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertFalse(store.aiStreaming)
        XCTAssertFalse(store.aiConversationHistory.contains { $0.hasPrefix("answer:") })
    }

    @MainActor
    func testSupersededRequestDoesNotOverwriteNewerOne() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TermyStoreLocalAIURLProtocol.self]
        // The first call opens an open-ended stream (one token, never finishes);
        // the second call returns a complete stream that should win.
        let callCount = Counter()
        TermyStoreLocalAIURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/x-ndjson"]
            )!
            if callCount.next() == 0 {
                return .openEnded(response, Data((#"{"response":"STALE","done":false}"# + "\n").utf8))
            } else {
                return .complete(response, Data((#"{"response":"FRESH","done":true}"# + "\n").utf8))
            }
        }
        defer { TermyStoreLocalAIURLProtocol.handler = nil }

        let store = TermyStore(
            startInitialPTY: false,
            localAISession: URLSession(configuration: configuration)
        )

        store.aiPrompt = "first"
        store.askLocalAIQuestion()
        try await waitUntil { store.aiExplanation == "STALE" }

        // Supersede with a second request — clears the buffer and starts fresh.
        store.aiPrompt = "second"
        store.askLocalAIQuestion()

        try await waitUntil { store.aiExplanation == "FRESH" && store.aiStreaming == false }
        // The superseded request's lingering tokens never reappear.
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(store.aiExplanation, "FRESH")
        XCTAssertEqual(store.aiConversationHistory.last, "answer: FRESH")
        XCTAssertFalse(store.aiConversationHistory.contains { $0 == "answer: STALE" })
    }

    private func waitUntil(
        timeoutNanoseconds: UInt64 = 2_000_000_000,
        condition: @MainActor @escaping () -> Bool
    ) async throws {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        while DispatchTime.now().uptimeNanoseconds < deadline {
            if await condition() {
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Timed out waiting for condition")
    }
}

/// Thread-safe call counter for the stale-gen test's two-phase handler.
private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func next() -> Int {
        lock.lock(); defer { lock.unlock() }
        let current = value
        value += 1
        return current
    }
}

/// A URLProtocol stub that delivers a body either fully (`.complete`) or
/// partially while keeping the connection open (`.openEnded`) so mid-stream
/// cancellation / stale-gen can be exercised deterministically. A handler may
/// return a bare `(HTTPURLResponse, Data)` tuple, which is treated as
/// `.complete` for back-compat with the non-streaming tests.
private final class TermyStoreLocalAIURLProtocol: URLProtocol {
    enum Outcome {
        case complete(HTTPURLResponse, Data)
        case openEnded(HTTPURLResponse, Data)
    }

    nonisolated(unsafe) static var handler: ((URLRequest) throws -> Outcome)?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            guard let handler = Self.handler else {
                throw URLError(.badServerResponse)
            }
            switch try handler(request) {
            case .complete(let response, let data):
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            case .openEnded(let response, let data):
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                // Never finish — stays open until stopLoading() (cancellation).
            }
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private extension URLRequest {
    var bodyData: Data? {
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
