import XCTest
import TermyCore
@testable import Termy

/// #4: ghost-text accept does an instant client-side insert and suppresses the
/// shell's char-by-char prefix echoes (so the line doesn't visibly type itself
/// in). These cover the pure suppression state machine; the echo *shape* against
/// a real PTY is the owner's live gate.
@MainActor
final class InlineAcceptOptimisticInsertTests: XCTestCase {
    private func bufferEvent(_ text: String) -> ShellIntegrationEvent {
        .inputBufferChanged(text: text, cursor: text.count, length: text.count)
    }

    func test_accept_setsBufferToFinalValueImmediately_andArmsPending() {
        let store = TermyStore(startInitialPTY: false)
        let sid = store.testAddRawPtySession()
        store.testSetInputBuffer(sid, text: "git st", cursor: 6)

        store.acceptInlineSuffix("atus", for: sid)

        XCTAssertEqual(store.testInputBufferText(sid), "git status", "accept must insert the whole suffix at once")
        XCTAssertTrue(store.testHasPendingInlineOptimistic(sid))
    }

    func test_prefixEchoes_areSuppressed_untilEchoCatchesUp() {
        let store = TermyStore(startInitialPTY: false)
        let sid = store.testAddRawPtySession()
        store.testSetInputBuffer(sid, text: "git st", cursor: 6)
        store.acceptInlineSuffix("atus", for: sid)

        // The shell re-echoes the accepted text one char at a time. Each
        // intermediate prefix must be DROPPED — the buffer stays at the final value.
        for prefix in ["git s", "git sta", "git stat", "git statu"] {
            store.ingestShellIntegrationEvents([bufferEvent(prefix)], for: sid)
            XCTAssertEqual(store.testInputBufferText(sid), "git status",
                           "prefix echo \"\(prefix)\" must not regress the optimistic buffer")
            XCTAssertTrue(store.testHasPendingInlineOptimistic(sid))
        }

        // When the echo finally reports the full text, pending clears.
        store.ingestShellIntegrationEvents([bufferEvent("git status")], for: sid)
        XCTAssertEqual(store.testInputBufferText(sid), "git status")
        XCTAssertFalse(store.testHasPendingInlineOptimistic(sid))
    }

    func test_afterEchoCatchesUp_furtherTypingAppliesNormally() {
        let store = TermyStore(startInitialPTY: false)
        let sid = store.testAddRawPtySession()
        store.testSetInputBuffer(sid, text: "git st", cursor: 6)
        store.acceptInlineSuffix("atus", for: sid)
        store.ingestShellIntegrationEvents([bufferEvent("git status")], for: sid)   // caught up

        store.ingestShellIntegrationEvents([bufferEvent("git status -v")], for: sid)
        XCTAssertEqual(store.testInputBufferText(sid), "git status -v")
        XCTAssertFalse(store.testHasPendingInlineOptimistic(sid))
    }

    func test_divergentEcho_clearsPending_andTrustsShell() {
        let store = TermyStore(startInitialPTY: false)
        let sid = store.testAddRawPtySession()
        store.testSetInputBuffer(sid, text: "git st", cursor: 6)
        store.acceptInlineSuffix("atus", for: sid)

        // A non-prefix report (user edited, or the shell reshaped the echo) must
        // clear the pending state and apply the shell's value — never stuck.
        store.ingestShellIntegrationEvents([bufferEvent("totally different")], for: sid)
        XCTAssertEqual(store.testInputBufferText(sid), "totally different")
        XCTAssertFalse(store.testHasPendingInlineOptimistic(sid))
    }

    func test_emptySuffix_isNoOp() {
        let store = TermyStore(startInitialPTY: false)
        let sid = store.testAddRawPtySession()
        store.testSetInputBuffer(sid, text: "ls", cursor: 2)
        store.acceptInlineSuffix("", for: sid)
        XCTAssertEqual(store.testInputBufferText(sid), "ls")
        XCTAssertFalse(store.testHasPendingInlineOptimistic(sid))
    }
}
