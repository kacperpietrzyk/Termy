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

    /// The small, low-latency model used for inline completion (FIM). Split
    /// from chat in AI-S3 so a small coder model handles completion while a
    /// 7–14B model handles conversation/explanation. Defaults to the prior
    /// single model so behaviour is unchanged before auto-discovery runs.
    var completionModel = "qwen2.5-coder"

    /// The larger conversational/explanation model (7–14B class). This is the
    /// model the status bar and the legacy `aiModel` facade surface.
    var chatModel = "qwen2.5-coder"

    /// Models auto-discovered from the local Ollama server via `GET /api/tags`.
    /// Empty until ``applyDiscoveredModels(_:)`` runs; drives the (future) S9
    /// model picker.
    var discoveredModels: [DiscoveredModel] = []

    /// Back-compat single-model accessor.
    ///
    /// Maps onto ``chatModel`` so the StatusBar label and the
    /// `OverlayPanelView` model `TextField` (which both read/write `aiModel`
    /// via the `TermyStore` facade) keep working unchanged.
    var aiModel: String {
        get { chatModel }
        set { chatModel = newValue }
    }

    /// The model to use for a given request role.
    func model(for role: LocalAIRole) -> String {
        switch role {
        case .completion: return completionModel
        case .chat: return chatModel
        }
    }

    /// Adopt an auto-discovered model set and auto-assign default roles.
    ///
    /// Stores the discovered list and, when non-empty, picks a sensible
    /// completion/chat pair via ``LocalAIModelDiscovery/defaultSelection(from:)``.
    /// An empty set leaves the current role assignments untouched (e.g. when
    /// the server is unreachable).
    func applyDiscoveredModels(_ models: [DiscoveredModel]) {
        discoveredModels = models
        guard let selection = LocalAIModelDiscovery.defaultSelection(from: models) else {
            return
        }
        completionModel = selection.completionModel
        chatModel = selection.chatModel
    }

    /// True while a streaming AI operation is in flight (AI-S5). Drives the
    /// future S9 Cancel/Esc affordance and a streaming indicator. Set when a
    /// streaming request starts, cleared when it finishes, errors, or is
    /// cancelled via `cancelAIRequest()`.
    var aiStreaming = false

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
