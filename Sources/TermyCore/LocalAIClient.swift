import Foundation

public enum LocalAIClientError: Error, Equatable {
    case invalidResponse
    case requestFailed(Int)
    case emptySuggestion
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
        let guidance = projectGuidance?.trimmingCharacters(in: .whitespacesAndNewlines)
        let context = guidance?.isEmpty == false ? "\nProject guidance:\n\(guidance!)\n" : ""
        let prompt = """
        Convert this request into one safe shell command. Return only the command, no markdown.\(context)
        Request: \(description)
        """
        let response = try await generate(prompt: prompt)
        let command = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else {
            throw LocalAIClientError.emptySuggestion
        }
        return LocalAICommandSuggestion(command: command)
    }

    public func suggestCommitMessage(forDiff diff: String) async throws -> LocalAITextSuggestion {
        let prompt = """
        Write one concise git commit message for this diff. Use imperative mood. Return only the commit message, no markdown.
        Diff:
        \(diff)
        """
        let response = try await generate(prompt: prompt)
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
        let guidance = projectGuidance?.trimmingCharacters(in: .whitespacesAndNewlines)
        let context = guidance?.isEmpty == false ? "\nProject guidance:\n\(guidance!)\n" : ""
        let prompt = """
        Answer this developer question concisely. Return plain text, no markdown.\(context)
        Question:
        \(question)
        """
        let response = try await generate(prompt: prompt)
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
        let guidance = projectGuidance?.trimmingCharacters(in: .whitespacesAndNewlines)
        let context = guidance?.isEmpty == false ? "\nProject guidance:\n\(guidance!)\n" : ""
        let prompt = """
        Briefly explain why this command failed and suggest the safest next fix. Return plain text, no markdown.\(context)
        Command:
        \(command)

        Output:
        \(output)
        """
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
        let guidance = projectGuidance?.trimmingCharacters(in: .whitespacesAndNewlines)
        let context = guidance?.isEmpty == false ? "\nProject guidance:\n\(guidance!)\n" : ""
        let conflictText = hunks.map { hunk in
            """
            File: \(hunk.path)
            Ours (\(hunk.oursLabel)):
            \(hunk.ours)

            Theirs (\(hunk.theirsLabel)):
            \(hunk.theirs)
            """
        }.joined(separator: "\n\n")
        let prompt = """
        Explain this git merge conflict and suggest the safest manual resolution. Return plain text, no markdown.\(context)
        \(conflictText)
        """
        let response = try await generate(prompt: prompt)
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
        let guidance = projectGuidance?.trimmingCharacters(in: .whitespacesAndNewlines)
        let context = guidance?.isEmpty == false ? "\nProject guidance:\n\(guidance!)\n" : ""
        let prompt = """
        Rewrite this editor buffer according to the instruction. Return only the full replacement text or a unified diff patch, no markdown.\(context)
        Instruction:
        \(instruction)

        Buffer:
        \(buffer)
        """
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
        let guidance = projectGuidance?.trimmingCharacters(in: .whitespacesAndNewlines)
        let context = guidance?.isEmpty == false ? "\nProject guidance:\n\(guidance!)\n" : ""
        let prompt = """
        Explain this selected editor text concisely. Return plain text, no markdown.\(context)
        Selection:
        \(selection)
        """
        let response = try await generate(prompt: prompt)
        let text = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw LocalAIClientError.emptySuggestion
        }
        return LocalAITextSuggestion(text: text)
    }

    public func suggestEditorCompletion(
        prefix: String,
        suffix: String,
        projectGuidance: String? = nil
    ) async throws -> LocalAITextSuggestion {
        let guidance = projectGuidance?.trimmingCharacters(in: .whitespacesAndNewlines)
        let context = guidance?.isEmpty == false ? "\nProject guidance:\n\(guidance!)\n" : ""
        let prompt = """
        Complete this editor buffer at the cursor. Return only the text to insert at the cursor, no markdown.\(context)
        Prefix:
        \(prefix)

        Suffix:
        \(suffix)
        """
        let response = try await generate(prompt: prompt)
        let text = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw LocalAIClientError.emptySuggestion
        }
        return LocalAITextSuggestion(text: text)
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
}
