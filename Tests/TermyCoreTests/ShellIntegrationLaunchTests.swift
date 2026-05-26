import XCTest
@testable import TermyCore

final class ShellIntegrationLaunchTests: XCTestCase {
    func testZshProfileProducesShellPathAndArgs() throws {
        let launch = try ShellIntegrationLaunch(profile: .zsh, sessionID: UUID())
        defer { launch.cleanup() }
        XCTAssertEqual(launch.shellPath, "/bin/zsh")
        XCTAssertEqual(launch.arguments, [])
    }

    func testWritesZshrcWithOSC133MarkersAndSetsZdotdir() throws {
        let launch = try ShellIntegrationLaunch(profile: .zsh, sessionID: UUID())
        defer { launch.cleanup() }
        let zdotdir = try XCTUnwrap(launch.zdotdir)
        let zshrc = try String(contentsOf: zdotdir.appendingPathComponent(".zshrc"), encoding: .utf8)
        XCTAssertTrue(zshrc.contains("133;C;cmd="), "must emit OSC 133 command-start with cmd=")
        XCTAssertTrue(zshrc.contains("133;D;exit="), "must emit OSC 133 command-end with exit=")
        XCTAssertEqual(launch.environment["ZDOTDIR"], zdotdir.path)
        XCTAssertEqual(launch.environment["TERM"], "xterm-256color")
    }

    func testEnvironmentArrayIsKeyValueStringsForSwiftTerm() throws {
        let launch = try ShellIntegrationLaunch(profile: .zsh, sessionID: UUID())
        defer { launch.cleanup() }
        XCTAssertTrue(launch.environmentArray.contains("TERM=xterm-256color"))
        XCTAssertTrue(launch.environmentArray.allSatisfy { $0.contains("=") })
    }

    func testCleanupRemovesIntegrationDirectory() throws {
        let launch = try ShellIntegrationLaunch(profile: .zsh, sessionID: UUID())
        let dir = try XCTUnwrap(launch.zdotdir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.path))
        launch.cleanup()
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.path))
    }

    func testBashProfileGetsNoIntegrationDirectoryOrZdotdir() throws {
        let launch = try ShellIntegrationLaunch(profile: .bash, sessionID: UUID())
        defer { launch.cleanup() }
        XCTAssertNil(launch.zdotdir, "bash must not provision an integration directory")
        XCTAssertNil(launch.environment["ZDOTDIR"], "bash must not get ZDOTDIR")
        XCTAssertEqual(launch.shellPath, "/bin/bash")
        XCTAssertEqual(launch.arguments, ["--noprofile", "--norc"])
        XCTAssertEqual(launch.environment["TERM"], "xterm-256color")
    }

    func testCustomProfileGetsNoIntegrationDirectoryOrZdotdir() throws {
        let launch = try ShellIntegrationLaunch(
            profile: .custom(path: "/usr/bin/fish", arguments: ["-l"]),
            sessionID: UUID())
        defer { launch.cleanup() }
        XCTAssertNil(launch.zdotdir, "custom must not provision an integration directory")
        XCTAssertNil(launch.environment["ZDOTDIR"], "custom must not get ZDOTDIR")
        XCTAssertEqual(launch.shellPath, "/usr/bin/fish")
        XCTAssertEqual(launch.arguments, ["-l"])
        XCTAssertEqual(launch.environment["TERM"], "xterm-256color")
    }

    func testDescriptorHighlightStylesAreInjectedIntoZshrc() throws {
        let descriptor = TerminalLaunchDescriptor(
            executable: "/bin/zsh", arguments: [],
            environment: ["TERMY_SYNTAX_HL_DIR": "/opt/hl"],
            workingDirectory: nil, usesZshIntegration: true,
            highlightStyles: ["ZSH_HIGHLIGHT_STYLES[command]='fg=#64D2FF'"])
        let launch = try ShellIntegrationLaunch(descriptor: descriptor, sessionID: UUID())
        defer { launch.cleanup() }
        let zdotdir = try XCTUnwrap(launch.zdotdir)
        let zshrc = try String(contentsOf: zdotdir.appendingPathComponent(".zshrc"), encoding: .utf8)
        XCTAssertTrue(zshrc.contains("ZSH_HIGHLIGHT_STYLES[command]='fg=#64D2FF'"))
        XCTAssertTrue(zshrc.contains("source \"$TERMY_SYNTAX_HL_DIR/zsh-syntax-highlighting.zsh\""))
        XCTAssertEqual(launch.environment["TERMY_SYNTAX_HL_DIR"], "/opt/hl")
    }

    func testDescriptorDefaultsToNoHighlightStyles() {
        let descriptor = TerminalLaunchDescriptor(
            executable: "/bin/zsh", arguments: [], environment: [:],
            workingDirectory: nil, usesZshIntegration: true)
        XCTAssertEqual(descriptor.highlightStyles, [])
    }
}
