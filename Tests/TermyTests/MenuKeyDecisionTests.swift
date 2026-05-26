#if canImport(AppKit)
import XCTest
import AppKit
@testable import Termy

final class MenuKeyDecisionTests: XCTestCase {
    // Key codes (US ANSI virtual keycodes — F-1 precedent, layout-independent)
    private let kTab: UInt16 = 48
    private let kRight: UInt16 = 124
    private let kUp: UInt16 = 126
    private let kDown: UInt16 = 125
    private let kReturn: UInt16 = 36
    private let kEsc: UInt16 = 53
    private let kA: UInt16 = 0  // any printable

    private func decide(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags = [],
        menuOpen: Bool = false,
        isAltScreen: Bool = false
    ) -> MenuKeyDecision {
        MenuKeyDecision.decide(
            keyCode: keyCode,
            modifiers: modifiers,
            menuOpen: menuOpen,
            isAltScreen: isAltScreen
        )
    }

    // ----- alt-screen short-circuit (TUI apps cannot host the menu) -----

    func test_anyKey_inAltScreen_passthrough() {
        XCTAssertEqual(decide(keyCode: kTab, isAltScreen: true), .passthrough)
        XCTAssertEqual(decide(keyCode: kUp, menuOpen: true, isAltScreen: true), .passthrough)
        XCTAssertEqual(decide(keyCode: kReturn, menuOpen: true, isAltScreen: true), .passthrough)
    }

    // ----- closed: only bare Tab can request `.open` -----

    func test_bareTab_closed_open() {
        XCTAssertEqual(decide(keyCode: kTab), .open)
    }

    func test_modifierTab_closed_passthrough() {
        // Cmd-Tab / Ctrl-Tab / Opt-Tab / Shift-Tab all pass through when menu closed.
        XCTAssertEqual(decide(keyCode: kTab, modifiers: .command), .passthrough)
        XCTAssertEqual(decide(keyCode: kTab, modifiers: .control), .passthrough)
        XCTAssertEqual(decide(keyCode: kTab, modifiers: .option), .passthrough)
        XCTAssertEqual(decide(keyCode: kTab, modifiers: .shift), .passthrough)
    }

    func test_otherKeys_closed_passthrough() {
        // Closed menu = everything except bare Tab is irrelevant to F-3.
        XCTAssertEqual(decide(keyCode: kRight), .passthrough)  // F-1 ghost handles it
        XCTAssertEqual(decide(keyCode: kUp), .passthrough)
        XCTAssertEqual(decide(keyCode: kReturn), .passthrough)
        XCTAssertEqual(decide(keyCode: kEsc), .passthrough)
        XCTAssertEqual(decide(keyCode: kA), .passthrough)
    }

    // ----- open: navigation / accept / cancel intercept -----

    func test_open_upArrow_moveUp() {
        XCTAssertEqual(decide(keyCode: kUp, menuOpen: true), .move(by: -1))
    }

    func test_open_downArrow_moveDown() {
        XCTAssertEqual(decide(keyCode: kDown, menuOpen: true), .move(by: 1))
    }

    func test_open_shiftTab_moveUp() {
        XCTAssertEqual(
            decide(keyCode: kTab, modifiers: .shift, menuOpen: true),
            .move(by: -1)
        )
    }

    func test_open_bareTab_accept() {
        XCTAssertEqual(decide(keyCode: kTab, menuOpen: true), .accept)
    }

    func test_open_return_accept() {
        XCTAssertEqual(decide(keyCode: kReturn, menuOpen: true), .accept)
    }

    func test_open_rightArrow_accept() {
        XCTAssertEqual(decide(keyCode: kRight, menuOpen: true), .accept)
    }

    func test_open_esc_cancel() {
        XCTAssertEqual(decide(keyCode: kEsc, menuOpen: true), .cancel)
    }

    func test_open_printable_passthrough() {
        // Any other key: live-narrow path — let zsh handle it, T event refreshes.
        XCTAssertEqual(decide(keyCode: kA, menuOpen: true), .passthrough)
    }

    func test_open_modifiedAccept_passthrough() {
        // Cmd-Return / Ctrl-Return etc. — out of the menu's modal set.
        XCTAssertEqual(decide(keyCode: kReturn, modifiers: .command, menuOpen: true), .passthrough)
        XCTAssertEqual(decide(keyCode: kRight, modifiers: .control, menuOpen: true), .passthrough)
    }
}
#endif
