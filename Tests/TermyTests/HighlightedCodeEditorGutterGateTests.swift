import XCTest
import SwiftUI
import AppKit
import TermyCore
@testable import Termy

/// Static visual + behavioral gate for the M3 line-number gutter. Drives the
/// real scroll-view-with-gutter builder used by `makeNSView`, asserts the scroll
/// view exposes a visible `LineNumberRulerView`, that the ruler reports line
/// labels for a multi-line buffer, and rasterizes gutter+text to /tmp for the
/// owner visual gate.
@MainActor
final class HighlightedCodeEditorGutterGateTests: XCTestCase {

    func test_scrollView_attachesVisibleLineNumberRuler() {
        let scroll = HighlightedCodeEditor.makeScrollViewWithGutter(text: "line one\nline two\nline three\n")
        XCTAssertTrue(scroll.rulersVisible, "rulers must be visible")
        XCTAssertTrue(scroll.hasVerticalRuler, "scroll view must have a vertical ruler")
        XCTAssertTrue(scroll.verticalRulerView is LineNumberRulerView,
                      "vertical ruler must be the LineNumberRulerView gutter")
    }

    func test_ruler_reportsLineLabelsForMultiLineBuffer() throws {
        let scroll = HighlightedCodeEditor.makeScrollViewWithGutter(text: "alpha\nbeta\ngamma\n")
        let textView = try XCTUnwrap(scroll.documentView as? NSTextView)
        let ruler = try XCTUnwrap(scroll.verticalRulerView as? LineNumberRulerView)
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)

        let labels = ruler.visibleLineLabels()
        XCTAssertGreaterThanOrEqual(labels.count, 1, "ruler must report at least one line label")
        // 3 content lines + 1 trailing empty line (source ends in \n).
        XCTAssertEqual(labels.map(\.number).max(), 4)
    }

    func test_singleLine_reportsOneLabel() throws {
        let scroll = HighlightedCodeEditor.makeScrollViewWithGutter(text: "only one line")
        let textView = try XCTUnwrap(scroll.documentView as? NSTextView)
        let ruler = try XCTUnwrap(scroll.verticalRulerView as? LineNumberRulerView)
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        XCTAssertEqual(ruler.visibleLineLabels().map(\.number), [1])
    }

    func test_gutterRendersToPNG_forOwnerGate() throws {
        let source = """
        import Foundation

        func greet(name: String) -> String {
            return "Hello, \\(name)"
        }
        """
        let scroll = HighlightedCodeEditor.makeScrollViewWithGutter(text: source)
        scroll.frame = NSRect(x: 0, y: 0, width: 520, height: 320)
        let textView = try XCTUnwrap(scroll.documentView as? NSTextView)
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        scroll.tile()
        scroll.layoutSubtreeIfNeeded()

        guard let rep = scroll.bitmapImageRepForCachingDisplay(in: scroll.bounds) else { return }
        scroll.cacheDisplay(in: scroll.bounds, to: rep)
        if let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: "/tmp/gate-editor-gutter-01.png"))
        }
    }

    // MARK: - ED-5 git blame gutter

    private func sampleBlame(lineCount: Int) -> GitBlame {
        let authors = ["Ada Lovelace", "Grace Hopper", "Carol Shaw"]
        let lines = (1...lineCount).map { n in
            GitBlameLine(lineNumber: n,
                         sha: String(format: "%040x", n * 0x1111),
                         author: authors[(n - 1) % authors.count],
                         date: Date(timeIntervalSince1970: 1_700_000_000 + Double(n) * 86_400))
        }
        return GitBlame(lines: lines)
    }

    func test_blameLabel_showsAuthorAndShortSHA() {
        let blame = sampleBlame(lineCount: 1)
        let label = try? XCTUnwrap(EditorBlameGutter.label(for: 1, in: blame))
        XCTAssertEqual(label, "Ada · \(blame.line(1)!.shortSHA)")
    }

    func test_blameLabel_uncommittedLineShowsMarker() {
        let blame = GitBlame(lines: [
            GitBlameLine(lineNumber: 1, sha: String(repeating: "0", count: 40),
                         author: "Not Committed Yet", date: nil)
        ])
        XCTAssertEqual(EditorBlameGutter.label(for: 1, in: blame), "uncommitted")
    }

    func test_blameLabel_nilWhenLineHasNoBlame() {
        XCTAssertNil(EditorBlameGutter.label(for: 99, in: sampleBlame(lineCount: 3)))
        XCTAssertNil(EditorBlameGutter.label(for: 1, in: nil))
    }

    func test_ruler_widensWhenBlamePresentAndNarrowsWhenCleared() {
        let scroll = HighlightedCodeEditor.makeScrollViewWithGutter(text: "a\nb\nc\n")
        guard let ruler = scroll.verticalRulerView as? LineNumberRulerView else {
            return XCTFail("expected LineNumberRulerView")
        }
        let bareThickness = ruler.ruleThickness
        ruler.blame = sampleBlame(lineCount: 3)
        XCTAssertGreaterThan(ruler.ruleThickness, bareThickness,
                             "ruler must reserve extra width for the blame column")
        ruler.blame = nil
        XCTAssertEqual(ruler.ruleThickness, bareThickness,
                       "ruler must narrow back when blame is cleared")
    }

    func test_blameGutterRendersToPNG_forOwnerGate() throws {
        let source = """
        import Foundation

        func greet(name: String) -> String {
            return "Hello, \\(name)"
        }
        """
        let scroll = HighlightedCodeEditor.makeScrollViewWithGutter(text: source)
        let ruler = try XCTUnwrap(scroll.verticalRulerView as? LineNumberRulerView)
        ruler.blame = sampleBlame(lineCount: 5)
        scroll.frame = NSRect(x: 0, y: 0, width: 680, height: 320)
        let textView = try XCTUnwrap(scroll.documentView as? NSTextView)
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        scroll.tile()
        scroll.layoutSubtreeIfNeeded()

        guard let rep = scroll.bitmapImageRepForCachingDisplay(in: scroll.bounds) else { return }
        scroll.cacheDisplay(in: scroll.bounds, to: rep)
        if let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: "/tmp/gate-editor-blame-gutter-01.png"))
        }
    }
}
