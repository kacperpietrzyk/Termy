import XCTest
@testable import TermyCore

final class LocalAIModelDiscoveryTests: XCTestCase {

    // MARK: - /api/tags JSON parsing

    func testParseTagsResponseExtractsNamesSizesAndParameterSizes() throws {
        let json = """
        {
          "models": [
            {
              "name": "deepseek-r1:latest",
              "model": "deepseek-r1:latest",
              "size": 4683075271,
              "details": { "parameter_size": "7.6B", "family": "qwen2" }
            },
            {
              "name": "llama3.2:latest",
              "model": "llama3.2:latest",
              "size": 2019393189,
              "details": { "parameter_size": "3.2B", "family": "llama" }
            }
          ]
        }
        """
        let models = LocalAIModelDiscovery.parseTagsResponse(Data(json.utf8))
        XCTAssertEqual(models.count, 2)
        XCTAssertEqual(models[0].name, "deepseek-r1:latest")
        XCTAssertEqual(models[0].sizeBytes, 4_683_075_271)
        XCTAssertEqual(models[0].parameterSize, "7.6B")
        XCTAssertEqual(models[1].name, "llama3.2:latest")
        XCTAssertEqual(models[1].sizeBytes, 2_019_393_189)
        XCTAssertEqual(models[1].parameterSize, "3.2B")
    }

    func testParseTagsResponseIsLenientAboutMissingOptionalFields() {
        // Missing size, missing details — must not throw, must default gracefully.
        let json = """
        { "models": [ { "name": "tinyllama" }, { "model": "qwen2.5-coder:1.5b" } ] }
        """
        let models = LocalAIModelDiscovery.parseTagsResponse(Data(json.utf8))
        XCTAssertEqual(models.count, 2)
        XCTAssertEqual(models[0].name, "tinyllama")
        XCTAssertNil(models[0].sizeBytes)
        XCTAssertNil(models[0].parameterSize)
        // Falls back to the `model` field when `name` is absent.
        XCTAssertEqual(models[1].name, "qwen2.5-coder:1.5b")
    }

    func testParseTagsResponseReturnsEmptyForMalformedOrEmptyPayloads() {
        XCTAssertTrue(LocalAIModelDiscovery.parseTagsResponse(Data("not json".utf8)).isEmpty)
        XCTAssertTrue(LocalAIModelDiscovery.parseTagsResponse(Data("{}".utf8)).isEmpty)
        XCTAssertTrue(LocalAIModelDiscovery.parseTagsResponse(Data(#"{"models":[]}"#.utf8)).isEmpty)
        // Entries with neither name nor model are dropped.
        XCTAssertTrue(LocalAIModelDiscovery.parseTagsResponse(Data(#"{"models":[{"size":1}]}"#.utf8)).isEmpty)
    }

    // MARK: - Parameter-size parsing

    func testParameterSizeBillionsParsesSuffixedStrings() throws {
        XCTAssertEqual(try XCTUnwrap(DiscoveredModel.parameterBillions(from: "7.6B")), 7.6, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(DiscoveredModel.parameterBillions(from: "3B")), 3.0, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(DiscoveredModel.parameterBillions(from: "1.5b")), 1.5, accuracy: 0.001)
        // Millions normalise to billions.
        XCTAssertEqual(try XCTUnwrap(DiscoveredModel.parameterBillions(from: "500M")), 0.5, accuracy: 0.001)
        XCTAssertNil(DiscoveredModel.parameterBillions(from: ""))
        XCTAssertNil(DiscoveredModel.parameterBillions(from: nil))
    }

    // MARK: - Role heuristic

    func testHeuristicRoutesSmallCoderModelToCompletion() {
        let m = DiscoveredModel(name: "qwen2.5-coder:1.5b", sizeBytes: nil, parameterSize: "1.5B")
        XCTAssertEqual(LocalAIModelDiscovery.defaultRole(for: m), .completion)
    }

    func testHeuristicRoutesLargeCoderModelToChat() {
        // A code model that is too large for the low-latency completion lane is chat.
        let m = DiscoveredModel(name: "codellama:34b", sizeBytes: nil, parameterSize: "34B")
        XCTAssertEqual(LocalAIModelDiscovery.defaultRole(for: m), .chat)
    }

    func testHeuristicRoutesGeneralChatModelToChat() {
        let m = DiscoveredModel(name: "llama3.1:8b", sizeBytes: nil, parameterSize: "8B")
        XCTAssertEqual(LocalAIModelDiscovery.defaultRole(for: m), .chat)
    }

    func testHeuristicFallsBackToSizeBytesWhenParameterSizeMissing() {
        // No parameter_size, but a coder name + a small on-disk size → completion.
        let small = DiscoveredModel(name: "deepseek-coder", sizeBytes: 1_200_000_000, parameterSize: nil)
        XCTAssertEqual(LocalAIModelDiscovery.defaultRole(for: small), .completion)
        // Coder name but a large on-disk size → chat.
        let large = DiscoveredModel(name: "deepseek-coder", sizeBytes: 20_000_000_000, parameterSize: nil)
        XCTAssertEqual(LocalAIModelDiscovery.defaultRole(for: large), .chat)
    }

    // MARK: - Default selection from a discovered set

    func testDefaultSelectionPicksSmallestCoderForCompletionAndLargestForChat() {
        let models = [
            DiscoveredModel(name: "qwen2.5-coder:7b", sizeBytes: nil, parameterSize: "7B"),
            DiscoveredModel(name: "qwen2.5-coder:1.5b", sizeBytes: nil, parameterSize: "1.5B"),
            DiscoveredModel(name: "llama3.1:8b", sizeBytes: nil, parameterSize: "8B"),
        ]
        let selection = LocalAIModelDiscovery.defaultSelection(from: models)
        // Completion = the smallest completion-eligible (coder) model.
        XCTAssertEqual(selection?.completionModel, "qwen2.5-coder:1.5b")
        // Chat = the largest chat-eligible model.
        XCTAssertEqual(selection?.chatModel, "llama3.1:8b")
    }

    func testDefaultSelectionReturnsNilForEmptySet() {
        XCTAssertNil(LocalAIModelDiscovery.defaultSelection(from: []))
    }

    func testDefaultSelectionFallsBackWhenOnlyOneRoleIsRepresented() {
        // Only completion-eligible models → chat falls back to the (only) model too.
        let models = [
            DiscoveredModel(name: "qwen2.5-coder:1.5b", sizeBytes: nil, parameterSize: "1.5B"),
            DiscoveredModel(name: "qwen2.5-coder:3b", sizeBytes: nil, parameterSize: "3B"),
        ]
        let selection = LocalAIModelDiscovery.defaultSelection(from: models)
        XCTAssertEqual(selection?.completionModel, "qwen2.5-coder:1.5b")
        // No 7-14B chat model present → fall back to the largest available.
        XCTAssertEqual(selection?.chatModel, "qwen2.5-coder:3b")
    }
}
