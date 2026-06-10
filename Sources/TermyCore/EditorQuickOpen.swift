import Foundation

/// One ranked result of the editor's ⌘P quick-open switcher — either an already
/// open buffer or a project file on disk. Pure value type so the ranking is
/// trivially testable without AppKit/SwiftUI or touching the filesystem.
///
/// `titleRanges` are `Character`-offset ranges into `title` (the basename), so a
/// view can highlight matched glyphs with the exact same char-offset run pattern
/// ⌘K uses (`CommandCenterItemRow.highlightedTitle`).
public struct EditorQuickOpenItem: Equatable, Identifiable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// An open editor buffer. `bufferID` selects it; `path` is its file path
        /// (nil for an unsaved scratch buffer).
        case buffer(bufferID: UUID)
        /// A project file on disk, identified by its root-relative path.
        case file
    }

    public let kind: Kind
    /// Displayed primary label — the basename (e.g. `EditorModel.swift`).
    public let title: String
    /// Displayed secondary label — the root-relative directory (e.g. `Sources/Termy/Models`),
    /// or a marker like `Unsaved` for a scratch buffer.
    public let subtitle: String
    /// Root-relative file path, or `nil` for an unsaved scratch buffer.
    public let path: String?
    /// Matched `Character` offsets into `title`, merged & sorted (for highlight).
    public let titleRanges: [Range<Int>]

    public var id: String {
        switch kind {
        case .buffer(let bufferID): return "buffer-\(bufferID.uuidString)"
        case .file: return "file-\(path ?? title)"
        }
    }

    public init(kind: Kind, title: String, subtitle: String, path: String?, titleRanges: [Range<Int>]) {
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.path = path
        self.titleRanges = titleRanges
    }
}

/// An open editor buffer as the ranker sees it — adapter input so the ranker
/// never depends on app types (mirrors how ⌘K adapts its own item kinds).
public struct EditorQuickOpenBuffer: Equatable, Sendable {
    public let id: UUID
    /// File path (root-relative or absolute as the caller stores it), or `nil`
    /// for an unsaved scratch buffer.
    public let path: String?

    public init(id: UUID, path: String?) {
        self.id = id
        self.path = path
    }
}

/// Pure ranker for the editor ⌘P quick-open. Reuses the SHARED
/// `FuzzyMatcher` (do not author a second matcher) so ⌘P stays consistent with
/// ⌘K, and enforces the slice's ordering contract:
///
/// 1. **Buffers first, as a TIER** — every matching open buffer precedes every
///    matching project file, regardless of raw fuzzy score (a tier, not a blend).
/// 2. **Dedup** — a project file whose path equals an open buffer's path is
///    already represented by the buffer and is dropped from the file tier.
/// 3. Within each tier, higher fuzzy score wins; ties break by case-insensitive
///    title then path for stable ordering.
///
/// An empty query lists open buffers only (no file flood), in their given order.
public enum EditorQuickOpen {
    /// Rank `buffers` (already open) and `files` (project-relative paths) against
    /// `query`. `files` are matched on their basename; the directory becomes the
    /// subtitle. Scratch buffers (nil path) match on a stable "Scratch" title.
    public static func rank(
        query: String,
        buffers: [EditorQuickOpenBuffer],
        files: [String]
    ) -> [EditorQuickOpenItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let openPaths = Set(buffers.compactMap { $0.path })

        // --- Buffer tier ---
        let bufferItems: [(item: EditorQuickOpenItem, score: Double)] = buffers.compactMap { buffer in
            let title = buffer.path.map(Self.basename) ?? "Scratch"
            let subtitle = buffer.path.map { dir -> String in
                let d = Self.directory(of: dir)
                return d.isEmpty ? "Open buffer" : d
            } ?? "Unsaved"

            if trimmed.isEmpty {
                return (EditorQuickOpenItem(kind: .buffer(bufferID: buffer.id),
                                            title: title, subtitle: subtitle,
                                            path: buffer.path, titleRanges: []), 0)
            }
            guard let match = FuzzyMatcher.match(trimmed, in: title) else { return nil }
            return (EditorQuickOpenItem(kind: .buffer(bufferID: buffer.id),
                                        title: title, subtitle: subtitle,
                                        path: buffer.path, titleRanges: match.ranges), match.score)
        }

        // --- File tier (deduped against open buffers) ---
        let fileItems: [(item: EditorQuickOpenItem, score: Double)]
        if trimmed.isEmpty {
            // Empty query → buffers only; do not flood with the whole tree.
            fileItems = []
        } else {
            fileItems = files.compactMap { path in
                guard !openPaths.contains(path) else { return nil }
                let title = Self.basename(path)
                guard let match = FuzzyMatcher.match(trimmed, in: title) else { return nil }
                let dir = Self.directory(of: path)
                return (EditorQuickOpenItem(kind: .file,
                                            title: title,
                                            subtitle: dir.isEmpty ? path : dir,
                                            path: path,
                                            titleRanges: match.ranges), match.score)
            }
        }

        // Empty query preserves the buffers' given order (most-recent tab order);
        // a real query ranks each tier by fuzzy score.
        let orderedBuffers = trimmed.isEmpty
            ? bufferItems.map(\.item)
            : bufferItems.sorted(by: Self.order).map(\.item)
        let sortedFiles = fileItems.sorted(by: Self.order).map(\.item)
        return orderedBuffers + sortedFiles
    }

    /// Higher score first; stable tie-break on title then path (case-insensitive).
    private static func order(_ lhs: (item: EditorQuickOpenItem, score: Double),
                              _ rhs: (item: EditorQuickOpenItem, score: Double)) -> Bool {
        if lhs.score != rhs.score { return lhs.score > rhs.score }
        let titleCompare = lhs.item.title.localizedCaseInsensitiveCompare(rhs.item.title)
        if titleCompare != .orderedSame { return titleCompare == .orderedAscending }
        return (lhs.item.path ?? "") < (rhs.item.path ?? "")
    }

    /// Last path component (basename) of a `/`-separated relative or absolute path.
    static func basename(_ path: String) -> String {
        path.split(separator: "/", omittingEmptySubsequences: true).last.map(String.init) ?? path
    }

    /// Directory portion (everything before the last `/`-component); empty when
    /// the path has no directory.
    static func directory(of path: String) -> String {
        let parts = path.split(separator: "/", omittingEmptySubsequences: true)
        guard parts.count > 1 else { return "" }
        return parts.dropLast().joined(separator: "/")
    }
}
