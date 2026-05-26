import XCTest
@testable import TermyCore

final class WorkspacePaneLayoutFocusTests: XCTestCase {
    func testFocusSetsFocusedWhenVisible() {
        var layout = WorkspacePaneLayout(trailingPane: .git)   // tree: terminal + git
        layout.focus(.git)
        XCTAssertEqual(layout.focusedPane, .git)
    }

    func testFocusIgnoresAbsentPane() {
        var layout = WorkspacePaneLayout()                     // tree: terminal only
        layout.focus(.git)
        XCTAssertEqual(layout.focusedPane, .terminal)
    }

    func testCloseRemovesPane() {
        var layout = WorkspacePaneLayout(trailingPane: .git)
        layout.close(.git)
        XCTAssertFalse(layout.visiblePanes.contains(.git))
        XCTAssertTrue(layout.visiblePanes.contains(.terminal))
    }

    func testCloseTerminalIsNoOp() {
        var layout = WorkspacePaneLayout(trailingPane: .git)
        layout.close(.terminal)                                // terminal is the base pane
        XCTAssertTrue(layout.visiblePanes.contains(.terminal))
        XCTAssertTrue(layout.visiblePanes.contains(.git))
    }

    func testCloseAbsentPaneIsNoOp() {
        var layout = WorkspacePaneLayout(trailingPane: .git)   // terminal + git
        layout.focus(.git)
        layout.close(.editor)                                  // .editor absent — must not close focused .git
        XCTAssertTrue(layout.visiblePanes.contains(.git))
        XCTAssertTrue(layout.visiblePanes.contains(.terminal))
    }
}
