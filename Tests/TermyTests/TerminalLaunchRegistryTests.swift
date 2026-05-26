import XCTest
import TermyCore
@testable import Termy

@MainActor
final class TerminalLaunchRegistryTests: XCTestCase {
    func testRegisterAndReadDescriptor() {
        let store = TermyStore(startInitialPTY: false)
        let id = store.sessions.first!.id
        let d = TerminalLaunchDescriptor(executable: "/bin/zsh", arguments: [],
            environment: [:], workingDirectory: nil, usesZshIntegration: true)
        store.registerTerminalLaunch(d, for: id)
        XCTAssertEqual(store.terminalLaunchDescriptor(for: id), d)
        XCTAssertEqual(store.terminalLaunchGeneration(for: id), 0)
        store.bumpTerminalLaunchGeneration(for: id)
        XCTAssertEqual(store.terminalLaunchGeneration(for: id), 1)
    }
}
