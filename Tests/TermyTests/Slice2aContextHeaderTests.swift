import XCTest
@testable import Termy
import TermyCore

/// Slice-2a: per-block context data (launch cwd + alt-screen flag) and the pure
/// Warp context-header formatter. Mirrors `ShellBlockDurationTests`' faithful
/// ingest-through-the-real-gate style.
@MainActor
final class Slice2aContextHeaderTests: XCTestCase {

    // MARK: - per-block launch cwd

    func testBlockCwdIsTheLaunchDirectory() throws {
        let store = TermyStore(startInitialPTY: false)
        guard let id = store.selectedSessionID,
              let idx = store.sessions.firstIndex(where: { $0.id == id }) else {
            return XCTFail("expected an initial session")
        }
        // Command launches in /work/alpha (cwd at start, before any finish advances it).
        store.sessions[idx].currentWorkingDirectory = "/work/alpha"

        store.ingestShellIntegrationEvents([
            .commandStarted("ls"),
            .output("a\n"),
            .commandFinished(exitCode: 0, workingDirectory: "/work/alpha"),
        ], for: id)

        let block = try XCTUnwrap(store.renderedTerminalCommandBlocks().first)
        XCTAssertEqual(block.contextCwd, "/work/alpha",
                       "block cwd must be the directory the command was launched in")
    }

    func testTwoCommandsCaptureTheirOwnLaunchDirs() throws {
        let store = TermyStore(startInitialPTY: false)
        guard let id = store.selectedSessionID,
              let idx = store.sessions.firstIndex(where: { $0.id == id }) else {
            return XCTFail("expected an initial session")
        }
        store.sessions[idx].currentWorkingDirectory = "/repo/a"

        store.ingestShellIntegrationEvents([
            .commandStarted("first"),
            .commandFinished(exitCode: 0, workingDirectory: "/repo/b"),  // advances cwd → /repo/b
            .commandStarted("second"),
            .commandFinished(exitCode: 0, workingDirectory: "/repo/c"),
        ], for: id)

        let blocks = store.renderedTerminalCommandBlocks()
        XCTAssertEqual(blocks.count, 2)
        XCTAssertEqual(blocks[0].contextCwd, "/repo/a", "first command launched in /repo/a")
        XCTAssertEqual(blocks[1].contextCwd, "/repo/b", "second launched in /repo/b (set by first's finish)")
    }

    func testBlockCwdNilWhenSessionHasNoCwd() throws {
        let store = TermyStore(startInitialPTY: false)
        guard let id = store.selectedSessionID else { return XCTFail("expected a session") }
        // currentWorkingDirectory left nil.
        store.ingestShellIntegrationEvents([
            .commandStarted("pwd"),
            .commandFinished(exitCode: 0, workingDirectory: "/tmp"),
        ], for: id)

        let block = try XCTUnwrap(store.renderedTerminalCommandBlocks().first)
        XCTAssertNil(block.contextCwd, "no launch cwd recorded when the session had none")
    }

    // MARK: - alt-screen flag

    func testAltScreenCommandIsFlagged() throws {
        let store = TermyStore(startInitialPTY: false)
        guard let id = store.selectedSessionID else { return XCTFail("expected a session") }

        store.ingestShellIntegrationEvents([.commandStarted("claude")], for: id)
        store.setTerminalAltScreen(true, for: id)   // claude entered the alt screen
        store.setTerminalAltScreen(false, for: id)  // …and exited
        store.ingestShellIntegrationEvents([
            .commandFinished(exitCode: 0, workingDirectory: "/tmp"),
        ], for: id)

        let block = try XCTUnwrap(store.renderedTerminalCommandBlocks().first)
        XCTAssertTrue(block.enteredAltScreen, "a command that drove the alt screen must be flagged")
    }

    func testPlainCommandIsNotAltScreenFlagged() throws {
        let store = TermyStore(startInitialPTY: false)
        guard let id = store.selectedSessionID else { return XCTFail("expected a session") }

        store.ingestShellIntegrationEvents([
            .commandStarted("echo hi"),
            .output("hi\n"),
            .commandFinished(exitCode: 0, workingDirectory: "/tmp"),
        ], for: id)

        let block = try XCTUnwrap(store.renderedTerminalCommandBlocks().first)
        XCTAssertFalse(block.enteredAltScreen, "a plain command must NOT be flagged as fullscreen")
    }

    // MARK: - trim remap alignment (the Slice-1 review bug class)

    func testContextKeysSurviveTranscriptTrim() throws {
        let localProfile = try XCTUnwrap(ConnectionProfile.local())
        let store = TermyStore(startInitialPTY: false)

        let session = TermySession(
            title: "Local Shell",
            profile: localProfile,
            lines: (0..<9_998).map { TerminalLine(role: .stdout, text: "line \($0)") },
            interactionMode: .rawPTY
        )
        store.sessions = [session]
        store.selectedSessionID = session.id
        guard let idx = store.sessions.firstIndex(where: { $0.id == session.id }) else {
            return XCTFail("session lost")
        }
        store.sessions[idx].currentWorkingDirectory = "/launch/dir"

        // prompt at index 9,998; exit at 9,999 → 10,000 lines, no trim yet.
        store.ingestShellIntegrationEvents([.commandStarted("vim")], for: session.id)
        store.setTerminalAltScreen(true, for: session.id)
        store.setTerminalAltScreen(false, for: session.id)
        store.ingestShellIntegrationEvents([
            .commandFinished(exitCode: 0, workingDirectory: "/tmp"),
        ], for: session.id)

        let originalKey = 9_998
        XCTAssertEqual(store.commandStartCwd(forSession: session.id, startLine: originalKey), "/launch/dir")
        XCTAssertTrue(store.commandUsedAltScreen(forSession: session.id, startLine: originalKey))

        // Trigger trim: a new command appends one prompt line → 10,001 → overflow = 1,
        // keys shift down by 1. (An `.output` would be suppressed post-alt-exit, so
        // `.commandStarted` is used — it also resumes capture.)
        store.ingestShellIntegrationEvents([.commandStarted("next")], for: session.id)

        XCTAssertEqual(store.commandStartCwd(forSession: session.id, startLine: originalKey - 1), "/launch/dir",
                       "cwd key must shift down by the drop count")
        XCTAssertNil(store.commandStartCwd(forSession: session.id, startLine: originalKey),
                     "old unshifted cwd key must be gone")
        XCTAssertTrue(store.commandUsedAltScreen(forSession: session.id, startLine: originalKey - 1),
                      "alt-screen flag must shift with its block")
        XCTAssertFalse(store.commandUsedAltScreen(forSession: session.id, startLine: originalKey),
                       "old unshifted alt-screen key must be gone")
    }

    // MARK: - pure header formatter

    func testHeaderAllFieldsPresent() {
        let header = ShellModuleModel.blockContextHeader(
            node: "node 20", cwd: "/repo", branch: "main", gitStatus: "●2", duration: 4.2)
        XCTAssertEqual(header, "node 20 · /repo · main · ●2 · 4.2s")
    }

    func testHeaderSparseIsCwdAndDuration() {
        // Slice-2a state: node/branch/gitStatus nil until 2c.
        let header = ShellModuleModel.blockContextHeader(
            node: nil, cwd: "/repo", branch: nil, gitStatus: nil, duration: 0.5)
        XCTAssertEqual(header, "/repo · 500ms")
    }

    func testHeaderEmptyWhenNothingPresent() {
        let header = ShellModuleModel.blockContextHeader(
            node: nil, cwd: nil, branch: nil, gitStatus: nil, duration: nil)
        XCTAssertEqual(header, "")
    }

    // MARK: - card body-branch selection (criterion #4)

    func testBodyKindFullscreenForAltScreenNoOutput() {
        XCTAssertEqual(ShellCommandBlockCard.bodyKind(enteredAltScreen: true, hasOutput: false),
                       .fullscreenAnnotation, "claude/vim with empty snapshot → compact annotation")
    }
    func testBodyKindEmptyForPlainNoOutput() {
        XCTAssertEqual(ShellCommandBlockCard.bodyKind(enteredAltScreen: false, hasOutput: false),
                       .empty, "a no-output cd/export must render nothing, NOT 'ran fullscreen'")
    }
    func testBodyKindOutputWins() {
        XCTAssertEqual(ShellCommandBlockCard.bodyKind(enteredAltScreen: false, hasOutput: true), .output)
        XCTAssertEqual(ShellCommandBlockCard.bodyKind(enteredAltScreen: true, hasOutput: true), .output,
                       "real inline output is shown even if the alt flag was set")
    }

    func testHeaderTildeAbbreviatesCwd() {
        let home = NSHomeDirectory()
        let header = ShellModuleModel.blockContextHeader(
            node: nil, cwd: "\(home)/Projects/Termy", branch: nil, gitStatus: nil, duration: nil)
        XCTAssertEqual(header, "~/Projects/Termy")
    }
}
