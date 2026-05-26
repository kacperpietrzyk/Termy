import XCTest
@testable import TermyCore

final class ShellVersionProbeTests: XCTestCase {
    func test_parsesZshVersion() {
        XCTAssertEqual(ShellVersionProbe.parseZshVersion("zsh 5.9 (x86_64-apple-darwin23.0)"), "5.9")
    }

    func test_trailingNewlineTolerated() {
        XCTAssertEqual(ShellVersionProbe.parseZshVersion("zsh 5.9\n"), "5.9")
    }

    func test_nonZshReturnsNil() {
        XCTAssertNil(ShellVersionProbe.parseZshVersion("bash 3.2.57(1)-release"))
    }

    func test_emptyReturnsNil() {
        XCTAssertNil(ShellVersionProbe.parseZshVersion(""))
    }
}
