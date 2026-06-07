import XCTest
@testable import TermyCore

final class ANSITextParserTests: XCTestCase {
    private let parser = ANSITextParser()

    func testPlainTextIsOneSpanWithDefaultAttributes() {
        XCTAssertEqual(parser.parse("hello"), [ANSISpan(text: "hello")])
    }

    func testStandardForegroundColor() {
        // ESC[31m red ESC[0m
        let spans = parser.parse("\u{1b}[31mred\u{1b}[0m")
        XCTAssertEqual(spans, [ANSISpan(text: "red",
            attributes: ANSIAttributes(foreground: .indexed(1)))])
    }

    func testResetClearsAttributesForFollowingText() {
        let spans = parser.parse("\u{1b}[31mred\u{1b}[0mplain")
        XCTAssertEqual(spans, [
            ANSISpan(text: "red", attributes: ANSIAttributes(foreground: .indexed(1))),
            ANSISpan(text: "plain"),
        ])
    }

    func testBoldAndForegroundCombineInOneCSI() {
        // ESC[1;32m
        let spans = parser.parse("\u{1b}[1;32mok\u{1b}[0m")
        XCTAssertEqual(spans, [ANSISpan(text: "ok",
            attributes: ANSIAttributes(foreground: .indexed(2), bold: true))])
    }

    func testBrightForegroundMapsToIndexed8Through15() {
        // ESC[91m -> bright red -> indexed(9)
        let spans = parser.parse("\u{1b}[91mx\u{1b}[0m")
        XCTAssertEqual(spans.first?.attributes.foreground, .indexed(9))
    }

    func testBackgroundColor() {
        // ESC[42m -> bg green -> indexed(2)
        let spans = parser.parse("\u{1b}[42mx\u{1b}[0m")
        XCTAssertEqual(spans.first?.attributes.background, .indexed(2))
    }

    func test256IndexedColor() {
        // ESC[38;5;208m
        let spans = parser.parse("\u{1b}[38;5;208mx\u{1b}[0m")
        XCTAssertEqual(spans.first?.attributes.foreground, .indexed(208))
    }

    func testTruecolorRGB() {
        // ESC[38;2;10;20;30m
        let spans = parser.parse("\u{1b}[38;2;10;20;30mx\u{1b}[0m")
        XCTAssertEqual(spans.first?.attributes.foreground, .rgb(10, 20, 30))
    }

    func testDefaultForegroundCodeClearsColorOnly() {
        // ESC[31m ... ESC[39m (default fg) keeps bold if set
        let spans = parser.parse("\u{1b}[1;31ma\u{1b}[39mb\u{1b}[0m")
        XCTAssertEqual(spans, [
            ANSISpan(text: "a", attributes: ANSIAttributes(foreground: .indexed(1), bold: true)),
            ANSISpan(text: "b", attributes: ANSIAttributes(bold: true)),
        ])
    }

    func testUnknownSGRCodeIsIgnored() {
        // ESC[99m is not a defined SGR -> ignored, text plain
        XCTAssertEqual(parser.parse("\u{1b}[99mx"), [ANSISpan(text: "x")])
    }

    func testNonSGREscapeIsDroppedFromVisibleText() {
        // ESC[2J (clear screen, ends in 'J' not 'm') -> dropped, not rendered
        XCTAssertEqual(parser.parse("a\u{1b}[2Jb"), [ANSISpan(text: "ab")])
    }

    func testIncompleteTrailingEscapeIsDropped() {
        XCTAssertEqual(parser.parse("ok\u{1b}["), [ANSISpan(text: "ok")])
    }

    func testEmptyStringIsNoSpans() {
        XCTAssertEqual(parser.parse(""), [])
    }

    func testOSCWithBELIsDropped() {
        XCTAssertEqual(parser.parse("a\u{1b}]0;my title\u{07}b"), [ANSISpan(text: "ab")])
    }

    func testOSCWithSTIsDropped() {
        // OSC-8 hyperlink terminated by ST (ESC \)
        XCTAssertEqual(parser.parse("a\u{1b}]8;;http://x\u{1b}\\b"), [ANSISpan(text: "ab")])
    }

    func testIncompleteOSCIsDropped() {
        XCTAssertEqual(parser.parse("ok\u{1b}]0;unterminated"), [ANSISpan(text: "ok")])
    }

    func testConsecutiveEscapesWithNoTextBetween() {
        // ESC[31m ESC[1m x ESC[0m  → bold red "x", no empty span emitted
        let spans = parser.parse("\u{1b}[31m\u{1b}[1mx\u{1b}[0m")
        XCTAssertEqual(spans, [ANSISpan(text: "x",
            attributes: ANSIAttributes(foreground: .indexed(1), bold: true))])
    }

    func testResetAndSetInOneCSI() {
        // ESC[0;31m  → reset then red
        let spans = parser.parse("\u{1b}[0;31mx\u{1b}[0m")
        XCTAssertEqual(spans, [ANSISpan(text: "x",
            attributes: ANSIAttributes(foreground: .indexed(1)))])
    }

    // Poziom-2a: charset designation (ESC ( B etc.) must be dropped, not leaked as
    // literal text — this is the `(B` half of the reported `78(B78%` TUI residue.
    func testCharsetDesignationG0IsDropped() {
        XCTAssertEqual(parser.parse("x\u{1b}(By"), [ANSISpan(text: "xy")])
    }

    func testCharsetDesignationG1IsDropped() {
        XCTAssertEqual(parser.parse("a\u{1b})0b"), [ANSISpan(text: "ab")])
    }

    func testIncompleteCharsetDesignationIsDropped() {
        XCTAssertEqual(parser.parse("ok\u{1b}("), [ANSISpan(text: "ok")])
    }

    // Poziom-2a#2: inline-TUI repaints (cursor moves back, rewrites) must collapse to
    // the FINAL state, not concatenate — the `787878%` residue half.

    func testCursorHorizontalAbsoluteRepaintCollapses() {
        // write "78", return to col 1 (CHA), rewrite, again, then "78%" → final "78%".
        XCTAssertEqual(parser.parse("78\u{1b}[G78\u{1b}[G78%"), [ANSISpan(text: "78%")])
    }

    func testCursorBackOverwrites() {
        // "abc", cursor back 3, write "X" → overwrites 'a' → "Xbc".
        XCTAssertEqual(parser.parse("abc\u{1b}[3DX"), [ANSISpan(text: "Xbc")])
    }

    func testEraseLineThenRewriteFromColumnZero() {
        // "junk", clear whole line (2K), CHA col 1, write "kept" → "kept".
        XCTAssertEqual(parser.parse("junk\u{1b}[2K\u{1b}[Gkept"), [ANSISpan(text: "kept")])
    }

    func testForwardOnlyMultilineIsUnchanged() {
        // No backward motion → byte-identical single span across newlines (regression).
        XCTAssertEqual(parser.parse("a\nb\nc"), [ANSISpan(text: "a\nb\nc")])
    }

    func testCursorUpThenRewriteOverwritesEarlierLine() {
        // "old\nx", up one row, CHA col 1, clear line, "new" → row0 "new", row1 "x".
        XCTAssertEqual(parser.parse("old\nx\u{1b}[A\u{1b}[G\u{1b}[2Knew"),
                       [ANSISpan(text: "new\nx")])
    }
}
