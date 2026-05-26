import Foundation

public enum CompletionKind: String, Sendable {
    case history
    case command
    case flag
    case file
    case sshHost
    case gitBranch
    case builtin
    case alias
    case directory
    case option
}

public struct CompletionCandidate: Equatable, Sendable {
    public let title: String
    public let replacement: String
    public let kind: CompletionKind
    public let description: String?

    public init(
        title: String,
        replacement: String,
        kind: CompletionKind,
        description: String? = nil
    ) {
        self.title = title
        self.replacement = replacement
        self.kind = kind
        self.description = description
    }
}

public struct InlineAutosuggestion: Equatable, Sendable {
    public let replacement: String
    public let ghostText: String
}

public struct CompletionEngine: Sendable {
    private let history: [String]
    private let commandNames: [String]
    private let commandFlags: [String: [String]]
    private let filePaths: [String]
    private let sshHosts: [String]
    private let gitBranches: [String]

    public init(
        history: [String] = [],
        commandNames: [String] = [],
        commandFlags: [String: [String]] = [:],
        filePaths: [String] = [],
        sshHosts: [String] = [],
        gitBranches: [String] = []
    ) {
        self.history = history
        self.commandNames = commandNames
        self.commandFlags = commandFlags
        self.filePaths = filePaths
        self.sshHosts = sshHosts
        self.gitBranches = gitBranches
    }

    public func suggestions(for input: String, limit: Int = 6) -> [CompletionCandidate] {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        if let flagPrefix = lastToken(in: trimmed),
           flagPrefix.hasPrefix("-"),
           let command = trimmed.split(separator: " ").first.map(String.init) {
            return matches(in: commandFlags[command] ?? [], prefix: flagPrefix)
                .map { CompletionCandidate(title: $0, replacement: replaceLastToken(in: trimmed, with: $0), kind: .flag) }
                .prefixArray(limit)
        }

        if let branchPrefix = suffix(afterAnyPrefix: ["git checkout ", "git switch "], in: trimmed) {
            return matches(in: gitBranches, prefix: branchPrefix)
                .map { CompletionCandidate(title: $0, replacement: replaceLastToken(in: trimmed, with: $0), kind: .gitBranch) }
                .prefixArray(limit)
        }

        if let sshPrefix = suffix(afterAnyPrefix: ["ssh "], in: trimmed) {
            return matches(in: sshHosts, prefix: sshPrefix)
                .map { CompletionCandidate(title: $0, replacement: "ssh \($0)", kind: .sshHost) }
                .prefixArray(limit)
        }

        if expectsPath(trimmed), let token = trimmed.split(separator: " ").last.map(String.init) {
            return fileMatches(prefix: token)
                .map { CompletionCandidate(title: $0, replacement: replaceLastToken(in: trimmed, with: $0), kind: .file) }
                .prefixArray(limit)
        }

        if !trimmed.contains(" ") {
            let commandCandidates = matches(in: commandNames, prefix: trimmed)
                .map { CompletionCandidate(title: $0, replacement: $0, kind: .command) }
                .prefixArray(limit)
            if !commandCandidates.isEmpty {
                return commandCandidates
            }
        }

        return matches(in: history, prefix: trimmed)
            .map { CompletionCandidate(title: $0, replacement: $0, kind: .history) }
            .prefixArray(limit)
    }

    public func inlineAutosuggestion(for input: String) -> InlineAutosuggestion? {
        guard !input.isEmpty else { return nil }
        let lowercasedInput = input.lowercased()
        guard let match = history.first(where: {
            $0.count > input.count && $0.lowercased().hasPrefix(lowercasedInput)
        }) else {
            return nil
        }

        let ghostStart = match.index(match.startIndex, offsetBy: input.count)
        return InlineAutosuggestion(
            replacement: match,
            ghostText: String(match[ghostStart...])
        )
    }

    private func suffix(afterAnyPrefix prefixes: [String], in input: String) -> String? {
        for prefix in prefixes where input.hasPrefix(prefix) {
            return String(input.dropFirst(prefix.count))
        }
        return nil
    }

    private func expectsPath(_ input: String) -> Bool {
        let command = input.split(separator: " ").first.map(String.init) ?? ""
        return ["cat", "cd", "ls", "open", "vim", "nano", "code"].contains(command)
    }

    private func matches(in values: [String], prefix: String) -> [String] {
        values
            .filter { prefix.isEmpty || $0.localizedCaseInsensitiveContains(prefix) }
            .sorted { lhs, rhs in
                let lhsStarts = lhs.localizedCaseInsensitiveCompare(prefix) == .orderedSame || lhs.lowercased().hasPrefix(prefix.lowercased())
                let rhsStarts = rhs.localizedCaseInsensitiveCompare(prefix) == .orderedSame || rhs.lowercased().hasPrefix(prefix.lowercased())
                if lhsStarts != rhsStarts { return lhsStarts }
                return lhs.localizedStandardCompare(rhs) == .orderedAscending
            }
    }

    private func fileMatches(prefix: String) -> [String] {
        let lowercasedPrefix = prefix.lowercased()
        return filePaths
            .filter {
                lowercasedPrefix.isEmpty
                    || $0.lowercased().hasPrefix(lowercasedPrefix)
                    || URL(fileURLWithPath: $0).lastPathComponent.lowercased().hasPrefix(lowercasedPrefix)
            }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private func replaceLastToken(in input: String, with replacement: String) -> String {
        guard let lastSpace = input.lastIndex(of: " ") else {
            return replacement
        }
        return String(input[..<input.index(after: lastSpace)]) + replacement
    }

    private func lastToken(in input: String) -> String? {
        input.split(separator: " ", omittingEmptySubsequences: false).last.map(String.init)
    }
}

private extension Array {
    func prefixArray(_ maxLength: Int) -> [Element] {
        Array(prefix(maxLength))
    }
}
