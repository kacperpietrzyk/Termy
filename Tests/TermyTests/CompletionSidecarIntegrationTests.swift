#if canImport(Darwin)
import XCTest
import Foundation
@testable import TermyCore

/// F-4 bootstrap-script smoke tests. Gated by `TERMY_RUN_PTY_TESTS=1`.
///
/// These tests verify the `SidecarShellScript.template` SOURCES CLEANLY in
/// a real `zsh -i -c '…'` invocation and writes the `__boot__.flag` file.
/// They do NOT exercise `_main_complete` because `zsh -i -c '…'` does not
/// activate `zle` — that requires a real PTY (`pty.fork()` or `openpty`).
/// The end-to-end completion behaviour is proved by:
///   1. The F-4 §0 spike report (`script/f4-spike/REPORT.md`, commit d0ad6b5)
///      which used a Python `pty.fork()` harness and showed `_main_complete`
///      returning 26 git candidates from the same script.
///   2. Task 8's `CompletionSidecar` lifecycle tests, which spawn the real
///      `Process` against a PTY.
///
/// What this file catches that the spike can't: syntax regressions or
/// missing-dependency regressions inside `SidecarShellScript.template`
/// after future edits.
final class CompletionSidecarIntegrationTests: XCTestCase {
    override func setUpWithError() throws {
        if ProcessInfo.processInfo.environment["TERMY_RUN_PTY_TESTS"] != "1" {
            throw XCTSkip("Set TERMY_RUN_PTY_TESTS=1 to run real-zsh smoke tests")
        }
    }

    // ----- harness -----

    private func makeWorkDir() throws -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("termy-f4-smoke-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeZdotdir(rc: String) throws -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("termy-f4-zdot-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try rc.write(
            to: dir.appendingPathComponent(".zshrc"),
            atomically: true,
            encoding: .utf8
        )
        return dir
    }

    private struct SourceResult {
        let exitCode: Int32
        let stdout: String
        let stderr: String
    }

    /// Spawn `zsh -i -c '<inline>'` where `<inline>` sources the bootstrap
    /// script and optionally runs a verification snippet.
    private func sourceBootstrap(
        workDir: URL,
        zdotdir: URL,
        extra: String = ""
    ) throws -> SourceResult {
        let bootstrapPath = workDir.appendingPathComponent("bootstrap.zsh")
        try SidecarShellScript.template.write(
            to: bootstrapPath, atomically: true, encoding: .utf8
        )
        let inline = """
        export TERMY_SIDECAR_DIR='\(workDir.path)'
        source '\(bootstrapPath.path)'
        \(extra)
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-i", "-c", inline]
        process.environment = [
            "ZDOTDIR": zdotdir.path,
            "TERMY_SIDECAR": "1",
            "PATH": ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin",
            "HOME": NSHomeDirectory(),
            "PROMPT": "",
            "RPROMPT": ""
        ]
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        return SourceResult(
            exitCode: process.terminationStatus,
            stdout: String(data: outData, encoding: .utf8) ?? "",
            stderr: String(data: errData, encoding: .utf8) ?? ""
        )
    }

    // ----- tests -----

    /// Sourcing `SidecarShellScript.template` against a minimal `.zshrc`
    /// must complete with exit 0 — no syntax errors, no missing functions.
    func test_bootstrap_sourcesCleanly_withCompinitRc() throws {
        let workDir = try makeWorkDir()
        let zdotdir = try makeZdotdir(rc: """
        autoload -Uz compinit
        compinit -u
        """)
        defer {
            try? FileManager.default.removeItem(at: workDir)
            try? FileManager.default.removeItem(at: zdotdir)
        }
        let result = try sourceBootstrap(workDir: workDir, zdotdir: zdotdir)
        XCTAssertEqual(
            result.exitCode, 0,
            "Bootstrap script must source cleanly; stderr: \(result.stderr.prefix(400))"
        )
    }

    /// The `.zshrc` does NOT call `compinit`. The bootstrap's defensive
    /// `compinit` guard (`if (( ${+_comps[git]} == 0 ))…`) must take over
    /// and the script must still source cleanly.
    func test_bootstrap_sourcesCleanly_withoutCompinitInRc() throws {
        let workDir = try makeWorkDir()
        let zdotdir = try makeZdotdir(rc: "# empty .zshrc — defensive compinit handles it\n")
        defer {
            try? FileManager.default.removeItem(at: workDir)
            try? FileManager.default.removeItem(at: zdotdir)
        }
        let result = try sourceBootstrap(workDir: workDir, zdotdir: zdotdir)
        XCTAssertEqual(
            result.exitCode, 0,
            "Bootstrap must self-recover when .zshrc has no compinit; stderr: \(result.stderr.prefix(400))"
        )
    }

    /// `__boot__.flag` must land in `$TERMY_SIDECAR_DIR` after sourcing.
    /// This is the ready-handshake signal the actor relies on.
    func test_bootstrap_writesBootFlag() throws {
        let workDir = try makeWorkDir()
        let zdotdir = try makeZdotdir(rc: """
        autoload -Uz compinit
        compinit -u
        """)
        defer {
            try? FileManager.default.removeItem(at: workDir)
            try? FileManager.default.removeItem(at: zdotdir)
        }
        let result = try sourceBootstrap(workDir: workDir, zdotdir: zdotdir)
        XCTAssertEqual(result.exitCode, 0)
        let flagURL = workDir.appendingPathComponent("__boot__.flag")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: flagURL.path),
            "Bootstrap must write __boot__.flag at \(flagURL.path); stderr: \(result.stderr.prefix(400))"
        )
    }

    /// `_zsh_autosuggest_disable` is called defensively. When the
    /// autosuggestions plugin is absent, the call must NOT abort sourcing.
    func test_bootstrap_autosuggestionsDisable_noErrorWhenAbsent() throws {
        let workDir = try makeWorkDir()
        let zdotdir = try makeZdotdir(rc: "# no autosuggestions plugin loaded\n")
        defer {
            try? FileManager.default.removeItem(at: workDir)
            try? FileManager.default.removeItem(at: zdotdir)
        }
        let result = try sourceBootstrap(workDir: workDir, zdotdir: zdotdir)
        XCTAssertEqual(result.exitCode, 0)
        // The defensive `2>/dev/null` should swallow the unknown-command error;
        // stderr must NOT contain a `_zsh_autosuggest_disable: command not found` line.
        XCTAssertFalse(
            result.stderr.contains("_zsh_autosuggest_disable: command not found"),
            "Defensive call must swallow missing-function error; stderr: \(result.stderr.prefix(400))"
        )
    }

    /// After sourcing, the widget must be REGISTERED with zle (visible via
    /// `zle -l`). zsh's `zle -l` works in `-i -c` mode even when the line
    /// editor itself is not active.
    func test_bootstrap_registersTermyCaptureWidget() throws {
        let workDir = try makeWorkDir()
        let zdotdir = try makeZdotdir(rc: """
        autoload -Uz compinit
        compinit -u
        """)
        defer {
            try? FileManager.default.removeItem(at: workDir)
            try? FileManager.default.removeItem(at: zdotdir)
        }
        let result = try sourceBootstrap(
            workDir: workDir, zdotdir: zdotdir,
            extra: "zle -l | grep -q _termy_capture && echo WIDGET_OK || echo WIDGET_MISSING"
        )
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(
            result.stdout.contains("WIDGET_OK"),
            "_termy_capture widget must be registered via zle -C; got stdout: \(result.stdout)"
        )
    }

    /// After sourcing, the `compadd` shadow MUST be a function (per
    /// advisor finding: alias would not intercept builtin calls).
    func test_bootstrap_compaddIsFunctionShadow() throws {
        let workDir = try makeWorkDir()
        let zdotdir = try makeZdotdir(rc: """
        autoload -Uz compinit
        compinit -u
        """)
        defer {
            try? FileManager.default.removeItem(at: workDir)
            try? FileManager.default.removeItem(at: zdotdir)
        }
        let result = try sourceBootstrap(
            workDir: workDir, zdotdir: zdotdir,
            extra: "whence -w compadd"
        )
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(
            result.stdout.contains("compadd: function"),
            "compadd must be shadowed as a function, not alias; got: \(result.stdout)"
        )
    }
}
#endif
