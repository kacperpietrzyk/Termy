import XCTest
@testable import TermyCore

final class AgentNotificationPolicyTests: XCTestCase {
    private func ctx(
        suppressed: Bool = false,
        exit: Int32? = nil,
        cwd: String? = "Termy"
    ) -> AgentNotificationPolicy.Context {
        .init(agent: .claudeCode, cwdBasename: cwd, lastExitCode: exit, suppressed: suppressed)
    }

    func testWaitingFires() {
        let n = AgentNotificationPolicy.notification(
            for: .waitingForInput, sessionID: UUID(), context: ctx())
        XCTAssertEqual(n?.body, "Waiting for your input")
        XCTAssertEqual(n?.category, .agentState)
    }

    func testExitedWithCode() {
        let n = AgentNotificationPolicy.notification(
            for: .exited, sessionID: UUID(), context: ctx(exit: 0))
        XCTAssertEqual(n?.body, "Finished (status 0)")
        XCTAssertEqual(n?.category, .agentState)
    }

    func testExitedWithoutCode() {
        let n = AgentNotificationPolicy.notification(
            for: .exited, sessionID: UUID(), context: ctx(exit: nil))
        XCTAssertEqual(n?.body, "Finished")
        XCTAssertEqual(n?.category, .agentState)
    }

    func testIdleDoesNotFire() {
        XCTAssertNil(AgentNotificationPolicy.notification(
            for: .idle, sessionID: UUID(), context: ctx()))
    }

    func testWorkingDoesNotFire() {
        XCTAssertNil(AgentNotificationPolicy.notification(
            for: .working, sessionID: UUID(), context: ctx()))
    }

    func testSuppressedFiresNothing() {
        XCTAssertNil(AgentNotificationPolicy.notification(
            for: .waitingForInput, sessionID: UUID(), context: ctx(suppressed: true)))
        XCTAssertNil(AgentNotificationPolicy.notification(
            for: .exited, sessionID: UUID(), context: ctx(suppressed: true, exit: 0)))
    }
}
