import Foundation

/// The source language of an editor buffer, derived from its file extension.
///
/// EDITOR-CESE Slice 2 (ED-2): a small repo-local, `Codable` value used by the
/// multi-file buffer model so a buffer's language can be persisted (for a later
/// iCloud-sync slice) and so the editing surface can pick a highlighter/grammar
/// without re-deriving it on every render. It is deliberately INDEPENDENT of the
/// editor engine: the CodeEditSourceEditor / CodeEditLanguages adoption (Slice 1)
/// is a separate, later slice, so this model must not reference any engine type.
/// The case set mirrors the extensions the in-repo `SyntaxHighlighter` already
/// recognises, plus the daily languages the target state scopes (yaml/toml/go/
/// shell), with `.plain` as the safe default for anything unknown or scratch.
public enum EditorLanguage: String, Codable, CaseIterable, Sendable {
    case plain
    case swift
    case javascript
    case typescript
    case python
    case rust
    case go
    case json
    case yaml
    case toml
    case markdown
    case html
    case css
    case shell

    /// Map a file path (or name) to a language via its extension. `nil` path
    /// (the unnamed scratch buffer) and unknown extensions resolve to `.plain`.
    public init(path: String?) {
        guard let ext = path?.split(separator: ".").last.map(String.init)?.lowercased(),
              !ext.isEmpty else {
            self = .plain
            return
        }
        switch ext {
        case "swift":
            self = .swift
        case "js", "jsx", "mjs", "cjs":
            self = .javascript
        case "ts", "tsx":
            self = .typescript
        case "py":
            self = .python
        case "rs":
            self = .rust
        case "go":
            self = .go
        case "json":
            self = .json
        case "yml", "yaml":
            self = .yaml
        case "toml":
            self = .toml
        case "md", "markdown":
            self = .markdown
        case "html", "htm":
            self = .html
        case "css":
            self = .css
        case "sh", "bash", "zsh":
            self = .shell
        default:
            self = .plain
        }
    }
}

/// A persisted text selection / cursor position inside an editor buffer, stored
/// as a UTF-16-offset range to match AppKit/`NSTextView` conventions.
///
/// ED-2 adds this as a `Codable` DATA field on `EditorBuffer` so cursor/selection
/// can ride a later sync slice. It is intentionally NOT wired into the live
/// editing surface here — re-pointing AI assist onto real cursor/selection is a
/// later slice (Editor Slice 4). A collapsed selection (`length == 0`) is a plain
/// caret at `location`.
public struct EditorSelection: Codable, Equatable, Sendable {
    /// UTF-16 offset of the selection's start (the caret, when collapsed).
    public var location: Int
    /// Number of UTF-16 units selected; `0` is a collapsed caret.
    public var length: Int

    public init(location: Int = 0, length: Int = 0) {
        self.location = max(0, location)
        self.length = max(0, length)
    }

    private enum CodingKeys: String, CodingKey {
        case location, length
    }

    // Route decoding through the validating initializer so a hand-crafted blob
    // can never yield a negative offset (keeps the clamp invariant honest).
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(location: try container.decode(Int.self, forKey: .location),
                  length: try container.decode(Int.self, forKey: .length))
    }
}
