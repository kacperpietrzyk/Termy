import XCTest
@testable import TermyCore

final class RemoteSessionNotificationTests: XCTestCase {
    func testAgentStateChangedFactory() {
        let id = UUID()
        let n = RemoteSessionNotification.agentStateChanged(
            sessionID: id,
            agent: .claudeCode,
            cwdBasename: "Termy",
            bodyText: "Waiting for your input"
        )
        XCTAssertEqual(n.identifier, "agent-state-\(id.uuidString)")
        XCTAssertEqual(n.title, "Claude Code — Termy")
        XCTAssertEqual(n.body, "Waiting for your input")
        XCTAssertEqual(n.category, .agentState)
        XCTAssertEqual(n.sessionID, id)
    }

    func testAgentStateChangedTitleOmitsCwdWhenNil() {
        let n = RemoteSessionNotification.agentStateChanged(
            sessionID: UUID(), agent: .codex, cwdBasename: nil, bodyText: "Finished")
        XCTAssertEqual(n.title, "Codex")
    }

    func testAgentStateChangedTitleOmitsCwdWhenEmpty() {
        let n = RemoteSessionNotification.agentStateChanged(
            sessionID: UUID(), agent: .codex, cwdBasename: "", bodyText: "Done")
        XCTAssertEqual(n.title, "Codex")
    }

    func testRdpReconnectStillHasNilSessionID() {
        let n = RemoteSessionNotification.rdpReconnectScheduled(
            profileName: "VM", attempt: 1, delaySeconds: 5)
        XCTAssertNil(n.sessionID)
    }
}
