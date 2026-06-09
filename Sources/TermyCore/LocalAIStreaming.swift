import Foundation

/// A single incremental token emitted by a streaming local-AI generation.
///
/// Ollama's `/api/generate` streaming endpoint returns newline-delimited JSON
/// (NDJSON): one object per line carrying an incremental `response` chunk, with
/// a terminal object marked `done: true` (and an optional `done_reason`).
public struct LocalAIToken: Equatable, Sendable {
    /// The incremental text chunk for this line. Empty on the terminal object.
    public let response: String
    /// Whether this is the terminal object of the stream.
    public let done: Bool
    /// The reason generation stopped, present on the terminal object (e.g. "stop").
    public let doneReason: String?

    public init(response: String, done: Bool, doneReason: String? = nil) {
        self.response = response
        self.done = done
        self.doneReason = doneReason
    }
}

/// The role a generation request plays, used later (S3) to pick a model.
///
/// In this slice the role is threaded honestly but does not yet resolve to a
/// distinct model — the client still uses its single configured model.
public enum LocalAIRole: String, Equatable, Sendable {
    /// Low-latency inline completion (small model in S3).
    case completion
    /// Conversational / explanation work (7–14B model in S3).
    case chat
}

/// A thin passthrough of Ollama generation `options` (e.g. temperature,
/// num_predict). Only the fields Termy needs are modelled; nil fields are
/// omitted from the request body.
public struct LocalAIGenerateOptions: Equatable, Sendable {
    public var temperature: Double?
    public var numPredict: Int?

    public init(temperature: Double? = nil, numPredict: Int? = nil) {
        self.temperature = temperature
        self.numPredict = numPredict
    }

    /// The JSON `options` object for the request body, or nil when empty.
    public var jsonObject: [String: Any]? {
        var object: [String: Any] = [:]
        if let temperature {
            object["temperature"] = temperature
        }
        if let numPredict {
            object["num_predict"] = numPredict
        }
        return object.isEmpty ? nil : object
    }
}

/// Parses one line of an Ollama NDJSON stream into a structured outcome.
///
/// Pure logic, isolated from transport so it can be unit-tested directly over
/// canned lines.
public enum LocalAINDJSONLineParser {
    public enum Outcome: Equatable, Sendable {
        /// A normal incremental (or terminal) token.
        case token(LocalAIToken)
        /// A mid-stream error object: `{"error": "..."}`.
        case error(String)
        /// Blank or unrecognised line — skip it.
        case ignored
    }

    /// Parse a single NDJSON line. Whitespace-only lines are ignored; lines that
    /// carry an `error` field surface as `.error`; anything with a recognisable
    /// `response`/`done` shape becomes a `.token`.
    public static func parse(_ line: String) -> Outcome {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .ignored
        }
        guard let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .ignored
        }

        if let message = json["error"] as? String {
            return .error(message)
        }

        let response = json["response"] as? String
        let done = json["done"] as? Bool
        // A valid generate chunk always carries at least `response` or `done`.
        guard response != nil || done != nil else {
            return .ignored
        }

        return .token(
            LocalAIToken(
                response: response ?? "",
                done: done ?? false,
                doneReason: json["done_reason"] as? String
            )
        )
    }
}
