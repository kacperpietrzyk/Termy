import XCTest
@testable import TermyCore

final class TerminalLaunchDescriptorTests: XCTestCase {
    func testDescriptorRoundTripsExecutableArgsEnv() {
        let d = TerminalLaunchDescriptor(
            executable: "/usr/bin/ssh",
            arguments: ["-tt", "host"],
            environment: ["TERM": "xterm-256color"],
            workingDirectory: "/tmp",
            usesZshIntegration: false
        )
        XCTAssertEqual(d.executable, "/usr/bin/ssh")
        XCTAssertEqual(d.arguments, ["-tt", "host"])
        XCTAssertEqual(d.environment["TERM"], "xterm-256color")
        XCTAssertEqual(d.workingDirectory, "/tmp")
        XCTAssertFalse(d.usesZshIntegration)
    }

    func testZshDescriptorBuildsZdotdirIntegration() throws {
        let d = TerminalLaunchDescriptor(
            executable: "/bin/zsh", arguments: [],
            environment: ["TERM": "xterm-256color"],
            workingDirectory: nil, usesZshIntegration: true
        )
        let launch = try ShellIntegrationLaunch(descriptor: d, sessionID: UUID())
        defer { launch.cleanup() }
        let zdotdir = try XCTUnwrap(launch.zdotdir)
        let zshrc = try String(contentsOf: zdotdir.appendingPathComponent(".zshrc"), encoding: .utf8)
        XCTAssertTrue(zshrc.contains("133;C;cmd="))
        XCTAssertTrue(zshrc.contains("133;D;exit="))
        XCTAssertEqual(launch.environment["ZDOTDIR"], zdotdir.path)
        XCTAssertEqual(launch.shellPath, "/bin/zsh")
    }

    func testNonZshDescriptorGetsNoIntegrationDirAndPreservesEnv() throws {
        let d = TerminalLaunchDescriptor(
            executable: "/usr/bin/ssh", arguments: ["host"],
            environment: ["TERM": "xterm-256color", "FOO": "bar"],
            workingDirectory: "/tmp", usesZshIntegration: false
        )
        let launch = try ShellIntegrationLaunch(descriptor: d, sessionID: UUID())
        defer { launch.cleanup() }
        XCTAssertNil(launch.zdotdir)
        XCTAssertEqual(launch.shellPath, "/usr/bin/ssh")
        XCTAssertEqual(launch.arguments, ["host"])
        XCTAssertEqual(launch.environment["FOO"], "bar")
        XCTAssertNil(launch.environment["ZDOTDIR"])
        XCTAssertEqual(launch.workingDirectory, "/tmp")
    }

    func testDescriptorTermDefaultedOnlyWhenAbsent() throws {
        let absent = TerminalLaunchDescriptor(
            executable: "/usr/bin/ssh", arguments: ["host"],
            environment: ["FOO": "bar"],
            workingDirectory: nil, usesZshIntegration: false
        )
        let absentLaunch = try ShellIntegrationLaunch(descriptor: absent, sessionID: UUID())
        defer { absentLaunch.cleanup() }
        XCTAssertEqual(absentLaunch.environment["TERM"], "xterm-256color")

        let supplied = TerminalLaunchDescriptor(
            executable: "/usr/bin/ssh", arguments: ["host"],
            environment: ["TERM": "screen-256color"],
            workingDirectory: nil, usesZshIntegration: false
        )
        let suppliedLaunch = try ShellIntegrationLaunch(descriptor: supplied, sessionID: UUID())
        defer { suppliedLaunch.cleanup() }
        XCTAssertEqual(suppliedLaunch.environment["TERM"], "screen-256color")
    }

    func testExistingProfileInitializerStillWorks() throws {
        let launch = try ShellIntegrationLaunch(profile: .zsh, sessionID: UUID())
        defer { launch.cleanup() }
        XCTAssertEqual(launch.shellPath, "/bin/zsh")
        XCTAssertNotNil(launch.zdotdir)
    }
}
