import XCTest
@testable import TermyCore
@testable import Termy

@MainActor
final class SpecHighlightWiringTests: XCTestCase {
    // MARK: - Step 3: ShellIntegrationScript registers spec layer and fails open

    func testScriptRegistersSpecLayerAndFailsOpen() {
        let s = ShellIntegrationScript.zsh(highlightStyles: [],
                                           specStylesBlock: SpecHighlightPalette.default.zshStylesBlock())
        XCTAssertTrue(s.contains("ZSH_HIGHLIGHT_HIGHLIGHTERS=(main termy_spec)"))
        XCTAssertTrue(s.contains("typeset -gA TERMY_SPEC_STYLES"))
        XCTAssertTrue(s.contains(#"[[ -n "$TERMY_SPEC_DIR" && -r "$TERMY_SPEC_DIR/termy-spec-highlighter.zsh" ]]"#))
        XCTAssertTrue(s.contains(#"source "$TERMY_SPEC_DIR/termy-spec-highlighter.zsh""#))
    }

    // MARK: - Step 5: TermyStore carries TERMY_SPEC_DIR (env-only) + gated palette block

    func testDescriptorExportsSpecDirEnvAndPaletteBlock() {
        let store = TermyStore(startInitialPTY: false)
        let descriptor = store.localZshLaunchDescriptor(
            executable: "/bin/zsh", arguments: [],
            baseEnvironment: ["TERM": "ignored"],
            theme: store.terminalTheme,
            syntaxHighlightDir: "/tmp/zsh-syntax-highlighting",
            specDir: "/tmp/specs",
            usesZshIntegration: true)
        // $TERMY_SPEC_DIR is env-only (mirrors TERMY_SYNTAX_HL_DIR) — no separate descriptor field.
        XCTAssertEqual(descriptor.environment["TERMY_SPEC_DIR"], "/tmp/specs")
        XCTAssertFalse(descriptor.specStylesBlock.isEmpty)
        XCTAssertTrue(descriptor.specStylesBlock.contains("TERMY_SPEC_STYLES"))
    }

    func testPaletteBlockGatedOnResolvedSpecDir() {
        // No spec dir resolved → don't emit TERMY_SPEC_STYLES (highlighter never sources).
        let store = TermyStore(startInitialPTY: false)
        let descriptor = store.localZshLaunchDescriptor(
            executable: "/bin/zsh", arguments: [],
            baseEnvironment: ["TERM": "ignored"],
            theme: store.terminalTheme,
            syntaxHighlightDir: "/tmp/zsh-syntax-highlighting",
            specDir: nil,
            usesZshIntegration: true)
        XCTAssertNil(descriptor.environment["TERMY_SPEC_DIR"])
        XCTAssertTrue(descriptor.specStylesBlock.isEmpty)
    }

    func testNonZshDescriptorHasNoSpecDir() {
        let store = TermyStore(startInitialPTY: false)
        let descriptor = store.localZshLaunchDescriptor(
            executable: "/bin/bash", arguments: ["--noprofile", "--norc"],
            baseEnvironment: [:],
            theme: store.terminalTheme,
            syntaxHighlightDir: "/tmp/zsh-syntax-highlighting",
            specDir: "/tmp/specs",
            usesZshIntegration: false)
        XCTAssertNil(descriptor.environment["TERMY_SPEC_DIR"])
        XCTAssertTrue(descriptor.specStylesBlock.isEmpty)
    }
}
