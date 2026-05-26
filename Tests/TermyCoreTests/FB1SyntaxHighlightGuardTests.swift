import XCTest
@testable import TermyCore

/// FB-1 structural guard (mirrors the M4/M5 dependency-boundary gates): the vendored
/// zsh-syntax-highlighting must stay pinned, minimized, and offline; the generated .zshrc
/// must fail-open on a missing resource.
final class FB1SyntaxHighlightGuardTests: XCTestCase {
    /// Repo root = this file is at <root>/Tests/TermyCoreTests/FB1SyntaxHighlightGuardTests.swift
    var root: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    func testVendoredEntrypointAndMainHighlighterPresent() {
        let fm = FileManager.default
        let base = root.appendingPathComponent("vendor/zsh-syntax-highlighting")
        XCTAssertTrue(fm.fileExists(atPath: base.appendingPathComponent("zsh-syntax-highlighting.zsh").path))
        XCTAssertTrue(fm.fileExists(atPath: base.appendingPathComponent("highlighters/main/main-highlighter.zsh").path))
        XCTAssertTrue(fm.fileExists(atPath: base.appendingPathComponent("LICENSE.md").path))
    }

    func testPinFileRecordsTagAndSha() throws {
        let pins = try String(contentsOf: root.appendingPathComponent("vendor/zsh-syntax-highlighting/PINS"), encoding: .utf8)
        XCTAssertTrue(pins.contains("TAG     0.8.0"))
        XCTAssertTrue(pins.range(of: #"SHA\s+[0-9a-f]{40}"#, options: .regularExpression) != nil, "PINS must record a 40-char SHA")
    }

    func testMinimizedNoExtraHighlightersOrTests() {
        let fm = FileManager.default
        let h = root.appendingPathComponent("vendor/zsh-syntax-highlighting/highlighters")
        for excluded in ["brackets", "pattern", "regexp", "cursor", "line", "root"] {
            XCTAssertFalse(fm.fileExists(atPath: h.appendingPathComponent(excluded).path),
                           "minimized: \(excluded) highlighter must not be vendored")
        }
        XCTAssertFalse(fm.fileExists(atPath: root.appendingPathComponent("vendor/zsh-syntax-highlighting/highlighters/main/test-data").path))
    }

    func testThirdpartyAuditPresent() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("THIRDPARTY-SYNTAX-HL.md").path))
    }

    func testGeneratedZshrcFailsOpenWhenResourceMissing() {
        // The source is guarded on $TERMY_SYNTAX_HL_DIR + readability, so an absent resource
        // never blocks shell start.
        let s = ShellIntegrationScript.zsh()
        XCTAssertTrue(s.contains(#"[[ -n "$TERMY_SYNTAX_HL_DIR" && -r "$TERMY_SYNTAX_HL_DIR/zsh-syntax-highlighting.zsh" ]]"#))
    }

    func testRealZshSourcesHighlighterAndKeepsBufferPublishHook() throws {
        guard FileManager.default.fileExists(atPath: "/bin/zsh") else {
            throw XCTSkip("zsh not available")
        }
        let zdotdir = FileManager.default.temporaryDirectory
            .appendingPathComponent("fb1-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: zdotdir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: zdotdir) }
        let styles = SyntaxHighlightStyleMap.styles(for: TerminalThemeCatalog.builtIn.defaultTheme)
        // Append a probe that prints the version + whether the buffer-publish fn survived.
        let rc = ShellIntegrationScript.zsh(highlightStyles: styles)
            + "\nprint -r -- \"FB1_VER=$ZSH_HIGHLIGHT_VERSION\""
            + "\nprint -r -- \"FB1_PUBLISH=${+functions[termy_buffer_publish]}\""
            + "\nexit\n"
        try rc.write(to: zdotdir.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-i"]
        var env = ProcessInfo.processInfo.environment
        env["ZDOTDIR"] = zdotdir.path
        env["TERM"] = "xterm-256color"
        env["TERMY_SYNTAX_HL_DIR"] = root.appendingPathComponent("vendor/zsh-syntax-highlighting").path
        proc.environment = env
        let outPipe = Pipe(); proc.standardOutput = outPipe; proc.standardError = Pipe()
        try proc.run(); proc.waitUntilExit()
        let s = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        XCTAssertTrue(s.contains("FB1_VER=0.8.0"), "z-s-h must source under the generated .zshrc; got: \(s)")
        XCTAssertTrue(s.contains("FB1_PUBLISH=1"), "F-1 termy_buffer_publish must still be defined")
        XCTAssertEqual(proc.terminationStatus, 0, "shell must start cleanly (fail-open contract)")
    }
}
