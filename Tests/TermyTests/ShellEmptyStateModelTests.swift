import XCTest
@testable import Termy
import TermyCore

/// T7: fresh-session empty-state panel. The pure model `ShellEmptyStateModel`
/// builds the context PILLS (byte-identical to the live pinned-input header via
/// `blockContextPills`) plus a deduped/capped recents list — never fabricating a
/// git field or a history entry (P1).
final class ShellEmptyStateModelTests: XCTestCase {

    // Pills mirror the live header exactly (cwd + branch + dirty + node, no duration).
    func testPillsMatchBlockContextPillsWithCwdBranchAndDirtyStatus() {
        let state = ShellEmptyStateModel.make(
            cwd: "~/dev/termy", node: nil, branch: "main", gitStatus: "3",
            recentCommands: ["git status"])
        XCTAssertEqual(state.pills, ShellModuleModel.blockContextPills(
            node: nil, cwd: "~/dev/termy", branch: "main", gitStatus: "3", duration: nil))
    }

    // Non-repo (nil branch + nil gitStatus): git pills absent, cwd-only; recents kept.
    func testNonRepoOmitsGitPillsButKeepsRecents() {
        let state = ShellEmptyStateModel.make(
            cwd: "/tmp", node: nil, branch: nil, gitStatus: nil,
            recentCommands: ["ls", "pwd"])
        XCTAssertEqual(state.pills, ShellModuleModel.blockContextPills(
            node: nil, cwd: "/tmp", branch: nil, gitStatus: nil, duration: nil))
        XCTAssertFalse(state.pills.contains { $0.kind == .branch })
        XCTAssertFalse(state.pills.contains { $0.kind == .diff })
        XCTAssertEqual(state.recents, ["ls", "pwd"])
        XCTAssertTrue(state.showsRecents)
    }

    // Empty history → no recents, showsRecents false (no fabricated rows).
    func testEmptyRecentCommandsGivesNoRecents() {
        let state = ShellEmptyStateModel.make(
            cwd: "~/dev", node: nil, branch: nil, gitStatus: nil,
            recentCommands: [])
        XCTAssertTrue(state.recents.isEmpty)
        XCTAssertFalse(state.showsRecents)
    }

    // Dedupes (preserving first/frecency order) and caps to limit.
    func testRecentsAreDedupedAndCappedPreservingOrder() {
        let state = ShellEmptyStateModel.make(
            cwd: "~/dev", node: nil, branch: nil, gitStatus: nil,
            recentCommands: ["git status", "ls", "git status", "pwd", "ls", "cd ..", "make"],
            limit: 3)
        XCTAssertEqual(state.recents, ["git status", "ls", "pwd"])
    }

    // Blank/whitespace-only entries are dropped (never shown as empty rows).
    func testRecentsDropEmptyAndWhitespaceOnlyEntries() {
        let state = ShellEmptyStateModel.make(
            cwd: "~/dev", node: nil, branch: nil, gitStatus: nil,
            recentCommands: ["   ", "ls", "", "  pwd  "])
        XCTAssertEqual(state.recents, ["ls", "pwd"])
    }

    // node (e.g. user@host) is included exactly as blockContextPills places it.
    func testNodeIsIncludedInPillsLikeBlockContextPills() {
        let state = ShellEmptyStateModel.make(
            cwd: "~/dev", node: "kacper@mbp", branch: "main", gitStatus: nil,
            recentCommands: [])
        XCTAssertEqual(state.pills, ShellModuleModel.blockContextPills(
            node: "kacper@mbp", cwd: "~/dev", branch: "main", gitStatus: nil, duration: nil))
        XCTAssertTrue(state.pills.contains { $0.kind == .node && $0.label == "kacper@mbp" })
    }

    // TermyStore.insertTerminalInput forwards the EXACT string to the sink with NO
    // trailing newline (prefill must not execute the command).
    @MainActor
    func testInsertTerminalInputForwardsRawTextWithoutNewline() {
        let store = TermyStore(startInitialPTY: false)
        let id = UUID()
        var received: [String] = []
        store.registerTerminalInputSink({ received.append($0) }, for: id)
        store.insertTerminalInput("git status", for: id)
        XCTAssertEqual(received, ["git status"])
        XCTAssertFalse(received.first?.contains("\r") ?? true)
        XCTAssertFalse(received.first?.contains("\n") ?? true)
    }
}
