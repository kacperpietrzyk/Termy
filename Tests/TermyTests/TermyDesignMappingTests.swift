import XCTest
@testable import Termy
@testable import TermyCore

final class TermyDesignMappingTests: XCTestCase {
    // Lock the area → status-hue table (OKLCH equality is reliable; Color
    // equality is not). DESIGN.md §3.2 orb hues + §6 module hues.
    func testAreaTokenMapping() {
        XCTAssertEqual(TermyDesign.areaToken(.terminal), DesignTokens.neutral.base)
        XCTAssertEqual(TermyDesign.areaToken(.files), DesignTokens.neutral.base)
        XCTAssertEqual(TermyDesign.areaToken(.ai), DesignTokens.ai.base)
        XCTAssertEqual(TermyDesign.areaToken(.editor), DesignTokens.ai.base)
        XCTAssertEqual(TermyDesign.areaToken(.commandCenter), DesignTokens.primary)
        XCTAssertEqual(TermyDesign.areaToken(.git), DesignTokens.git.base)
        XCTAssertEqual(TermyDesign.areaToken(.ssh), DesignTokens.host.base)
        XCTAssertEqual(TermyDesign.areaToken(.rdp), DesignTokens.host.base)
        XCTAssertEqual(TermyDesign.areaToken(.sync), DesignTokens.sync.base)
    }

    // Live-chip hues, DESIGN.md §5.6: waiting=amber, running(working)=sync, idle=gray.
    func testActivityTokenMapping() {
        XCTAssertEqual(TermyDesign.activityToken(.working), DesignTokens.sync.base)
        XCTAssertEqual(TermyDesign.activityToken(.waitingForInput), DesignTokens.agent.base)
        XCTAssertEqual(TermyDesign.activityToken(.idle), DesignTokens.fg3)
        XCTAssertEqual(TermyDesign.activityToken(.exited), DesignTokens.fg5)
    }
}
