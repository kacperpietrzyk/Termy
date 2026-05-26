import XCTest
@testable import Termy
import TermyCore

@MainActor
final class TermyStoreSessionRestoreTests: XCTestCase {
    private func temporaryRestoreStore() throws -> SessionRestoreStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-session-restore-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return SessionRestoreStore(directoryURL: directory)
    }

    private func removeTemporaryRestoreStore(_ store: SessionRestoreStore) {
        try? FileManager.default.removeItem(at: store.directoryURL)
    }

    private func localDescriptor(workingDirectory: String? = nil) -> TerminalLaunchDescriptor {
        TerminalLaunchDescriptor(
            executable: "/bin/zsh",
            arguments: ["-l"],
            environment: [:],
            workingDirectory: workingDirectory,
            usesZshIntegration: true
        )
    }

    private func descriptor(
        executable: String,
        arguments: [String],
        workingDirectory: String?,
        environment: [String: String] = [:]
    ) -> TerminalLaunchDescriptor {
        TerminalLaunchDescriptor(
            executable: executable,
            arguments: arguments,
            environment: environment,
            workingDirectory: workingDirectory,
            usesZshIntegration: false
        )
    }

    private func seedSnapshot(
        in store: SessionRestoreStore,
        selectedSessionID: UUID = UUID()
    ) throws {
        let entry = SessionRestoreEntry(
            id: selectedSessionID,
            title: "Previous Shell",
            kind: .localPTY,
            profileReference: .local,
            workingDirectory: "/tmp/previous",
            launch: .localShell(shellKind: "zsh", executable: "/bin/zsh", arguments: ["-l"]),
            scrollback: [RestoredTerminalLine(role: .stdout, text: "previous")],
            scrollbackBytes: 0,
            lastExitCode: 0,
            capturedAt: Date(timeIntervalSince1970: 1)
        )
        try store.save(.makeBounded(
            capturedAt: Date(timeIntervalSince1970: 1),
            selectedSessionID: selectedSessionID,
            paneTree: "terminal",
            focusedPane: .terminal,
            activePanel: nil,
            sessions: [entry]
        ))
    }

    func testCleanStartupDoesNotAutoRestoreExistingSnapshot() throws {
        let restoreStore = try temporaryRestoreStore()
        defer { removeTemporaryRestoreStore(restoreStore) }
        try seedSnapshot(in: restoreStore)

        let store = TermyStore(startInitialPTY: false, sessionRestoreStore: restoreStore)

        XCTAssertTrue(store.hasRestorableSession)
        XCTAssertEqual(store.sessionRestoreStatus, "Previous session available.")
        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.sessions.first?.title, "Local Shell")
    }

    func testStartupIgnoresEmptyLegacySnapshot() throws {
        let restoreStore = try temporaryRestoreStore()
        defer { removeTemporaryRestoreStore(restoreStore) }
        try restoreStore.save(.makeBounded(
            capturedAt: Date(timeIntervalSince1970: 2),
            selectedSessionID: nil,
            paneTree: "terminal",
            focusedPane: .terminal,
            activePanel: nil,
            sessions: []
        ))

        let store = TermyStore(startInitialPTY: false, sessionRestoreStore: restoreStore)
        store.commandQuery = "restore"

        XCTAssertFalse(store.hasRestorableSession)
        XCTAssertNil(store.sessionRestoreStatus)
        XCTAssertFalse(store.filteredCommandCenterItems.contains { item in
            if case .action(let action) = item {
                return action.id == "restore-last-session"
            }
            return false
        })
    }

    func testCaptureWritesBoundedLocalSessionSnapshot() throws {
        let restoreStore = try temporaryRestoreStore()
        defer { removeTemporaryRestoreStore(restoreStore) }
        let store = TermyStore(startInitialPTY: false, sessionRestoreStore: restoreStore)
        let session = try XCTUnwrap(store.sessions.first)
        store.sessions[0].lines = (0..<2_050).map { TerminalLine(role: .stdout, text: "line-\($0)") }
        store.sessions[0].currentWorkingDirectory = "/tmp/project"
        store.registerTerminalLaunch(localDescriptor(workingDirectory: "/tmp/project"), for: session.id)

        try store.captureSessionRestoreSnapshotNow(capturedAt: Date(timeIntervalSince1970: 10))

        let snapshot = try XCTUnwrap(try restoreStore.load())
        XCTAssertEqual(snapshot.selectedSessionID, session.id)
        XCTAssertEqual(snapshot.sessions.count, 1)
        XCTAssertEqual(snapshot.sessions[0].workingDirectory, "/tmp/project")
        XCTAssertEqual(snapshot.sessions[0].scrollback.count, 2_000)
        XCTAssertEqual(snapshot.sessions[0].scrollback.first?.text, "line-50")
        XCTAssertTrue(store.hasRestorableSession)
        XCTAssertEqual(store.sessionRestoreStatus, "Saved previous session context.")
    }

    func testCaptureIncludesRDPPlaceholderWithoutLaunchDescriptor() throws {
        let restoreStore = try temporaryRestoreStore()
        defer { removeTemporaryRestoreStore(restoreStore) }
        let profile = ConnectionProfile.rdp(
            name: "Windows Build VM",
            host: "win-build.example.test",
            user: "builder",
            gateway: nil,
            credential: .keychain("rdp.build")
        )
        let session = TermySession(
            title: "Windows Build VM",
            profile: profile,
            lines: [TerminalLine(role: .system, text: "RDP session prepared.")],
            interactionMode: .commandLine
        )
        let store = TermyStore(startInitialPTY: false, sessionRestoreStore: restoreStore)
        store.sessions = [session]
        store.selectedSessionID = session.id

        try store.captureSessionRestoreSnapshotNow(capturedAt: Date(timeIntervalSince1970: 20))

        let snapshot = try XCTUnwrap(try restoreStore.load())
        XCTAssertEqual(snapshot.sessions.first?.kind, .rdpPlaceholder)
        XCTAssertEqual(snapshot.sessions.first?.scrollback, [])
        XCTAssertNil(store.terminalLaunchDescriptor(for: session.id))
    }

    func testCaptureWritesSSHSessionSnapshotWithoutDescriptorEnvironment() throws {
        let restoreStore = try temporaryRestoreStore()
        defer { removeTemporaryRestoreStore(restoreStore) }
        let profile = ConnectionProfile.ssh(
            name: "Production Bastion",
            host: "bastion.prod.example.test",
            user: "deploy",
            identity: .keychain("ssh.prod")
        )
        let session = TermySession(
            title: "Production Bastion",
            profile: profile,
            lines: [TerminalLine(role: .stdout, text: "remote output")],
            currentWorkingDirectory: "/srv/app",
            interactionMode: .rawPTY
        )
        let store = TermyStore(startInitialPTY: false, sessionRestoreStore: restoreStore)
        store.sessions = [session]
        store.selectedSessionID = session.id
        store.registerTerminalLaunch(
            descriptor(
                executable: "/usr/bin/ssh",
                arguments: ["-p", "22", "--", "deploy@bastion.prod.example.test"],
                workingDirectory: "/tmp/ignored",
                environment: ["TERM": "xterm-256color", "SECRET_TOKEN": "SHOULD_NOT_SERIALIZE"]
            ),
            for: session.id
        )

        try store.captureSessionRestoreSnapshotNow(capturedAt: Date(timeIntervalSince1970: 21))

        let snapshot = try XCTUnwrap(try restoreStore.load())
        let entry = try XCTUnwrap(snapshot.sessions.first)
        XCTAssertEqual(entry.kind, .ssh)
        XCTAssertEqual(entry.workingDirectory, "/srv/app")
        XCTAssertEqual(
            entry.launch,
            .sshProfile(
                profileID: profile.id.uuidString,
                fallbackName: "Production Bastion",
                executable: "/usr/bin/ssh",
                arguments: ["-p", "22", "--", "deploy@bastion.prod.example.test"]
            )
        )
        XCTAssertEqual(
            entry.profileReference,
            .connectionProfile(
                id: profile.id.uuidString,
                name: "Production Bastion",
                host: "bastion.prod.example.test"
            )
        )
        let json = String(data: try JSONEncoder.sessionRestore.encode(snapshot), encoding: .utf8)
        XCTAssertFalse(try XCTUnwrap(json).contains("SHOULD_NOT_SERIALIZE"))
    }

    func testCaptureWritesCLIAgentSnapshotWithoutDescriptorEnvironment() throws {
        let restoreStore = try temporaryRestoreStore()
        defer { removeTemporaryRestoreStore(restoreStore) }
        let session = TermySession(
            title: "Codex",
            profile: ConnectionProfile.local(name: "Codex Agent"),
            lines: [TerminalLine(role: .stdout, text: "agent output")],
            interactionMode: .rawPTY
        )
        let store = TermyStore(startInitialPTY: false, sessionRestoreStore: restoreStore)
        store.sessions = [session]
        store.selectedSessionID = session.id
        store.registerTerminalLaunch(
            descriptor(
                executable: "/usr/bin/env",
                arguments: ["codex"],
                workingDirectory: "/tmp/code",
                environment: ["OPENAI_API_KEY": "SHOULD_NOT_SERIALIZE"]
            ),
            for: session.id
        )

        try store.captureSessionRestoreSnapshotNow(capturedAt: Date(timeIntervalSince1970: 22))

        let snapshot = try XCTUnwrap(try restoreStore.load())
        let entry = try XCTUnwrap(snapshot.sessions.first)
        XCTAssertEqual(entry.kind, .cliAgent)
        XCTAssertEqual(entry.workingDirectory, "/tmp/code")
        XCTAssertEqual(
            entry.launch,
            .cliAgent(kind: "codex", executable: "/usr/bin/env", arguments: ["codex"])
        )
        XCTAssertEqual(
            entry.profileReference,
            .tool(kind: "codex", displayName: "Codex")
        )
        let json = String(data: try JSONEncoder.sessionRestore.encode(snapshot), encoding: .utf8)
        XCTAssertFalse(try XCTUnwrap(json).contains("SHOULD_NOT_SERIALIZE"))
    }

    func testCaptureWithNoRestorableEntriesDoesNotCreateAvailableSnapshot() throws {
        let restoreStore = try temporaryRestoreStore()
        defer { removeTemporaryRestoreStore(restoreStore) }
        try seedSnapshot(in: restoreStore)
        let store = TermyStore(startInitialPTY: false, sessionRestoreStore: restoreStore)
        XCTAssertTrue(store.hasRestorableSession)
        store.sessions = []
        store.selectedSessionID = nil

        try store.captureSessionRestoreSnapshotNow(capturedAt: Date(timeIntervalSince1970: 30))

        XCTAssertNil(try restoreStore.load())
        XCTAssertFalse(restoreStore.hasValidSnapshot())
        XCTAssertFalse(store.hasRestorableSession)
        XCTAssertNil(store.sessionRestoreStatus)
    }

    func testCaptureClearsSelectedSessionIDWhenSelectedSessionIsSkipped() throws {
        let restoreStore = try temporaryRestoreStore()
        defer { removeTemporaryRestoreStore(restoreStore) }
        let store = TermyStore(startInitialPTY: false, sessionRestoreStore: restoreStore)
        let skipped = TermySession(
            title: "Preview",
            profile: ConnectionProfile.local(name: "Preview"),
            lines: [TerminalLine(role: .system, text: "No descriptor")]
        )
        let restorable = TermySession(
            title: "Local Shell",
            profile: ConnectionProfile.local(name: "Local Shell"),
            lines: [TerminalLine(role: .stdout, text: "kept")],
            interactionMode: .rawPTY
        )
        store.sessions = [skipped, restorable]
        store.selectedSessionID = skipped.id
        store.registerTerminalLaunch(localDescriptor(workingDirectory: "/tmp/restorable"), for: restorable.id)

        try store.captureSessionRestoreSnapshotNow(capturedAt: Date(timeIntervalSince1970: 40))

        let snapshot = try XCTUnwrap(try restoreStore.load())
        XCTAssertNil(snapshot.selectedSessionID)
        XCTAssertEqual(snapshot.sessions.map(\.id), [restorable.id])
        XCTAssertTrue(store.hasRestorableSession)
    }

    func testFilteredCommandCenterItemsHideRestoreActionWithoutSnapshot() throws {
        let restoreStore = try temporaryRestoreStore()
        defer { removeTemporaryRestoreStore(restoreStore) }
        let store = TermyStore(startInitialPTY: false, sessionRestoreStore: restoreStore)

        store.commandQuery = "restore"

        XCTAssertFalse(store.filteredActions.contains { $0.id == "restore-last-session" })
        XCTAssertFalse(store.filteredCommandCenterItems.contains { item in
            if case .action(let action) = item {
                return action.id == "restore-last-session"
            }
            return false
        })
    }

    func testFilteredCommandCenterItemsShowRestoreActionWithSnapshot() throws {
        let restoreStore = try temporaryRestoreStore()
        defer { removeTemporaryRestoreStore(restoreStore) }
        try seedSnapshot(in: restoreStore)
        let store = TermyStore(startInitialPTY: false, sessionRestoreStore: restoreStore)

        store.commandQuery = "restore"

        XCTAssertTrue(store.filteredActions.contains { $0.id == "restore-last-session" })
        XCTAssertTrue(store.filteredCommandCenterItems.contains { item in
            if case .action(let action) = item {
                return action.id == "restore-last-session"
            }
            return false
        })
    }

    func testRestoreLastSessionCreatesFreshLocalLaunchDescriptor() throws {
        let restoreStore = try temporaryRestoreStore()
        defer { removeTemporaryRestoreStore(restoreStore) }
        let sessionID = UUID()
        try restoreStore.save(.makeBounded(
            capturedAt: Date(timeIntervalSince1970: 50),
            selectedSessionID: sessionID,
            paneTree: "terminal",
            focusedPane: .terminal,
            activePanel: nil,
            sessions: [
                SessionRestoreEntry(
                    id: sessionID,
                    title: "Previous Local",
                    kind: .localPTY,
                    profileReference: .local,
                    workingDirectory: "/tmp",
                    launch: .localShell(shellKind: "zsh", executable: "/bin/zsh", arguments: ["-l"]),
                    scrollback: [RestoredTerminalLine(role: .stdout, text: "old output")],
                    scrollbackBytes: 0,
                    lastExitCode: nil,
                    capturedAt: Date(timeIntervalSince1970: 50)
                )
            ]
        ))
        let store = TermyStore(startInitialPTY: false, sessionRestoreStore: restoreStore)

        store.restoreLastSession()

        let session = try XCTUnwrap(store.sessions.first)
        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(session.title, "Previous Local")
        XCTAssertEqual(session.currentWorkingDirectory, "/tmp")
        XCTAssertTrue(session.lines.first?.text.contains("Restored local scrollback") == true)
        XCTAssertTrue(session.lines.contains { $0.text == "old output" })
        XCTAssertEqual(store.terminalLaunchDescriptor(for: session.id)?.workingDirectory, "/tmp")
    }

    func testRestoreRawPTYProvidesInitialTranscriptReplayForSwiftTermPath() throws {
        let restoreStore = try temporaryRestoreStore()
        defer { removeTemporaryRestoreStore(restoreStore) }
        let sessionID = UUID()
        try restoreStore.save(.makeBounded(
            capturedAt: Date(timeIntervalSince1970: 55),
            selectedSessionID: sessionID,
            paneTree: "terminal",
            focusedPane: .terminal,
            activePanel: nil,
            sessions: [
                SessionRestoreEntry(
                    id: sessionID,
                    title: "Previous Local",
                    kind: .localPTY,
                    profileReference: .local,
                    workingDirectory: "/tmp",
                    launch: .localShell(shellKind: "zsh", executable: "/bin/zsh", arguments: ["-l"]),
                    scrollback: [RestoredTerminalLine(role: .stdout, text: "old output")],
                    scrollbackBytes: 0,
                    lastExitCode: nil,
                    capturedAt: Date(timeIntervalSince1970: 55)
                )
            ]
        ))
        let store = TermyStore(startInitialPTY: false, sessionRestoreStore: restoreStore)

        store.restoreLastSession()

        let replay = try XCTUnwrap(store.initialTerminalTranscriptReplay(for: sessionID))
        XCTAssertTrue(replay.contains("Restored local scrollback"))
        XCTAssertTrue(replay.contains("old output"))
        XCTAssertNotNil(store.terminalLaunchDescriptor(for: sessionID))
    }

    func testRestoreLocalZshStartsCompletionSidecar() throws {
        let restoreStore = try temporaryRestoreStore()
        defer { removeTemporaryRestoreStore(restoreStore) }
        let sessionID = UUID()
        try restoreStore.save(.makeBounded(
            capturedAt: Date(timeIntervalSince1970: 56),
            selectedSessionID: sessionID,
            paneTree: "terminal",
            focusedPane: .terminal,
            activePanel: nil,
            sessions: [
                SessionRestoreEntry(
                    id: sessionID,
                    title: "Previous Local",
                    kind: .localPTY,
                    profileReference: .local,
                    workingDirectory: "/tmp",
                    launch: .localShell(shellKind: "zsh", executable: "/bin/zsh", arguments: ["-l"]),
                    scrollback: [],
                    scrollbackBytes: 0,
                    lastExitCode: nil,
                    capturedAt: Date(timeIntervalSince1970: 56)
                )
            ]
        ))
        let store = TermyStore(startInitialPTY: false, sessionRestoreStore: restoreStore)
        defer { store.shutdown() }

        store.restoreLastSession()

        XCTAssertTrue(store.testHasCompletionSidecar(for: sessionID))
    }

    func testRestoringSameZshSnapshotTwiceDoesNotReuseSidecarWorkDirectory() throws {
        let restoreStore = try temporaryRestoreStore()
        defer { removeTemporaryRestoreStore(restoreStore) }
        let sessionID = UUID()
        try restoreStore.save(.makeBounded(
            capturedAt: Date(timeIntervalSince1970: 57),
            selectedSessionID: sessionID,
            paneTree: "terminal",
            focusedPane: .terminal,
            activePanel: nil,
            sessions: [
                SessionRestoreEntry(
                    id: sessionID,
                    title: "Previous Local",
                    kind: .localPTY,
                    profileReference: .local,
                    workingDirectory: "/tmp",
                    launch: .localShell(shellKind: "zsh", executable: "/bin/zsh", arguments: ["-l"]),
                    scrollback: [],
                    scrollbackBytes: 0,
                    lastExitCode: nil,
                    capturedAt: Date(timeIntervalSince1970: 57)
                )
            ]
        ))
        let store = TermyStore(startInitialPTY: false, sessionRestoreStore: restoreStore)
        defer { store.shutdown() }

        store.restoreLastSession()
        let firstWorkDir = try XCTUnwrap(store.testCompletionSidecarWorkDir(for: sessionID))
        store.restoreLastSession()
        let secondWorkDir = try XCTUnwrap(store.testCompletionSidecarWorkDir(for: sessionID))

        XCTAssertNotEqual(firstWorkDir, secondWorkDir)
        let replacementSentinel = secondWorkDir.appendingPathComponent("replacement-survives")
        try "ok".write(to: replacementSentinel, atomically: true, encoding: .utf8)
        try? FileManager.default.removeItem(at: firstWorkDir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: replacementSentinel.path))
    }

    func testRestoreMissingCLIExecutableCreatesTranscriptOnlyWarning() throws {
        let restoreStore = try temporaryRestoreStore()
        defer { removeTemporaryRestoreStore(restoreStore) }
        let sessionID = UUID()
        try restoreStore.save(.makeBounded(
            capturedAt: Date(timeIntervalSince1970: 51),
            selectedSessionID: sessionID,
            paneTree: "terminal",
            focusedPane: .terminal,
            activePanel: nil,
            sessions: [
                SessionRestoreEntry(
                    id: sessionID,
                    title: "Codex",
                    kind: .cliAgent,
                    profileReference: .tool(kind: "codex", displayName: "Codex"),
                    workingDirectory: "/tmp",
                    launch: .cliAgent(kind: "codex", executable: "/missing/codex", arguments: []),
                    scrollback: [RestoredTerminalLine(role: .stdout, text: "agent output")],
                    scrollbackBytes: 0,
                    lastExitCode: nil,
                    capturedAt: Date(timeIntervalSince1970: 51)
                )
            ]
        ))
        let store = TermyStore(startInitialPTY: false, sessionRestoreStore: restoreStore)

        store.restoreLastSession()

        let session = try XCTUnwrap(store.sessions.first)
        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertNil(store.terminalLaunchDescriptor(for: session.id))
        XCTAssertTrue(session.lines.contains { $0.text.contains("could not restart") })
    }

    func testRestoreMissingSSHProfileCreatesTranscriptOnlyWarning() throws {
        let restoreStore = try temporaryRestoreStore()
        defer { removeTemporaryRestoreStore(restoreStore) }
        let missingProfileID = UUID()
        let sessionID = UUID()
        try restoreStore.save(.makeBounded(
            capturedAt: Date(timeIntervalSince1970: 51.5),
            selectedSessionID: sessionID,
            paneTree: "terminal",
            focusedPane: .terminal,
            activePanel: nil,
            sessions: [
                SessionRestoreEntry(
                    id: sessionID,
                    title: "Deleted SSH",
                    kind: .ssh,
                    profileReference: .connectionProfile(
                        id: missingProfileID.uuidString,
                        name: "Deleted SSH",
                        host: "deleted.example.test"
                    ),
                    workingDirectory: "/tmp",
                    launch: .sshProfile(
                        profileID: missingProfileID.uuidString,
                        fallbackName: "Deleted SSH",
                        executable: "/usr/bin/ssh",
                        arguments: ["--", "deploy@deleted.example.test"]
                    ),
                    scrollback: [RestoredTerminalLine(role: .stdout, text: "remote output")],
                    scrollbackBytes: 0,
                    lastExitCode: nil,
                    capturedAt: Date(timeIntervalSince1970: 51.5)
                )
            ]
        ))
        let store = TermyStore(startInitialPTY: false, sessionRestoreStore: restoreStore)

        store.restoreLastSession()

        let session = try XCTUnwrap(store.sessions.first)
        XCTAssertNil(store.terminalLaunchDescriptor(for: session.id))
        XCTAssertTrue(session.lines.contains { $0.text.contains("could not restart") })
        XCTAssertTrue(session.lines.contains { $0.text.contains("SSH profile Deleted SSH is unavailable") })
    }

    func testRestoreSSHProfileUsesCurrentProfileArguments() throws {
        let restoreStore = try temporaryRestoreStore()
        defer { removeTemporaryRestoreStore(restoreStore) }
        let profileID = UUID()
        let sessionID = UUID()
        try restoreStore.save(.makeBounded(
            capturedAt: Date(timeIntervalSince1970: 51.6),
            selectedSessionID: sessionID,
            paneTree: "terminal",
            focusedPane: .terminal,
            activePanel: nil,
            sessions: [
                SessionRestoreEntry(
                    id: sessionID,
                    title: "Production",
                    kind: .ssh,
                    profileReference: .connectionProfile(
                        id: profileID.uuidString,
                        name: "Production",
                        host: "stale.example.test"
                    ),
                    workingDirectory: "/tmp",
                    launch: .sshProfile(
                        profileID: profileID.uuidString,
                        fallbackName: "Production",
                        executable: "/usr/bin/ssh",
                        arguments: ["--", "deploy@stale.example.test"]
                    ),
                    scrollback: [],
                    scrollbackBytes: 0,
                    lastExitCode: nil,
                    capturedAt: Date(timeIntervalSince1970: 51.6)
                )
            ]
        ))
        let store = TermyStore(startInitialPTY: false, sessionRestoreStore: restoreStore)
        store.profiles = [
            .local(),
            .ssh(
                id: profileID,
                name: "Production",
                host: "current.example.test",
                user: "deploy",
                identity: .keychain("ssh.current")
            )
        ]

        store.restoreLastSession()

        let descriptor = try XCTUnwrap(store.terminalLaunchDescriptor(for: sessionID))
        XCTAssertEqual(descriptor.arguments.suffix(2), ["--", "deploy@current.example.test"])
    }

    func testRestoreLastSessionViaCommandCenterAction() throws {
        let restoreStore = try temporaryRestoreStore()
        defer { removeTemporaryRestoreStore(restoreStore) }
        let sessionID = UUID()
        try restoreStore.save(.makeBounded(
            capturedAt: Date(timeIntervalSince1970: 52),
            selectedSessionID: sessionID,
            paneTree: "terminal",
            focusedPane: .terminal,
            activePanel: nil,
            sessions: [
                SessionRestoreEntry(
                    id: sessionID,
                    title: "Previous",
                    kind: .localPTY,
                    profileReference: .local,
                    workingDirectory: "/tmp",
                    launch: .localShell(shellKind: "zsh", executable: "/bin/zsh", arguments: ["-l"]),
                    scrollback: [],
                    scrollbackBytes: 0,
                    lastExitCode: nil,
                    capturedAt: Date(timeIntervalSince1970: 52)
                )
            ]
        ))
        let store = TermyStore(startInitialPTY: false, sessionRestoreStore: restoreStore)

        store.perform("restore-last-session")

        XCTAssertEqual(store.sessions.first?.title, "Previous")
        XCTAssertTrue(store.hasRestorableSession)
        XCTAssertEqual(store.sessionRestoreStatus, "Previous session available.")
        XCTAssertEqual(store.statusMessage, "Restored previous session context.")
    }

    func testStaleSidecarEventsAreIgnoredAfterRestoreRespawnsSameSessionID() async throws {
        let restoreStore = try temporaryRestoreStore()
        defer { removeTemporaryRestoreStore(restoreStore) }
        let store = TermyStore(startInitialPTY: false, sessionRestoreStore: restoreStore)
        defer { store.shutdown() }
        let sessionID = store.testAddRawPtySession()
        _ = await store.testInstallFakeSidecar(for: sessionID)
        let staleToken = try XCTUnwrap(store.testCompletionSidecarToken(for: sessionID))
        try restoreStore.save(.makeBounded(
            capturedAt: Date(timeIntervalSince1970: 52.5),
            selectedSessionID: sessionID,
            paneTree: "terminal",
            focusedPane: .terminal,
            activePanel: nil,
            sessions: [
                SessionRestoreEntry(
                    id: sessionID,
                    title: "Previous Local",
                    kind: .localPTY,
                    profileReference: .local,
                    workingDirectory: "/tmp",
                    launch: .localShell(shellKind: "zsh", executable: "/bin/zsh", arguments: ["-l"]),
                    scrollback: [],
                    scrollbackBytes: 0,
                    lastExitCode: nil,
                    capturedAt: Date(timeIntervalSince1970: 52.5)
                )
            ]
        ))

        store.restoreLastSession()

        let currentToken = try XCTUnwrap(store.testCompletionSidecarToken(for: sessionID))
        XCTAssertNotEqual(staleToken, currentToken)
        store.applySidecarEventForTesting(
            .result(id: 100, items: [
                CompletionCandidate(title: "git", replacement: "git", kind: .command)
            ]),
            sessionID: sessionID,
            sidecarToken: staleToken
        )
        XCTAssertNil(store.terminalSidecarGhost(for: sessionID))
    }

    func testRestoreStatusClearsAfterSuccessfulRestore() throws {
        let restoreStore = try temporaryRestoreStore()
        defer { removeTemporaryRestoreStore(restoreStore) }
        try seedSnapshot(in: restoreStore)
        let store = TermyStore(startInitialPTY: false, sessionRestoreStore: restoreStore)

        XCTAssertEqual(store.sessionRestoreStatus, "Previous session available.")

        store.restoreLastSession()

        XCTAssertEqual(store.statusMessage, "Restored previous session context.")
    }

    func testRestoreRDPPlaceholderHasNoLaunchDescriptor() throws {
        let restoreStore = try temporaryRestoreStore()
        defer { removeTemporaryRestoreStore(restoreStore) }
        let sessionID = UUID()
        try restoreStore.save(.makeBounded(
            capturedAt: Date(timeIntervalSince1970: 53),
            selectedSessionID: sessionID,
            paneTree: "terminal",
            focusedPane: .terminal,
            activePanel: nil,
            sessions: [
                SessionRestoreEntry(
                    id: sessionID,
                    title: "Windows VM",
                    kind: .rdpPlaceholder,
                    profileReference: .connectionProfile(id: UUID().uuidString, name: "Windows VM", host: "win.example.test"),
                    workingDirectory: nil,
                    launch: .rdpPlaceholder(profileID: UUID().uuidString, fallbackName: "Windows VM"),
                    scrollback: [],
                    scrollbackBytes: 0,
                    lastExitCode: nil,
                    capturedAt: Date(timeIntervalSince1970: 53)
                )
            ]
        ))
        let store = TermyStore(startInitialPTY: false, sessionRestoreStore: restoreStore)

        store.restoreLastSession()

        let session = try XCTUnwrap(store.sessions.first)
        XCTAssertNil(store.terminalLaunchDescriptor(for: session.id))
        XCTAssertTrue(session.lines.contains { $0.text.contains("requires explicit reconnect") })
    }

    func testRestoreInvalidSelectedSessionFallsBackToFirstSession() throws {
        let restoreStore = try temporaryRestoreStore()
        defer { removeTemporaryRestoreStore(restoreStore) }
        let firstID = UUID()
        try restoreStore.save(.makeBounded(
            capturedAt: Date(timeIntervalSince1970: 54),
            selectedSessionID: UUID(),
            paneTree: "terminal",
            focusedPane: .terminal,
            activePanel: nil,
            sessions: [
                SessionRestoreEntry(
                    id: firstID,
                    title: "First",
                    kind: .localPTY,
                    profileReference: .local,
                    workingDirectory: "/tmp",
                    launch: .localShell(shellKind: "zsh", executable: "/bin/zsh", arguments: ["-l"]),
                    scrollback: [],
                    scrollbackBytes: 0,
                    lastExitCode: nil,
                    capturedAt: Date(timeIntervalSince1970: 54)
                )
            ]
        ))
        let store = TermyStore(startInitialPTY: false, sessionRestoreStore: restoreStore)

        store.restoreLastSession()

        XCTAssertEqual(store.selectedSessionID, firstID)
    }

    func testRestoreLastSessionWithNoSnapshotReportsUnavailable() throws {
        let restoreStore = try temporaryRestoreStore()
        defer { removeTemporaryRestoreStore(restoreStore) }
        let store = TermyStore(startInitialPTY: false, sessionRestoreStore: restoreStore)

        store.restoreLastSession()

        XCTAssertFalse(store.hasRestorableSession)
        XCTAssertNil(store.sessionRestoreStatus)
        XCTAssertEqual(store.statusMessage, "No previous session to restore.")
    }
}
