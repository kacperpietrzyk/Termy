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

    // MARK: - AD-2: non-zero exit reads as a failure

    func testExitedNonZeroReadsAsFailure() {
        let n = AgentNotificationPolicy.notification(
            for: .exited, sessionID: UUID(), context: ctx(exit: 1))
        XCTAssertEqual(n?.body, "Failed (status 1)")
    }

    // MARK: - AD-2: kind classification (pure, type distinction)

    func testKindWaiting() {
        XCTAssertEqual(AgentNotificationPolicy.kind(for: .waitingForInput, lastExitCode: nil),
                       .waitingForInput)
    }

    func testKindCleanExit() {
        XCTAssertEqual(AgentNotificationPolicy.kind(for: .exited, lastExitCode: 0), .exited)
        XCTAssertEqual(AgentNotificationPolicy.kind(for: .exited, lastExitCode: nil), .exited)
    }

    func testKindErrorOnNonZeroExit() {
        XCTAssertEqual(AgentNotificationPolicy.kind(for: .exited, lastExitCode: 137), .error)
        XCTAssertEqual(AgentNotificationPolicy.kind(for: .exited, lastExitCode: -1), .error)
    }

    func testKindNoneForWorkingAndIdle() {
        XCTAssertNil(AgentNotificationPolicy.kind(for: .working, lastExitCode: nil))
        XCTAssertNil(AgentNotificationPolicy.kind(for: .idle, lastExitCode: nil))
    }

    // MARK: - AD-2: deep-link userInfo round-trip (tests the routing without a
    //         live UNUserNotificationCenter / signed build)

    func testSessionUserInfoRoundTrips() {
        let id = UUID()
        let userInfo = AgentNotificationPolicy.encodeSessionUserInfo(id)
        XCTAssertEqual(userInfo[AgentNotificationPolicy.sessionUserInfoKey], id.uuidString)
        XCTAssertEqual(AgentNotificationPolicy.decodeSession(fromUserInfo: userInfo), id)
    }

    func testDecodeSessionRejectsMissingOrMalformed() {
        XCTAssertNil(AgentNotificationPolicy.decodeSession(fromUserInfo: [:]))
        XCTAssertNil(AgentNotificationPolicy.decodeSession(
            fromUserInfo: [AgentNotificationPolicy.sessionUserInfoKey: "not-a-uuid"]))
        XCTAssertNil(AgentNotificationPolicy.decodeSession(
            fromUserInfo: ["other": UUID().uuidString]))
    }
}
