import Foundation

public struct ProjectGuidanceDocument: Equatable, Sendable {
    public let fileName: String
    public let contents: String

    public init(fileName: String, contents: String) {
        self.fileName = fileName
        self.contents = contents
    }
}

public struct ProjectGuidance: Equatable, Sendable {
    public let documents: [ProjectGuidanceDocument]

    public init(documents: [ProjectGuidanceDocument]) {
        self.documents = documents
    }

    public func combinedContext(maxCharacters: Int) -> String {
        guard maxCharacters > 0 else { return "" }
        let context = documents
            .map { "# \($0.fileName)\n\($0.contents)" }
            .joined(separator: "\n\n")
        return String(context.prefix(maxCharacters))
    }
}

public struct ProjectGuidanceLoader: Sendable {
    public init() {}

    public func load(from root: URL) -> ProjectGuidance {
        let documents = ["TERMY.md", "CLAUDE.md", "AGENTS.md"].compactMap { fileName -> ProjectGuidanceDocument? in
            let url = root.appendingPathComponent(fileName)
            guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
                return nil
            }
            return ProjectGuidanceDocument(fileName: fileName, contents: contents)
        }
        return ProjectGuidance(documents: documents)
    }
}
