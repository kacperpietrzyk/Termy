import Foundation

public enum LocalAIClientError: Error, Equatable {
    case invalidResponse
    case requestFailed(Int)
    case emptySuggestion
    /// An error object surfaced mid-stream by the model (`{"error":"..."}`).
    case streamError(String)
}

public struct LocalAICommandSuggestion: Equatable, Sendable {
    public let command: String
}

public struct LocalAITextSuggestion: Equatable, Sendable {
    public let text: String
}

public struct LocalAIClient {
    public let endpoint: LocalAIEndpoint
    public let model: String
    private let session: URLSession

    public init(endpoint: LocalAIEndpoint, model: String = "qwen2.5-coder", session: URLSession = .shared) {
        self.endpoint = endpoint
        self.model = model
        self.session = session
    }

    public func suggestCommand(for description: String, projectGuidance: String? = nil) async throws -> LocalAICommandSuggestion {
        let prompt = Self.suggestCommandPrompt(for: description, projectGuidance: projectGuidance)
        let response = try await generate(prompt: prompt)
        let command = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else {
            throw LocalAIClientError.emptySuggestion
        }
        return LocalAICommandSuggestion(command: command)
    }

    public func suggestCommitMessage(forDiff diff: String) async throws -> LocalAITextSuggestion {
        let response = try await generate(prompt: Self.commitMessagePrompt(forDiff: diff))
        let text = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw LocalAIClientError.emptySuggestion
        }
        return LocalAITextSuggestion(text: text)
    }

    public func answerQuestion(
        _ question: String,
        projectGuidance: String? = nil
    ) async throws -> LocalAITextSuggestion {
        let response = try await generate(prompt: Self.answerQuestionPrompt(question, projectGuidance: projectGuidance))
        let text = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw LocalAIClientError.emptySuggestion
        }
        return LocalAITextSuggestion(text: text)
    }

    public func explainFailedCommand(
        command: String,
        output: String,
        projectGuidance: String? = nil
    ) async throws -> LocalAITextSuggestion {
        let prompt = Self.explainFailedCommandPrompt(command: command, output: output, projectGuidance: projectGuidance)
        let response = try await generate(prompt: prompt)
        let text = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw LocalAIClientError.emptySuggestion
        }
        return LocalAITextSuggestion(text: text)
    }

    public func explainGitConflict(
        hunks: [GitConflictHunk],
        projectGuidance: String? = nil
    ) async throws -> LocalAITextSuggestion {
        let response = try await generate(prompt: Self.explainGitConflictPrompt(hunks: hunks, projectGuidance: projectGuidance))
        let text = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw LocalAIClientError.emptySuggestion
        }
        return LocalAITextSuggestion(text: text)
    }

    public func suggestEditorEdit(
        instruction: String,
        buffer: String,
        projectGuidance: String? = nil
    ) async throws -> LocalAITextSuggestion {
        let prompt = Self.editorEditPrompt(instruction: instruction, buffer: buffer, projectGuidance: projectGuidance)
        let response = try await generate(prompt: prompt)
        let text = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw LocalAIClientError.emptySuggestion
        }
        return LocalAITextSuggestion(text: text)
    }

    public func explainEditorSelection(
        _ selection: String,
        projectGuidance: String? = nil
    ) async throws -> LocalAITextSuggestion {
        let response = try await generate(prompt: Self.explainEditorSelectionPrompt(selection, projectGuidance: projectGuidance))
        let text = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw LocalAIClientError.emptySuggestion
        }
        return LocalAITextSuggestion(text: text)
    }

    // MARK: - Prompt builders (single source for both the blocking and streaming paths)

    private static func guidanceContext(_ projectGuidance: String?) -> String {
        let guidance = projectGuidance?.trimmingCharacters(in: .whitespacesAndNewlines)
        return guidance?.isEmpty == false ? "\nProject guidance:\n\(guidance!)\n" : ""
    }

    static func suggestCommandPrompt(for description: String, projectGuidance: String?) -> String {
        """
        Convert this request into one safe shell command. Return only the command, no markdown.\(guidanceContext(projectGuidance))
        Request: \(description)
        """
    }

    static func commitMessagePrompt(forDiff diff: String) -> String {
        """
        Write one concise git commit message for this diff. Use imperative mood. Return only the commit message, no markdown.
        Diff:
        \(diff)
        """
    }

    static func answerQuestionPrompt(_ question: String, projectGuidance: String?) -> String {
        """
        Answer this developer question concisely. Return plain text, no markdown.\(guidanceContext(projectGuidance))
        Question:
        \(question)
        """
    }

    static func explainFailedCommandPrompt(command: String, output: String, projectGuidance: String?) -> String {
        """
        Briefly explain why this command failed and suggest the safest next fix. Return plain text, no markdown.\(guidanceContext(projectGuidance))
        Command:
        \(command)

        Output:
        \(output)
        """
    }

    static func explainGitConflictPrompt(hunks: [GitConflictHunk], projectGuidance: String?) -> String {
        let conflictText = hunks.map { hunk in
            """
            File: \(hunk.path)
            Ours (\(hunk.oursLabel)):
            \(hunk.ours)

            Theirs (\(hunk.theirsLabel)):
            \(hunk.theirs)
            """
        }.joined(separator: "\n\n")
        return """
        Explain this git merge conflict and suggest the safest manual resolution. Return plain text, no markdown.\(guidanceContext(projectGuidance))
        \(conflictText)
        """
    }

    static func editorEditPrompt(instruction: String, buffer: String, projectGuidance: String?) -> String {
        """
        Rewrite this editor buffer according to the instruction. Return only the full replacement text or a unified diff patch, no markdown.\(guidanceContext(projectGuidance))
        Instruction:
        \(instruction)

        Buffer:
        \(buffer)
        """
    }

    static func explainEditorSelectionPrompt(_ selection: String, projectGuidance: String?) -> String {
        """
        Explain this selected editor text concisely. Return plain text, no markdown.\(guidanceContext(projectGuidance))
        Selection:
        \(selection)
        """
    }

    // MARK: - Streaming siblings (S5)
    //
    // Each returns the S1 token stream built from the SAME prompt as its
    // blocking counterpart above. The store accumulates tokens into its target
    // observable field as they arrive (live streaming + Esc-cancel), while the
    // blocking variants stay on the `stream:false` path that existing callers
    // and unit tests depend on.

    public func suggestCommandStream(
        for description: String,
        projectGuidance: String? = nil,
        role: LocalAIRole = .chat
    ) -> AsyncThrowingStream<LocalAIToken, Error> {
        generateStream(prompt: Self.suggestCommandPrompt(for: description, projectGuidance: projectGuidance), role: role)
    }

    public func suggestCommitMessageStream(
        forDiff diff: String,
        role: LocalAIRole = .chat
    ) -> AsyncThrowingStream<LocalAIToken, Error> {
        generateStream(prompt: Self.commitMessagePrompt(forDiff: diff), role: role)
    }

    public func answerQuestionStream(
        _ question: String,
        projectGuidance: String? = nil,
        role: LocalAIRole = .chat
    ) -> AsyncThrowingStream<LocalAIToken, Error> {
        generateStream(prompt: Self.answerQuestionPrompt(question, projectGuidance: projectGuidance), role: role)
    }

    public func explainFailedCommandStream(
        command: String,
        output: String,
        projectGuidance: String? = nil,
        role: LocalAIRole = .chat
    ) -> AsyncThrowingStream<LocalAIToken, Error> {
        generateStream(
            prompt: Self.explainFailedCommandPrompt(command: command, output: output, projectGuidance: projectGuidance),
            role: role
        )
    }

    public func explainGitConflictStream(
        hunks: [GitConflictHunk],
        projectGuidance: String? = nil,
        role: LocalAIRole = .chat
    ) -> AsyncThrowingStream<LocalAIToken, Error> {
        generateStream(prompt: Self.explainGitConflictPrompt(hunks: hunks, projectGuidance: projectGuidance), role: role)
    }

    public func suggestEditorEditStream(
        instruction: String,
        buffer: String,
        projectGuidance: String? = nil,
        role: LocalAIRole = .chat
    ) -> AsyncThrowingStream<LocalAIToken, Error> {
        generateStream(
            prompt: Self.editorEditPrompt(instruction: instruction, buffer: buffer, projectGuidance: projectGuidance),
            role: role
        )
    }

    public func explainEditorSelectionStream(
        _ selection: String,
        projectGuidance: String? = nil,
        role: LocalAIRole = .chat
    ) -> AsyncThrowingStream<LocalAIToken, Error> {
        generateStream(prompt: Self.explainEditorSelectionPrompt(selection, projectGuidance: projectGuidance), role: role)
    }

    /// The set of local-model name fragments known to support native
    /// fill-in-the-middle (FIM) via Ollama's `suffix` field on `/api/generate`.
    ///
    /// FIM-capable code models accept a prefix/suffix pair and infill the gap
    /// using their FIM tokens — a far higher-quality completion than the legacy
    /// prose `Complete… Prefix:/Suffix:` prompt. Matching is a pure, offline,
    /// case-insensitive substring test against the configured model name; no
    /// network probe (model auto-discovery via `GET /api/tags` is a later slice).
    private static let fimCapableModelFragments: [String] = [
        "qwen2.5-coder",
        "qwen-coder",
        "qwen3-coder",
        "codellama",
        "deepseek-coder",
        "starcoder",
        "codegemma",
        "stable-code",
        "stablecode",
        "codestral",
        "granite-code"
    ]

    /// Whether `model` is known to support native FIM completion.
    ///
    /// Pure, offline name classifier — used to route the completion path to
    /// native `suffix`-field FIM (capable) or the legacy prose prompt (otherwise).
    public static func isFIMCapable(_ model: String) -> Bool {
        let normalized = model.lowercased()
        return fimCapableModelFragments.contains { normalized.contains($0) }
    }

    /// Native fill-in-the-middle completion at the cursor.
    ///
    /// For FIM-capable models (``isFIMCapable(_:)``) this sends `prompt: prefix`
    /// plus the Ollama `suffix` field so the model infills the gap with its
    /// native FIM tokens — the highest-ROI completion-quality path. For
    /// non-FIM models it gracefully falls back to the legacy prose prompt
    /// (no `suffix` field). Either path is accumulated from the S1 streaming
    /// transport (``generateStream(prompt:suffix:role:options:)``).
    ///
    /// - Parameters:
    ///   - prefix: Buffer text before the cursor.
    ///   - suffix: Buffer text after the cursor.
    ///   - role: The request role (defaults to `.completion`).
    ///   - projectGuidance: Optional project guidance — applied only on the
    ///     prose fallback path (native FIM has no prompt slot for it).
    public func completeFIM(
        prefix: String,
        suffix: String,
        role: LocalAIRole = .completion,
        projectGuidance: String? = nil
    ) async throws -> LocalAITextSuggestion {
        let prompt: String
        let fimSuffix: String?
        if Self.isFIMCapable(model) {
            // Native FIM: the model infills between prefix and suffix.
            prompt = prefix
            fimSuffix = suffix
        } else {
            // Graceful fallback: the legacy prose prompt, no suffix field.
            let guidance = projectGuidance?.trimmingCharacters(in: .whitespacesAndNewlines)
            let context = guidance?.isEmpty == false ? "\nProject guidance:\n\(guidance!)\n" : ""
            prompt = """
            Complete this editor buffer at the cursor. Return only the text to insert at the cursor, no markdown.\(context)
            Prefix:
            \(prefix)

            Suffix:
            \(suffix)
            """
            fimSuffix = nil
        }

        var response = ""
        for try await token in generateStream(prompt: prompt, suffix: fimSuffix, role: role) {
            response += token.response
        }
        let text = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw LocalAIClientError.emptySuggestion
        }
        return LocalAITextSuggestion(text: text)
    }

    /// Editor completion at the cursor, re-pointed onto native FIM.
    ///
    /// Preserves the original signature so the existing store caller is
    /// unchanged; delegates to ``completeFIM(prefix:suffix:role:projectGuidance:)``.
    public func suggestEditorCompletion(
        prefix: String,
        suffix: String,
        projectGuidance: String? = nil
    ) async throws -> LocalAITextSuggestion {
        try await completeFIM(prefix: prefix, suffix: suffix, projectGuidance: projectGuidance)
    }

    /// Auto-discover the models installed on the local Ollama server.
    ///
    /// Issues `GET /api/tags` against the (already localhost-validated)
    /// endpoint and parses the payload via ``LocalAIModelDiscovery``. The
    /// zero-remote invariant holds by construction: `endpoint` only ever
    /// resolves to loopback. Parsing is lenient — a partial payload yields a
    /// best-effort list rather than throwing; only transport failures throw.
    public func discoverModels() async throws -> [DiscoveredModel] {
        var request = URLRequest(url: endpoint.url.appending(path: "api/tags"))
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw LocalAIClientError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw LocalAIClientError.requestFailed(http.statusCode)
        }
        return LocalAIModelDiscovery.parseTagsResponse(data)
    }

    private func generate(prompt: String) async throws -> String {
        var request = URLRequest(url: endpoint.url.appending(path: "api/generate"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model,
            "prompt": prompt,
            "stream": false
        ])

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw LocalAIClientError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw LocalAIClientError.requestFailed(http.statusCode)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = json["response"] as? String else {
            throw LocalAIClientError.invalidResponse
        }
        return text
    }

    /// Stream a generation as it is produced, one ``LocalAIToken`` per NDJSON line.
    ///
    /// Sends `stream: true` to Ollama's `/api/generate` and parses the
    /// newline-delimited JSON response incrementally via `URLSession.bytes(for:)`.
    /// A terminal token (`done == true`) ends the stream; a mid-stream
    /// `{"error":...}` object surfaces as ``LocalAIClientError/streamError(_:)``.
    ///
    /// The returned stream honours Swift Task cancellation: when the consuming
    /// task is cancelled (e.g. on Esc), the underlying URLSession transfer is
    /// cancelled and the stream finishes.
    ///
    /// - Parameters:
    ///   - prompt: The generation prompt.
    ///   - suffix: Optional text after the cursor (Ollama `suffix` field) — used
    ///     by later FIM work; threaded into the request when non-nil.
    ///   - role: The role of this request. Threaded for forward-compatibility;
    ///     model selection by role arrives in a later slice.
    ///   - options: Optional Ollama generation options passthrough.
    public func generateStream(
        prompt: String,
        suffix: String? = nil,
        role: LocalAIRole = .chat,
        options: LocalAIGenerateOptions? = nil
    ) -> AsyncThrowingStream<LocalAIToken, Error> {
        _ = role
        var body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": true
        ]
        if let suffix {
            body["suffix"] = suffix
        }
        if let optionsObject = options?.jsonObject {
            body["options"] = optionsObject
        }

        let url = endpoint.url.appending(path: "api/generate")
        let session = self.session

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw LocalAIClientError.invalidResponse
                    }
                    guard (200..<300).contains(http.statusCode) else {
                        throw LocalAIClientError.requestFailed(http.statusCode)
                    }

                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        switch LocalAINDJSONLineParser.parse(line) {
                        case .token(let token):
                            continuation.yield(token)
                            if token.done {
                                continuation.finish()
                                return
                            }
                        case .error(let message):
                            throw LocalAIClientError.streamError(message)
                        case .ignored:
                            continue
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
