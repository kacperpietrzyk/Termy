import XCTest
import SwiftUI
import AppKit
import TermyCore
@testable import Termy

/// Static visual + behavioral gate for the Editor in-place syntax highlighting
/// slice (D-DEBT-ORDER #5). Drives the REAL HighlightedCodeEditor.Coordinator
/// highlight path against an NSTextView, asserts keywords/strings actually get
/// colored in the editing surface (not just a separate preview), and rasterizes
/// the result to /tmp for inspection.
@MainActor
final class HighlightedCodeEditorGateTests: XCTestCase {
    private func highlight(_ source: String, fileName: String) -> NSTextView {
        let editor = HighlightedCodeEditor(text: .constant(source), fileName: fileName)
        let coordinator = editor.makeCoordinator()
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 540, height: 340))
        textView.backgroundColor = NSColor(Color(DesignTokens.bg1))
        textView.string = source
        coordinator.applyHighlight(to: textView)
        return textView
    }

    private func snapshot(_ textView: NSTextView, name: String) {
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        guard let rep = textView.bitmapImageRepForCachingDisplay(in: textView.bounds) else { return }
        textView.cacheDisplay(in: textView.bounds, to: rep)
        if let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: "/tmp/gate-editor-\(name).png"))
        }
    }

    /// The color attribute at a given substring's first occurrence.
    private func color(in textView: NSTextView, ofFirst substring: String) -> NSColor? {
        let ns = textView.string as NSString
        let range = ns.range(of: substring)
        guard range.location != NSNotFound, let storage = textView.textStorage else { return nil }
        return storage.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? NSColor
    }

    func test_swift_keywordsAndStringsAreColoredInEditingSurface() throws {
        let source = """
        import Foundation

        // a greeting
        func greet(name: String) -> String {
            let message = "Hello, world"
            return message
        }
        """
        let textView = highlight(source, fileName: "App.swift")
        snapshot(textView, name: "01-swift")

        let plain = NSColor(SyntaxTokenColor.color(for: .plain))
        let keyword = try XCTUnwrap(color(in: textView, ofFirst: "func"))
        let string = try XCTUnwrap(color(in: textView, ofFirst: "\"Hello, world\""))
        let comment = try XCTUnwrap(color(in: textView, ofFirst: "// a greeting"))

        // The editing surface itself must carry distinct colors — the whole point
        // of the slice (no longer "plain box + separate preview").
        XCTAssertNotEqual(keyword, plain, "keyword not colored in the editor")
        XCTAssertNotEqual(string, plain, "string literal not colored")
        XCTAssertNotEqual(comment, plain, "comment not colored")
        XCTAssertNotEqual(keyword, string, "keyword and string should differ")
    }

    func test_json_keysAndValuesColored() throws {
        let source = """
        {
          "name": "termy",
          "version": 3,
          "private": true
        }
        """
        let textView = highlight(source, fileName: "package.json")
        snapshot(textView, name: "02-json")
        let plain = NSColor(SyntaxTokenColor.color(for: .plain))
        XCTAssertNotEqual(try XCTUnwrap(color(in: textView, ofFirst: "\"name\"")), plain)
        XCTAssertNotEqual(try XCTUnwrap(color(in: textView, ofFirst: "3")), plain)
    }

    func test_unknownExtension_rendersPlain_noCrash() throws {
        let source = "just some text\nwith no language\n"
        let textView = highlight(source, fileName: "notes.xyz")
        snapshot(textView, name: "03-plain")
        // Plain language → everything is the plain color, and it must not crash.
        let plain = NSColor(SyntaxTokenColor.color(for: .plain))
        XCTAssertEqual(color(in: textView, ofFirst: "some"), plain)
    }
}
