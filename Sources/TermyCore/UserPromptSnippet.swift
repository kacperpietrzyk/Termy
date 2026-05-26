import Foundation

public struct UserPromptSnippet: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let body: String

    public init(id: String, title: String, body: String) {
        self.id = id
        self.title = title
        self.body = body
    }
}

public struct UserPromptSnippetLibrary: Equatable, Sendable {
    public let snippets: [UserPromptSnippet]

    public init(snippets: [UserPromptSnippet]) {
        self.snippets = snippets
    }

    public func promptContext() -> String {
        activeSnippets()
            .map { "\($0.title)\n\($0.body.trimmingCharacters(in: .whitespacesAndNewlines))" }
            .joined(separator: "\n\n")
    }

    /// Snippets with non-blank bodies. `public` so the sync layer can map
    /// them across the `TermySync` target boundary without
    /// `UserPromptSnippetLibrary` carrying sync-DTO knowledge.
    public func activeSnippets() -> [UserPromptSnippet] {
        snippets.filter { !$0.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}
