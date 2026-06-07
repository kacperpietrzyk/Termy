#if canImport(Darwin)
import XCTest
import Foundation
@testable import TermyCore

/// Real-zsh end-to-end proof of the B4 path-completion fix: spawning the actual
/// `CompletionSidecar` (forkpty + `_main_complete` + the `compadd` shadow) and
/// driving `cd <dir>/<TAB>` must yield candidates whose REPLACEMENT is the full
/// inserted word (`Projects/Nexus`), not the bare segment (`Nexus`). The bare
/// segment was the root cause of `cd Projects/Nexus` collapsing to `cd Projects`.
///
/// Gated by `TERMY_RUN_PTY_TESTS=1` (needs a real PTY + ~2 s zsh boot), exactly
/// like `CompletionSidecarIntegrationTests`.
final class CompletionSidecarPathCompletionTests: XCTestCase {
    override func setUpWithError() throws {
        if ProcessInfo.processInfo.environment["TERMY_RUN_PTY_TESTS"] != "1" {
            throw XCTSkip("Set TERMY_RUN_PTY_TESTS=1 to run real-zsh PTY completion tests")
        }
    }

    private final class EventSink: @unchecked Sendable {
        private var items: [CompletionSidecarResultWatcher.Event] = []
        private let lock = NSLock()
        func append(_ e: CompletionSidecarResultWatcher.Event) { lock.lock(); items.append(e); lock.unlock() }
        var snapshot: [CompletionSidecarResultWatcher.Event] { lock.lock(); defer { lock.unlock() }; return items }
    }

    private func tmpDir(_ tag: String) throws -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("termy-pathcomp-\(tag)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Poll `sink` for a `.result` whose items satisfy `predicate`, up to `timeout`.
    private func awaitResult(
        _ sink: EventSink,
        timeout: TimeInterval,
        where predicate: ([CompletionCandidate]) -> Bool
    ) async -> [CompletionCandidate]? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            for case let .result(_, items) in sink.snapshot where predicate(items) {
                return items
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return nil
    }

    private func spawnReadySidecar(cwd: URL, workDir: URL, zdotdir: URL, sink: EventSink) async throws -> CompletionSidecar {
        let sidecar = try CompletionSidecar.spawn(
            shellPath: "/bin/zsh",
            zdotdir: zdotdir.path,
            extraEnvironment: [:],
            cwd: cwd.path,
            workDir: workDir,
            onEvent: { sink.append($0) }
        )
        // Wait for the boot handshake (zsh init + source bootstrap ~2 s).
        let deadline = Date().addingTimeInterval(12)
        while Date() < deadline {
            if sink.snapshot.contains(where: { if case .boot = $0 { return true } else { return false } }) { break }
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
        return sidecar
    }

    func test_realZsh_pathCompletion_reportsFullWordReplacement() async throws {
        let cwd = try tmpDir("cwd")
        let workDir = try tmpDir("work")
        let zdot = try tmpDir("zdot")
        try "autoload -Uz compinit\ncompinit -u\n".write(
            to: zdot.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)
        // Real subdirectories under cwd: `Projects/{Nexus,Other}`.
        let projects = cwd.appendingPathComponent("Projects")
        try FileManager.default.createDirectory(
            at: projects.appendingPathComponent("Nexus"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: projects.appendingPathComponent("Other"), withIntermediateDirectories: true)
        defer { for d in [cwd, workDir, zdot] { try? FileManager.default.removeItem(at: d) } }

        let sink = EventSink()
        let sidecar = try await spawnReadySidecar(cwd: cwd, workDir: workDir, zdotdir: zdot, sink: sink)
        defer { Task { await sidecar.terminate() } }

        await sidecar.query(buffer: "cd Projects/", cursor: 12, cwd: cwd.path)
        let items = await awaitResult(sink, timeout: 8) { cands in
            cands.contains { $0.title == "Nexus" }
        }
        let cands = try XCTUnwrap(items, "No completion result containing `Nexus` arrived")
        let nexus = try XCTUnwrap(cands.first { $0.title == "Nexus" })
        // THE assertion: replacement is the full inserted word, not the bare segment.
        XCTAssertEqual(nexus.replacement, "Projects/Nexus",
            "compadd shadow must report prefix+segment as the replacement")
        if let other = cands.first(where: { $0.title == "Other" }) {
            XCTAssertEqual(other.replacement, "Projects/Other")
        }
    }

    func test_realZsh_partialSegmentAfterSlash_completesFullWord() async throws {
        let cwd = try tmpDir("cwd-partial")
        let workDir = try tmpDir("work-partial")
        let zdot = try tmpDir("zdot-partial")
        try "autoload -Uz compinit\ncompinit -u\n".write(
            to: zdot.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)
        let projects = cwd.appendingPathComponent("Projects")
        try FileManager.default.createDirectory(
            at: projects.appendingPathComponent("Nexus").appendingPathComponent("Deep"),
            withIntermediateDirectories: true)
        defer { for d in [cwd, workDir, zdot] { try? FileManager.default.removeItem(at: d) } }

        let sink = EventSink()
        let sidecar = try await spawnReadySidecar(cwd: cwd, workDir: workDir, zdotdir: zdot, sink: sink)
        defer { Task { await sidecar.terminate() } }

        // Partial segment AFTER the slash: `cd Projects/Ne` → `Projects/Nexus`.
        await sidecar.query(buffer: "cd Projects/Ne", cursor: 14, cwd: cwd.path)
        let items = await awaitResult(sink, timeout: 8) { $0.contains { $0.title == "Nexus" } }
        let cands = try XCTUnwrap(items, "No result containing `Nexus` for partial segment")
        let nexus = try XCTUnwrap(cands.first { $0.title == "Nexus" })
        XCTAssertEqual(nexus.replacement, "Projects/Nexus",
            "Partial post-slash segment still yields the full-word replacement")

        // Deeper nesting: `cd Projects/Nexus/` → `Projects/Nexus/Deep`.
        await sidecar.query(buffer: "cd Projects/Nexus/", cursor: 18, cwd: cwd.path)
        let deepItems = await awaitResult(sink, timeout: 8) { $0.contains { $0.title == "Deep" } }
        let deepCands = try XCTUnwrap(deepItems, "No result containing `Deep` for deep nesting")
        let deep = try XCTUnwrap(deepCands.first { $0.title == "Deep" })
        XCTAssertEqual(deep.replacement, "Projects/Nexus/Deep",
            "Multi-level path keeps the entire typed prefix in the replacement")
    }

    func test_realZsh_tildeExpansion_keepsTildePrefix() async throws {
        let home = try tmpDir("home")
        let workDir = try tmpDir("work-tilde")
        let zdot = try tmpDir("zdot-tilde")
        try "autoload -Uz compinit\ncompinit -u\n".write(
            to: zdot.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(
            at: home.appendingPathComponent("Workspace"), withIntermediateDirectories: true)
        defer { for d in [home, workDir, zdot] { try? FileManager.default.removeItem(at: d) } }

        let sink = EventSink()
        // HOME drives `~` expansion; point it at our controlled dir.
        let sidecar = try CompletionSidecar.spawn(
            shellPath: "/bin/zsh",
            zdotdir: zdot.path,
            extraEnvironment: ["HOME": home.path],
            cwd: home.path,
            workDir: workDir,
            onEvent: { sink.append($0) }
        )
        defer { Task { await sidecar.terminate() } }
        let deadline = Date().addingTimeInterval(12)
        while Date() < deadline {
            if sink.snapshot.contains(where: { if case .boot = $0 { return true } else { return false } }) { break }
            try? await Task.sleep(nanoseconds: 150_000_000)
        }

        await sidecar.query(buffer: "cd ~/Work", cursor: 9, cwd: home.path)
        let items = await awaitResult(sink, timeout: 8) { $0.contains { $0.title == "Workspace" } }
        let cands = try XCTUnwrap(items, "No `~/Work` result containing `Workspace`")
        let ws = try XCTUnwrap(cands.first { $0.title == "Workspace" })
        // zsh keeps the literal `~/` prefix; the replacement must too so the Swift
        // token `~/Work` is a prefix of it.
        XCTAssertEqual(ws.replacement, "~/Workspace",
            "Tilde-prefixed path keeps `~/` in the replacement word")
    }

    /// Regression guard (code-review finding): some completers (zsh `_path_files`
    /// `-U` branch) pass `compadd -p` with a value that ALREADY embeds `$IPREFIX`.
    /// The shadow must NOT prepend `$IPREFIX` a second time (`X/X/deep/gamma`).
    /// A custom completer reproduces that exact shape deterministically.
    func test_realZsh_pPrefixEmbeddingIPREFIX_noDoubleCount() async throws {
        let cwd = try tmpDir("cwd-dbl")
        let workDir = try tmpDir("work-dbl")
        let zdot = try tmpDir("zdot-dbl")
        // Custom completer for `fakecmd2`: consume `X/` into $IPREFIX via compset,
        // then add a match with `-p "${IPREFIX}deep/"` (embeds IPREFIX, mimicking _path_files -U).
        try """
        autoload -Uz compinit
        compinit -u
        _termy_fakecmd2() { compset -P 'X/'; compadd -p "${IPREFIX}deep/" gamma }
        compdef _termy_fakecmd2 fakecmd2
        """.write(to: zdot.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)
        defer { for d in [cwd, workDir, zdot] { try? FileManager.default.removeItem(at: d) } }

        let sink = EventSink()
        let sidecar = try await spawnReadySidecar(cwd: cwd, workDir: workDir, zdotdir: zdot, sink: sink)
        defer { Task { await sidecar.terminate() } }

        await sidecar.query(buffer: "fakecmd2 X/", cursor: 11, cwd: cwd.path)
        let items = await awaitResult(sink, timeout: 8) { $0.contains { $0.title == "gamma" } }
        let cands = try XCTUnwrap(items, "No result containing `gamma`")
        let gamma = try XCTUnwrap(cands.first { $0.title == "gamma" })
        XCTAssertEqual(gamma.replacement, "X/deep/gamma",
            "IPREFIX must not be double-prepended when the -p value already embeds it")
    }

    func test_realZsh_subcommand_replacementUnchanged() async throws {
        let cwd = try tmpDir("cwd2")
        let workDir = try tmpDir("work2")
        let zdot = try tmpDir("zdot2")
        try "autoload -Uz compinit\ncompinit -u\n".write(
            to: zdot.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)
        defer { for d in [cwd, workDir, zdot] { try? FileManager.default.removeItem(at: d) } }

        let sink = EventSink()
        let sidecar = try await spawnReadySidecar(cwd: cwd, workDir: workDir, zdotdir: zdot, sink: sink)
        defer { Task { await sidecar.terminate() } }

        // `git ` (with trailing space) → subcommands. No prefix, so replacement
        // must equal the bare title (no regression for the common case).
        await sidecar.query(buffer: "git ", cursor: 4, cwd: cwd.path)
        let items = await awaitResult(sink, timeout: 8) { cands in
            cands.contains { $0.title == "status" }
        }
        let cands = try XCTUnwrap(items, "No `git` subcommand result containing `status` arrived")
        let status = try XCTUnwrap(cands.first { $0.title == "status" })
        XCTAssertEqual(status.replacement, "status",
            "Subcommand completion (empty prefix) keeps replacement == title")
    }
}
#endif
