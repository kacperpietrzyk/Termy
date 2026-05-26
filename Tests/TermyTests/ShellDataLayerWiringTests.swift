import XCTest
import TermyCore
@testable import Termy

@MainActor
final class ShellDataLayerWiringTests: XCTestCase {
    private func makeStore(log: CommandActivityLog) -> (TermyStore, UUID) {
        let store = TermyStore(startInitialPTY: false, commandActivityLog: log)
        let session = TermySession(
            title: "Test",
            profile: ConnectionProfile.local(),
            interactionMode: .rawPTY
        )
        store.sessions = [session]
        store.selectedSessionID = session.id
        return (store, session.id)
    }

    func test_commandStarted_incrementsCommandsToday() throws {
        let fileURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("termy-wire-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let log = CommandActivityLog(fileURL: fileURL)
        let (store, id) = makeStore(log: log)

        XCTAssertEqual(store.commandsToday(), 0)
        store.ingestShellIntegrationEvents([.commandStarted("git status")], for: id)
        store.ingestShellIntegrationEvents([.commandStarted("git log")], for: id)
        XCTAssertEqual(store.commandsToday(), 2)
    }

    func test_recordTerminalExplain_setsRecordWithCorrectOrdinal() throws {
        let fileURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("termy-wire-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let (store, id) = makeStore(log: CommandActivityLog(fileURL: fileURL))

        store.ingestShellIntegrationEvents(
            [.commandStarted("echo a"), .output("a\n"), .commandFinished(exitCode: 0, workingDirectory: nil)], for: id)
        store.ingestShellIntegrationEvents(
            [.commandStarted("badcmd"), .output("err\n"), .commandFinished(exitCode: 1, workingDirectory: nil)], for: id)

        let blocks = store.terminalCommandBlocks()
        XCTAssertEqual(blocks.count, 2)
        let failed = try XCTUnwrap(blocks.last)

        store.recordTerminalExplain(failedBlockStartLine: failed.startLine, in: blocks,
                                    durationSeconds: 0.92, succeeded: true)
        let record = try XCTUnwrap(store.lastTerminalExplain)
        XCTAssertEqual(record.blockOrdinal, 2)
        XCTAssertEqual(record.durationSeconds, 0.92)
        XCTAssertTrue(record.succeeded)
    }

    func test_recordTerminalExplain_unmatchedBlock_recordsNilOrdinal_notZero() throws {
        let fileURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("termy-wire-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let (store, id) = makeStore(log: CommandActivityLog(fileURL: fileURL))

        store.ingestShellIntegrationEvents(
            [.commandStarted("echo a"), .output("a\n"), .commandFinished(exitCode: 0, workingDirectory: nil)], for: id)
        let blocks = store.terminalCommandBlocks()

        // startLine 9999 is not in the snapshot → honest nil ordinal, never a fabricated 0.
        store.recordTerminalExplain(failedBlockStartLine: 9999, in: blocks,
                                    durationSeconds: 0.1, succeeded: false)
        let record = try XCTUnwrap(store.lastTerminalExplain)
        XCTAssertNil(record.blockOrdinal)
        XCTAssertFalse(record.succeeded)
    }
}
