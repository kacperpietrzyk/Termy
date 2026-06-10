import Foundation
import TermyCore

/// Pure formatting for the editor's read-only git-blame gutter column
/// (EDITOR-CESE Slice 5). Kept free of AppKit so the label logic is unit-testable
/// without a live `NSRulerView`. The blame DATA itself comes FROM the Git module
/// (`GitRepository.blame`) — this only shapes it for display.
enum EditorBlameGutter {
    /// The short label shown for one source line: abbreviated author + short SHA,
    /// e.g. "Ada · aabbccdd". An uncommitted (all-zero SHA) line shows a calm
    /// "uncommitted" marker instead of a meaningless author/sha. `nil` when there
    /// is no blame for that line (out of range / not yet loaded), so the gutter
    /// renders blank for it.
    static func label(for line: Int, in blame: GitBlame?) -> String? {
        guard let entry = blame?.line(line) else { return nil }
        if entry.isUncommitted {
            return "uncommitted"
        }
        let author = abbreviatedAuthor(entry.author)
        return "\(author) · \(entry.shortSHA)"
    }

    /// First name (or first token) of the author, so the gutter stays narrow.
    /// Empty author degrades to "—".
    static func abbreviatedAuthor(_ author: String) -> String {
        let trimmed = author.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.split(separator: " ").first else { return "—" }
        return String(first)
    }
}
