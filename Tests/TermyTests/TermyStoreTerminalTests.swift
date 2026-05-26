import XCTest
@testable import Termy
import TermyCore
import TermyRDP

/// Records the descriptors the store hands to its `rdpConnect` factory. Post-
/// cutover the test deliberately throws AFTER capturing the descriptor so the
/// store never reaches `FreeRDPSession.start()` — `start()` would try to TLS-
/// handshake a real RDP server and hang the test. The store's failure path
/// (`failLiveRDPConnection`) handles the thrown error gracefully (sets the
/// reconnect plan, surfaces the error), which is the exact production
/// resilience contract.
private struct CommandCenterRDPConnectProbeError: Error {}

private actor CommandCenterRDPConnectProbe {
    private(set) var descriptors: [RDPSessionDescriptor] = []

    func connect(descriptor: RDPSessionDescriptor) async throws -> FreeRDPSession {
        descriptors.append(descriptor)
        throw CommandCenterRDPConnectProbeError()
    }

    func observedHosts() -> [String] {
        descriptors.map(\.host)
    }
}

final class TermyStoreTerminalTests: XCTestCase {
    @MainActor
    func testTerminalTranscriptIsBoundedWhenAppendingNewLines() throws {
        let localProfile = try XCTUnwrap(ConnectionProfile.local())
        let store = TermyStore(startInitialPTY: false)
        let session = TermySession(
            title: "Local Shell",
            profile: localProfile,
            lines: (0..<10_050).map { TerminalLine(role: .stdout, text: "line \($0)") },
            interactionMode: .rawPTY
        )
        store.sessions = [session]
        store.selectedSessionID = session.id

        store.ingestShellIntegrationEvents([.output("x\n")], for: session.id)

        let lines = try XCTUnwrap(store.selectedSession?.lines)
        XCTAssertEqual(lines.count, 10_000)
        XCTAssertEqual(lines.first?.text, "line 51")
    }

    @MainActor
    func testTerminalTranscriptTrimAdjustsSelectedAndFoldedCommandBlockOffsets() throws {
        let localProfile = try XCTUnwrap(ConnectionProfile.local())
        let store = TermyStore(startInitialPTY: false)
        let session = TermySession(
            title: "Local Shell",
            profile: localProfile,
            lines: (0..<10_000).map { TerminalLine(role: .stdout, text: "line \($0)") },
            interactionMode: .rawPTY
        )
        store.sessions = [session]
        store.selectedSessionID = session.id
        store.selectedTerminalBlockStartLine = 100
        store.foldedTerminalBlockStartLines = [20, 200]

        store.ingestShellIntegrationEvents([.output("x\n")], for: session.id)

        XCTAssertEqual(store.selectedTerminalBlockStartLine, 99)
        XCTAssertEqual(store.foldedTerminalBlockStartLines, [19, 199])
    }

    @MainActor
    func testGitStatusBarSummaryShowsBranchDivergenceAndDirtyCount() {
        let store = TermyStore(startInitialPTY: false)
        store.selectedGitBranch = "main"
        store.gitDivergence = GitDivergence(ahead: 2, behind: 1)
        store.gitStatus = " M Sources/App.swift\n?? README.md"

        XCTAssertEqual(store.gitStatusBarSummary, "git: main 2 changes +2 -1")
    }

    @MainActor
    func testCopySelectedTerminalBlockOutputUsesCurrentSelection() throws {
        let localProfile = try XCTUnwrap(ConnectionProfile.local())
        let store = TermyStore(startInitialPTY: false)
        let session = TermySession(
            title: "Local Shell",
            profile: localProfile,
            lines: [
                TerminalLine(role: .prompt, text: "$ first"),
                TerminalLine(role: .stdout, text: "first output\n"),
                TerminalLine(role: .system, text: "Exit 0"),
                TerminalLine(role: .prompt, text: "$ second"),
                TerminalLine(role: .stdout, text: "second output\n"),
                TerminalLine(role: .system, text: "Exit 0")
            ]
        )
        store.sessions = [session]
        store.selectedSessionID = session.id
        store.selectedTerminalBlockStartLine = 0

        store.copySelectedCommandOutput()

        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "first output\n")
        XCTAssertEqual(store.statusMessage, "Copied output for first.")
    }

    @MainActor
    func testCommandCenterActionCopiesSelectedTerminalBlockOutput() throws {
        let localProfile = try XCTUnwrap(ConnectionProfile.local())
        let store = TermyStore(startInitialPTY: false)
        let session = TermySession(
            title: "Local Shell",
            profile: localProfile,
            lines: [
                TerminalLine(role: .prompt, text: "$ swift test"),
                TerminalLine(role: .stdout, text: "passed\n"),
                TerminalLine(role: .system, text: "Exit 0")
            ]
        )
        store.sessions = [session]
        store.selectedSessionID = session.id
        store.selectedTerminalBlockStartLine = 0

        store.perform("copy-selected-command-output")

        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "passed\n")
        XCTAssertEqual(store.statusMessage, "Copied output for swift test.")
    }

    @MainActor
    func testCommandCenterActionsNavigateAndFoldTerminalBlocks() throws {
        let localProfile = try XCTUnwrap(ConnectionProfile.local())
        let store = TermyStore(startInitialPTY: false)
        let session = TermySession(
            title: "Local Shell",
            profile: localProfile,
            lines: [
                TerminalLine(role: .prompt, text: "$ first"),
                TerminalLine(role: .stdout, text: "one\n"),
                TerminalLine(role: .system, text: "Exit 0"),
                TerminalLine(role: .prompt, text: "$ second"),
                TerminalLine(role: .stdout, text: "two\n"),
                TerminalLine(role: .system, text: "Exit 0")
            ]
        )
        store.sessions = [session]
        store.selectedSessionID = session.id

        store.perform("terminal-next-command-block")
        XCTAssertEqual(store.selectedTerminalBlockStartLine, 0)

        store.perform("terminal-next-command-block")
        XCTAssertEqual(store.selectedTerminalBlockStartLine, 3)

        store.perform("terminal-previous-command-block")
        XCTAssertEqual(store.selectedTerminalBlockStartLine, 0)

        store.perform("terminal-toggle-command-block-fold")
        XCTAssertEqual(store.foldedTerminalBlockStartLines, [0])
        XCTAssertEqual(store.statusMessage, "Selected command block.")

        store.perform("terminal-toggle-command-block-fold")
        XCTAssertTrue(store.foldedTerminalBlockStartLines.isEmpty)
        XCTAssertEqual(store.statusMessage, "Selected command block.")
    }

    @MainActor
    func testCommandCenterActionCopiesLastTerminalBlockOutput() throws {
        let localProfile = try XCTUnwrap(ConnectionProfile.local())
        let store = TermyStore(startInitialPTY: false)
        let session = TermySession(
            title: "Local Shell",
            profile: localProfile,
            lines: [
                TerminalLine(role: .prompt, text: "$ first"),
                TerminalLine(role: .stdout, text: "one\n"),
                TerminalLine(role: .system, text: "Exit 0"),
                TerminalLine(role: .prompt, text: "$ second"),
                TerminalLine(role: .stdout, text: "two\n"),
                TerminalLine(role: .system, text: "Exit 0")
            ]
        )
        store.sessions = [session]
        store.selectedSessionID = session.id

        store.perform("copy-last-command-output")

        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "two\n")
        XCTAssertEqual(store.statusMessage, "Copied output for second.")
    }

    @MainActor
    func testTerminalBlocksOutputModeBuildsCommandCardsFromTranscript() throws {
        let localProfile = try XCTUnwrap(ConnectionProfile.local())
        let store = TermyStore(startInitialPTY: false)
        let session = TermySession(
            title: "Local Shell",
            profile: localProfile,
            lines: [
                TerminalLine(role: .system, text: "Welcome"),
                TerminalLine(role: .prompt, text: "$ make test"),
                TerminalLine(role: .stdout, text: "Running tests\n"),
                TerminalLine(role: .stderr, text: "warning: slow test\n"),
                TerminalLine(role: .system, text: "Exit 1"),
                TerminalLine(role: .prompt, text: "$ git status"),
                TerminalLine(role: .stdout, text: "working tree clean\n")
            ]
        )
        store.sessions = [session]
        store.selectedSessionID = session.id
        store.terminalOutputMode = "blocks"
        store.selectedTerminalBlockStartLine = 1
        store.foldedTerminalBlockStartLines = [5]

        let cards = store.renderedTerminalCommandBlocks()

        XCTAssertEqual(cards.count, 2)
        XCTAssertEqual(cards[0].command, "make test")
        XCTAssertEqual(cards[0].outputLines.map(\.text), ["Running tests\n", "warning: slow test\n"])
        XCTAssertEqual(cards[0].exitCode, 1)
        XCTAssertTrue(cards[0].isSelected)
        XCTAssertFalse(cards[0].isFolded)
        XCTAssertEqual(cards[1].command, "git status")
        XCTAssertEqual(cards[1].outputLines.map(\.text), ["working tree clean\n"])
        XCTAssertNil(cards[1].exitCode)
        XCTAssertFalse(cards[1].isSelected)
        XCTAssertTrue(cards[1].isFolded)
    }

    @MainActor
    func testCommandCenterActionsSwitchTerminalOutputMode() {
        let store = TermyStore(startInitialPTY: false)

        store.perform("set-terminal-output-blocks")
        XCTAssertEqual(store.terminalOutputMode, "blocks")
        XCTAssertEqual(store.statusMessage, "Terminal output uses command blocks.")

        store.perform("set-terminal-output-stream")
        XCTAssertEqual(store.terminalOutputMode, "stream")
        XCTAssertEqual(store.statusMessage, "Terminal output uses classic stream.")
    }

    @MainActor
    func testSelectedTerminalOutputModeFollowsActiveProfile() throws {
        let streamProfile = ConnectionProfile.local(name: "Stream", terminalOutputMode: .stream)
        let blockProfile = ConnectionProfile.local(name: "Blocks", terminalOutputMode: .blocks)
        let store = TermyStore(startInitialPTY: false)
        let streamSession = TermySession(title: "Stream", profile: streamProfile)
        let blockSession = TermySession(title: "Blocks", profile: blockProfile)
        store.sessions = [streamSession, blockSession]

        store.terminalOutputMode = "stream"
        store.selectedSessionID = streamSession.id
        XCTAssertEqual(store.selectedTerminalOutputModeValue, .stream)

        store.selectedSessionID = blockSession.id
        XCTAssertEqual(store.selectedTerminalOutputModeValue, .blocks)

        store.perform("set-terminal-output-stream")
        XCTAssertEqual(store.selectedTerminalOutputModeValue, .stream)
        XCTAssertEqual(store.selectedSession?.profile.terminalOutputMode, .stream)
    }

    @MainActor
    func testCommandCenterSearchIncludesSavedSSHAndRDPProfiles() {
        let store = TermyStore(startInitialPTY: false)
        let ssh = ConnectionProfile.ssh(
            name: "Production Bastion",
            host: "bastion.prod.example.test",
            user: "deploy",
            identity: .keychain("ssh.prod"),
            groupPath: "Production/Bastions"
        )
        let rdp = ConnectionProfile.rdp(
            name: "Windows Build VM",
            host: "win-build.example.test",
            user: "builder",
            gateway: "gateway.example.test",
            credential: .keychain("rdp.build"),
            groupPath: "Windows"
        )
        store.profiles = [.local(), ssh, rdp]

        store.commandQuery = "prod bastion"
        XCTAssertEqual(store.filteredCommandCenterItems.first?.id, "profile-\(ssh.id.uuidString)")
        XCTAssertEqual(store.filteredCommandCenterItems.first?.title, "Production Bastion")
        XCTAssertEqual(store.filteredCommandCenterItems.first?.subtitle, "SSH deploy@bastion.prod.example.test - Production/Bastions")

        store.commandQuery = "win gateway"
        XCTAssertEqual(store.filteredCommandCenterItems.first?.id, "profile-\(rdp.id.uuidString)")
        XCTAssertEqual(store.filteredCommandCenterItems.first?.title, "Windows Build VM")
        XCTAssertEqual(store.filteredCommandCenterItems.first?.subtitle, "RDP builder@win-build.example.test via gateway.example.test - Windows")
    }

    @MainActor
    func testCommandCenterPerformsSavedRDPProfileSelection() async throws {
        let probe = CommandCenterRDPConnectProbe()
        let profile = ConnectionProfile.rdp(
            name: "Windows Build VM",
            host: "win-build.example.test",
            user: "builder",
            gateway: nil,
            credential: .keychain("rdp.build")
        )
        let store = TermyStore(
            startInitialPTY: false,
            rdpConnect: { descriptor in
                try await probe.connect(descriptor: descriptor)
            }
        )
        defer { store.shutdown() }
        store.profiles = [.local(), profile]
        store.isCommandCenterPresented = true
        store.commandQuery = "build vm"

        let item = try XCTUnwrap(store.filteredCommandCenterItems.first)
        store.performCommandCenterItem(item)

        let session = try XCTUnwrap(store.selectedSession)
        XCTAssertEqual(session.profile.id, profile.id)
        XCTAssertFalse(store.isCommandCenterPresented)
        for _ in 0..<20 where await probe.observedHosts().isEmpty {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        let observedHosts = await probe.observedHosts()
        XCTAssertEqual(observedHosts, ["win-build.example.test"])
    }

    @MainActor
    func testCopyVisibleTerminalScreenCopiesRegisteredSwiftTermProviderText() throws {
        let store = TermyStore(startInitialPTY: false)
        let id = try XCTUnwrap(store.selectedSessionID)
        let pb = NSPasteboard.general
        let saved = pb.string(forType: .string)
        defer { pb.clearContents(); if let saved { pb.setString(saved, forType: .string) } }
        store.registerTerminalScreenTextProvider({ "alpha\nbeta\n\n" }, for: id)
        store.copyVisibleTerminalScreen()
        XCTAssertEqual(pb.string(forType: .string), "alpha\nbeta",
                       "must copy the active session's SwiftTerm screen text, trailing blank rows trimmed")
        XCTAssertEqual(store.statusMessage, "Copied terminal screen.")
    }

    @MainActor
    func testCopyVisibleTerminalScreenWithNoProviderReportsNothingToCopy() throws {
        let store = TermyStore(startInitialPTY: false)
        store.copyVisibleTerminalScreen()
        XCTAssertEqual(store.statusMessage, "No terminal screen content to copy.")
    }
}
