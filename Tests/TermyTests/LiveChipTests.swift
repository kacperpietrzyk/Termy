import XCTest
@testable import Termy
@testable import TermyCore

final class LiveChipTests: XCTestCase {
    func testLiveChipHueMapping() {
        XCTAssertEqual(TermyLiveChip.hue(for: .waiting), DesignTokens.agent.base)
        XCTAssertEqual(TermyLiveChip.hue(for: .running), DesignTokens.sync.base)
        XCTAssertEqual(TermyLiveChip.hue(for: .idle), DesignTokens.fg3)
    }

    func testWaitingPulses() {
        XCTAssertTrue(TermyLiveChip.State.waiting.pulses)
        XCTAssertFalse(TermyLiveChip.State.idle.pulses)
    }

    func testStateLabels() {
        XCTAssertEqual(TermyLiveChip.State.waiting.label, "waiting")
        XCTAssertEqual(TermyLiveChip.State.running.label, "running")
        XCTAssertEqual(TermyLiveChip.State.idle.label, "idle")
    }
}
