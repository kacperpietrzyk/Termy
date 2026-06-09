import XCTest
@testable import Termy
import TermyCore

@MainActor
final class AIModelRolesTests: XCTestCase {

    // MARK: - Defaults + back-compat

    func testDefaultsKeepBothRolesOnQwenCoderAndBackCompatLabel() {
        let model = AIModel()
        XCTAssertEqual(model.completionModel, "qwen2.5-coder")
        XCTAssertEqual(model.chatModel, "qwen2.5-coder")
        // The status-bar / facade label is the chat model, byte-identical to before.
        XCTAssertEqual(model.aiModel, "qwen2.5-coder")
    }

    func testAiModelGetterReflectsChatModel() {
        let model = AIModel()
        model.chatModel = "llama3.1:8b"
        XCTAssertEqual(model.aiModel, "llama3.1:8b")
    }

    func testAiModelSetterWritesChatModel() {
        // OverlayPanelView's TextField binds to aiModel — the setter must still write.
        let model = AIModel()
        model.aiModel = "mistral:7b"
        XCTAssertEqual(model.chatModel, "mistral:7b")
        XCTAssertEqual(model.aiModel, "mistral:7b")
        // Completion model is independent of the chat-label write.
        XCTAssertEqual(model.completionModel, "qwen2.5-coder")
    }

    // MARK: - Role resolution

    func testModelForRoleReturnsRoleSpecificModel() {
        let model = AIModel()
        model.completionModel = "qwen2.5-coder:1.5b"
        model.chatModel = "llama3.1:8b"
        XCTAssertEqual(model.model(for: .completion), "qwen2.5-coder:1.5b")
        XCTAssertEqual(model.model(for: .chat), "llama3.1:8b")
    }

    // MARK: - Applying a discovered set

    func testApplyDiscoveredModelsStoresSetAndAutoAssignsRoles() {
        let model = AIModel()
        let discovered = [
            DiscoveredModel(name: "qwen2.5-coder:1.5b", sizeBytes: nil, parameterSize: "1.5B"),
            DiscoveredModel(name: "llama3.1:8b", sizeBytes: nil, parameterSize: "8B"),
        ]
        model.applyDiscoveredModels(discovered)

        XCTAssertEqual(model.discoveredModels.map(\.name), ["qwen2.5-coder:1.5b", "llama3.1:8b"])
        XCTAssertEqual(model.completionModel, "qwen2.5-coder:1.5b")
        XCTAssertEqual(model.chatModel, "llama3.1:8b")
        XCTAssertEqual(model.aiModel, "llama3.1:8b")
    }

    func testApplyEmptyDiscoveredModelsLeavesRolesUnchanged() {
        let model = AIModel()
        model.completionModel = "custom-small"
        model.chatModel = "custom-large"
        model.applyDiscoveredModels([])

        XCTAssertTrue(model.discoveredModels.isEmpty)
        XCTAssertEqual(model.completionModel, "custom-small")
        XCTAssertEqual(model.chatModel, "custom-large")
    }
}
