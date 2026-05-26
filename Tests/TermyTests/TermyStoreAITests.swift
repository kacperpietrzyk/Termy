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
            let prompt = try XCTUnwrap(json["prompt"] as? String)
            XCTAssertTrue(prompt.contains("Complete this editor buffer at the cursor"))
            XCTAssertTrue(prompt.contains("func deploy()"))

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(#"{"response":" {\n    runDeploy()\n}"}"#.utf8))
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
            return (response, Data(#"{"response":"The selection defines a deploy function."}"#.utf8))
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

private final class TermyStoreLocalAIURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

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
