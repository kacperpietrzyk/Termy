import XCTest
@testable import TermyCore

final class TerminalExplainRecordTests: XCTestCase {
    private func block(_ command: String, startLine: Int, exit: Int32) -> TerminalCommandBlock {
        TerminalCommandBlock(command: command, startLine: startLine, endLine: startLine + 1,
                             exitCode: exit, output: "out")
    }

    func test_ordinal_isOneBasedIndexOfMatchingStartLine() {
        let blocks = [
            block("echo a", startLine: 0, exit: 0),
            block("badcmd", startLine: 4, exit: 1),
        ]
        XCTAssertEqual(TerminalExplainRecord.ordinal(ofBlockStartingAt: 0, in: blocks), 1)
        XCTAssertEqual(TerminalExplainRecord.ordinal(ofBlockStartingAt: 4, in: blocks), 2)
    }

    func test_ordinal_returnsNilWhenAbsent() {
        let blocks = [block("echo a", startLine: 0, exit: 0)]
        XCTAssertNil(TerminalExplainRecord.ordinal(ofBlockStartingAt: 99, in: blocks))
    }

    func testRecordCarriesCommand() {
        let r = TerminalExplainRecord(blockOrdinal: 3, blockStartLine: 12, command: "keychain test",
                                      durationSeconds: 0.92, finishedAt: Date(), succeeded: true)
        XCTAssertEqual(r.command, "keychain test")
        XCTAssertEqual(r.blockOrdinal, 3)
    }
}
