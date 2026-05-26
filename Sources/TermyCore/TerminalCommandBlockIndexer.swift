import Foundation

public enum TerminalTranscriptRole: Equatable, Sendable {
    case prompt
    case output
    case system
}

public struct TerminalTranscriptEntry: Equatable, Sendable {
    public let role: TerminalTranscriptRole
    public let text: String

    public init(role: TerminalTranscriptRole, text: String) {
        self.role = role
        self.text = text
    }
}

public struct TerminalCommandBlock: Equatable, Sendable {
    public let command: String
    public let startLine: Int
    public let endLine: Int
    public let exitCode: Int32?
    public let output: String

    public init(command: String, startLine: Int, endLine: Int, exitCode: Int32?, output: String) {
        self.command = command
        self.startLine = startLine
        self.endLine = endLine
        self.exitCode = exitCode
        self.output = output
    }
}

public struct TerminalCommandBlockIndexer: Sendable {
    public init() {}

    public func blocks(from entries: [TerminalTranscriptEntry]) -> [TerminalCommandBlock] {
        var blocks: [TerminalCommandBlock] = []
        var currentCommand: String?
        var currentStartLine: Int?
        var currentOutput = ""

        for (line, entry) in entries.enumerated() {
            switch entry.role {
            case .prompt:
                if let command = currentCommand, let startLine = currentStartLine {
                    blocks.append(TerminalCommandBlock(
                        command: command,
                        startLine: startLine,
                        endLine: max(startLine, line - 1),
                        exitCode: nil,
                        output: currentOutput
                    ))
                }
                currentCommand = normalizedCommand(from: entry.text)
                currentStartLine = line
                currentOutput = ""
            case .output:
                if currentCommand != nil {
                    currentOutput += entry.text
                }
            case .system:
                if let exitCode = exitCode(from: entry.text),
                   let command = currentCommand,
                   let startLine = currentStartLine {
                    blocks.append(TerminalCommandBlock(
                        command: command,
                        startLine: startLine,
                        endLine: line,
                        exitCode: exitCode,
                        output: currentOutput
                    ))
                    currentCommand = nil
                    currentStartLine = nil
                    currentOutput = ""
                }
            }
        }

        if let command = currentCommand, let startLine = currentStartLine {
            blocks.append(TerminalCommandBlock(
                command: command,
                startLine: startLine,
                endLine: entries.indices.last ?? startLine,
                exitCode: nil,
                output: currentOutput
            ))
        }

        return blocks
    }

    private func normalizedCommand(from prompt: String) -> String {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["$ ", "% ", "# "] where trimmed.hasPrefix(prefix) {
            return String(trimmed.dropFirst(prefix.count))
        }
        return trimmed
    }

    private func exitCode(from text: String) -> Int32? {
        guard text.hasPrefix("Exit ") else { return nil }
        return Int32(text.dropFirst("Exit ".count).trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

public struct TerminalCommandBlockVisibility: Sendable {
    public init() {}

    public func hiddenLineIndexes(
        for blocks: [TerminalCommandBlock],
        foldedStartLines: Set<Int>
    ) -> Set<Int> {
        var hidden: Set<Int> = []

        for block in blocks where foldedStartLines.contains(block.startLine) {
            guard block.endLine > block.startLine + 1 else { continue }
            hidden.formUnion((block.startLine + 1)..<block.endLine)
        }

        return hidden
    }

    public func nextBlockStart(after current: Int?, in blocks: [TerminalCommandBlock]) -> Int? {
        guard !blocks.isEmpty else { return nil }
        guard let current else { return blocks.first?.startLine }
        return blocks.first { $0.startLine > current }?.startLine ?? blocks.first?.startLine
    }

    public func previousBlockStart(before current: Int?, in blocks: [TerminalCommandBlock]) -> Int? {
        guard !blocks.isEmpty else { return nil }
        guard let current else { return blocks.last?.startLine }
        return blocks.last { $0.startLine < current }?.startLine ?? blocks.last?.startLine
    }
}
