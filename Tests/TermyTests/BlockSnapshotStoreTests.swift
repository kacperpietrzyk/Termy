import XCTest
@testable import Termy

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
}
