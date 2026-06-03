import XCTest
@testable import Termy
import TermyCore

@MainActor
final class BlockSnapshotStoreTests: XCTestCase {

    // MARK: - Helpers

    private func makeStore() -> (TermyStore, UUID) {
        let store = TermyStore(startInitialPTY: false)
        guard let id = store.selectedSessionID else {
            XCTFail("expected an initial session from TermyStore(startInitialPTY: false)")
            fatalError("unreachable")
        }
        return (store, id)
    }

    // MARK: - Tests

    /// (a) arm handler fires at commandStarted; (b) snapshot is stored at commandFinished
    /// keyed by the prompt index.
    func testCommandFinishedStoresSnapshotKeyedByPromptIndex() {
        let (store, id) = makeStore()

        var armed = false
        store.registerTerminalBlockArmHandler({ armed = true }, for: id)
        store.registerTerminalBlockSnapshotProvider({ "out-A\nout-B" }, for: id)

        store.ingestShellIntegrationEvents([
            .commandStarted("echo hi"),
            .output("hi\n"),
            .commandFinished(exitCode: 0, workingDirectory: "/tmp"),
        ], for: id)

        XCTAssertTrue(armed, "arm handler must fire at commandStarted")

        let snap = store.terminalBlockSnapshotForTesting(sessionID: id)
        XCTAssertNotNil(snap, "snapshot dict must be non-nil after commandFinished")
        XCTAssertEqual(snap?.values.first, "out-A\nout-B",
                       "snapshot must be keyed by the prompt index with the provider's return value")
    }

    /// nil provider → empty string stored (NOT skipped). Pure TUI commands like
    /// `claude` leave no main-buffer range; the empty snapshot is the correct
    /// clean result so block rendering doesn't fall back to the residue-prone re-parse.
    func testCommandFinishedStoresEmptyWhenProviderReturnsNil() {
        let (store, id) = makeStore()

        store.registerTerminalBlockArmHandler({}, for: id)
        store.registerTerminalBlockSnapshotProvider({ nil }, for: id)

        store.ingestShellIntegrationEvents([
            .commandStarted("claude"),
            .commandFinished(exitCode: 0, workingDirectory: "/tmp"),
        ], for: id)

        let snap = store.terminalBlockSnapshotForTesting(sessionID: id)
        XCTAssertNotNil(snap, "snapshot dict must be non-nil even when provider returns nil")
        XCTAssertEqual(snap?.values.first, "",
                       "nil provider must coalesce to empty string, not skip the entry")
    }

    /// Snapshot NOT stored when no provider is registered (no arm side-effect either).
    func testNoSnapshotStoredWithoutRegisteredProvider() {
        let (store, id) = makeStore()
        // Deliberately no registerTerminalBlockSnapshotProvider call.

        store.ingestShellIntegrationEvents([
            .commandStarted("ls"),
            .commandFinished(exitCode: 0, workingDirectory: "/tmp"),
        ], for: id)

        XCTAssertNil(store.terminalBlockSnapshotForTesting(sessionID: id),
                     "snapshot dict must remain nil when no provider is registered")
    }

    func testRenderedBlockUsesSnapshotOutputWhenPresent() {
        let store = TermyStore(startInitialPTY: false)
        guard let id = store.selectedSessionID else { return XCTFail("no selected session") }
        store.registerTerminalBlockArmHandler({}, for: id)
        store.registerTerminalBlockSnapshotProvider({ "SNAPSHOT-LINE" }, for: id)
        store.ingestShellIntegrationEvents([
            .commandStarted("echo hi"),
            .output("RAW-REPARSE\n"),
            .commandFinished(exitCode: 0, workingDirectory: "/tmp"),
        ], for: id)
        let blocks = store.renderedTerminalCommandBlocks()
        let text = blocks.first?.outputLines.map(\.text).joined() ?? ""
        XCTAssertTrue(text.contains("SNAPSHOT-LINE"), "finished block must render the snapshot")
        XCTAssertFalse(text.contains("RAW-REPARSE"), "finished block must NOT render the re-parsed output")
    }

    func testRenderedBlockEmptySnapshotRendersNoOutput() {
        let store = TermyStore(startInitialPTY: false)
        guard let id = store.selectedSessionID else { return XCTFail("no selected session") }
        store.registerTerminalBlockArmHandler({}, for: id)
        store.registerTerminalBlockSnapshotProvider({ "" }, for: id)     // clean / pure-TUI
        store.ingestShellIntegrationEvents([
            .commandStarted("claude"),
            .output("junk-from-reparse\n"),
            .commandFinished(exitCode: 0, workingDirectory: "/tmp"),
        ], for: id)
        let blocks = store.renderedTerminalCommandBlocks()
        XCTAssertEqual(blocks.first?.outputLines.count, 0, "empty snapshot → no output lines (clean block)")
    }

    /// Multiple commands each get their own keyed snapshot.
    func testMultipleCommandsGetSeparateSnapshots() throws {
        let (store, id) = makeStore()

        var callCount = 0
        let snapshots = ["first output", "second output"]
        store.registerTerminalBlockArmHandler({}, for: id)
        store.registerTerminalBlockSnapshotProvider({
            let s = snapshots[callCount]
            callCount += 1
            return s
        }, for: id)

        store.ingestShellIntegrationEvents([
            .commandStarted("echo first"),
            .output("first output\n"),
            .commandFinished(exitCode: 0, workingDirectory: "/tmp"),
            .commandStarted("echo second"),
            .output("second output\n"),
            .commandFinished(exitCode: 0, workingDirectory: "/tmp"),
        ], for: id)

        let snap = try XCTUnwrap(store.terminalBlockSnapshotForTesting(sessionID: id))
        XCTAssertEqual(snap.count, 2, "two commands → two snapshot entries keyed by different prompt indices")
        XCTAssertTrue(snap.values.contains("first output"))
        XCTAssertTrue(snap.values.contains("second output"))
    }

    /// When leading lines are trimmed from the transcript, `terminalBlockSnapshots`
    /// must be re-keyed by the same drop count so finished blocks keep their output.
    ///
    /// Strategy (mirrors TermyStoreTerminalTests approach):
    /// 1. Pre-fill the session to 9,998 lines so the next appends don't yet overflow.
    /// 2. Run one command (commandStarted + commandFinished) — this appends 2 lines
    ///    (prompt at index 9,998, exit at 9,999 but we only care about the snapshot key
    ///    = promptIndex = 9,998) and stores a snapshot at that key. Total = 10,000.
    /// 3. Append one more output line via ingestShellIntegrationEvents([.output(…)]).
    ///    This pushes the count to 10,001 → trim drops 1 line (overflow = 1).
    ///    The snapshot key must shift from 9,998 → 9,997; the old key must be nil.
    func testSnapshotKeysSurviveTranscriptTrim() throws {
        let localProfile = try XCTUnwrap(ConnectionProfile.local())
        let store = TermyStore(startInitialPTY: false)

        // Pre-fill to 9,998 so two more lines (prompt + exit from commandStarted/Finished)
        // bring us to exactly 10,000 without triggering a trim yet.
        let session = TermySession(
            title: "Local Shell",
            profile: localProfile,
            lines: (0..<9_998).map { TerminalLine(role: .stdout, text: "line \($0)") },
            interactionMode: .rawPTY
        )
        store.sessions = [session]
        store.selectedSessionID = session.id

        // Register a snapshot provider so a snapshot is stored at commandFinished.
        store.registerTerminalBlockArmHandler({}, for: session.id)
        store.registerTerminalBlockSnapshotProvider({ "trimmed-snapshot" }, for: session.id)

        // Run a command: appends prompt line (index 9,998) + exit line (index 9,999).
        // Snapshot is stored keyed by promptIndex = 9,998. No trim yet (count = 10,000).
        store.ingestShellIntegrationEvents([
            .commandStarted("echo hi"),
            .commandFinished(exitCode: 0, workingDirectory: "/tmp"),
        ], for: session.id)

        // Confirm the snapshot key before trim.
        let snapsBefore = try XCTUnwrap(store.terminalBlockSnapshotForTesting(sessionID: session.id),
                                        "snapshot must be stored after commandFinished")
        let originalKey = try XCTUnwrap(snapsBefore.keys.first,
                                        "snapshot dict must have one entry")
        XCTAssertEqual(snapsBefore[originalKey], "trimmed-snapshot", "snapshot value before trim")

        // Trigger trim: one more append → 10,001 lines → overflow = 1.
        store.ingestShellIntegrationEvents([.output("trigger-trim\n")], for: session.id)

        let snapsAfter = try XCTUnwrap(store.terminalBlockSnapshotForTesting(sessionID: session.id),
                                       "snapshot dict must still exist after trim")
        XCTAssertEqual(snapsAfter[originalKey - 1], "trimmed-snapshot",
                       "snapshot key must shift down by 1 (the drop count)")
        XCTAssertNil(snapsAfter[originalKey],
                     "old unshifted key must be gone after trim")
    }
}
