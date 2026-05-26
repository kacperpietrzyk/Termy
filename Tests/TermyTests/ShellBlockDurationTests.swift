import XCTest
@testable import Termy
import TermyCore

@MainActor
final class ShellBlockDurationTests: XCTestCase {

    func testDurationRecordedOnCommandFinished() throws {
        let store = TermyStore(startInitialPTY: false)
        guard let id = store.selectedSessionID else {
            return XCTFail("expected an initial session")
        }

        store.ingestShellIntegrationEvents([
            .commandStarted("ls"),
            .output("a\nb\n"),
            .commandFinished(exitCode: 0, workingDirectory: "/tmp"),
        ], for: id)

        let blocks = store.renderedTerminalCommandBlocks()
        XCTAssertEqual(blocks.count, 1, "one command block expected")
        let d = try XCTUnwrap(blocks.first?.duration, "duration must be recorded after commandFinished")
        XCTAssertGreaterThanOrEqual(d, 0, "duration must be non-negative")
        XCTAssertEqual(blocks.first?.exitCode, 0)
    }

    func testDurationNilWhenCommandFinishedWithNoStart() {
        let store = TermyStore(startInitialPTY: false)
        guard let id = store.selectedSessionID,
              let idx = store.sessions.firstIndex(where: { $0.id == id }) else {
            return XCTFail("expected an initial session")
        }

        // Manually inject a prompt line without going through commandStarted,
        // so no start time is recorded.
        store.sessions[idx].lines.append(TerminalLine(role: .prompt, text: "$ echo hi"))

        // commandFinished alone — no pending prompt index for this session.
        store.ingestShellIntegrationEvents([
            .commandFinished(exitCode: 0, workingDirectory: "/tmp"),
        ], for: id)

        let blocks = store.renderedTerminalCommandBlocks()
        XCTAssertEqual(blocks.count, 1)
        XCTAssertNil(blocks.first?.duration, "duration must be nil when no commandStarted was recorded")
    }

    func testDurationNotLeakedAfterCloseSession() {
        let store = TermyStore(startInitialPTY: false)
        guard let id = store.selectedSessionID else {
            return XCTFail("expected an initial session")
        }

        store.ingestShellIntegrationEvents([
            .commandStarted("sleep 1"),
        ], for: id)

        // Close without commandFinished — timing state must be cleaned up.
        store.closeSession(sessionID: id)

        // Verify no memory leak: the session is gone and no orphan entry remains.
        XCTAssertNil(store.commandDuration(forSession: id, startLine: 0),
                     "timing state must be cleared on closeSession")
    }

    func testMultipleCommandsEachGetDuration() throws {
        let store = TermyStore(startInitialPTY: false)
        guard let id = store.selectedSessionID else {
            return XCTFail("expected an initial session")
        }

        store.ingestShellIntegrationEvents([
            .commandStarted("echo first"),
            .output("first\n"),
            .commandFinished(exitCode: 0, workingDirectory: "/tmp"),
            .commandStarted("echo second"),
            .output("second\n"),
            .commandFinished(exitCode: 1, workingDirectory: "/tmp"),
        ], for: id)

        let blocks = store.renderedTerminalCommandBlocks()
        XCTAssertEqual(blocks.count, 2, "two command blocks expected")
        let d0 = try XCTUnwrap(blocks[0].duration)
        let d1 = try XCTUnwrap(blocks[1].duration)
        XCTAssertGreaterThanOrEqual(d0, 0)
        XCTAssertGreaterThanOrEqual(d1, 0)
        XCTAssertEqual(blocks[1].exitCode, 1)
    }

    // MARK: - trim remap (shiftLineKeys)

    func testShiftLineKeysShiftsSurvivorsAndDropsTrimmed() {
        // key 5 with overflow 3 → key 2 (survives); key 2 with overflow 3 → dropped.
        let input: [Int: TimeInterval] = [5: 1.5, 2: 0.7, 3: 0.9, 10: 4.2]
        let shifted = TermyStore.shiftLineKeys(input, by: 3)

        XCTAssertEqual(shifted[2], 1.5, "key 5 shifts to key 2, value preserved")
        XCTAssertEqual(shifted[0], 0.9, "key 3 (== overflow) shifts to key 0, kept")
        XCTAssertEqual(shifted[7], 4.2, "key 10 shifts to key 7")
        XCTAssertNil(shifted[-1], "no negative keys")
        XCTAssertEqual(shifted.count, 3, "key 2 (< overflow) is dropped")
        // The trimmed-away key's value is not findable under any shifted key.
        XCTAssertFalse(shifted.values.contains(0.7), "trimmed entry's value is gone")
    }

    func testShiftLineKeysIsGenericOverDate() {
        let now = Date()
        let input: [Int: Date] = [4: now, 1: now]
        let shifted = TermyStore.shiftLineKeys(input, by: 2)
        XCTAssertEqual(shifted[2], now, "key 4 → key 2")
        XCTAssertNil(shifted[-1])
        XCTAssertEqual(shifted.count, 1, "key 1 (< overflow) dropped")
    }

    func testShiftLineKeysZeroOverflowIsIdentity() {
        let input: [Int: TimeInterval] = [0: 1.0, 5: 2.0]
        let shifted = TermyStore.shiftLineKeys(input, by: 0)
        XCTAssertEqual(shifted, input, "overflow 0 leaves keys unchanged")
    }
}
