import XCTest
import SwiftTerm

// Replaces TermyTerminalSpikeTests.testSwiftTermLinksAndProvidesEnvironment:
// proves the pinned SwiftTerm 1.13.0 product resolves, builds, and links
// from the Termy app target's test bundle (not the deleted spike target).
final class SwiftTermLinkSmokeTests: XCTestCase {
    func testSwiftTermLinksFromTermyTarget() {
        let env = Terminal.getEnvironmentVariables(termName: "xterm-256color", trueColor: true)
        XCTAssertFalse(env.isEmpty, "SwiftTerm must resolve and return env entries from the Termy target")
        XCTAssertTrue(env.contains { $0.hasPrefix("TERM=") }, "expected a TERM= entry from SwiftTerm")
    }
}
