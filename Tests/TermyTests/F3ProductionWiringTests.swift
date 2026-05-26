import XCTest
import TermyCore
@testable import Termy

@MainActor
final class F3ProductionWiringTests: XCTestCase {
    /// Pins two things at once:
    ///
    ///   1. **Compile-time witness:** the file references `TerminalStageView`,
    ///      so a refactor that removes the view (or moves the F-3 overlay
    ///      out of this module) breaks the test at compile time.
    ///   2. **Runtime contract:** `TermyStore.MenuSnapshot` produced by
    ///      `completionSuggestionsForMenu(text:sessionID:)` for a real-world
    ///      buffer must be non-nil, non-empty, with a valid selection and a
    ///      kind set drawn from `{command, flag, file, gitBranch, sshHost}`.
    ///      `.history` is excluded by construction (the menu engine call
    ///      passes `history: []`).
    ///
    /// Together these defend against a regression that either strands the
    /// view layer or silently broadens the engine output for the menu path.
    func test_menuSnapshotShapeUnchanged() {
        // Compile-time witness — fails to compile if TerminalStageView is
        // removed from the module.
        _ = TerminalStageView.self

        let store = TermyStore(startInitialPTY: false)
        let session = TermySession(
            title: "Test",
            profile: ConnectionProfile.local(),
            interactionMode: .rawPTY
        )
        store.sessions = [session]
        store.selectedSessionID = session.id
        let id = session.id
        // "gi" hits command-name branch (avoid the "ls" expectsPath trap).
        store.ingestShellIntegrationEvents(
            [.inputBufferChanged(text: "gi", cursor: 2, length: 2)],
            for: id
        )
        _ = store.terminalMenuOpen(for: id)
        let snap = store.terminalMenuSnapshot(for: id)
        XCTAssertNotNil(snap)
        XCTAssertGreaterThanOrEqual(snap?.items.count ?? 0, 1)
        XCTAssertGreaterThanOrEqual(snap?.selection ?? -1, 0)
        // Closed-world kind set — forces a conscious update when F-4 adds new
        // kinds. `.history` excluded because the menu engine call uses `history: []`.
        let kinds: Set<CompletionKind> = Set(snap?.items.map(\.kind) ?? [])
        XCTAssertTrue(kinds.isSubset(of: [.command, .flag, .file, .gitBranch, .sshHost]))
    }
}
