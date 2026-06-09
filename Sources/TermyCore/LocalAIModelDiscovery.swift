import Foundation

/// A local model reported by Ollama's `GET /api/tags` endpoint.
///
/// Pure, `Sendable` value type so the app-target `AIModel` can store a
/// discovered set. Only the fields Termy's role heuristic needs are modelled;
/// the parser is lenient (missing size/details default to `nil`), mirroring
/// ``LocalAINDJSONLineParser`` — a partial payload never throws.
public struct DiscoveredModel: Equatable, Sendable, Identifiable {
    /// The model tag, e.g. `"qwen2.5-coder:1.5b"`. Used as the request `model`.
    public let name: String
    /// On-disk size in bytes (`size` field), if reported.
    public let sizeBytes: Int?
    /// Human parameter size string (`details.parameter_size`), e.g. `"7.6B"`.
    public let parameterSize: String?

    public var id: String { name }

    public init(name: String, sizeBytes: Int?, parameterSize: String?) {
        self.name = name
        self.sizeBytes = sizeBytes
        self.parameterSize = parameterSize
    }

    /// Parse an Ollama `parameter_size` string (e.g. `"7.6B"`, `"500M"`) into a
    /// billions-of-parameters magnitude. Returns `nil` when the string is
    /// absent or unparseable. `M` suffixes normalise to billions.
    public static func parameterBillions(from parameterSize: String?) -> Double? {
        guard let raw = parameterSize?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        let lower = raw.lowercased()
        let multiplier: Double
        let numericPart: Substring
        if lower.hasSuffix("b") {
            multiplier = 1.0
            numericPart = lower.dropLast()
        } else if lower.hasSuffix("m") {
            multiplier = 0.001
            numericPart = lower.dropLast()
        } else {
            multiplier = 1.0
            numericPart = lower[...]
        }
        guard let value = Double(numericPart) else {
            return nil
        }
        return value * multiplier
    }
}

/// A resolved completion/chat model pair derived from a discovered set.
public struct AIModelRoleSelection: Equatable, Sendable {
    /// The small, low-latency model for inline completion (FIM).
    public let completionModel: String
    /// The larger conversational/explanation model (7–14B class).
    public let chatModel: String

    public init(completionModel: String, chatModel: String) {
        self.completionModel = completionModel
        self.chatModel = chatModel
    }
}

/// Pure parsing + heuristics for local-model auto-discovery and role assignment.
///
/// Isolated from transport so it can be unit-tested directly over canned
/// `/api/tags` payloads — never the network.
public enum LocalAIModelDiscovery {
    /// The parameter-count ceiling (in billions) for the low-latency completion
    /// lane. Models at or below this are eligible for the completion role; the
    /// chat role wants larger (7–14B class) models.
    static let completionSizeCeilingBillions = 4.0

    /// On-disk byte ceiling used only when `parameter_size` is unreported.
    /// ~6 GB roughly separates a small (≤~4B, Q4) coder from a 7–14B model.
    static let completionSizeCeilingBytes = 6_000_000_000

    /// Parse a `GET /api/tags` response body into discovered models.
    ///
    /// Lenient: a malformed payload, a missing `models` array, or entries with
    /// neither `name` nor `model` yield an empty/filtered result rather than
    /// throwing. An entry's `name` falls back to its `model` field.
    public static func parseTagsResponse(_ data: Data) -> [DiscoveredModel] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawModels = json["models"] as? [[String: Any]] else {
            return []
        }
        return rawModels.compactMap { entry in
            let name = (entry["name"] as? String) ?? (entry["model"] as? String)
            guard let name, !name.isEmpty else {
                return nil
            }
            let size = entry["size"] as? Int
            let parameterSize = (entry["details"] as? [String: Any])?["parameter_size"] as? String
            return DiscoveredModel(name: name, sizeBytes: size, parameterSize: parameterSize)
        }
    }

    /// Whether a discovered model is small enough for the completion lane.
    private static func isSmall(_ model: DiscoveredModel) -> Bool {
        if let billions = DiscoveredModel.parameterBillions(from: model.parameterSize) {
            return billions <= completionSizeCeilingBillions
        }
        if let bytes = model.sizeBytes {
            return bytes <= completionSizeCeilingBytes
        }
        // Unknown magnitude: assume not-small so it doesn't displace a real
        // small completion model.
        return false
    }

    /// The heuristic default role for a single model.
    ///
    /// A code model (``LocalAIClient/isFIMCapable(_:)``) that is small enough
    /// for the low-latency lane is a completion model; everything else (large
    /// code models, general chat models) is a chat model. Pure + offline.
    public static func defaultRole(for model: DiscoveredModel) -> LocalAIRole {
        if LocalAIClient.isFIMCapable(model.name) && isSmall(model) {
            return .completion
        }
        return .chat
    }

    /// Pick a sensible completion/chat pair from a discovered set.
    ///
    /// Completion = the smallest completion-eligible (small + FIM-capable)
    /// model; falls back to the smallest model overall. Chat = the largest
    /// chat-eligible model; falls back to the largest model overall. Returns
    /// `nil` for an empty set.
    public static func defaultSelection(from models: [DiscoveredModel]) -> AIModelRoleSelection? {
        guard !models.isEmpty else { return nil }

        let completionCandidates = models.filter { defaultRole(for: $0) == .completion }
        let chatCandidates = models.filter { defaultRole(for: $0) == .chat }

        let completion = (completionCandidates.isEmpty ? models : completionCandidates)
            .min(by: { magnitude(of: $0) < magnitude(of: $1) })
        let chat = (chatCandidates.isEmpty ? models : chatCandidates)
            .max(by: { magnitude(of: $0) < magnitude(of: $1) })

        guard let completion, let chat else { return nil }
        return AIModelRoleSelection(completionModel: completion.name, chatModel: chat.name)
    }

    /// A comparable magnitude for ordering: prefers parameter size, falls back
    /// to on-disk bytes, then zero.
    private static func magnitude(of model: DiscoveredModel) -> Double {
        if let billions = DiscoveredModel.parameterBillions(from: model.parameterSize) {
            return billions
        }
        if let bytes = model.sizeBytes {
            // Normalise bytes into an approximate billions scale for ordering.
            return Double(bytes) / 1_000_000_000.0
        }
        return 0
    }
}
