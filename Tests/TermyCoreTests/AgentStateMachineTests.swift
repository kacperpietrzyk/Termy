import XCTest
@testable import TermyCore

final class AgentStateMachineTests: XCTestCase {
    func testInitialStateIsWorking() {
        XCTAssertEqual(AgentStateMachine().state, .working)
    }

    func testActivityTickKeepsWorking() {
        var m = AgentStateMachine()
        XCTAssertFalse(m.handle(.activityTick))   // already working → no change
        XCTAssertEqual(m.state, .working)
    }

    func testQuiescenceFromWorkingGoesIdle() {
        var m = AgentStateMachine()
        XCTAssertTrue(m.handle(.quiescenceElapsed))
        XCTAssertEqual(m.state, .idle)
    }

    func testWaitingHookOverridesAndIsNotDemotedByQuiescence() {
        var m = AgentStateMachine()
        XCTAssertTrue(m.handle(.hook(.waiting)))
        XCTAssertEqual(m.state, .waitingForInput)
        XCTAssertFalse(m.handle(.quiescenceElapsed))  // must NOT demote a hook-set waiting
        XCTAssertEqual(m.state, .waitingForInput)
    }

    func testActivityAfterWaitingReturnsToWorking() {
        var m = AgentStateMachine()
        m.handle(.hook(.waiting))
        XCTAssertTrue(m.handle(.activityTick))
        XCTAssertEqual(m.state, .working)
    }

    func testExitIsTerminal() {
        var m = AgentStateMachine()
        XCTAssertTrue(m.handle(.processExited))
        XCTAssertEqual(m.state, .exited)
        XCTAssertFalse(m.handle(.activityTick))    // ignored after exit
        XCTAssertFalse(m.handle(.hook(.waiting)))  // ignored after exit
        XCTAssertEqual(m.state, .exited)
    }

    func testActiveHookFromIdleGoesWorking() {
        var m = AgentStateMachine()
        m.handle(.quiescenceElapsed)               // → idle
        XCTAssertTrue(m.handle(.hook(.active)))
        XCTAssertEqual(m.state, .working)
    }
}
