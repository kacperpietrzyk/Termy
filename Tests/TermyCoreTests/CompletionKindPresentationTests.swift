import XCTest
@testable import TermyCore

final class CompletionKindPresentationTests: XCTestCase {
    // Every kind must map to a non-empty SF Symbol name and a short type label —
    // the F-3/F-4 completion menu renders both. A missing mapping would render a
    // blank icon or label in the menu (silent visual bug).
    func test_everyKind_hasNonEmptySymbolAndLabel() {
        for kind in CompletionKind.allCases {
            let p = CompletionKindPresentation.for(kind)
            XCTAssertFalse(p.symbolName.isEmpty, "empty symbol for \(kind)")
            XCTAssertFalse(p.typeLabel.isEmpty, "empty label for \(kind)")
        }
    }

    // Type labels are compact tags shown right-aligned per row — keep them short
    // so they never crowd the candidate title.
    func test_typeLabels_areShort() {
        for kind in CompletionKind.allCases {
            let label = CompletionKindPresentation.for(kind).typeLabel
            XCTAssertLessThanOrEqual(label.count, 7, "label too long for \(kind): \(label)")
        }
    }

    // Directories vs files must read differently at a glance (Warp-parity): a
    // filled folder for directories, a plain doc for files.
    func test_directoryAndFile_distinctSymbols() {
        XCTAssertEqual(CompletionKindPresentation.for(.directory).symbolName, "folder.fill")
        XCTAssertEqual(CompletionKindPresentation.for(.file).symbolName, "doc")
        XCTAssertNotEqual(
            CompletionKindPresentation.for(.directory).symbolName,
            CompletionKindPresentation.for(.file).symbolName
        )
    }

    func test_spotCheck_representativeLabels() {
        XCTAssertEqual(CompletionKindPresentation.for(.directory).typeLabel, "dir")
        XCTAssertEqual(CompletionKindPresentation.for(.command).typeLabel, "cmd")
        XCTAssertEqual(CompletionKindPresentation.for(.gitBranch).typeLabel, "branch")
        XCTAssertEqual(CompletionKindPresentation.for(.sshHost).typeLabel, "host")
    }

    // The tint role drives the icon color in the view layer; it must be stable so
    // the same kind always reads the same color (folders blue, hosts cyan, etc.).
    func test_tintRole_isStablePerKind() {
        XCTAssertEqual(CompletionKindPresentation.for(.directory).tint, .accent)
        XCTAssertEqual(CompletionKindPresentation.for(.gitBranch).tint, .git)
        XCTAssertEqual(CompletionKindPresentation.for(.sshHost).tint, .host)
        XCTAssertEqual(CompletionKindPresentation.for(.file).tint, .neutral)
    }
}
