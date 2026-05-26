import Foundation
import Observation
import TermyCore

/// AI-assistant-domain state, extracted from the `TermyStore` god-object as
/// part of the strangler-facade decomposition (M2c-1). `@Observable` +
/// `@MainActor`: the future state is views observing this model directly via
/// `@Environment(AppModel.self)`; until then `TermyStore` forwards to it.
@MainActor
@Observable
final class AIModel {
    var aiEndpoint = "http://localhost:11434"
    var aiModel = "qwen2.5-coder"
    var aiPrompt = ""
    var aiSuggestedCommand = ""
    var aiExplanation = ""
    var lastTerminalExplain: TerminalExplainRecord?
    var aiConversationHistory: [String] = []
    var userPromptSnippets: [UserPromptSnippet] = []
    var promptSnippetTitle = "Deploy"
    var promptSnippetBody = "Use make deploy"

    init() {}
}
