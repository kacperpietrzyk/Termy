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
}
