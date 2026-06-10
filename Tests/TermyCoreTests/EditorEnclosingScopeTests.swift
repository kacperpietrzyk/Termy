import XCTest
@testable import TermyCore

/// ED-4 — enclosing-scope context extractor.
///
/// Pure, offline, language-aware heuristic that reports the declaration
/// header(s) surrounding an editor selection so the local-AI prompt sees
/// structural context. (Honest heuristic — semantic tree-sitter symbols arrive
/// with the CESE engine in a later slice.)
final class EditorEnclosingScopeTests: XCTestCase {

    /// UTF-16 offset of the first occurrence of `needle` in `text`.
    private func offset(of needle: String, in text: String) -> Int {
        (text as NSString).range(of: needle).location
    }

    func testSwiftReportsEnclosingTypeAndFunction() {
        let src = """
        struct Foo {
            func bar() {
                let x = 1
                print(x)
            }
        }
        """
        let loc = offset(of: "print(x)", in: src)
        let headers = EditorEnclosingScope.headers(
            in: src,
            selection: EditorSelection(location: loc, length: 0),
            language: .swift
        )
        XCTAssertEqual(headers, ["struct Foo", "func bar()"])
    }

    func testInnermostScopeIsLastAndDepthBounded() {
        let src = """
        enum E {
            struct S {
                func f() {
                    if true {
                        target()
                    }
                }
            }
        }
        """
        let loc = offset(of: "target()", in: src)
        let headers = EditorEnclosingScope.headers(
            in: src,
            selection: EditorSelection(location: loc, length: 0),
            language: .swift,
            maxDepth: 2
        )
        // Bottom-up scan keeps the two INNERMOST openers, ordered outer→inner.
        XCTAssertEqual(headers, ["func f()", "if true"])
    }

    func testTopLevelSelectionHasNoEnclosingScope() {
        let src = """
        let a = 1
        let b = 2
        """
        let loc = offset(of: "let b", in: src)
        let headers = EditorEnclosingScope.headers(
            in: src,
            selection: EditorSelection(location: loc, length: 0),
            language: .swift
        )
        XCTAssertTrue(headers.isEmpty)
    }

    func testBraceInsideStringIsNotTreatedAsScope() {
        let src = """
        func f() {
            let s = "not a { brace"
            here()
        }
        """
        let loc = offset(of: "here()", in: src)
        let headers = EditorEnclosingScope.headers(
            in: src,
            selection: EditorSelection(location: loc, length: 0),
            language: .swift
        )
        XCTAssertEqual(headers, ["func f()"])
    }

    func testPythonReportsClassAndDef() {
        let src = """
        class Widget:
            def render(self):
                value = compute()
                return value
        """
        let loc = offset(of: "return value", in: src)
        let headers = EditorEnclosingScope.headers(
            in: src,
            selection: EditorSelection(location: loc, length: 0),
            language: .python
        )
        XCTAssertEqual(headers, ["class Widget:", "def render(self):"])
    }

    func testPlainTextNeverReportsScope() {
        let src = "{ this is { not } code }"
        let headers = EditorEnclosingScope.headers(
            in: src,
            selection: EditorSelection(location: 5, length: 0),
            language: .plain
        )
        // Brace heuristic still applies to plain (treated as brace-family), but a
        // single line with no enclosing opener above the selection yields nothing.
        XCTAssertTrue(headers.isEmpty)
    }

    func testPromptContextJoinsHeadersAndIsEmptyWhenNone() {
        let src = """
        struct Foo {
            func bar() {
                x()
            }
        }
        """
        let loc = offset(of: "x()", in: src)
        let ctx = EditorEnclosingScope.promptContext(
            in: src,
            selection: EditorSelection(location: loc, length: 0),
            language: .swift
        )
        XCTAssertEqual(ctx, "struct Foo\nfunc bar()")

        let empty = EditorEnclosingScope.promptContext(
            in: "let a = 1",
            selection: EditorSelection(location: 0, length: 0),
            language: .swift
        )
        XCTAssertEqual(empty, "")
    }

    func testEmptyTextIsSafe() {
        let headers = EditorEnclosingScope.headers(
            in: "",
            selection: EditorSelection(location: 0, length: 0),
            language: .swift
        )
        XCTAssertTrue(headers.isEmpty)
    }
}
