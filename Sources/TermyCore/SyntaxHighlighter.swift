import Foundation

public enum SyntaxTokenKind: String, Equatable, Sendable {
    case plain
    case heading
    case keyword
    case string
    case key
    case number
    case comment
}

public struct SyntaxToken: Equatable, Sendable {
    public let text: String
    public let kind: SyntaxTokenKind

    public init(text: String, kind: SyntaxTokenKind) {
        self.text = text
        self.kind = kind
    }
}

public struct SyntaxHighlighter: Sendable {
    public init() {}

    public func highlight(_ source: String, fileName: String?) -> [SyntaxToken] {
        switch language(for: fileName) {
        case .markdown:
            return highlightMarkdown(source)
        case .json:
            return highlightJSON(source)
        case .swift:
            return highlightCode(
                source,
                keywords: [
                    "actor", "class", "enum", "func", "import", "let", "private", "public", "return",
                    "struct", "var"
                ],
                commentPrefix: "//"
            )
        case .javascript:
            return highlightCode(
                source,
                keywords: ["async", "await", "class", "const", "export", "function", "import", "let", "return", "type", "var"],
                commentPrefix: "//"
            )
        case .python:
            return highlightCode(
                source,
                keywords: ["class", "def", "from", "import", "lambda", "pass", "return", "self"],
                commentPrefix: "#"
            )
        case .rust:
            return highlightCode(
                source,
                keywords: ["enum", "fn", "impl", "let", "match", "mod", "pub", "struct", "use"],
                commentPrefix: "//"
            )
        case .html:
            return highlightHTML(source)
        case .css:
            return highlightCSS(source)
        case .plain:
            return [SyntaxToken(text: source, kind: .plain)]
        }
    }

    private func language(for fileName: String?) -> SyntaxLanguage {
        guard let ext = fileName?.split(separator: ".").last?.lowercased() else {
            return .plain
        }
        switch ext {
        case "md", "markdown":
            return .markdown
        case "json":
            return .json
        case "swift":
            return .swift
        case "js", "jsx", "ts", "tsx", "mjs", "cjs":
            return .javascript
        case "py":
            return .python
        case "rs":
            return .rust
        case "html", "htm":
            return .html
        case "css":
            return .css
        default:
            return .plain
        }
    }

    private func highlightMarkdown(_ source: String) -> [SyntaxToken] {
        source.split(separator: "\n", omittingEmptySubsequences: false).enumerated().flatMap { index, line in
            var tokens: [SyntaxToken] = []
            let text = String(line)
            if text.hasPrefix("#") {
                tokens.append(SyntaxToken(text: text, kind: .heading))
            } else {
                tokens.append(SyntaxToken(text: text, kind: .plain))
            }
            if index < source.split(separator: "\n", omittingEmptySubsequences: false).count - 1 {
                tokens.append(SyntaxToken(text: "\n", kind: .plain))
            }
            return tokens
        }
    }

    private func highlightJSON(_ source: String) -> [SyntaxToken] {
        var tokens: [SyntaxToken] = []
        var index = source.startIndex

        while index < source.endIndex {
            if source[index] == "\"" {
                let start = index
                index = source.index(after: index)
                var escaped = false
                while index < source.endIndex {
                    let character = source[index]
                    index = source.index(after: index)
                    if character == "\\" {
                        escaped.toggle()
                    } else if character == "\"", !escaped {
                        break
                    } else {
                        escaped = false
                    }
                }
                let string = String(source[start..<index])
                let nextNonSpace = source[index...].first { !$0.isWhitespace }
                tokens.append(SyntaxToken(text: string, kind: nextNonSpace == ":" ? .key : .string))
            } else if source[index].isNumber {
                let start = index
                while index < source.endIndex, source[index].isNumber {
                    index = source.index(after: index)
                }
                tokens.append(SyntaxToken(text: String(source[start..<index]), kind: .number))
            } else {
                let start = index
                index = source.index(after: index)
                tokens.append(SyntaxToken(text: String(source[start..<index]), kind: .plain))
            }
        }

        return coalesce(tokens)
    }

    private func highlightCode(_ source: String, keywords: Set<String>, commentPrefix: String) -> [SyntaxToken] {
        var tokens: [SyntaxToken] = []
        var index = source.startIndex

        while index < source.endIndex {
            if source[index] == "\"" || source[index] == "'" {
                let quote = source[index]
                let start = index
                index = source.index(after: index)
                while index < source.endIndex {
                    // Bound an unterminated string to its own line so a single stray
                    // quote can't render the entire rest of the file as a string. A
                    // terminated single-line string is unaffected (it breaks on the
                    // closing quote first).
                    if source[index] == "\n" { break }
                    let character = source[index]
                    index = source.index(after: index)
                    if character == quote { break }
                }
                tokens.append(SyntaxToken(text: String(source[start..<index]), kind: .string))
            } else if source[index...].hasPrefix(commentPrefix) {
                let start = index
                while index < source.endIndex, source[index] != "\n" {
                    index = source.index(after: index)
                }
                tokens.append(SyntaxToken(text: String(source[start..<index]), kind: .comment))
            } else if source[index].isLetter || source[index] == "_" {
                let start = index
                while index < source.endIndex, source[index].isLetter || source[index].isNumber || source[index] == "_" {
                    index = source.index(after: index)
                }
                let word = String(source[start..<index])
                tokens.append(SyntaxToken(text: word, kind: keywords.contains(word) ? .keyword : .plain))
            } else if source[index].isNumber {
                let start = index
                while index < source.endIndex, source[index].isNumber {
                    index = source.index(after: index)
                }
                tokens.append(SyntaxToken(text: String(source[start..<index]), kind: .number))
            } else {
                let start = index
                index = source.index(after: index)
                tokens.append(SyntaxToken(text: String(source[start..<index]), kind: .plain))
            }
        }

        return coalesce(tokens)
    }

    private func highlightHTML(_ source: String) -> [SyntaxToken] {
        var tokens: [SyntaxToken] = []
        var index = source.startIndex

        while index < source.endIndex {
            if source[index] == "<" {
                let start = index
                index = source.index(after: index)
                while index < source.endIndex, source[index].isLetter || source[index] == "/" {
                    index = source.index(after: index)
                }
                tokens.append(SyntaxToken(text: String(source[start..<index]), kind: .keyword))
            } else if source[index] == "\"" || source[index] == "'" {
                let quote = source[index]
                let start = index
                index = source.index(after: index)
                while index < source.endIndex {
                    let character = source[index]
                    index = source.index(after: index)
                    if character == quote { break }
                }
                tokens.append(SyntaxToken(text: String(source[start..<index]), kind: .string))
            } else {
                let start = index
                index = source.index(after: index)
                tokens.append(SyntaxToken(text: String(source[start..<index]), kind: .plain))
            }
        }

        return coalesce(tokens)
    }

    private func highlightCSS(_ source: String) -> [SyntaxToken] {
        var tokens: [SyntaxToken] = []
        var index = source.startIndex

        while index < source.endIndex {
            if source[index].isLetter || source[index] == "-" {
                let start = index
                while index < source.endIndex, source[index].isLetter || source[index].isNumber || source[index] == "-" {
                    index = source.index(after: index)
                }
                let word = String(source[start..<index])
                let nextNonSpace = source[index...].first { !$0.isWhitespace }
                tokens.append(SyntaxToken(text: word, kind: nextNonSpace == ":" ? .key : .plain))
            } else if source[index] == "\"" || source[index] == "'" {
                let quote = source[index]
                let start = index
                index = source.index(after: index)
                while index < source.endIndex {
                    let character = source[index]
                    index = source.index(after: index)
                    if character == quote { break }
                }
                tokens.append(SyntaxToken(text: String(source[start..<index]), kind: .string))
            } else {
                let start = index
                index = source.index(after: index)
                tokens.append(SyntaxToken(text: String(source[start..<index]), kind: .plain))
            }
        }

        return coalesce(tokens)
    }

    private func coalesce(_ tokens: [SyntaxToken]) -> [SyntaxToken] {
        var result: [SyntaxToken] = []
        for token in tokens {
            if let last = result.last, last.kind == token.kind {
                result[result.count - 1] = SyntaxToken(text: last.text + token.text, kind: last.kind)
            } else {
                result.append(token)
            }
        }
        return result
    }
}

private enum SyntaxLanguage {
    case markdown
    case json
    case swift
    case javascript
    case python
    case rust
    case html
    case css
    case plain
}
