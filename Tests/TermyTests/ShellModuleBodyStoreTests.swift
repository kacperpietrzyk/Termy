import XCTest
@testable import Termy
import TermyCore

@MainActor
final class ShellModuleBodyStoreTests: XCTestCase {

    func testRecordTerminalExplainCapturesCommandFromBlock() {
        let store = TermyStore(startInitialPTY: false)
        let blocks = [
            TerminalCommandBlock(command: "git status", startLine: 0, endLine: 1, exitCode: 0, output: ""),
            TerminalCommandBlock(command: "keychain test", startLine: 2, endLine: 3, exitCode: 1, output: "boom"),
        ]
        store.recordTerminalExplain(failedBlockStartLine: 2, in: blocks, durationSeconds: 0.5, succeeded: false)
        XCTAssertEqual(store.lastTerminalExplain?.command, "keychain test")
        XCTAssertEqual(store.lastTerminalExplain?.blockOrdinal, 2)
    }

    func testRecordTerminalExplainEmptyCommandWhenBlockAbsent() {
        let store = TermyStore(startInitialPTY: false)
        store.recordTerminalExplain(failedBlockStartLine: 99, in: [], durationSeconds: 0.1, succeeded: false)
        XCTAssertEqual(store.lastTerminalExplain?.command, "", "honest empty, never fabricated")
        XCTAssertNil(store.lastTerminalExplain?.blockOrdinal)
    }

    func testSidecarRecentCrashCountZeroWhenNoSidecar() async {
        let store = TermyStore(startInitialPTY: false)
        let n = await store.sidecarRecentCrashCount(forSession: UUID())
        XCTAssertEqual(n, 0, "no sidecar for this id → honest 0, never crashes")
    }
}
