import XCTest
import TermyCore
@testable import Termy

@MainActor
final class SwiftTermSessionSeamTests: XCTestCase {
    private func storeWithOneSession() -> (TermyStore, UUID) {
        // Use an isolated HistoryStore (no zsh import, in-memory only via /dev/null)
        // so tests don't inherit the user's real shell history.
        let isolatedHistory = HistoryStore(
            fileURL: URL(fileURLWithPath: "/dev/null"),
            markerURL: URL(fileURLWithPath: "/dev/null"),
            zshHistoryURL: nil
        )
        let store = TermyStore(startInitialPTY: false, historyStore: isolatedHistory)
        let id = store.sessions.first!.id
        return (store, id)
    }

    func testIngestShellIntegrationEventsAppendsCommandBlockLines() {
        let (store, id) = storeWithOneSession()
        store.ingestShellIntegrationEvents(
            [.commandStarted("ls"), .output("a\nb\n"), .commandFinished(exitCode: 0, workingDirectory: "/tmp")],
            for: id)
        let texts = store.sessions.first { $0.id == id }!.lines.map(\.text)
        XCTAssertTrue(texts.contains("$ ls"))
        XCTAssertTrue(texts.contains("a\nb\n"))
        XCTAssertTrue(texts.contains("Exit 0"))
        XCTAssertEqual(store.sessions.first { $0.id == id }!.lastExitCode, 0)
        XCTAssertEqual(store.sessions.first { $0.id == id }!.currentWorkingDirectory, "/tmp")
    }

    func testSetSessionTitleAndDirectory() {
        let (store, id) = storeWithOneSession()
        store.setSessionTerminalTitle("vim ~/x", for: id)
        store.setSessionWorkingDirectory("/var/log", for: id)
        XCTAssertEqual(store.sessions.first { $0.id == id }!.title, "vim ~/x")
        XCTAssertEqual(store.sessions.first { $0.id == id }!.currentWorkingDirectory, "/var/log")
    }

    // Coverage moved here from the retired legacy test
    // `testPTYOSCTitleMetadataIsTrimmedAndBounded` (skipped in Task 6, deleted
    // in Stage 3): the trim + 120-char-bound branches of setSessionTerminalTitle
    // are pure-string logic the Task-10 PTY gate is too coarse to backstop.
    func testSetSessionTerminalTitleTrimsWhitespaceAndBoundsTo120() {
        let (store, id) = storeWithOneSession()
        let longTitle = String(repeating: "x", count: 160)
        store.setSessionTerminalTitle("  \(longTitle)  ", for: id)
        XCTAssertEqual(store.sessions.first { $0.id == id }!.title,
                       String(longTitle.prefix(120)))
    }

    func testSetSessionTerminalTitleIgnoresWhitespaceOnlyInput() {
        let (store, id) = storeWithOneSession()
        let original = store.sessions.first { $0.id == id }!.title
        store.setSessionTerminalTitle("   ", for: id)
        XCTAssertEqual(store.sessions.first { $0.id == id }!.title, original)
    }

    // M3-2 regression: the SwiftTerm cutover deleted the legacy runCommand
    // PTY-write branch, which was the sole caller of rememberCommand. Command
    // history (CompletionEngine source) must now be fed from the OSC 133
    // .commandStarted stream so keyboard-first completion/autosuggestion still
    // works. Asserts the user-facing consequence (autosuggestion), not just
    // the backing array, so it would fail if the rewire regressed.
    func testIngestCommandStartedRecordsCommandHistoryForCompletion() {
        let (store, id) = storeWithOneSession()
        store.ingestShellIntegrationEvents([.commandStarted("git status --short")], for: id)
        XCTAssertEqual(store.historyStore.rankedSnapshot(forCwd: nil).first, "git status --short")
        let suggestion = store.inlineAutosuggestion(for: "git stat")
        XCTAssertEqual(suggestion?.replacement, "git status --short")
        XCTAssertEqual(suggestion?.ghostText, "us --short")
    }

    func testNoteSessionProcessExitedAppendsSystemLine() {
        let (store, id) = storeWithOneSession()
        store.noteSessionProcessExited(exitCode: 3, for: id)
        XCTAssertEqual(store.sessions.first { $0.id == id }!.lastExitCode, 3)
        XCTAssertTrue(store.sessions.first { $0.id == id }!.lines.map(\.text)
            .contains { $0.contains("exited") })
    }

    func testInlineSuggestionSuffixUsesHistoryAndRequiresCursorAtEnd() {
        let (store, id) = storeWithOneSession()
        store.ingestShellIntegrationEvents([.commandStarted("git status --short")], for: id)
        store.ingestShellIntegrationEvents(
            [.inputBufferChanged(text: "git stat", cursor: 8, length: 8)], for: id)
        XCTAssertEqual(store.terminalInlineSuggestionSuffix(for: id), "us --short")

        store.ingestShellIntegrationEvents(
            [.inputBufferChanged(text: "git stat", cursor: 3, length: 8)], for: id)
        XCTAssertNil(store.terminalInlineSuggestionSuffix(for: id))
    }

    func testInlineSuggestionClearedWhenCommandStarts() {
        let (store, id) = storeWithOneSession()
        store.ingestShellIntegrationEvents([.commandStarted("git status --short")], for: id)
        store.ingestShellIntegrationEvents(
            [.inputBufferChanged(text: "git stat", cursor: 8, length: 8)], for: id)
        XCTAssertEqual(store.terminalInlineSuggestionSuffix(for: id), "us --short")
        store.ingestShellIntegrationEvents([.commandStarted("git stat")], for: id)
        XCTAssertNil(store.terminalInlineSuggestionSuffix(for: id))
    }

    func testInlineAcceptDecisionGatesOnAltScreenAndPending() {
        XCTAssertEqual(
            InlineAcceptDecision.suffix(isAltScreen: false, pending: "us --short"),
            "us --short")
        XCTAssertNil(InlineAcceptDecision.suffix(isAltScreen: true, pending: "us --short"))
        XCTAssertNil(InlineAcceptDecision.suffix(isAltScreen: false, pending: nil))
        XCTAssertNil(InlineAcceptDecision.suffix(isAltScreen: false, pending: ""))
    }

    // F-2: registerTerminalLaunch seeds session.currentWorkingDirectory from
    // the descriptor so the first command in a session — emitted before any
    // OSC 133 D prompt mark — records with a non-nil cwd.
    func testRegisterTerminalLaunchSeedsSessionWorkingDirectoryWhenNil() {
        let (store, id) = storeWithOneSession()
        XCTAssertNil(store.sessions.first { $0.id == id }!.currentWorkingDirectory)
        let descriptor = TerminalLaunchDescriptor(
            executable: "/bin/zsh",
            arguments: [],
            environment: [:],
            workingDirectory: "/tmp/seed",
            usesZshIntegration: true
        )
        store.registerTerminalLaunch(descriptor, for: id)
        XCTAssertEqual(store.sessions.first { $0.id == id }!.currentWorkingDirectory, "/tmp/seed")
    }

    // The seed must not clobber a cwd that was already set (e.g. by a prior
    // OSC 133 D mark before a session-reattach).
    func testRegisterTerminalLaunchDoesNotOverwriteExistingCwd() {
        let (store, id) = storeWithOneSession()
        store.setSessionWorkingDirectory("/already/set", for: id)
        let descriptor = TerminalLaunchDescriptor(
            executable: "/bin/zsh",
            arguments: [],
            environment: [:],
            workingDirectory: "/tmp/seed",
            usesZshIntegration: true
        )
        store.registerTerminalLaunch(descriptor, for: id)
        XCTAssertEqual(store.sessions.first { $0.id == id }!.currentWorkingDirectory, "/already/set")
    }

    func testCaretOriginProviderRegistersAndReads() {
        let (store, id) = storeWithOneSession()
        store.registerTerminalCaretOriginProvider({ (x: 12, y: 34) }, for: id)
        let p = store.terminalCaretOrigin(for: id)
        XCTAssertEqual(p?.x, 12)
        XCTAssertEqual(p?.y, 34)
        store.clearTerminalCaretOriginProvider(for: id)
        XCTAssertNil(store.terminalCaretOrigin(for: id))
    }
}
