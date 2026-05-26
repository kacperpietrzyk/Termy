import XCTest
@testable import Termy
@testable import TermyCore

@MainActor
final class FB1SyntaxHighlightWiringTests: XCTestCase {
    func testZshDescriptorCarriesThemeStylesAndResourceDir() {
        let store = TermyStore(startInitialPTY: false)
        let theme = store.terminalTheme
        let descriptor = store.localZshLaunchDescriptor(
            executable: "/bin/zsh", arguments: [],
            baseEnvironment: ["TERM": "ignored"],
            theme: theme,
            syntaxHighlightDir: "/tmp/zsh-syntax-highlighting",
            usesZshIntegration: true)
        XCTAssertEqual(descriptor.highlightStyles, SyntaxHighlightStyleMap.styles(for: theme))
        XCTAssertEqual(descriptor.environment["TERMY_SYNTAX_HL_DIR"], "/tmp/zsh-syntax-highlighting")
        XCTAssertEqual(descriptor.environment["TERM"], "xterm-256color")
    }

    func testNonZshDescriptorHasNoStylesOrResourceDir() {
        let store = TermyStore(startInitialPTY: false)
        let descriptor = store.localZshLaunchDescriptor(
            executable: "/bin/bash", arguments: ["--noprofile", "--norc"],
            baseEnvironment: [:],
            theme: store.terminalTheme,
            syntaxHighlightDir: "/tmp/zsh-syntax-highlighting",
            usesZshIntegration: false)
        XCTAssertEqual(descriptor.highlightStyles, [])
        XCTAssertNil(descriptor.environment["TERMY_SYNTAX_HL_DIR"])
    }
}
