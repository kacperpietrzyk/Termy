import Foundation

public struct TerminalSearchMatch: Equatable, Sendable {
    public let line: Int
    public let range: Range<Int>
    public let excerpt: String

    public init(line: Int, range: Range<Int>, excerpt: String) {
        self.line = line
        self.range = range
        self.excerpt = excerpt
    }
}

public struct TerminalLink: Equatable, Sendable {
    public let line: Int
    public let urlString: String

    public init(line: Int, urlString: String) {
        self.line = line
        self.urlString = urlString
    }
}

public struct TerminalTextIndex: Sendable {
    private let lines: [String]

    public init(lines: [String]) {
        self.lines = lines
    }

    public func search(_ query: String) -> [TerminalSearchMatch] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        return lines.enumerated().flatMap { lineNumber, line in
            ranges(of: trimmed, in: line).map {
                TerminalSearchMatch(line: lineNumber, range: $0, excerpt: line)
            }
        }
    }

    public func links() -> [TerminalLink] {
        let pattern = #"https?://[^\s<>"']+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        return lines.enumerated().flatMap { lineNumber, line -> [TerminalLink] in
            let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
            return regex.matches(in: line, range: nsRange).compactMap { match -> TerminalLink? in
                guard let range = Range(match.range, in: line) else { return nil }
                return TerminalLink(line: lineNumber, urlString: String(line[range]).trimmedTerminalPunctuation)
            }
        }
    }

    private func ranges(of query: String, in line: String) -> [Range<Int>] {
        var result: [Range<Int>] = []
        var searchRange = line.startIndex..<line.endIndex

        while let range = line.range(of: query, options: [.caseInsensitive], range: searchRange) {
            let start = line.distance(from: line.startIndex, to: range.lowerBound)
            let end = line.distance(from: line.startIndex, to: range.upperBound)
            result.append(start..<end)
            searchRange = range.upperBound..<line.endIndex
        }

        return result
    }
}

private extension String {
    var trimmedTerminalPunctuation: String {
        trimmingCharacters(in: CharacterSet(charactersIn: ".,);]"))
    }
}
