import XCTest
@testable import TermyCore
import TermySync
import TermyRDP
import Darwin
#if canImport(CloudKit)
import CloudKit
#endif

private extension Data {
    func windowsUTF16String(at offset: Int, byteCount: Int) -> String {
        var units: [UInt16] = []
        var index = offset
        let end = Swift.min(offset + byteCount, count)
        while index + 1 < end {
            let unit = UInt16(self[index]) | (UInt16(self[index + 1]) << 8)
            if unit == 0 { break }
            units.append(unit)
            index += 2
        }
        return String(decoding: units, as: UTF16.self)
    }

    func uint16BEForTest(at offset: Int) -> UInt16 {
        (UInt16(self[offset]) << 8) | UInt16(self[offset + 1])
    }

    func uint16LEForTest(at offset: Int) -> UInt16 {
        UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
    }

    func uint32LEForTest(at offset: Int) -> UInt32 {
        UInt32(self[offset])
            | (UInt32(self[offset + 1]) << 8)
            | (UInt32(self[offset + 2]) << 16)
            | (UInt32(self[offset + 3]) << 24)
    }

    func uint64LEForTest(at offset: Int) -> UInt64 {
        UInt64(self[offset])
            | (UInt64(self[offset + 1]) << 8)
            | (UInt64(self[offset + 2]) << 16)
            | (UInt64(self[offset + 3]) << 24)
            | (UInt64(self[offset + 4]) << 32)
            | (UInt64(self[offset + 5]) << 40)
            | (UInt64(self[offset + 6]) << 48)
            | (UInt64(self[offset + 7]) << 56)
    }

    func containsSubsequence(_ needle: Data) -> Bool {
        guard !needle.isEmpty, needle.count <= count else { return false }
        return (0...(count - needle.count)).contains { offset in
            self[offset..<(offset + needle.count)].elementsEqual(needle)
        }
    }
}

final class TermyCoreTests: XCTestCase {
    private func microsoftNTLMv2Type2Challenge() -> Data {
        Data([
            0x4e, 0x54, 0x4c, 0x4d, 0x53, 0x53, 0x50, 0x00,
            0x02, 0x00, 0x00, 0x00,
            0x0c, 0x00, 0x0c, 0x00,
            0x38, 0x00, 0x00, 0x00,
            0x33, 0x82, 0x8a, 0xe2,
            0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x24, 0x00, 0x24, 0x00,
            0x44, 0x00, 0x00, 0x00,
            0x06, 0x00, 0x70, 0x17, 0x00, 0x00, 0x00, 0x0f,
            0x53, 0x00, 0x65, 0x00, 0x72, 0x00, 0x76, 0x00, 0x65, 0x00, 0x72, 0x00,
            0x02, 0x00, 0x0c, 0x00,
            0x44, 0x00, 0x6f, 0x00, 0x6d, 0x00, 0x61, 0x00, 0x69, 0x00, 0x6e, 0x00,
            0x01, 0x00, 0x0c, 0x00,
            0x53, 0x00, 0x65, 0x00, 0x72, 0x00, 0x76, 0x00, 0x65, 0x00, 0x72, 0x00,
            0x00, 0x00, 0x00, 0x00
        ])
    }

    func testDefaultPrivacyPolicyMatchesPRDGuardrails() {
        let policy = PrivacyPolicy.termDefault

        XCTAssertFalse(policy.allowsTelemetry)
        XCTAssertFalse(policy.allowsTermyAccount)
        XCTAssertFalse(policy.allowsCloudAIProviders)
        XCTAssertTrue(policy.requiresLocalBuiltInAI)
        XCTAssertEqual(
            policy.allowedOutboundTraffic,
            [
                .userInitiatedSSH,
                .userInitiatedRDP,
                .userLaunchedCLIAgent,
                .privateICloudSync,
                .userInitiatedUpdateCheck,
                .optedInAutomaticUpdateCheck
            ]
        )
    }

    func testRemoteSessionNotificationBuildsNativeUserNotificationContent() {
        let notification = RemoteSessionNotification.rdpReconnectScheduled(
            profileName: "Windows Build",
            attempt: 2,
            delaySeconds: 5
        )

        XCTAssertEqual(notification.identifier, "rdp-reconnect-Windows Build-2")
        XCTAssertEqual(notification.title, "RDP reconnect scheduled")
        XCTAssertEqual(notification.body, "Windows Build will retry connection attempt 2 in 5s.")
        XCTAssertEqual(notification.category, .remoteSession)
    }

    func testPrivateSyncPlannerExportsOnlyConfigurationAndKeychainReferences() {
        let keymap = KeymapProfile(bindings: [
            "open-command-center": .commandShift("p"),
            "toggle-ai-panel": .commandOption("a")
        ])
        let profile = ConnectionProfile.ssh(
            name: "Production",
            host: "bastion.example.test",
            user: "deploy",
            port: 2222,
            identity: .keychain("ssh.identity.prod"),
            proxyJump: "jump.example.test",
            groupPath: "Production/Bastions",
            sshOptions: [
                "Compression": "yes",
                "ServerAliveInterval": "30"
            ]
        )
        let snapshot = PrivateSyncSnapshot(
            profiles: [profile],
            terminalThemeID: "solarized-dark",
            terminalFontSize: 14,
            terminalFontFamily: "JetBrains Mono",
            terminalUsesLigatures: true,
            terminalIncreasedContrast: true,
            interfaceTextScale: .large,
            terminalShell: .custom(path: "/opt/homebrew/bin/fish", arguments: ["--login"]),
            keymapBindings: keymap.bindings,
            snippets: [.init(id: "deploy", title: "Deploy", body: "make deploy")],
            workspaces: [.init(id: "debug", name: "Debug", panelIDs: ["terminal", "git"])],
            terminalScrollback: ["secret output"],
            aiConversationHistory: ["local question"]
        )

        let plan = PrivateSyncPlanner().plan(for: snapshot)

        XCTAssertEqual(
            plan.datasets,
            [
                .connectionProfiles: .cloudKitPrivateDatabase,
                .appearanceAndKeymap: .cloudKitPrivateDatabase,
                .snippetsAndPrompts: .cloudKitPrivateDatabase,
                .workspaces: .cloudKitPrivateDatabase,
                .secrets: .iCloudKeychain,
                .terminalScrollback: .localOnly,
                .projectFiles: .localOnly,
                .aiConversationHistory: .cloudKitPrivateDatabase
            ]
        )
        XCTAssertEqual(plan.records.count, 5)
        let profileRecord = try! XCTUnwrap(plan.records.first { $0.recordType == "ConnectionProfile" })
        XCTAssertEqual(profileRecord.fields["host"], "bastion.example.test")
        XCTAssertEqual(profileRecord.fields["groupPath"], "Production/Bastions")
        XCTAssertEqual(profileRecord.fields["sshOptions"], "Compression=yes;ServerAliveInterval=30")
        XCTAssertEqual(profileRecord.fields["secretReferences"], "ssh.identity.prod")
        XCTAssertNil(profileRecord.fields["inlineSecret"])
        let appearanceRecord = try! XCTUnwrap(plan.records.first { $0.recordType == "Appearance" })
        XCTAssertEqual(appearanceRecord.fields["terminalFontFamily"], "JetBrains Mono")
        XCTAssertEqual(appearanceRecord.fields["terminalIncreasedContrast"], "true")
        XCTAssertEqual(appearanceRecord.fields["interfaceTextScale"], "large")
        // D3: collision-free JSON encoding (was delimiter-joined).
        XCTAssertEqual(appearanceRecord.fields["keymapBindings"], "[[\"open-command-center\",\"commandShift:p\"],[\"toggle-ai-panel\",\"commandOption:a\"]]")
        XCTAssertEqual(appearanceRecord.fields["terminalShellPath"], "/opt/homebrew/bin/fish")
        XCTAssertEqual(appearanceRecord.fields["terminalShellArguments"], "[\"--login\"]")
        XCTAssertEqual(plan.datasets[.terminalScrollback], .localOnly)
        XCTAssertFalse(plan.records.contains { record in
            record.fields.values.contains { value in
                value.localizedCaseInsensitiveContains("secret output")
            }
        })
    }

    func testPrivateSyncPlannerRestoresTerminalFontFamily() throws {
        let snapshot = PrivateSyncSnapshot(
            profiles: [],
            terminalThemeID: "default-dark",
            terminalFontSize: 15,
            terminalFontFamily: "Berkeley Mono",
            terminalUsesLigatures: false,
            snippets: [],
            workspaces: [],
            terminalScrollback: [],
            aiConversationHistory: []
        )

        let plan = PrivateSyncPlanner().plan(for: snapshot)
        let appearanceRecord = try XCTUnwrap(plan.records.first { $0.recordType == "Appearance" })

        XCTAssertEqual(appearanceRecord.fields["terminalFontFamily"], "Berkeley Mono")
        let restored = PrivateSyncSnapshotRestorer().restore(from: [appearanceRecord])
        XCTAssertEqual(restored.terminalFontFamily, "Berkeley Mono")
    }

    func testPrivateSyncRestoresAIHistoryInNumericOrderBeyondTenMessages() {
        // D2: positional record names (`ai-history-<offset>`) restored by a LEXICOGRAPHIC
        // sort put `ai-history-10` before `ai-history-2`, scrambling any history with ≥10
        // messages. The restore must order by the numeric suffix.
        let messages = (0..<12).map { "message-\($0)" }
        let records = messages.enumerated().map { offset, message in
            PrivateSyncRecord(
                recordType: "AIConversation",
                recordName: "ai-history-\(offset)",
                fields: ["message": message]
            )
        }.shuffled()

        let restored = PrivateSyncSnapshotRestorer().restore(from: records)
        XCTAssertEqual(restored.aiConversationHistory, messages)
    }

    func testPrivateSyncDeletionPlannerFindsShrunkAIHistoryOrphans() {
        // D2: when ai-history shrinks, the higher-index records that disappeared must
        // be tombstoned so they don't resurrect on the next fetch. Non-AIConversation
        // records and still-present indices are not deleted.
        func ai(_ n: Int) -> PrivateSyncRecord {
            PrivateSyncRecord(recordType: "AIConversation", recordName: "ai-history-\(n)", fields: [:])
        }
        let previous = [ai(0), ai(1), ai(2),
                        PrivateSyncRecord(recordType: "Snippet", recordName: "snippet-x", fields: [:])]
        let current = [ai(0),
                       PrivateSyncRecord(recordType: "Snippet", recordName: "snippet-x", fields: [:])]

        XCTAssertEqual(
            PrivateSyncDeletionPlanner.aiHistoryOrphans(previous: previous, current: current).sorted(),
            ["ai-history-1", "ai-history-2"]
        )
        // No shrink → no orphans.
        XCTAssertEqual(
            PrivateSyncDeletionPlanner.aiHistoryOrphans(previous: current, current: previous),
            []
        )
    }

    func testPrivateSyncRoundTripsDelimiterContainingShellArgsThemesKeymap() throws {
        // D3: list/map values containing the legacy delimiters (space, |, ;, =)
        // survive the round-trip (the old joined(separator:) scheme corrupted them).
        let theme = TerminalTheme(
            id: "t;1", name: "Solar | Dark; v2",
            backgroundHex: "#001", foregroundHex: "#eee",
            promptHex: "#0f0", errorHex: "#f00", mutedHex: "#888"
        )
        let snapshot = PrivateSyncSnapshot(
            profiles: [],
            terminalThemeID: "t;1",
            terminalFontSize: 13,
            terminalUsesLigatures: false,
            terminalShell: .custom(path: "/opt/homebrew/bin/fish",
                                   arguments: ["--rcfile", "/Users/x/My Files/rc", "-o", "a;b|c"]),
            customTerminalThemes: [theme],
            keymapBindings: ["weird=key;id": .command("k")],
            snippets: [],
            workspaces: [],
            terminalScrollback: [],
            aiConversationHistory: []
        )

        let plan = PrivateSyncPlanner().plan(for: snapshot)
        let appearance = try XCTUnwrap(plan.records.first { $0.recordType == "Appearance" })
        let restored = PrivateSyncSnapshotRestorer().restore(from: [appearance])

        guard case .custom(_, let args)? = restored.terminalShell else {
            return XCTFail("expected a custom shell profile")
        }
        XCTAssertEqual(args, ["--rcfile", "/Users/x/My Files/rc", "-o", "a;b|c"])
        XCTAssertEqual(restored.customTerminalThemes, [theme])
        XCTAssertEqual(restored.keymapBindings["weird=key;id"], .command("k"))
    }

    func testPrivateSyncStillDecodesLegacyDelimiterEncodedAppearanceFields() {
        // D3: records written by an older build (delimiter-joined, no JSON) must
        // still restore via the fallback path.
        let legacy = PrivateSyncRecord(
            recordType: "Appearance",
            recordName: "appearance-default",
            fields: [
                "terminalShellPath": "/opt/homebrew/bin/fish",
                "terminalShellArguments": "-l -i",
                "customTerminalThemes": "t1|Dark|#000|#fff|#0f0|#f00|#888",
                "keymapBindings": "save=command:s"
            ]
        )
        let restored = PrivateSyncSnapshotRestorer().restore(from: [legacy])

        guard case .custom(_, let args)? = restored.terminalShell else {
            return XCTFail("expected a custom shell profile")
        }
        XCTAssertEqual(args, ["-l", "-i"])
        XCTAssertEqual(restored.customTerminalThemes.first?.name, "Dark")
        XCTAssertEqual(restored.keymapBindings["save"], .command("s"))
    }

    func testPrivateSyncPlannerPreservesTerminalOutputMode() throws {
        let snapshot = PrivateSyncSnapshot(
            profiles: [],
            terminalThemeID: "default-dark",
            terminalFontSize: 13,
            terminalUsesLigatures: true,
            terminalShell: .zsh,
            terminalOutputMode: .blocks,
            snippets: [],
            workspaces: [],
            terminalScrollback: [],
            aiConversationHistory: []
        )

        let plan = PrivateSyncPlanner().plan(for: snapshot)
        let appearanceRecord = try XCTUnwrap(plan.records.first { $0.recordType == "Appearance" })

        XCTAssertEqual(appearanceRecord.fields["terminalOutputMode"], "blocks")

        let restored = PrivateSyncSnapshotRestorer().restore(from: [appearanceRecord])
        XCTAssertEqual(restored.terminalOutputMode, .blocks)
    }

    func testConnectionProfilePreservesTerminalOutputModeThroughPrivateSync() throws {
        let id = UUID()
        let profile = ConnectionProfile.ssh(
            id: id,
            name: "Blocky Bastion",
            host: "bastion.example.test",
            user: "deploy",
            port: 2222,
            identity: .keychain("ssh.identity.blocky"),
            groupPath: "Production",
            terminalOutputMode: .blocks
        )
        let snapshot = PrivateSyncSnapshot(
            profiles: [profile],
            terminalThemeID: "default-dark",
            terminalFontSize: 13,
            terminalUsesLigatures: true,
            snippets: [],
            workspaces: [],
            terminalScrollback: [],
            aiConversationHistory: []
        )

        let plan = PrivateSyncPlanner().plan(for: snapshot)
        let profileRecord = try XCTUnwrap(plan.records.first { $0.recordType == "ConnectionProfile" })

        XCTAssertEqual(profileRecord.fields["terminalOutputMode"], "blocks")
        XCTAssertEqual(PrivateSyncSnapshotRestorer.connectionProfile(from: profileRecord)?.terminalOutputMode, .blocks)
    }

    func testConnectionProfilePreservesSSHOptionsThroughPrivateSync() throws {
        let id = UUID()
        let profile = ConnectionProfile.ssh(
            id: id,
            name: "Production",
            host: "bastion.example.test",
            user: "deploy",
            port: 2222,
            identity: .keychain("ssh.identity.prod"),
            sshOptions: [
                "Compression": "yes",
                "ServerAliveInterval": "30"
            ]
        )
        let snapshot = PrivateSyncSnapshot(
            profiles: [profile],
            terminalThemeID: "default-dark",
            terminalFontSize: 13,
            terminalUsesLigatures: true,
            snippets: [],
            workspaces: [],
            terminalScrollback: [],
            aiConversationHistory: []
        )

        let plan = PrivateSyncPlanner().plan(for: snapshot)
        let profileRecord = try XCTUnwrap(plan.records.first { $0.recordType == "ConnectionProfile" })
        let restored = try XCTUnwrap(PrivateSyncSnapshotRestorer.connectionProfile(from: profileRecord))

        XCTAssertEqual(profileRecord.fields["sshOptions"], "Compression=yes;ServerAliveInterval=30")
        XCTAssertEqual(restored.sshOptions, ["Compression": "yes", "ServerAliveInterval": "30"])
    }

    func testConnectionProfileRestoresGroupPathFromPrivateSyncRecord() throws {
        let id = UUID()
        let record = PrivateSyncRecord(
            recordType: "ConnectionProfile",
            recordName: "connection-\(id.uuidString)",
            fields: [
                "kind": "ssh",
                "name": "Prod DB",
                "host": "db.example.test",
                "user": "deploy",
                "port": "2222",
                "gateway": "jump.example.test",
                "groupPath": "Production/Databases",
                "sshOptions": "Compression=yes;ServerAliveInterval=30",
                "secretReferences": "ssh.identity.prod-db"
            ]
        )

        let profile = try XCTUnwrap(PrivateSyncSnapshotRestorer.connectionProfile(from: record))

        XCTAssertEqual(profile.id, id)
        XCTAssertEqual(profile.groupPath, "Production/Databases")
        XCTAssertEqual(profile.sshOptions, ["Compression": "yes", "ServerAliveInterval": "30"])
        XCTAssertEqual(profile.secretReferences, [.keychain("ssh.identity.prod-db")])
    }

    func testPrivateSyncSchedulerPlansDebouncedPushAndImmediateFetch() {
        var scheduler = PrivateSyncScheduler(debounceSeconds: 10)

        XCTAssertEqual(
            scheduler.schedule(reason: .localChange, at: 100),
            PrivateSyncOperation(kind: .push, reason: .localChange, earliestRunAt: 110)
        )
        XCTAssertEqual(
            scheduler.schedule(reason: .silentRemoteNotification, at: 102),
            PrivateSyncOperation(kind: .fetch, reason: .silentRemoteNotification, earliestRunAt: 102)
        )
        XCTAssertNil(scheduler.schedule(reason: .localChange, at: 105))
        XCTAssertEqual(
            scheduler.pendingOperations(),
            [
                PrivateSyncOperation(kind: .fetch, reason: .silentRemoteNotification, earliestRunAt: 102),
                PrivateSyncOperation(kind: .push, reason: .localChange, earliestRunAt: 110)
            ]
        )

        XCTAssertEqual(
            scheduler.markCompleted(kind: .fetch),
            PrivateSyncOperation(kind: .fetch, reason: .silentRemoteNotification, earliestRunAt: 102)
        )
        XCTAssertEqual(scheduler.pendingOperations(), [
            PrivateSyncOperation(kind: .push, reason: .localChange, earliestRunAt: 110)
        ])
    }

    func testPrivateSyncSchedulerRunsDueOperationsAndKeepsFailedWorkPending() {
        var scheduler = PrivateSyncScheduler(debounceSeconds: 10)
        _ = scheduler.schedule(reason: .localChange, at: 100)
        _ = scheduler.schedule(reason: .silentRemoteNotification, at: 102)
        var performed: [PrivateSyncOperationKind] = []

        let earlyResults = scheduler.runDueOperations(at: 105) { operation in
            performed.append(operation.kind)
            return .completed
        }

        XCTAssertEqual(performed, [.fetch])
        XCTAssertEqual(earlyResults, [
            PrivateSyncOperationResult(
                operation: PrivateSyncOperation(kind: .fetch, reason: .silentRemoteNotification, earliestRunAt: 102),
                outcome: .completed
            )
        ])
        XCTAssertEqual(scheduler.pendingOperations(), [
            PrivateSyncOperation(kind: .push, reason: .localChange, earliestRunAt: 110)
        ])

        let retryResults = scheduler.runDueOperations(at: 110) { _ in .failed("offline") }

        XCTAssertEqual(retryResults, [
            PrivateSyncOperationResult(
                operation: PrivateSyncOperation(kind: .push, reason: .localChange, earliestRunAt: 110),
                outcome: .failed("offline")
            )
        ])
        XCTAssertEqual(scheduler.pendingOperations(), [
            PrivateSyncOperation(kind: .push, reason: .localChange, earliestRunAt: 110)
        ])
    }

    func testPrivateSyncEventLoopSchedulesEventsAndRunsDueAdapterWork() {
        var eventLoop = PrivateSyncEventLoop(scheduler: PrivateSyncScheduler(debounceSeconds: 10))
        var performed: [PrivateSyncOperationKind] = []

        let localChange = eventLoop.handle(event: .localChange, at: 100) { operation in
            performed.append(operation.kind)
            return .completed
        }

        XCTAssertEqual(localChange.scheduledOperation, PrivateSyncOperation(kind: .push, reason: .localChange, earliestRunAt: 110))
        XCTAssertEqual(localChange.operationResults, [])
        XCTAssertEqual(localChange.pendingOperations, [
            PrivateSyncOperation(kind: .push, reason: .localChange, earliestRunAt: 110)
        ])
        XCTAssertEqual(performed, [])

        let remoteNotification = eventLoop.handle(event: .silentRemoteNotification, at: 105) { operation in
            performed.append(operation.kind)
            return .completed
        }

        XCTAssertEqual(remoteNotification.scheduledOperation, PrivateSyncOperation(kind: .fetch, reason: .silentRemoteNotification, earliestRunAt: 105))
        XCTAssertEqual(remoteNotification.operationResults, [
            PrivateSyncOperationResult(
                operation: PrivateSyncOperation(kind: .fetch, reason: .silentRemoteNotification, earliestRunAt: 105),
                outcome: .completed
            )
        ])
        XCTAssertEqual(remoteNotification.pendingOperations, [
            PrivateSyncOperation(kind: .push, reason: .localChange, earliestRunAt: 110)
        ])

        let retry = eventLoop.handle(event: .timer, at: 110) { operation in
            performed.append(operation.kind)
            return .failed("offline")
        }

        XCTAssertEqual(performed, [.fetch, .push])
        XCTAssertNil(retry.scheduledOperation)
        XCTAssertEqual(retry.operationResults, [
            PrivateSyncOperationResult(
                operation: PrivateSyncOperation(kind: .push, reason: .localChange, earliestRunAt: 110),
                outcome: .failed("offline")
            )
        ])
        XCTAssertEqual(eventLoop.pendingOperations(), [
            PrivateSyncOperation(kind: .push, reason: .localChange, earliestRunAt: 110)
        ])
    }

    func testPrivateSyncOperationAdapterMapsDuePushAndFetchClosures() {
        var eventLoop = PrivateSyncEventLoop(scheduler: PrivateSyncScheduler(debounceSeconds: 10))
        let adapter = PrivateSyncOperationAdapter(
            push: { .failed("offline") },
            fetch: { .completed }
        )

        _ = eventLoop.handle(event: .localChange, at: 100, perform: adapter.perform)
        let fetchStep = eventLoop.handle(event: .appLaunch, at: 105, perform: adapter.perform)

        XCTAssertEqual(fetchStep.operationResults, [
            PrivateSyncOperationResult(
                operation: PrivateSyncOperation(kind: .fetch, reason: .appLaunch, earliestRunAt: 105),
                outcome: .completed
            )
        ])
        XCTAssertEqual(fetchStep.pendingOperations, [
            PrivateSyncOperation(kind: .push, reason: .localChange, earliestRunAt: 110)
        ])

        let pushStep = eventLoop.handle(event: .timer, at: 110, perform: adapter.perform)

        XCTAssertEqual(pushStep.operationResults, [
            PrivateSyncOperationResult(
                operation: PrivateSyncOperation(kind: .push, reason: .localChange, earliestRunAt: 110),
                outcome: .failed("offline")
            )
        ])
        XCTAssertEqual(pushStep.pendingOperations, [
            PrivateSyncOperation(kind: .push, reason: .localChange, earliestRunAt: 110)
        ])
    }

    func testPrivateSyncAsyncEventLoopAwaitsPushAndFetchBeforeUpdatingPendingWork() async {
        var eventLoop = PrivateSyncEventLoop(scheduler: PrivateSyncScheduler(debounceSeconds: 10))
        let adapter = PrivateSyncAsyncOperationAdapter(
            push: { .failed("offline") },
            fetch: { .completed }
        )

        let fetchStep = await eventLoop.handleAsync(event: .appLaunch, at: 100, perform: adapter.perform)

        XCTAssertEqual(fetchStep.operationResults, [
            PrivateSyncOperationResult(
                operation: PrivateSyncOperation(kind: .fetch, reason: .appLaunch, earliestRunAt: 100),
                outcome: .completed
            )
        ])
        XCTAssertEqual(fetchStep.pendingOperations, [])

        _ = await eventLoop.handleAsync(event: .localChange, at: 100, perform: adapter.perform)
        let pushStep = await eventLoop.handleAsync(event: .timer, at: 110, perform: adapter.perform)

        XCTAssertEqual(pushStep.operationResults, [
            PrivateSyncOperationResult(
                operation: PrivateSyncOperation(kind: .push, reason: .localChange, earliestRunAt: 110),
                outcome: .failed("offline")
            )
        ])
        XCTAssertEqual(pushStep.pendingOperations, [
            PrivateSyncOperation(kind: .push, reason: .localChange, earliestRunAt: 110)
        ])
    }

    func testPrivateSyncBackgroundTaskRunnerExecutesDueWorkWithinBudget() async {
        let pending = [
            PrivateSyncOperation(kind: .fetch, reason: .silentRemoteNotification, earliestRunAt: 100),
            PrivateSyncOperation(kind: .push, reason: .localChange, earliestRunAt: 100)
        ]
        var runner = PrivateSyncBackgroundTaskRunner(
            scheduler: PrivateSyncScheduler(pendingOperations: pending),
            maxOperationsPerTask: 1
        )
        let recorder = PrivateSyncOperationRecorder()
        let adapter = PrivateSyncAsyncOperationAdapter(
            push: {
                await recorder.append(.push)
                return .completed
            },
            fetch: {
                await recorder.append(.fetch)
                return .completed
            }
        )

        let firstRun = await runner.runDueTask(at: 100, perform: adapter.perform)
        let firstPerformed = await recorder.values()

        XCTAssertEqual(firstPerformed, [.fetch])
        XCTAssertEqual(firstRun.completedOperationCount, 1)
        XCTAssertEqual(firstRun.remainingPendingOperations, [
            PrivateSyncOperation(kind: .push, reason: .localChange, earliestRunAt: 100)
        ])
        XCTAssertEqual(firstRun.nextWakeAt, 100)

        let secondRun = await runner.runDueTask(at: 100, perform: adapter.perform)
        let secondPerformed = await recorder.values()

        XCTAssertEqual(secondPerformed, [.fetch, .push])
        XCTAssertEqual(secondRun.remainingPendingOperations, [])
        XCTAssertEqual(secondRun.nextWakeAt, nil)
    }

    func testPrivateSyncBackgroundTaskConfigurationDefinesPermittedIdentifiers() {
        let configuration = PrivateSyncBackgroundTaskConfiguration.termDefault

        XCTAssertEqual(configuration.appRefreshIdentifier, "pl.kacper.Termy.private-sync.refresh")
        XCTAssertEqual(configuration.processingIdentifier, "pl.kacper.Termy.private-sync.processing")
        XCTAssertEqual(configuration.permittedIdentifiers, [
            "pl.kacper.Termy.private-sync.refresh",
            "pl.kacper.Termy.private-sync.processing"
        ])
    }

    func testPrivateSyncAppEventCoordinatorRunsCloudOperationsAndMergesFetchedRecords() async {
        let localWorkspace = PrivateSyncRecord(
            recordType: "Workspace",
            recordName: "workspace-debug",
            fields: ["name": "Debug", "panelIDs": "terminal"]
        )
        let remoteWorkspace = PrivateSyncRecord(
            recordType: "Workspace",
            recordName: "workspace-debug",
            // Newer stamp than the unstamped local (→ epoch 0) so the fetched remote edit
            // legitimately wins the conflict (D1: equal/unknown stamps keep local).
            fields: ["name": "Debug Remote", "panelIDs": "terminal,git", "modifiedAt": "200"]
        )
        let remoteAppearance = PrivateSyncRecord(
            recordType: "Appearance",
            recordName: "appearance-default",
            fields: ["terminalThemeID": "solarized"]
        )
        var coordinator = PrivateSyncAppEventCoordinator(
            eventLoop: PrivateSyncEventLoop(scheduler: PrivateSyncScheduler(debounceSeconds: 5)),
            fetchRecordTypes: ["Workspace", "Appearance"]
        )
        var savedBatches: [[PrivateSyncRecord]] = []
        var fetchedTypes: [String] = []

        _ = await coordinator.handle(
            event: .localChange,
            at: 10,
            records: [localWorkspace],
            activeLocalSessionRecordNames: [],
            save: { records in
                savedBatches.append(records)
                return records
            },
            fetch: { _ in [] }
        )
        let pushStep = await coordinator.handle(
            event: .timer,
            at: 15,
            records: [localWorkspace],
            activeLocalSessionRecordNames: [],
            save: { records in
                savedBatches.append(records)
                return records
            },
            fetch: { _ in [] }
        )

        XCTAssertEqual(savedBatches, [[localWorkspace]])
        XCTAssertEqual(pushStep.records, [localWorkspace])
        XCTAssertEqual(pushStep.eventLoopStep.pendingOperations, [])
        XCTAssertEqual(pushStep.savedRecordCount, 1)

        let fetchStep = await coordinator.handle(
            event: .silentRemoteNotification,
            at: 20,
            records: [localWorkspace],
            activeLocalSessionRecordNames: [],
            save: { records in records },
            fetch: { recordType in
                fetchedTypes.append(recordType)
                switch recordType {
                case "Workspace":
                    return [remoteWorkspace]
                case "Appearance":
                    return [remoteAppearance]
                default:
                    return []
                }
            }
        )

        XCTAssertEqual(fetchedTypes, ["Workspace", "Appearance"])
        XCTAssertEqual(fetchStep.records, [remoteAppearance, remoteWorkspace])
        XCTAssertEqual(fetchStep.fetchedRecordCount, 2)
        XCTAssertEqual(fetchStep.eventLoopStep.operationResults.map(\.outcome), [.completed])
    }

    func testUserPromptSnippetLibraryBuildsSyncSnippetsAndPromptContext() {
        let snippets = UserPromptSnippetLibrary(snippets: [
            UserPromptSnippet(id: "deploy", title: "Deploy", body: "Use make deploy"),
            UserPromptSnippet(id: "empty", title: "Empty", body: " ")
        ])

        XCTAssertEqual(PrivateSyncPlanner.syncSnippets(from: snippets), [
            SyncSnippet(id: "user-deploy", title: "Deploy", body: "Use make deploy")
        ])
        XCTAssertEqual(snippets.promptContext(), "Deploy\nUse make deploy")
    }

    func testWorkspaceStoreSavesAndRestoresNamedLayouts() {
        var store = WorkspaceStore()
        let paneTree = WorkspacePaneTree.split(
            axis: .horizontal,
            ratio: 0.42,
            first: .leaf(.terminal),
            second: .split(
                axis: .vertical,
                ratio: 0.30,
                first: .leaf(.editor),
                second: .leaf(.ai)
            )
        )
        let layout = WorkspaceLayout(
            id: "debug",
            name: "Debug",
            sessionProfileIDs: ["local", "prod"],
            activeSessionProfileID: "prod",
            panelIDs: ["terminal", "git"],
            splitRatio: 0.62,
            paneTree: paneTree
        )

        store.save(layout)
        store.save(.init(
            id: "deploy",
            name: "Deploy",
            sessionProfileIDs: ["prod"],
            activeSessionProfileID: "prod",
            panelIDs: ["terminal", "ai"],
            splitRatio: 0.5
        ))

        XCTAssertEqual(store.layouts.map(\.name), ["Debug", "Deploy"])
        XCTAssertEqual(store.restore(id: "debug"), layout)
        XCTAssertEqual(store.restore(id: "debug")?.paneTree, paneTree)
        XCTAssertEqual(store.restore(id: "missing"), nil)
    }

    func testWorkspacePaneLayoutSupportsKeyboardDrivenSplitsFocusAndResize() {
        var layout = WorkspacePaneLayout()

        layout.split(.editor, edge: .trailing)
        XCTAssertEqual(layout.visiblePanes, [.terminal, .editor])
        XCTAssertEqual(layout.focusedPane, .editor)

        layout.resizeFocusedPane(by: 0.5)
        XCTAssertEqual(layout.trailingRatio, 0.75)

        layout.split(.ai, edge: .bottom)
        XCTAssertEqual(layout.visiblePanes, [.terminal, .editor, .ai])
        XCTAssertEqual(layout.focusedPane, .ai)

        layout.focusNextPane()
        XCTAssertEqual(layout.focusedPane, .terminal)
        layout.focusNextPane()
        XCTAssertEqual(layout.focusedPane, .editor)

        layout.closeFocusedPane()
        XCTAssertEqual(layout.visiblePanes, [.terminal, .ai])
        XCTAssertEqual(layout.focusedPane, .terminal)
    }

    func testWorkspacePaneLayoutSupportsFourDirectionalSplits() {
        var layout = WorkspacePaneLayout()

        layout.split(.files, edge: .leading)
        layout.split(.editor, edge: .trailing)
        layout.split(.git, edge: .top)
        layout.split(.ai, edge: .bottom)

        XCTAssertEqual(layout.leadingPane, .files)
        XCTAssertEqual(layout.trailingPane, .editor)
        XCTAssertEqual(layout.topPane, .git)
        XCTAssertEqual(layout.bottomPane, .ai)
        XCTAssertEqual(layout.visiblePanes, [.files, .git, .ai, .editor, .terminal])
        XCTAssertEqual(layout.focusedPane, .ai)

        layout.resizeFocusedPane(by: 0.5)
        XCTAssertEqual(layout.bottomRatio, 0.65)

        layout.focusNextPane()
        XCTAssertEqual(layout.focusedPane, .editor)
        layout.focusNextPane()
        XCTAssertEqual(layout.focusedPane, .terminal)
        layout.focusNextPane()
        XCTAssertEqual(layout.focusedPane, .files)

        layout.closeFocusedPane()
        XCTAssertEqual(layout.visiblePanes, [.git, .ai, .editor, .terminal])
        XCTAssertEqual(layout.focusedPane, .git)
    }

    func testWorkspacePaneLayoutSupportsNestedFreeformPaneTree() {
        var layout = WorkspacePaneLayout()

        layout.split(.editor, edge: .trailing)
        layout.split(.ai, edge: .bottom)
        layout.focusNextPane()
        layout.focusNextPane()
        layout.split(.files, edge: .leading)

        XCTAssertEqual(layout.visiblePanes, [.terminal, .files, .editor, .ai])
        XCTAssertEqual(layout.focusedPane, .files)
        XCTAssertEqual(
            layout.paneTree,
            .split(
                axis: .horizontal,
                ratio: 0.34,
                first: .leaf(.terminal),
                second: .split(
                    axis: .vertical,
                    ratio: 0.30,
                    first: .split(
                        axis: .horizontal,
                        ratio: 0.24,
                        first: .leaf(.files),
                        second: .leaf(.editor)
                    ),
                    second: .leaf(.ai)
                )
            )
        )

        layout.resizeFocusedPane(by: 0.10)
        XCTAssertEqual(
            layout.paneTree,
            .split(
                axis: .horizontal,
                ratio: 0.34,
                first: .leaf(.terminal),
                second: .split(
                    axis: .vertical,
                    ratio: 0.30,
                    first: .split(
                        axis: .horizontal,
                        ratio: 0.34,
                        first: .leaf(.files),
                        second: .leaf(.editor)
                    ),
                    second: .leaf(.ai)
                )
            )
        )

        layout.closeFocusedPane()
        XCTAssertEqual(layout.visiblePanes, [.terminal, .editor, .ai])
        XCTAssertEqual(
            layout.paneTree,
            .split(
                axis: .horizontal,
                ratio: 0.34,
                first: .leaf(.terminal),
                second: .split(
                    axis: .vertical,
                    ratio: 0.30,
                    first: .leaf(.editor),
                    second: .leaf(.ai)
                )
            )
        )
    }

    func testWorkspacePaneLayoutResizesNestedSplitFromPointerDragHandle() {
        var layout = WorkspacePaneLayout()
        layout.split(.editor, edge: .trailing)
        layout.split(.ai, edge: .bottom)

        layout.resizeSplit(
            at: [.second],
            byDraggingPixels: 84,
            inContainerLength: 700
        )

        XCTAssertEqual(
            layout.paneTree,
            .split(
                axis: .horizontal,
                ratio: 0.34,
                first: .leaf(.terminal),
                second: .split(
                    axis: .vertical,
                    ratio: 0.42,
                    first: .leaf(.editor),
                    second: .leaf(.ai)
                )
            )
        )
        XCTAssertEqual(layout.paneTree.storageValue, "h:0.34(terminal|v:0.42(editor|ai))")

        layout.resizeSplit(
            at: [.second],
            byDraggingPixels: -500,
            inContainerLength: 700
        )

        XCTAssertEqual(layout.paneTree.storageValue, "h:0.34(terminal|v:0.15(editor|ai))")
    }

    func testPrivateSyncPlannerPersistsWorkspacePaneTreeDescriptor() throws {
        let tree = WorkspacePaneTree.split(
            axis: .horizontal,
            ratio: 0.34,
            first: .leaf(.terminal),
            second: .split(
                axis: .vertical,
                ratio: 0.30,
                first: .leaf(.editor),
                second: .leaf(.ai)
            )
        )
        let snapshot = PrivateSyncSnapshot(
            profiles: [],
            terminalThemeID: "default",
            terminalFontSize: 14,
            terminalUsesLigatures: true,
            snippets: [],
            workspaces: [.init(id: "debug", name: "Debug", panelIDs: ["terminal", "editor", "ai"], paneTree: tree)],
            terminalScrollback: [],
            aiConversationHistory: []
        )

        let plan = PrivateSyncPlanner().plan(for: snapshot)
        let workspace = try XCTUnwrap(plan.records.first { $0.recordType == "Workspace" })

        XCTAssertEqual(workspace.fields["paneTree"], "h:0.34(terminal|v:0.30(editor|ai))")
    }

    func testWorkspacePaneLayoutBuildsRecursiveRenderPlan() {
        let layout = WorkspacePaneLayout(
            paneTree: .split(
                axis: .horizontal,
                ratio: 0.40,
                first: .leaf(.files),
                second: .split(
                    axis: .vertical,
                    ratio: 0.35,
                    first: .leaf(.terminal),
                    second: .leaf(.ai)
                )
            ),
            focusedPane: .terminal
        )

        XCTAssertEqual(
            layout.renderPlan.root,
            .split(
                axis: .horizontal,
                ratio: 0.40,
                first: .leaf(.files),
                second: .split(
                    axis: .vertical,
                    ratio: 0.35,
                    first: .leaf(.terminal),
                    second: .leaf(.ai)
                )
            )
        )
        XCTAssertEqual(layout.renderPlan.leafPanes, [.files, .terminal, .ai])
        XCTAssertEqual(layout.renderPlan.focusedPane, .terminal)
    }

    func testWorkspacePaneTreeParsesStorageDescriptorForSyncRestore() {
        let descriptor = "h:0.34(terminal|v:0.30(editor|ai))"

        XCTAssertEqual(
            WorkspacePaneTree(storageValue: descriptor),
            .split(
                axis: .horizontal,
                ratio: 0.34,
                first: .leaf(.terminal),
                second: .split(
                    axis: .vertical,
                    ratio: 0.30,
                    first: .leaf(.editor),
                    second: .leaf(.ai)
                )
            )
        )
        XCTAssertEqual(WorkspacePaneTree(storageValue: "h:0.50(terminal|unknown)"), nil)
        XCTAssertEqual(WorkspacePaneTree(storageValue: "h:0.50(terminal|ai"), nil)
    }

    func testSyncWorkspaceRestoresPaneTreeFromPrivateSyncRecord() throws {
        let record = PrivateSyncRecord(
            recordType: "Workspace",
            recordName: "workspace-debug",
            fields: [
                "name": "Debug",
                "panelIDs": "terminal,editor,ai",
                "paneTree": "h:0.34(terminal|v:0.30(editor|ai))"
            ]
        )

        let workspace = try XCTUnwrap(SyncWorkspace(record: record))

        XCTAssertEqual(workspace.id, "debug")
        XCTAssertEqual(workspace.name, "Debug")
        XCTAssertEqual(workspace.panelIDs, ["terminal", "editor", "ai"])
        XCTAssertEqual(
            workspace.paneTree,
            .split(
                axis: .horizontal,
                ratio: 0.34,
                first: .leaf(.terminal),
                second: .split(
                    axis: .vertical,
                    ratio: 0.30,
                    first: .leaf(.editor),
                    second: .leaf(.ai)
                )
            )
        )
        XCTAssertNil(SyncWorkspace(record: .init(recordType: "Workspace", recordName: "workspace-bad", fields: ["paneTree": "h:0.50(terminal|bad)"])))
        XCTAssertNil(SyncWorkspace(record: .init(recordType: "Snippet", recordName: "snippet-debug", fields: [:])))
    }

    func testCloudKitRecordNamesAreStableForPrivateSyncRecords() {
        let record = PrivateSyncRecord(
            recordType: "Workspace",
            recordName: "workspace-debug",
            fields: ["name": "Debug"]
        )

        XCTAssertEqual(record.zoneName, "TermyPrivateSync")
        XCTAssertEqual(record.cloudKitRecordType, "TermyWorkspace")
        XCTAssertEqual(record.cloudKitRecordName, "workspace-debug")
    }

    func testCloudKitPrivateSyncMapperBuildsPrivateZoneRecords() throws {
        #if canImport(CloudKit)
        let source = PrivateSyncRecord(
            recordType: "Workspace",
            recordName: "workspace-debug",
            // D1: the conflict timestamp must survive the CKRecord round-trip — if the
            // inbound decoder dropped it, remote would always read as epoch 0 and local
            // would always win, silently breaking inbound sync.
            fields: ["name": "Debug", "panelIDs": "terminal,git", "modifiedAt": "200"]
        )
        let mapper = CloudKitPrivateSyncMapper()

        let record = mapper.makeCloudKitRecord(from: source)

        XCTAssertEqual(record.recordType, "TermyWorkspace")
        XCTAssertEqual(record.recordID.recordName, "workspace-debug")
        XCTAssertEqual(record.recordID.zoneID.zoneName, "TermyPrivateSync")
        XCTAssertEqual(record["name"] as? String, "Debug")
        XCTAssertEqual(record["panelIDs"] as? String, "terminal,git")
        XCTAssertEqual(record["modifiedAt"] as? String, "200")
        let roundTripped = try mapper.makePrivateSyncRecord(from: record)
        XCTAssertEqual(roundTripped, source)
        XCTAssertEqual(roundTripped.fields["modifiedAt"], "200")
        #endif
    }

    func testCloudKitPrivateSyncSubscriptionUsesPrivateZoneChanges() {
        #if canImport(CloudKit)
        let subscription = CloudKitPrivateSyncMapper().makeZoneSubscription()

        XCTAssertEqual(subscription.subscriptionID, "TermyPrivateSyncZoneChanges")
        XCTAssertEqual(subscription.zoneID.zoneName, "TermyPrivateSync")
        XCTAssertEqual(subscription.notificationInfo?.shouldSendContentAvailable, true)
        #endif
    }

    func testCloudKitPrivateSyncEngineMapperBuildsRuntimeEvents() throws {
        #if canImport(CloudKit)
        if #available(macOS 14.0, *) {
            let source = PrivateSyncRecord(
                recordType: "Snippet",
                recordName: "snippet-user-runtime",
                fields: ["title": "Runtime", "body": "sync"]
            )
            let mapper = CloudKitPrivateSyncMapper()
            let record = mapper.makeCloudKitRecord(from: source)
            let zoneID = record.recordID.zoneID
            let deletedID = CKRecord.ID(recordName: "snippet-user-old", zoneID: zoneID)
            let stateToken = PrivateSyncChangeToken(rawValue: "sync-engine-state-2")

            XCTAssertEqual(
                try mapper.makeFetchedRecordZoneChangesEvent(
                    modifications: [record],
                    deletedRecordIDs: [deletedID],
                    stateToken: stateToken
                ),
                .fetchedDatabaseChanges(
                    PrivateSyncChangeSet(
                        changedRecords: [source],
                        deletedRecordNames: ["snippet-user-old"],
                        newChangeToken: stateToken
                    )
                )
            )
            XCTAssertEqual(
                try mapper.makeSentRecordZoneChangesEvent(savedRecords: [record]),
                .sentDatabaseChanges([source])
            )
            XCTAssertEqual(
                mapper.makeAccountState(from: .signIn(currentUser: CKRecord.ID(recordName: "_default"))),
                .available
            )
        }
        #endif
    }

    func testCloudKitPrivateSyncEngineSessionBindsDelegateToAppleRuntime() async throws {
        #if canImport(CloudKit)
        if #available(macOS 14.0, *) {
            let source = PrivateSyncRecord(
                recordType: "Workspace",
                recordName: "workspace-runtime",
                fields: ["name": "Runtime", "panelIDs": "terminal"]
            )
            let delegate = CloudKitPrivateSyncEngineDelegate(
                recordsProvider: { [source] },
                eventHandler: { _ in }
            )
            let batch = delegate.makeRecordZoneChangeBatch(for: [source])

            XCTAssertEqual(batch.recordsToSave.count, 1)
            XCTAssertEqual(batch.recordsToSave.first?.recordID.recordName, "workspace-runtime")
            XCTAssertEqual(batch.recordIDsToDelete, [])
            XCTAssertTrue(batch.atomicByZone)

            // D2: tombstones for locally-removed records ride in recordIDsToDelete.
            let withDeletes = delegate.makeRecordZoneChangeBatch(
                for: [source], deleting: ["ai-history-2", "ai-history-3"]
            )
            XCTAssertEqual(
                withDeletes.recordIDsToDelete.map(\.recordName).sorted(),
                ["ai-history-2", "ai-history-3"]
            )
            XCTAssertEqual(withDeletes.recordIDsToDelete.first?.zoneID.zoneName, "TermyPrivateSync")
            XCTAssertEqual(CloudKitPrivateSyncEngineSession.defaultSubscriptionID, "TermyPrivateSyncZoneChanges")
            XCTAssertFalse(CloudKitPrivateSyncEngineSession.defaultAutomaticallySync)
        }
        #endif
    }

    func testPrivateSyncConflictResolverProtectsSecretsAndActiveSession() {
        let resolver = PrivateSyncConflictResolver()
        let localProfile = PrivateSyncRecord(
            recordType: "ConnectionProfile",
            recordName: "connection-prod",
            fields: ["host": "local.example", "secretReferences": "local-key", "modifiedAt": "100"]
        )
        let remoteProfile = PrivateSyncRecord(
            recordType: "ConnectionProfile",
            recordName: "connection-prod",
            fields: ["host": "remote.example", "secretReferences": "remote-key", "modifiedAt": "200"]
        )
        let activeLocalWorkspace = PrivateSyncRecord(
            recordType: "Workspace",
            recordName: "workspace-current",
            fields: ["name": "Local", "activeSession": "local", "modifiedAt": "100"]
        )
        let remoteWorkspace = PrivateSyncRecord(
            recordType: "Workspace",
            recordName: "workspace-current",
            fields: ["name": "Remote", "activeSession": "remote", "modifiedAt": "200"]
        )

        // D4: remote is newer (200 > 100) and wins, so its secretReferences must be
        // adopted — NOT force-overwritten with local's. Force-local here is the D4 bug:
        // after a credential is re-issued on another Mac (new reference id), this Mac
        // would keep pointing at the stale Keychain item and auth would fail.
        XCTAssertEqual(
            resolver.resolve(local: localProfile, remote: remoteProfile, activeLocalSessionRecordNames: []),
            PrivateSyncRecord(
                recordType: "ConnectionProfile",
                recordName: "connection-prod",
                fields: ["host": "remote.example", "secretReferences": "remote-key", "modifiedAt": "200"]
            )
        )
        XCTAssertEqual(
            resolver.resolve(
                local: activeLocalWorkspace,
                remote: remoteWorkspace,
                activeLocalSessionRecordNames: ["workspace-current"]
            ),
            activeLocalWorkspace
        )
    }

    func testPrivateSyncConflictResolverUsesLastEditedTimestamps() {
        let resolver = PrivateSyncConflictResolver()
        func profile(_ host: String, modifiedAt: String?) -> PrivateSyncRecord {
            var fields = ["host": host]
            if let modifiedAt { fields["modifiedAt"] = modifiedAt }
            return PrivateSyncRecord(
                recordType: "ConnectionProfile",
                recordName: "connection-prod",
                fields: fields
            )
        }

        // Local edited more recently → local wins (D1: the bug let remote always win).
        XCTAssertEqual(
            resolver.resolve(
                local: profile("local", modifiedAt: "200"),
                remote: profile("remote", modifiedAt: "100"),
                activeLocalSessionRecordNames: []
            ).fields["host"],
            "local"
        )
        // Equal stamps → keep local (strict `>`; avoids needless churn on unchanged records).
        XCTAssertEqual(
            resolver.resolve(
                local: profile("local", modifiedAt: "100"),
                remote: profile("remote", modifiedAt: "100"),
                activeLocalSessionRecordNames: []
            ).fields["host"],
            "local"
        )
        // Both legacy/unstamped (missing → epoch 0) → keep local (conservative; no surprise
        // overwrite). A genuinely newer remote still wins once it carries a real stamp.
        XCTAssertEqual(
            resolver.resolve(
                local: profile("local", modifiedAt: nil),
                remote: profile("remote", modifiedAt: nil),
                activeLocalSessionRecordNames: []
            ).fields["host"],
            "local"
        )
        // Remote stamped, local unstamped (unknown = old) → remote wins.
        XCTAssertEqual(
            resolver.resolve(
                local: profile("local", modifiedAt: nil),
                remote: profile("remote", modifiedAt: "1"),
                activeLocalSessionRecordNames: []
            ).fields["host"],
            "remote"
        )
    }

    func testPrivateSyncChangeProcessorAppliesChangesDeletesAndStoresToken() {
        let localWorkspace = PrivateSyncRecord(
            recordType: "Workspace",
            recordName: "workspace-current",
            fields: ["name": "Local", "activeSession": "local", "modifiedAt": "100"]
        )
        let staleSnippet = PrivateSyncRecord(
            recordType: "Snippet",
            recordName: "snippet-old",
            fields: ["title": "Old"]
        )
        let changedWorkspace = PrivateSyncRecord(
            recordType: "Workspace",
            recordName: "workspace-current",
            fields: ["name": "Remote", "activeSession": "remote", "modifiedAt": "200"]
        )
        let newSnippet = PrivateSyncRecord(
            recordType: "Snippet",
            recordName: "snippet-new",
            fields: ["title": "New"]
        )
        let changeSet = PrivateSyncChangeSet(
            changedRecords: [changedWorkspace, newSnippet],
            deletedRecordNames: ["snippet-old", "workspace-current"],
            newChangeToken: .init(rawValue: "token-2")
        )

        let result = PrivateSyncChangeProcessor().process(
            localRecords: [localWorkspace, staleSnippet],
            changeSet: changeSet,
            previousChangeToken: .init(rawValue: "token-1"),
            activeLocalSessionRecordNames: ["workspace-current"]
        )

        XCTAssertEqual(result.changeToken?.rawValue, "token-2")
        XCTAssertEqual(result.appliedChangeCount, 3)
        XCTAssertEqual(
            result.records,
            [
                newSnippet,
                localWorkspace
            ]
        )
    }

    func testPrivateSyncEngineRuntimeMapsCloudKitStyleEventsIntoAppSyncWork() async {
        let localWorkspace = PrivateSyncRecord(
            recordType: "Workspace",
            recordName: "workspace-debug",
            fields: ["name": "Local", "panelIDs": "terminal", "modifiedAt": "100"]
        )
        let remoteWorkspace = PrivateSyncRecord(
            recordType: "Workspace",
            recordName: "workspace-debug",
            fields: ["name": "Remote", "panelIDs": "terminal,ai", "modifiedAt": "200"]
        )
        let newSnippet = PrivateSyncRecord(
            recordType: "Snippet",
            recordName: "snippet-user-runtime",
            fields: ["title": "Runtime", "body": "sync"]
        )
        var runtime = PrivateSyncEngineRuntime(
            coordinator: PrivateSyncAppEventCoordinator(
                eventLoop: PrivateSyncEventLoop(scheduler: PrivateSyncScheduler(debounceSeconds: 5)),
                fetchRecordTypes: ["Workspace"]
            ),
            changeToken: .init(rawValue: "token-1")
        )
        var savedBatches: [[PrivateSyncRecord]] = []

        let scheduledPush = await runtime.handle(
            event: .localRecordsChanged,
            at: 10,
            records: [localWorkspace],
            activeLocalSessionRecordNames: [],
            save: { records in
                savedBatches.append(records)
                return records
            },
            fetch: { _ in [] }
        )
        XCTAssertEqual(
            scheduledPush.appEventStep?.eventLoopStep.scheduledOperation,
            PrivateSyncOperation(kind: .push, reason: .localChange, earliestRunAt: 15)
        )

        let sentChanges = await runtime.handle(
            event: .willSendChanges,
            at: 15,
            records: [localWorkspace],
            activeLocalSessionRecordNames: [],
            save: { records in
                savedBatches.append(records)
                return records
            },
            fetch: { _ in [] }
        )
        XCTAssertEqual(savedBatches, [[localWorkspace]])
        XCTAssertEqual(sentChanges.appEventStep?.savedRecordCount, 1)

        let fetchedChanges = await runtime.handle(
            event: .fetchedDatabaseChanges(
                .init(
                    changedRecords: [remoteWorkspace, newSnippet],
                    deletedRecordNames: [],
                    newChangeToken: .init(rawValue: "token-2")
                )
            ),
            at: 20,
            records: [localWorkspace],
            activeLocalSessionRecordNames: []
        )
        XCTAssertEqual(fetchedChanges.records, [newSnippet, remoteWorkspace])
        XCTAssertEqual(fetchedChanges.changeToken?.rawValue, "token-2")
        XCTAssertEqual(fetchedChanges.appliedChangeCount, 2)

        let accountFetch = await runtime.handle(
            event: .accountChanged(.available),
            at: 25,
            records: fetchedChanges.records,
            activeLocalSessionRecordNames: [],
            save: { records in records },
            fetch: { recordType in
                XCTAssertEqual(recordType, "Workspace")
                return [remoteWorkspace]
            }
        )
        XCTAssertEqual(accountFetch.accountState, .available)
        XCTAssertEqual(accountFetch.appEventStep?.fetchedRecordCount, 1)
    }

    func testDistributionPlanMatchesDirectDeveloperIDPRD() {
        let plan = DistributionPlan.termDefault

        XCTAssertEqual(plan.bundleIdentifier, "pl.kacper.Termy")
        XCTAssertEqual(plan.channel, .directDMG)
        XCTAssertTrue(plan.requiresDeveloperIDApplicationCertificate)
        XCTAssertTrue(plan.requiresNotarization)
        XCTAssertTrue(plan.requiresHardenedRuntime)
        XCTAssertFalse(plan.usesAppSandbox)
        XCTAssertEqual(plan.dmgName(version: "0.1.0"), "Termy-0.1.0.dmg")
    }

    func testDistributionAuditReportsMissingDirectDeveloperIDRequirements() {
        let unsigned = DistributionAudit(
            appBundleSignedWithDeveloperID: false,
            hardenedRuntimeEnabled: false,
            dmgNotarizedAndStapled: false,
            appSandboxEnabled: false
        )
        let signed = DistributionAudit(
            appBundleSignedWithDeveloperID: true,
            hardenedRuntimeEnabled: true,
            dmgNotarizedAndStapled: true,
            appSandboxEnabled: false
        )

        XCTAssertEqual(
            unsigned.missingRequirements(for: .termDefault),
            [
                .developerIDApplicationSignature,
                .hardenedRuntime,
                .notarizedAndStapledDMG
            ]
        )
        XCTAssertFalse(unsigned.satisfies(.termDefault))
        XCTAssertTrue(signed.missingRequirements(for: .termDefault).isEmpty)
        XCTAssertTrue(signed.satisfies(.termDefault))
    }

    func testFeatureCatalogCoversPRDProductAreasAndKeyboardActions() {
        let catalog = FeatureCatalog.termDefault

        XCTAssertEqual(
            Set(catalog.sections.map(\.area)),
            Set(ProductArea.allCases)
        )

        let actions = catalog.commandCenterActions
        XCTAssertTrue(actions.contains { $0.id == "open-command-center" && $0.shortcut == .command("k") })
        XCTAssertTrue(actions.contains { $0.id == "connect-ssh" })
        XCTAssertTrue(actions.contains { $0.id == "create-ssh-profile" })
        XCTAssertTrue(actions.contains { $0.id == "connect-rdp" })
        XCTAssertTrue(actions.contains { $0.id == "create-rdp-profile" })
        XCTAssertTrue(actions.contains { action in
            action.id == "restore-last-session" &&
            action.title == "Restore Last Session" &&
            action.area == .terminal &&
            action.keywords.contains("scrollback")
        })
        XCTAssertTrue(actions.contains { $0.id == "set-terminal-output-stream" })
        XCTAssertTrue(actions.contains { $0.id == "set-terminal-output-blocks" })
        XCTAssertTrue(actions.contains { $0.id == "copy-selected-command-output" })
        XCTAssertTrue(actions.contains { $0.id == "copy-last-command-output" })
        XCTAssertTrue(actions.contains { $0.id == "copy-visible-terminal-screen" })
        XCTAssertTrue(actions.contains { $0.id == "terminal-next-command-block" })
        XCTAssertTrue(actions.contains { $0.id == "terminal-previous-command-block" })
        XCTAssertTrue(actions.contains { $0.id == "terminal-toggle-command-block-fold" })
        XCTAssertTrue(actions.contains { $0.id == "toggle-ai-panel" })
        XCTAssertTrue(actions.contains { $0.id == "toggle-file-explorer" })
        XCTAssertTrue(actions.contains { $0.id == "sftp-next-item" })
        XCTAssertTrue(actions.contains { $0.id == "sftp-previous-item" })
        XCTAssertTrue(actions.contains { $0.id == "sftp-create-directory" })
        XCTAssertTrue(actions.contains { $0.id == "sftp-rename-selected" })
        XCTAssertTrue(actions.contains { $0.id == "sftp-move-selected" })
        XCTAssertTrue(actions.contains { $0.id == "sftp-delete-selected" })
        XCTAssertTrue(actions.contains { $0.id == "tile-editor-right" })
        XCTAssertTrue(actions.contains { $0.id == "tile-files-left" })
        XCTAssertTrue(actions.contains { $0.id == "tile-git-top" })
        XCTAssertTrue(actions.contains { $0.id == "tile-ai-bottom" })
        XCTAssertTrue(actions.contains { $0.id == "focus-next-pane" })
        XCTAssertTrue(actions.contains { $0.id == "toggle-ai-panel" && $0.shortcut != nil })
        XCTAssertTrue(actions.contains { $0.id == "toggle-file-explorer" && $0.shortcut != nil })
        XCTAssertTrue(actions.contains { $0.id == "tile-editor-right" && $0.shortcut != nil })
        XCTAssertTrue(actions.contains { $0.id == "tile-ai-bottom" && $0.shortcut != nil })
        XCTAssertTrue(actions.contains { $0.id == "focus-next-pane" && $0.shortcut != nil })
        XCTAssertTrue(actions.allSatisfy { !$0.title.isEmpty })
    }

    func testKeymapProfileOverridesActionShortcutsAndDetectsConflicts() {
        let catalog = FeatureCatalog.termDefault
        let profile = KeymapProfile(
            bindings: [
                "open-command-center": .commandShift("p"),
                "toggle-ai-panel": .commandShift("p"),
                "new-local-terminal": .commandOption("n")
            ]
        )

        let actions = profile.apply(to: catalog.commandCenterActions)

        XCTAssertEqual(actions.first { $0.id == "open-command-center" }?.shortcut, .commandShift("p"))
        XCTAssertEqual(actions.first { $0.id == "new-local-terminal" }?.shortcut, .commandOption("n"))
        XCTAssertEqual(
            profile.conflicts(in: catalog.commandCenterActions),
            [
                KeymapConflict(
                    shortcut: .commandShift("p"),
                    actionIDs: ["open-command-center", "toggle-ai-panel"]
                )
            ]
        )
    }

    func testKeymapProfileBuildsShortcutCheatSheetWithConflicts() {
        let catalog = FeatureCatalog.termDefault
        let profile = KeymapProfile(
            bindings: [
                "open-command-center": .commandShift("p"),
                "toggle-ai-panel": .commandShift("p")
            ]
        )

        let cheatSheet = profile.shortcutCheatSheet(for: catalog.commandCenterActions)

        let commandCenter = cheatSheet.first { $0.actionID == "open-command-center" }
        XCTAssertEqual(commandCenter?.title, "Open Command Center")
        XCTAssertEqual(commandCenter?.shortcut, .commandShift("p"))
        XCTAssertEqual(commandCenter?.conflictingActionIDs, ["open-command-center", "toggle-ai-panel"])
        XCTAssertTrue(cheatSheet.contains { $0.actionID == "connect-rdp" && $0.shortcut == .commandShift("r") })
    }

    func testConnectionProfilesSeparateConfigurationFromKeychainSecrets() {
        let ssh = ConnectionProfile.ssh(
            name: "Production Bastion",
            host: "bastion.example.test",
            user: "deploy",
            port: 2222,
            identity: .keychain("ssh-key-prod")
        )
        let rdp = ConnectionProfile.rdp(
            name: "Windows Build VM",
            host: "win.example.test",
            user: "builder",
            gateway: "rdp-gw.example.test",
            credential: .keychain("rdp-build-vm")
        )

        XCTAssertEqual(ssh.kind, .ssh)
        XCTAssertEqual(rdp.kind, .rdp)
        XCTAssertNil(ssh.inlineSecret)
        XCTAssertNil(rdp.inlineSecret)
        XCTAssertEqual(ssh.secretReferences, [.keychain("ssh-key-prod")])
        XCTAssertEqual(rdp.secretReferences, [.keychain("rdp-build-vm")])
    }

    func testRDPSessionConfigurationCoversCoreRedirectionsWithoutSecrets() {
        let profile = ConnectionProfile.rdp(
            name: "Windows Build VM",
            host: "win.example.test",
            user: "builder",
            gateway: "rdp-gw.example.test",
            credential: .keychain("rdp-build-vm")
        )
        let descriptor = try! RDPSessionDescriptor(
            profile: profile,
            resolution: .init(width: 1920, height: 1080),
            scale: 1.5,
            localFolderPath: "/Users/kacper/Projects"
        )

        XCTAssertEqual(descriptor.host, "win.example.test")
        XCTAssertEqual(descriptor.gateway, "rdp-gw.example.test")
        XCTAssertEqual(descriptor.redirections, [.clipboard, .folderDrive("/Users/kacper/Projects"), .audioOutput])
        XCTAssertEqual(descriptor.secretReferences, [.keychain("rdp-build-vm")])
        XCTAssertNil(descriptor.inlinePassword)
    }

    func testRDPReconnectPolicyLimitsNetworkAndTransportRetries() {
        let policy = RDPReconnectPolicy(maxAttempts: 2, retryDelaySeconds: 3)

        XCTAssertTrue(policy.shouldReconnect(disconnectReason: .networkFailure, completedAttempts: 0))
        XCTAssertTrue(policy.shouldReconnect(disconnectReason: .transportError(255), completedAttempts: 1))
        XCTAssertFalse(policy.shouldReconnect(disconnectReason: .userInitiated, completedAttempts: 0))
        XCTAssertFalse(policy.shouldReconnect(disconnectReason: .networkFailure, completedAttempts: 2))

        let profile = ConnectionProfile.rdp(
            name: "Windows Build VM",
            host: "win.example.test",
            user: "builder",
            gateway: nil,
            credential: .keychain("rdp-build-vm")
        )
        let descriptor = try! RDPSessionDescriptor(
            profile: profile,
            resolution: .init(width: 1440, height: 900),
            scale: 1,
            localFolderPath: nil,
            reconnectPolicy: policy
        )

        XCTAssertEqual(descriptor.reconnectPolicy, policy)
    }

    func testRDPSessionLifecycleSchedulesReconnectAttemptsAndStopsAtLimit() {
        let profile = ConnectionProfile.rdp(
            name: "Windows Build VM",
            host: "win.example.test",
            user: "builder",
            gateway: nil,
            credential: .keychain("rdp-build-vm")
        )
        let descriptor = try! RDPSessionDescriptor(
            profile: profile,
            resolution: .init(width: 1440, height: 900),
            scale: 1,
            localFolderPath: nil,
            reconnectPolicy: RDPReconnectPolicy(maxAttempts: 2, retryDelaySeconds: 3)
        )
        var lifecycle = RDPSessionLifecycle(descriptor: descriptor)

        XCTAssertEqual(lifecycle.state, .prepared)

        lifecycle.markConnecting()
        lifecycle.markConnected()
        let firstPlan = lifecycle.handleDisconnect(reason: .networkFailure)

        XCTAssertEqual(firstPlan, RDPReconnectPlan(attempt: 1, delaySeconds: 3))
        XCTAssertEqual(lifecycle.state, .reconnecting(attempt: 1))

        lifecycle.markConnecting()
        lifecycle.markConnected()
        let secondPlan = lifecycle.handleDisconnect(reason: .transportError(255))

        XCTAssertEqual(secondPlan, RDPReconnectPlan(attempt: 2, delaySeconds: 3))
        XCTAssertEqual(lifecycle.state, .reconnecting(attempt: 2))

        lifecycle.markConnecting()
        lifecycle.markConnected()
        let exhausted = lifecycle.handleDisconnect(reason: .transportError(255))

        XCTAssertNil(exhausted)
        XCTAssertEqual(lifecycle.state, .failed(reason: .transportError(255)))

        lifecycle.markConnecting()
        lifecycle.markConnected()
        let userDisconnect = lifecycle.handleDisconnect(reason: .userInitiated)

        XCTAssertNil(userDisconnect)
        XCTAssertEqual(lifecycle.state, .disconnected(reason: .userInitiated))
    }

    func testRDPReconnectExecutorRunsTransportAndUpdatesLifecycle() {
        let profile = ConnectionProfile.rdp(
            name: "Windows Build VM",
            host: "win.example.test",
            user: "builder",
            gateway: nil,
            credential: .keychain("rdp-build-vm")
        )
        let descriptor = try! RDPSessionDescriptor(
            profile: profile,
            resolution: .init(width: 1440, height: 900),
            scale: 1,
            localFolderPath: nil,
            reconnectPolicy: RDPReconnectPolicy(maxAttempts: 3, retryDelaySeconds: 3)
        )
        var lifecycle = RDPSessionLifecycle(descriptor: descriptor)
        lifecycle.markConnected()
        let firstPlan = lifecycle.handleDisconnect(reason: .networkFailure)!
        var attemptedHosts: [String] = []
        var attemptedNumbers: [Int] = []

        let success = RDPReconnectExecutor().execute(plan: firstPlan, lifecycle: &lifecycle) { descriptor, plan in
            attemptedHosts.append(descriptor.host)
            attemptedNumbers.append(plan.attempt)
            return .connected
        }

        XCTAssertEqual(attemptedHosts, ["win.example.test"])
        XCTAssertEqual(attemptedNumbers, [1])
        XCTAssertEqual(success, RDPReconnectExecution(plan: firstPlan, result: .connected, followUpPlan: nil))
        XCTAssertEqual(lifecycle.state, .connected)

        let secondPlan = lifecycle.handleDisconnect(reason: .networkFailure)!
        let failure = RDPReconnectExecutor().execute(plan: secondPlan, lifecycle: &lifecycle) { _, _ in
            .disconnected(.transportError(42))
        }

        XCTAssertEqual(
            failure,
            RDPReconnectExecution(
                plan: secondPlan,
                result: .disconnected(.transportError(42)),
                followUpPlan: RDPReconnectPlan(attempt: 3, delaySeconds: 3)
            )
        )
        XCTAssertEqual(lifecycle.state, .reconnecting(attempt: 3))
    }

    func testRDPClipboardBridgeBuildsDeduplicatedClipboardMessages() {
        let profile = ConnectionProfile.rdp(
            name: "Windows Build VM",
            host: "win.example.test",
            user: "builder",
            gateway: nil,
            credential: .keychain("rdp-build-vm")
        )
        let descriptor = try! RDPSessionDescriptor(
            profile: profile,
            resolution: .init(width: 1440, height: 900),
            scale: 1,
            localFolderPath: nil
        )
        var bridge = RDPClipboardBridge(descriptor: descriptor)

        XCTAssertTrue(bridge.isEnabled)
        XCTAssertEqual(
            bridge.captureLocalClipboard(text: "copy from mac", changeCount: 4),
            RDPClipboardMessage(direction: .localToRemote, text: "copy from mac", sequence: 4)
        )
        XCTAssertNil(bridge.captureLocalClipboard(text: "copy from mac", changeCount: 4))
        XCTAssertEqual(
            bridge.receiveRemoteClipboard(text: "copy from windows", sequence: 7),
            RDPClipboardMessage(direction: .remoteToLocal, text: "copy from windows", sequence: 7)
        )

        var disabled = RDPClipboardBridge(redirections: [.audioOutput])
        XCTAssertFalse(disabled.isEnabled)
        XCTAssertNil(disabled.captureLocalClipboard(text: "ignored", changeCount: 1))
        XCTAssertNil(disabled.receiveRemoteClipboard(text: "ignored", sequence: 1))
    }

    func testRDPClipboardSynchronizerPollsLocalClipboardAndWritesRemoteClipboard() {
        var synchronizer = RDPClipboardSynchronizer(bridge: RDPClipboardBridge(redirections: [.clipboard]))
        var localPasteboardWrites: [String] = []

        XCTAssertEqual(
            synchronizer.pollLocalClipboard(snapshot: RDPClipboardSnapshot(text: "copy from mac", changeCount: 12)),
            RDPClipboardMessage(direction: .localToRemote, text: "copy from mac", sequence: 12)
        )
        XCTAssertNil(synchronizer.pollLocalClipboard(snapshot: RDPClipboardSnapshot(text: "copy from mac", changeCount: 12)))
        XCTAssertEqual(
            synchronizer.pollLocalClipboard(snapshot: RDPClipboardSnapshot(text: "new copy", changeCount: 13)),
            RDPClipboardMessage(direction: .localToRemote, text: "new copy", sequence: 13)
        )

        let remoteMessage = synchronizer.applyRemoteClipboard(text: "copy from windows", sequence: 4) { text in
            localPasteboardWrites.append(text)
        }

        XCTAssertEqual(
            remoteMessage,
            RDPClipboardMessage(direction: .remoteToLocal, text: "copy from windows", sequence: 4)
        )
        XCTAssertEqual(localPasteboardWrites, ["copy from windows"])

        XCTAssertNil(synchronizer.applyRemoteClipboard(text: "copy from windows", sequence: 4) { text in
            localPasteboardWrites.append(text)
        })
        XCTAssertEqual(localPasteboardWrites, ["copy from windows"])
    }

    func testRDPClipboardVirtualChannelMessageBuildsUnicodeTextFormatDataResponse() throws {
        let message = RDPClipboardVirtualChannelMessage.formatDataResponse(text: "Hi")
        let encoded = message.encoded

        XCTAssertEqual(encoded, Data([
            0x05, 0x00, 0x01, 0x00,
            0x06, 0x00, 0x00, 0x00,
            0x48, 0x00, 0x69, 0x00, 0x00, 0x00
        ]))
        XCTAssertEqual(try RDPClipboardVirtualChannelMessage.parse(encoded), message)
    }

    func testRDPClipboardVirtualChannelMessageBuildsUnicodeTextFormatDataRequest() throws {
        let message = RDPClipboardVirtualChannelMessage.formatDataRequest(.unicodeText)
        let encoded = message.encoded

        XCTAssertEqual(encoded, Data([
            0x04, 0x00, 0x00, 0x00,
            0x04, 0x00, 0x00, 0x00,
            0x0d, 0x00, 0x00, 0x00
        ]))
        XCTAssertEqual(try RDPClipboardVirtualChannelMessage.parse(encoded), message)
    }

    func testRDPClipboardVirtualChannelMessageBuildsUnicodeTextFormatList() throws {
        let message = RDPClipboardVirtualChannelMessage.formatList([.unicodeText])
        let encoded = message.encoded

        XCTAssertEqual(encoded.prefix(12), Data([
            0x02, 0x00, 0x00, 0x00,
            0x24, 0x00, 0x00, 0x00,
            0x0d, 0x00, 0x00, 0x00
        ]))
        XCTAssertEqual(encoded.count, 44)
        XCTAssertEqual(encoded.suffix(32), Data(repeating: 0, count: 32))
        XCTAssertEqual(try RDPClipboardVirtualChannelMessage.parse(encoded), message)
    }

    func testRDPClipboardVirtualChannelMessageBuildsSuccessfulFormatListResponse() throws {
        let message = RDPClipboardVirtualChannelMessage.formatListResponse(isSuccessful: true)
        let encoded = message.encoded

        XCTAssertEqual(encoded, Data([
            0x03, 0x00, 0x01, 0x00,
            0x00, 0x00, 0x00, 0x00
        ]))
        XCTAssertEqual(try RDPClipboardVirtualChannelMessage.parse(encoded), message)
    }

    func testRDPClipboardVirtualChannelExchangeRequestsUnicodeTextFromRemoteFormatList() {
        let exchange = RDPClipboardVirtualChannelExchange()

        XCTAssertEqual(
            exchange.outboundMessages(
                for: .formatList([.unicodeText]),
                localClipboardText: nil
            ),
            [
                .formatListResponse(isSuccessful: true),
                .formatDataRequest(.unicodeText)
            ]
        )
    }

    func testRDPClipboardVirtualChannelExchangeRespondsToUnicodeTextDataRequest() {
        let exchange = RDPClipboardVirtualChannelExchange()

        XCTAssertEqual(
            exchange.outboundMessages(
                for: .formatDataRequest(.unicodeText),
                localClipboardText: "from mac"
            ),
            [
                .formatDataResponse(text: "from mac")
            ]
        )
        XCTAssertEqual(
            exchange.outboundMessages(
                for: .formatDataRequest(.unicodeText),
                localClipboardText: nil
            ),
            []
        )
    }

    func testRDPDriveBridgeMapsRemoteDrivePathsInsideSharedFolder() {
        let bridge = RDPDriveBridge(redirections: [.folderDrive("/Users/kacper/Projects")])

        XCTAssertTrue(bridge.isEnabled)
        XCTAssertEqual(
            bridge.localURL(forRemotePath: #"Termy\Sources\main.swift"#)?.path,
            "/Users/kacper/Projects/Termy/Sources/main.swift"
        )
        XCTAssertEqual(
            bridge.localURL(forRemotePath: "/Termy/docs/PRD.md")?.path,
            "/Users/kacper/Projects/Termy/docs/PRD.md"
        )
        XCTAssertNil(bridge.localURL(forRemotePath: #"Termy\..\Secrets.txt"#))

        let disabled = RDPDriveBridge(redirections: [.clipboard, .audioOutput])
        XCTAssertFalse(disabled.isEnabled)
        XCTAssertNil(disabled.localURL(forRemotePath: "Termy/README.md"))
    }

    func testRDPDriveBridgeBuildsProtocolFileRequestsInsideSharedFolder() {
        let bridge = RDPDriveBridge(redirections: [.folderDrive("/Users/kacper/Projects")])

        XCTAssertEqual(
            bridge.localFileRequest(for: .listDirectory(remotePath: "Termy")),
            RDPDriveLocalFileRequest(
                kind: .listDirectory,
                localURL: URL(fileURLWithPath: "/Users/kacper/Projects/Termy"),
                byteCount: nil
            )
        )
        XCTAssertEqual(
            bridge.localFileRequest(for: .readFile(remotePath: #"Termy\README.md"#)),
            RDPDriveLocalFileRequest(
                kind: .readFile,
                localURL: URL(fileURLWithPath: "/Users/kacper/Projects/Termy/README.md"),
                byteCount: nil
            )
        )
        XCTAssertEqual(
            bridge.localFileRequest(for: .writeFile(remotePath: "Termy/out.log", byteCount: 512)),
            RDPDriveLocalFileRequest(
                kind: .writeFile,
                localURL: URL(fileURLWithPath: "/Users/kacper/Projects/Termy/out.log"),
                byteCount: 512
            )
        )
        XCTAssertNil(bridge.localFileRequest(for: .readFile(remotePath: "../Secrets.txt")))

        let disabled = RDPDriveBridge(redirections: [.clipboard])
        XCTAssertNil(disabled.localFileRequest(for: .listDirectory(remotePath: "Termy")))
    }

    func testRDPDriveBridgeRejectsSymlinkEscapeFromSharedFolder() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-rdp-root-\(UUID().uuidString)", isDirectory: true)
        let outside = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-rdp-outside-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: outside)
        }
        try "secret".write(to: outside.appendingPathComponent("secret.txt"), atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("outside"),
            withDestinationURL: outside
        )

        let bridge = RDPDriveBridge(redirections: [.folderDrive(root.path)])

        XCTAssertNil(bridge.localURL(forRemotePath: "outside/secret.txt"))
        XCTAssertNil(bridge.localFileRequest(for: .readFile(remotePath: "outside/secret.txt")))
    }

    func testRDPDriveLocalFileExecutorListsReadsAndWritesMappedRequests() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-rdp-drive-\(UUID().uuidString)", isDirectory: true)
        let shared = root.appendingPathComponent("Termy", isDirectory: true)
        try FileManager.default.createDirectory(at: shared, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("hello".utf8).write(to: shared.appendingPathComponent("README.md"))

        let bridge = RDPDriveBridge(redirections: [.folderDrive(root.path)])
        let executor = RDPDriveLocalFileExecutor()

        let listResponse = try executor.execute(bridge.localFileRequest(for: .listDirectory(remotePath: "Termy"))!)
        XCTAssertEqual(listResponse.kind, .listDirectory)
        XCTAssertEqual(listResponse.entries, [
            LocalFileItem(name: "README.md", relativePath: "README.md", isDirectory: false, byteCount: 5)
        ])

        let readResponse = try executor.execute(bridge.localFileRequest(for: .readFile(remotePath: "Termy/README.md"))!)
        XCTAssertEqual(readResponse.kind, .readFile)
        XCTAssertEqual(readResponse.data, Data("hello".utf8))

        let payload = Data("remote output".utf8)
        let writeResponse = try executor.execute(
            bridge.localFileRequest(for: .writeFile(remotePath: "Termy/out.log", byteCount: payload.count))!,
            payload: payload
        )
        XCTAssertEqual(writeResponse.kind, .writeFile)
        XCTAssertEqual(writeResponse.bytesWritten, payload.count)
        XCTAssertEqual(
            try Data(contentsOf: shared.appendingPathComponent("out.log")),
            payload
        )
    }

    func testRDPDriveVirtualChannelBuildsClientAnnounceNameAndDriveDeviceList() throws {
        let serverAnnounce = Data([
            0x72, 0x44, 0x6e, 0x49,
            0x01, 0x00, 0x0c, 0x00,
            0x44, 0x33, 0x22, 0x11
        ])
        let message = try RDPDriveVirtualChannelMessage.parse(serverAnnounce)
        XCTAssertEqual(
            message,
            .serverAnnounce(versionMajor: 1, versionMinor: 12, clientID: 0x1122_3344)
        )

        let exchange = RDPDriveVirtualChannelExchange(clientName: "TERMY-MAC", driveName: "Termy", deviceID: 3)
        XCTAssertEqual(
            exchange.outboundMessages(for: message, localFolderPath: "/Users/kacper/Projects"),
            [
                .clientAnnounceReply(versionMinor: 12, clientID: 0x1122_3344),
                .clientName("TERMY-MAC")
            ]
        )

        XCTAssertEqual(
            RDPDriveVirtualChannelMessage.clientAnnounceReply(versionMinor: 12, clientID: 0x1122_3344).encoded,
            Data([
                0x72, 0x44, 0x43, 0x43,
                0x01, 0x00, 0x0c, 0x00,
                0x44, 0x33, 0x22, 0x11
            ])
        )
        XCTAssertEqual(
            RDPDriveVirtualChannelMessage.clientName("TERMY-MAC").encoded,
            Data([
                0x72, 0x44, 0x4e, 0x43,
                0x01, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00,
                0x14, 0x00, 0x00, 0x00,
                0x54, 0x00, 0x45, 0x00, 0x52, 0x00, 0x4d, 0x00,
                0x59, 0x00, 0x2d, 0x00, 0x4d, 0x00, 0x41, 0x00,
                0x43, 0x00, 0x00, 0x00
            ])
        )

        let deviceList = RDPDriveVirtualChannelMessage.deviceListAnnounce([
            RDPDriveDeviceAnnounce(deviceID: 3, preferredDOSName: "Termy", fullName: "Termy")
        ]).encoded
        XCTAssertEqual(deviceList.prefix(24), Data([
            0x72, 0x44, 0x41, 0x44,
            0x01, 0x00, 0x00, 0x00,
            0x08, 0x00, 0x00, 0x00,
            0x03, 0x00, 0x00, 0x00,
            0x54, 0x65, 0x72, 0x6d, 0x79, 0x00, 0x00, 0x00
        ]))
        XCTAssertEqual(deviceList.suffix(12), Data([
            0x54, 0x00, 0x65, 0x00, 0x72, 0x00,
            0x6d, 0x00, 0x79, 0x00, 0x00, 0x00
        ]))
    }

    func testRDPDriveVirtualChannelRespondsToServerClientIDConfirmWithCapabilityAndDriveList() throws {
        let serverClientIDConfirm = Data([
            0x72, 0x44, 0x43, 0x43,
            0x01, 0x00, 0x0c, 0x00,
            0x03, 0x00, 0x00, 0x00
        ])
        let message = try RDPDriveVirtualChannelMessage.parse(serverClientIDConfirm)
        XCTAssertEqual(
            message,
            .serverClientIDConfirm(versionMajor: 1, versionMinor: 12, clientID: 3)
        )

        let exchange = RDPDriveVirtualChannelExchange(clientName: "TERMY-MAC", driveName: "Termy", deviceID: 3)
        XCTAssertEqual(
            exchange.outboundMessages(for: message, localFolderPath: "/Users/kacper/Projects"),
            [
                .clientCoreCapabilityResponse,
                .deviceListAnnounce([
                    RDPDriveDeviceAnnounce(deviceID: 3, preferredDOSName: "Termy", fullName: "Termy")
                ])
            ]
        )

        XCTAssertEqual(
            RDPDriveVirtualChannelMessage.clientCoreCapabilityResponse.encoded,
            Data([
                0x72, 0x44, 0x50, 0x43,
                0x02, 0x00, 0x00, 0x00,
                0x01, 0x00, 0x2c, 0x00, 0x02, 0x00, 0x00, 0x00,
                0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x01, 0x00, 0x0c, 0x00, 0xff, 0xff, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x07, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x02, 0x00, 0x00, 0x00,
                0x04, 0x00, 0x08, 0x00, 0x02, 0x00, 0x00, 0x00
            ])
        )
    }

    func testRDPDriveVirtualChannelParsesServerDeviceAnnounceResponse() throws {
        let serverDeviceResponse = Data([
            0x72, 0x44, 0x72, 0x64,
            0x01, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00
        ])

        XCTAssertEqual(
            try RDPDriveVirtualChannelMessage.parse(serverDeviceResponse),
            .serverDeviceAnnounceResponse(deviceID: 1, resultCode: 0)
        )

        let exchange = RDPDriveVirtualChannelExchange(clientName: "TERMY-MAC", driveName: "Termy")
        XCTAssertEqual(
            exchange.outboundMessages(
                for: .serverDeviceAnnounceResponse(deviceID: 1, resultCode: 0),
                localFolderPath: "/Users/kacper/Projects"
            ),
            []
        )
    }

    func testRDPDriveVirtualChannelParsesDeviceIORequestHeaderAndBuildsCompletion() throws {
        let request = Data([
            0x72, 0x44, 0x52, 0x49,
            0x01, 0x00, 0x00, 0x00,
            0x07, 0x00, 0x00, 0x00,
            0x44, 0x33, 0x22, 0x11,
            0x03, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00,
            0xde, 0xad, 0xbe, 0xef
        ])

        XCTAssertEqual(
            try RDPDriveVirtualChannelMessage.parse(request),
            .deviceIORequest(RDPDriveDeviceIORequest(
                deviceID: 1,
                fileID: 7,
                completionID: 0x1122_3344,
                majorFunction: .read,
                minorFunction: 0,
                payload: Data([0xde, 0xad, 0xbe, 0xef])
            ))
        )

        XCTAssertEqual(
            RDPDriveVirtualChannelMessage.deviceIOCompletion(RDPDriveDeviceIOCompletion(
                deviceID: 1,
                completionID: 0x1122_3344,
                ioStatus: 0,
                payload: Data([0xaa, 0xbb])
            )).encoded,
            Data([
                0x72, 0x44, 0x43, 0x49,
                0x01, 0x00, 0x00, 0x00,
                0x44, 0x33, 0x22, 0x11,
                0x00, 0x00, 0x00, 0x00,
                0xaa, 0xbb
            ])
        )
    }

    func testRDPDriveDeviceIOHandlerCompletesCreateReadAndWriteRequests() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-rdp-device-io-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Termy"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let fileURL = root.appendingPathComponent("Termy/readme.txt")
        try Data("read me".utf8).write(to: fileURL)

        var handler = RDPDriveDeviceIOHandler(redirections: [.folderDrive(root.path)])
        let create = try handler.completion(for: RDPDriveDeviceIORequest(
            deviceID: 1,
            fileID: 0,
            completionID: 0x10,
            majorFunction: .create,
            minorFunction: 0,
            payload: Self.rdpdrCreatePayload(path: "Termy/readme.txt")
        ))
        XCTAssertEqual(create, RDPDriveDeviceIOCompletion(
            deviceID: 1,
            completionID: 0x10,
            ioStatus: 0,
            payload: Data([0x01, 0x00, 0x00, 0x00, 0x00])
        ))

        let read = try handler.completion(for: RDPDriveDeviceIORequest(
            deviceID: 1,
            fileID: 1,
            completionID: 0x11,
            majorFunction: .read,
            minorFunction: 0,
            payload: Self.rdpdrReadWriteHeader(length: 4, offset: 0)
        ))
        XCTAssertEqual(read, RDPDriveDeviceIOCompletion(
            deviceID: 1,
            completionID: 0x11,
            ioStatus: 0,
            payload: Data([0x04, 0x00, 0x00, 0x00]) + Data("read".utf8)
        ))

        let write = try handler.completion(for: RDPDriveDeviceIORequest(
            deviceID: 1,
            fileID: 1,
            completionID: 0x12,
            majorFunction: .write,
            minorFunction: 0,
            payload: Self.rdpdrReadWriteHeader(length: 3, offset: 5) + Data("!!!".utf8)
        ))
        XCTAssertEqual(write, RDPDriveDeviceIOCompletion(
            deviceID: 1,
            completionID: 0x12,
            ioStatus: 0,
            payload: Data([0x03, 0x00, 0x00, 0x00])
        ))
        XCTAssertEqual(try Data(contentsOf: fileURL), Data("read !!!".utf8))
    }

    func testRDPDriveDeviceIOHandlerCreatesNewFileForCreateDispositionFileCreate() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-rdp-device-create-file-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Termy"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let fileURL = root.appendingPathComponent("Termy/new.txt")

        var handler = RDPDriveDeviceIOHandler(redirections: [.folderDrive(root.path)])
        let create = try handler.completion(for: RDPDriveDeviceIORequest(
            deviceID: 1,
            fileID: 0,
            completionID: 0x13,
            majorFunction: .create,
            minorFunction: 0,
            payload: Self.rdpdrCreatePayload(path: "Termy/new.txt", createDisposition: 0x02)
        ))
        XCTAssertEqual(create.ioStatus, 0)
        XCTAssertEqual(create.payload, Data([0x01, 0x00, 0x00, 0x00, 0x00]))
        XCTAssertEqual(try Data(contentsOf: fileURL), Data())

        let write = try handler.completion(for: RDPDriveDeviceIORequest(
            deviceID: 1,
            fileID: 1,
            completionID: 0x14,
            majorFunction: .write,
            minorFunction: 0,
            payload: Self.rdpdrReadWriteHeader(length: 5, offset: 0) + Data("hello".utf8)
        ))

        XCTAssertEqual(write.ioStatus, 0)
        XCTAssertEqual(try Data(contentsOf: fileURL), Data("hello".utf8))
    }

    func testRDPDriveDeviceIOHandlerRejectsFileOpenForMissingPath() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-rdp-device-open-missing-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Termy"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        var handler = RDPDriveDeviceIOHandler(redirections: [.folderDrive(root.path)])
        let create = try handler.completion(for: RDPDriveDeviceIORequest(
            deviceID: 1,
            fileID: 0,
            completionID: 0x16,
            majorFunction: .create,
            minorFunction: 0,
            payload: Self.rdpdrCreatePayload(path: "Termy/missing.txt", createDisposition: 0x01)
        ))

        XCTAssertEqual(create.ioStatus, 0xc000_0001)
        XCTAssertEqual(create.payload, Data())
        XCTAssertTrue(handler.fileHandles.isEmpty)
    }

    func testRDPDriveDeviceIOHandlerCreatesNewDirectoryForDirectoryCreateOptions() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-rdp-device-create-directory-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Termy"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let directoryURL = root.appendingPathComponent("Termy/NewFolder", isDirectory: true)

        var handler = RDPDriveDeviceIOHandler(redirections: [.folderDrive(root.path)])
        let create = try handler.completion(for: RDPDriveDeviceIORequest(
            deviceID: 1,
            fileID: 0,
            completionID: 0x15,
            majorFunction: .create,
            minorFunction: 0,
            payload: Self.rdpdrCreatePayload(
                path: "Termy/NewFolder",
                createDisposition: 0x02,
                createOptions: 0x01
            )
        ))

        var isDirectory = ObjCBool(false)
        XCTAssertEqual(create.ioStatus, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
    }

    func testRDPDriveDeviceIOHandlerCompletesQueryInformationWithFileStandardInformation() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-rdp-query-information-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Termy"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("read me".utf8).write(to: root.appendingPathComponent("Termy/readme.txt"))

        var handler = RDPDriveDeviceIOHandler(redirections: [.folderDrive(root.path)])
        _ = try handler.completion(for: RDPDriveDeviceIORequest(
            deviceID: 1,
            fileID: 0,
            completionID: 0x18,
            majorFunction: .create,
            minorFunction: 0,
            payload: Self.rdpdrCreatePayload(path: "Termy/readme.txt")
        ))

        let completion = try handler.completion(for: RDPDriveDeviceIORequest(
            deviceID: 1,
            fileID: 1,
            completionID: 0x19,
            majorFunction: .queryInformation,
            minorFunction: 0,
            payload: Self.rdpdrQueryInformationPayload(fsInformationClass: 0x05)
        ))

        XCTAssertEqual(completion.ioStatus, 0)
        XCTAssertEqual(completion.payload.uint32LEForTest(at: 0), 22)
        XCTAssertEqual(completion.payload.uint64LEForTest(at: 12), 7)
        XCTAssertEqual(completion.payload.uint32LEForTest(at: 20), 1)
        XCTAssertEqual(completion.payload[24], 0)
        XCTAssertEqual(completion.payload[25], 0)
    }

    func testRDPDriveDeviceIOHandlerCompletesQueryInformationWithFileBasicInformation() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-rdp-basic-information-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Termy"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("read me".utf8).write(to: root.appendingPathComponent("Termy/readme.txt"))

        var handler = RDPDriveDeviceIOHandler(redirections: [.folderDrive(root.path)])
        _ = try handler.completion(for: RDPDriveDeviceIORequest(
            deviceID: 1,
            fileID: 0,
            completionID: 0x1a,
            majorFunction: .create,
            minorFunction: 0,
            payload: Self.rdpdrCreatePayload(path: "Termy/readme.txt")
        ))

        let completion = try handler.completion(for: RDPDriveDeviceIORequest(
            deviceID: 1,
            fileID: 1,
            completionID: 0x1b,
            majorFunction: .queryInformation,
            minorFunction: 0,
            payload: Self.rdpdrQueryInformationPayload(fsInformationClass: 0x04)
        ))

        XCTAssertEqual(completion.ioStatus, 0)
        XCTAssertEqual(completion.payload.uint32LEForTest(at: 0), 36)
        XCTAssertEqual(completion.payload.uint32LEForTest(at: 36), 0x20)
        XCTAssertEqual(completion.payload.count, 40)
    }

    func testRDPDriveDeviceIOHandlerCompletesQueryInformationWithFileAttributeTagInformation() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-rdp-attribute-tag-information-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Termy"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("read me".utf8).write(to: root.appendingPathComponent("Termy/readme.txt"))

        var handler = RDPDriveDeviceIOHandler(redirections: [.folderDrive(root.path)])
        _ = try handler.completion(for: RDPDriveDeviceIORequest(
            deviceID: 1,
            fileID: 0,
            completionID: 0x1c,
            majorFunction: .create,
            minorFunction: 0,
            payload: Self.rdpdrCreatePayload(path: "Termy/readme.txt")
        ))

        let completion = try handler.completion(for: RDPDriveDeviceIORequest(
            deviceID: 1,
            fileID: 1,
            completionID: 0x1d,
            majorFunction: .queryInformation,
            minorFunction: 0,
            payload: Self.rdpdrQueryInformationPayload(fsInformationClass: 0x23)
        ))

        XCTAssertEqual(completion.ioStatus, 0)
        XCTAssertEqual(completion.payload.uint32LEForTest(at: 0), 8)
        XCTAssertEqual(completion.payload.uint32LEForTest(at: 4), 0x20)
        XCTAssertEqual(completion.payload.uint32LEForTest(at: 8), 0)
    }

    func testRDPDriveDeviceIOHandlerCompletesQueryVolumeInformationWithFileFsAttributeInformation() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-rdp-query-volume-attribute-information-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Termy"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        var handler = RDPDriveDeviceIOHandler(redirections: [.folderDrive(root.path)])
        _ = try handler.completion(for: RDPDriveDeviceIORequest(
            deviceID: 1,
            fileID: 0,
            completionID: 0x20,
            majorFunction: .create,
            minorFunction: 0,
            payload: Self.rdpdrCreatePayload(path: "Termy")
        ))

        let completion = try handler.completion(for: RDPDriveDeviceIORequest(
            deviceID: 1,
            fileID: 1,
            completionID: 0x21,
            majorFunction: .queryVolumeInformation,
            minorFunction: 0,
            payload: Self.rdpdrQueryVolumeInformationPayload(fsInformationClass: 0x05)
        ))

        XCTAssertEqual(completion.ioStatus, 0)
        XCTAssertGreaterThanOrEqual(completion.payload.count, 24)
        guard completion.payload.count >= 24 else { return }
        XCTAssertEqual(completion.payload.uint32LEForTest(at: 0), 22)
        XCTAssertEqual(completion.payload.uint32LEForTest(at: 4), 0x0000_0007)
        XCTAssertEqual(completion.payload.uint32LEForTest(at: 8), 255)
        XCTAssertEqual(completion.payload.uint32LEForTest(at: 12), 10)
        XCTAssertEqual(completion.payload.windowsUTF16String(at: 16, byteCount: 10), "Termy")
    }

    func testRDPDriveDeviceIOHandlerCompletesQueryVolumeInformationWithFileFsSizeInformation() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-rdp-query-volume-size-information-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Termy"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        var handler = RDPDriveDeviceIOHandler(redirections: [.folderDrive(root.path)])
        _ = try handler.completion(for: RDPDriveDeviceIORequest(
            deviceID: 1,
            fileID: 0,
            completionID: 0x22,
            majorFunction: .create,
            minorFunction: 0,
            payload: Self.rdpdrCreatePayload(path: "Termy")
        ))

        let completion = try handler.completion(for: RDPDriveDeviceIORequest(
            deviceID: 1,
            fileID: 1,
            completionID: 0x23,
            majorFunction: .queryVolumeInformation,
            minorFunction: 0,
            payload: Self.rdpdrQueryVolumeInformationPayload(fsInformationClass: 0x03)
        ))

        XCTAssertEqual(completion.ioStatus, 0)
        XCTAssertGreaterThanOrEqual(completion.payload.count, 28)
        guard completion.payload.count >= 28 else { return }
        XCTAssertEqual(completion.payload.uint32LEForTest(at: 0), 24)
        XCTAssertGreaterThan(completion.payload.uint64LEForTest(at: 4), 0)
        XCTAssertGreaterThan(completion.payload.uint64LEForTest(at: 12), 0)
        XCTAssertEqual(completion.payload.uint32LEForTest(at: 20), 8)
        XCTAssertEqual(completion.payload.uint32LEForTest(at: 24), 512)
    }

    func testRDPDriveDeviceIOHandlerCompletesSetInformationWithFileEndOfFileInformation() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-rdp-set-eof-information-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Termy"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let fileURL = root.appendingPathComponent("Termy/readme.txt")
        try Data("read me".utf8).write(to: fileURL)

        var handler = RDPDriveDeviceIOHandler(redirections: [.folderDrive(root.path)])
        _ = try handler.completion(for: RDPDriveDeviceIORequest(
            deviceID: 1,
            fileID: 0,
            completionID: 0x1e,
            majorFunction: .create,
            minorFunction: 0,
            payload: Self.rdpdrCreatePayload(path: "Termy/readme.txt")
        ))

        let completion = try handler.completion(for: RDPDriveDeviceIORequest(
            deviceID: 1,
            fileID: 1,
            completionID: 0x1f,
            majorFunction: .setInformation,
            minorFunction: 0,
            payload: Self.rdpdrSetInformationPayload(fsInformationClass: 0x14, buffer: Self.uint64LEForTest(4))
        ))

        XCTAssertEqual(completion.ioStatus, 0)
        XCTAssertEqual(completion.payload, Data([0x08, 0x00, 0x00, 0x00]))
        XCTAssertEqual(try Data(contentsOf: fileURL), Data("read".utf8))
    }

    func testRDPDriveDeviceIOHandlerDeletesFileMarkedWithFileDispositionInformationOnClose() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-rdp-set-disposition-information-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Termy"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let fileURL = root.appendingPathComponent("Termy/delete-me.txt")
        try Data("remove".utf8).write(to: fileURL)

        var handler = RDPDriveDeviceIOHandler(redirections: [.folderDrive(root.path)])
        _ = try handler.completion(for: RDPDriveDeviceIORequest(
            deviceID: 1,
            fileID: 0,
            completionID: 0x20,
            majorFunction: .create,
            minorFunction: 0,
            payload: Self.rdpdrCreatePayload(path: "Termy/delete-me.txt")
        ))

        let setCompletion = try handler.completion(for: RDPDriveDeviceIORequest(
            deviceID: 1,
            fileID: 1,
            completionID: 0x21,
            majorFunction: .setInformation,
            minorFunction: 0,
            payload: Self.rdpdrSetInformationPayload(fsInformationClass: 0x0d, buffer: Data())
        ))
        XCTAssertEqual(setCompletion.ioStatus, 0)
        XCTAssertEqual(setCompletion.payload, Data([0x00, 0x00, 0x00, 0x00]))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        _ = try handler.completion(for: RDPDriveDeviceIORequest(
            deviceID: 1,
            fileID: 1,
            completionID: 0x22,
            majorFunction: .close,
            minorFunction: 0,
            payload: Data()
        ))

        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testRDPDriveDeviceIOHandlerCompletesSetInformationWithFileRenameInformation() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-rdp-set-rename-information-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Termy"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let originalURL = root.appendingPathComponent("Termy/old.txt")
        let renamedURL = root.appendingPathComponent("Termy/new.txt")
        try Data("renamed".utf8).write(to: originalURL)

        var handler = RDPDriveDeviceIOHandler(redirections: [.folderDrive(root.path)])
        _ = try handler.completion(for: RDPDriveDeviceIORequest(
            deviceID: 1,
            fileID: 0,
            completionID: 0x23,
            majorFunction: .create,
            minorFunction: 0,
            payload: Self.rdpdrCreatePayload(path: "Termy/old.txt")
        ))

        let renameBuffer = Self.rdpdrRenameInformationBuffer(replaceIfExists: false, path: "Termy/new.txt")
        let completion = try handler.completion(for: RDPDriveDeviceIORequest(
            deviceID: 1,
            fileID: 1,
            completionID: 0x24,
            majorFunction: .setInformation,
            minorFunction: 0,
            payload: Self.rdpdrSetInformationPayload(fsInformationClass: 0x0a, buffer: renameBuffer)
        ))

        XCTAssertEqual(completion.ioStatus, 0)
        XCTAssertEqual(completion.payload.count, 4)
        if completion.payload.count >= 4 {
            XCTAssertEqual(completion.payload.uint32LEForTest(at: 0), UInt32(renameBuffer.count))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: originalURL.path))
        XCTAssertEqual(try Data(contentsOf: renamedURL), Data("renamed".utf8))
    }

    func testRDPDriveDeviceIOHandlerCompletesDirectoryQueryWithFileNamesInformation() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-rdp-directory-io-\(UUID().uuidString)", isDirectory: true)
        let directory = root.appendingPathComponent("Termy", isDirectory: true)
        try FileManager.default.createDirectory(at: directory.appendingPathComponent("Sources"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("read me".utf8).write(to: directory.appendingPathComponent("README.md"))

        var handler = RDPDriveDeviceIOHandler(redirections: [.folderDrive(root.path)])
        _ = try handler.completion(for: RDPDriveDeviceIORequest(
            deviceID: 1,
            fileID: 0,
            completionID: 0x20,
            majorFunction: .create,
            minorFunction: 0,
            payload: Self.rdpdrCreatePayload(path: "Termy")
        ))

        let completion = try handler.completion(for: RDPDriveDeviceIORequest(
            deviceID: 1,
            fileID: 1,
            completionID: 0x21,
            majorFunction: .directoryControl,
            minorFunction: 1,
            payload: Self.rdpdrQueryDirectoryPayload(fsInformationClass: 0x0c, initialQuery: true, path: "*")
        ))

        XCTAssertEqual(completion.deviceID, 1)
        XCTAssertEqual(completion.completionID, 0x21)
        XCTAssertEqual(completion.ioStatus, 0)
        XCTAssertEqual(Int(completion.payload.uint32LEForTest(at: 0)), completion.payload.count - 4)
        XCTAssertEqual(Self.fileNamesInformationNames(in: Data(completion.payload.dropFirst(4))), ["README.md", "Sources"])
    }

    func testRDPDriveDeviceIOHandlerCompletesDirectoryQueryWithFileDirectoryInformation() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-rdp-directory-metadata-\(UUID().uuidString)", isDirectory: true)
        let directory = root.appendingPathComponent("Termy", isDirectory: true)
        try FileManager.default.createDirectory(at: directory.appendingPathComponent("Sources"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("read me".utf8).write(to: directory.appendingPathComponent("README.md"))

        var handler = RDPDriveDeviceIOHandler(redirections: [.folderDrive(root.path)])
        _ = try handler.completion(for: RDPDriveDeviceIORequest(
            deviceID: 1,
            fileID: 0,
            completionID: 0x30,
            majorFunction: .create,
            minorFunction: 0,
            payload: Self.rdpdrCreatePayload(path: "Termy")
        ))

        let completion = try handler.completion(for: RDPDriveDeviceIORequest(
            deviceID: 1,
            fileID: 1,
            completionID: 0x31,
            majorFunction: .directoryControl,
            minorFunction: 1,
            payload: Self.rdpdrQueryDirectoryPayload(fsInformationClass: 0x01, initialQuery: true, path: "*")
        ))

        XCTAssertEqual(completion.ioStatus, 0)
        XCTAssertEqual(Int(completion.payload.uint32LEForTest(at: 0)), completion.payload.count - 4)
        XCTAssertEqual(
            Self.fileDirectoryInformationEntries(in: Data(completion.payload.dropFirst(4))),
            [
                FileDirectoryInformationForTest(name: "README.md", endOfFile: 7, attributes: 0x20),
                FileDirectoryInformationForTest(name: "Sources", endOfFile: 0, attributes: 0x10)
            ]
        )
    }

    func testRDPDriveDeviceIOHandlerCompletesDirectoryQueryWithFileFullDirectoryInformation() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-rdp-directory-full-metadata-\(UUID().uuidString)", isDirectory: true)
        let directory = root.appendingPathComponent("Termy", isDirectory: true)
        try FileManager.default.createDirectory(at: directory.appendingPathComponent("Sources"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("read me".utf8).write(to: directory.appendingPathComponent("README.md"))

        var handler = RDPDriveDeviceIOHandler(redirections: [.folderDrive(root.path)])
        _ = try handler.completion(for: RDPDriveDeviceIORequest(
            deviceID: 1,
            fileID: 0,
            completionID: 0x40,
            majorFunction: .create,
            minorFunction: 0,
            payload: Self.rdpdrCreatePayload(path: "Termy")
        ))

        let completion = try handler.completion(for: RDPDriveDeviceIORequest(
            deviceID: 1,
            fileID: 1,
            completionID: 0x41,
            majorFunction: .directoryControl,
            minorFunction: 1,
            payload: Self.rdpdrQueryDirectoryPayload(fsInformationClass: 0x02, initialQuery: true, path: "*")
        ))

        XCTAssertEqual(completion.ioStatus, 0)
        XCTAssertEqual(Int(completion.payload.uint32LEForTest(at: 0)), completion.payload.count - 4)
        XCTAssertEqual(
            Self.fileFullDirectoryInformationEntries(in: Data(completion.payload.dropFirst(4))),
            [
                FileFullDirectoryInformationForTest(name: "README.md", endOfFile: 7, attributes: 0x20, eaSize: 0),
                FileFullDirectoryInformationForTest(name: "Sources", endOfFile: 0, attributes: 0x10, eaSize: 0)
            ]
        )
    }

    func testRDPDriveDeviceIOHandlerCompletesDirectoryQueryWithFileBothDirectoryInformation() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-rdp-directory-both-metadata-\(UUID().uuidString)", isDirectory: true)
        let directory = root.appendingPathComponent("Termy", isDirectory: true)
        try FileManager.default.createDirectory(at: directory.appendingPathComponent("Sources"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("read me".utf8).write(to: directory.appendingPathComponent("README.md"))

        var handler = RDPDriveDeviceIOHandler(redirections: [.folderDrive(root.path)])
        _ = try handler.completion(for: RDPDriveDeviceIORequest(
            deviceID: 1,
            fileID: 0,
            completionID: 0x50,
            majorFunction: .create,
            minorFunction: 0,
            payload: Self.rdpdrCreatePayload(path: "Termy")
        ))

        let completion = try handler.completion(for: RDPDriveDeviceIORequest(
            deviceID: 1,
            fileID: 1,
            completionID: 0x51,
            majorFunction: .directoryControl,
            minorFunction: 1,
            payload: Self.rdpdrQueryDirectoryPayload(fsInformationClass: 0x03, initialQuery: true, path: "*")
        ))

        XCTAssertEqual(completion.ioStatus, 0)
        XCTAssertEqual(Int(completion.payload.uint32LEForTest(at: 0)), completion.payload.count - 4)
        XCTAssertEqual(
            Self.fileBothDirectoryInformationEntries(in: Data(completion.payload.dropFirst(4))),
            [
                FileBothDirectoryInformationForTest(name: "README.md", endOfFile: 7, attributes: 0x20, eaSize: 0, shortNameLength: 0),
                FileBothDirectoryInformationForTest(name: "Sources", endOfFile: 0, attributes: 0x10, eaSize: 0, shortNameLength: 0)
            ]
        )
    }

    private static func rdpdrCreatePayload(
        path: String,
        createDisposition: UInt32 = 0x01,
        createOptions: UInt32 = 0x00
    ) -> Data {
        var pathBytes = Data()
        for codeUnit in path.utf16 {
            pathBytes.append(UInt8(codeUnit & 0xff))
            pathBytes.append(UInt8((codeUnit >> 8) & 0xff))
        }
        pathBytes.append(contentsOf: [0x00, 0x00])

        var payload = Data()
        payload.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // DesiredAccess
        payload.append(contentsOf: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]) // AllocationSize
        payload.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // FileAttributes
        payload.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // SharedAccess
        payload.append(contentsOf: [
            UInt8(createDisposition & 0xff),
            UInt8((createDisposition >> 8) & 0xff),
            UInt8((createDisposition >> 16) & 0xff),
            UInt8((createDisposition >> 24) & 0xff)
        ])
        payload.append(contentsOf: [
            UInt8(createOptions & 0xff),
            UInt8((createOptions >> 8) & 0xff),
            UInt8((createOptions >> 16) & 0xff),
            UInt8((createOptions >> 24) & 0xff)
        ])
        payload.append(contentsOf: [
            UInt8(pathBytes.count & 0xff),
            UInt8((pathBytes.count >> 8) & 0xff),
            UInt8((pathBytes.count >> 16) & 0xff),
            UInt8((pathBytes.count >> 24) & 0xff)
        ])
        payload.append(pathBytes)
        return payload
    }

    private static func rdpdrReadWriteHeader(length: UInt32, offset: UInt64) -> Data {
        var payload = Data()
        payload.append(contentsOf: [
            UInt8(length & 0xff),
            UInt8((length >> 8) & 0xff),
            UInt8((length >> 16) & 0xff),
            UInt8((length >> 24) & 0xff)
        ])
        for shift in stride(from: 0, through: 56, by: 8) {
            payload.append(UInt8((offset >> UInt64(shift)) & 0xff))
        }
        payload.append(Data(repeating: 0, count: 20))
        return payload
    }

    private static func rdpdrQueryInformationPayload(fsInformationClass: UInt32, length: UInt32 = 0) -> Data {
        var payload = Data()
        payload.append(contentsOf: [
            UInt8(fsInformationClass & 0xff),
            UInt8((fsInformationClass >> 8) & 0xff),
            UInt8((fsInformationClass >> 16) & 0xff),
            UInt8((fsInformationClass >> 24) & 0xff),
            UInt8(length & 0xff),
            UInt8((length >> 8) & 0xff),
            UInt8((length >> 16) & 0xff),
            UInt8((length >> 24) & 0xff)
        ])
        payload.append(Data(repeating: 0, count: 24))
        return payload
    }

    private static func rdpdrQueryVolumeInformationPayload(fsInformationClass: UInt32, length: UInt32 = 0) -> Data {
        rdpdrQueryInformationPayload(fsInformationClass: fsInformationClass, length: length)
    }

    private static func rdpdrSetInformationPayload(fsInformationClass: UInt32, buffer: Data) -> Data {
        var payload = Data()
        payload.append(contentsOf: [
            UInt8(fsInformationClass & 0xff),
            UInt8((fsInformationClass >> 8) & 0xff),
            UInt8((fsInformationClass >> 16) & 0xff),
            UInt8((fsInformationClass >> 24) & 0xff),
            UInt8(buffer.count & 0xff),
            UInt8((buffer.count >> 8) & 0xff),
            UInt8((buffer.count >> 16) & 0xff),
            UInt8((buffer.count >> 24) & 0xff)
        ])
        payload.append(Data(repeating: 0, count: 24))
        payload.append(buffer)
        return payload
    }

    private static func rdpdrRenameInformationBuffer(replaceIfExists: Bool, path: String) -> Data {
        var pathBytes = Data()
        for codeUnit in path.utf16 {
            pathBytes.append(contentsOf: [
                UInt8(codeUnit & 0xff),
                UInt8((codeUnit >> 8) & 0xff)
            ])
        }
        var payload = Data([replaceIfExists ? 1 : 0, 0])
        let length = UInt32(pathBytes.count)
        payload.append(contentsOf: [
            UInt8(length & 0xff),
            UInt8((length >> 8) & 0xff),
            UInt8((length >> 16) & 0xff),
            UInt8((length >> 24) & 0xff)
        ])
        payload.append(pathBytes)
        return payload
    }

    private static func uint64LEForTest(_ value: UInt64) -> Data {
        var data = Data()
        for shift in stride(from: 0, through: 56, by: 8) {
            data.append(UInt8((value >> UInt64(shift)) & 0xff))
        }
        return data
    }

    private static func rdpdrQueryDirectoryPayload(
        fsInformationClass: UInt32,
        initialQuery: Bool,
        path: String
    ) -> Data {
        var pathBytes = Data()
        for codeUnit in path.utf16 {
            pathBytes.append(UInt8(codeUnit & 0xff))
            pathBytes.append(UInt8((codeUnit >> 8) & 0xff))
        }
        pathBytes.append(contentsOf: [0x00, 0x00])

        var payload = Data()
        payload.append(contentsOf: [
            UInt8(fsInformationClass & 0xff),
            UInt8((fsInformationClass >> 8) & 0xff),
            UInt8((fsInformationClass >> 16) & 0xff),
            UInt8((fsInformationClass >> 24) & 0xff)
        ])
        payload.append(initialQuery ? 1 : 0)
        payload.append(contentsOf: [
            UInt8(pathBytes.count & 0xff),
            UInt8((pathBytes.count >> 8) & 0xff),
            UInt8((pathBytes.count >> 16) & 0xff),
            UInt8((pathBytes.count >> 24) & 0xff)
        ])
        payload.append(Data(repeating: 0, count: 23))
        payload.append(pathBytes)
        return payload
    }

    private static func fileNamesInformationNames(in buffer: Data) -> [String] {
        var names: [String] = []
        var offset = 0
        while offset + 12 <= buffer.count {
            let nextOffset = Int(buffer.uint32LEForTest(at: offset))
            let nameLength = Int(buffer.uint32LEForTest(at: offset + 8))
            let nameStart = offset + 12
            let nameEnd = min(nameStart + nameLength, buffer.count)
            var units: [UInt16] = []
            var index = nameStart
            while index + 1 < nameEnd {
                units.append(buffer.uint16LEForTest(at: index))
                index += 2
            }
            names.append(String(decoding: units, as: UTF16.self))
            if nextOffset == 0 { break }
            offset += nextOffset
        }
        return names
    }

    private struct FileDirectoryInformationForTest: Equatable {
        let name: String
        let endOfFile: UInt64
        let attributes: UInt32
    }

    private static func fileDirectoryInformationEntries(in buffer: Data) -> [FileDirectoryInformationForTest] {
        var entries: [FileDirectoryInformationForTest] = []
        var offset = 0
        while offset + 64 <= buffer.count {
            let nextOffset = Int(buffer.uint32LEForTest(at: offset))
            let endOfFile = buffer.uint64LEForTest(at: offset + 40)
            let attributes = buffer.uint32LEForTest(at: offset + 56)
            let nameLength = Int(buffer.uint32LEForTest(at: offset + 60))
            let nameStart = offset + 64
            let nameEnd = min(nameStart + nameLength, buffer.count)
            var units: [UInt16] = []
            var index = nameStart
            while index + 1 < nameEnd {
                units.append(buffer.uint16LEForTest(at: index))
                index += 2
            }
            entries.append(FileDirectoryInformationForTest(
                name: String(decoding: units, as: UTF16.self),
                endOfFile: endOfFile,
                attributes: attributes
            ))
            if nextOffset == 0 { break }
            offset += nextOffset
        }
        return entries
    }

    private struct FileFullDirectoryInformationForTest: Equatable {
        let name: String
        let endOfFile: UInt64
        let attributes: UInt32
        let eaSize: UInt32
    }

    private static func fileFullDirectoryInformationEntries(in buffer: Data) -> [FileFullDirectoryInformationForTest] {
        var entries: [FileFullDirectoryInformationForTest] = []
        var offset = 0
        while offset + 68 <= buffer.count {
            let nextOffset = Int(buffer.uint32LEForTest(at: offset))
            let endOfFile = buffer.uint64LEForTest(at: offset + 40)
            let attributes = buffer.uint32LEForTest(at: offset + 56)
            let nameLength = Int(buffer.uint32LEForTest(at: offset + 60))
            let eaSize = buffer.uint32LEForTest(at: offset + 64)
            let nameStart = offset + 68
            let nameEnd = min(nameStart + nameLength, buffer.count)
            var units: [UInt16] = []
            var index = nameStart
            while index + 1 < nameEnd {
                units.append(buffer.uint16LEForTest(at: index))
                index += 2
            }
            entries.append(FileFullDirectoryInformationForTest(
                name: String(decoding: units, as: UTF16.self),
                endOfFile: endOfFile,
                attributes: attributes,
                eaSize: eaSize
            ))
            if nextOffset == 0 { break }
            offset += nextOffset
        }
        return entries
    }

    private struct FileBothDirectoryInformationForTest: Equatable {
        let name: String
        let endOfFile: UInt64
        let attributes: UInt32
        let eaSize: UInt32
        let shortNameLength: UInt8
    }

    private static func fileBothDirectoryInformationEntries(in buffer: Data) -> [FileBothDirectoryInformationForTest] {
        var entries: [FileBothDirectoryInformationForTest] = []
        var offset = 0
        while offset + 94 <= buffer.count {
            let nextOffset = Int(buffer.uint32LEForTest(at: offset))
            let endOfFile = buffer.uint64LEForTest(at: offset + 40)
            let attributes = buffer.uint32LEForTest(at: offset + 56)
            let nameLength = Int(buffer.uint32LEForTest(at: offset + 60))
            let eaSize = buffer.uint32LEForTest(at: offset + 64)
            let shortNameLength = buffer[offset + 68]
            let nameStart = offset + 94
            let nameEnd = min(nameStart + nameLength, buffer.count)
            var units: [UInt16] = []
            var index = nameStart
            while index + 1 < nameEnd {
                units.append(buffer.uint16LEForTest(at: index))
                index += 2
            }
            entries.append(FileBothDirectoryInformationForTest(
                name: String(decoding: units, as: UTF16.self),
                endOfFile: endOfFile,
                attributes: attributes,
                eaSize: eaSize,
                shortNameLength: shortNameLength
            ))
            if nextOffset == 0 { break }
            offset += nextOffset
        }
        return entries
    }

    func testRDPFrameBufferAcceptsValidFramesAndRejectsDuplicatesOrInvalidPayloads() {
        var buffer = RDPFrameBuffer()
        let frame = RDPRemoteDesktopFrame(
            sequence: 1,
            width: 2,
            height: 1,
            scale: 2,
            pixelFormat: .bgra8,
            data: Data([0, 0, 255, 255, 0, 255, 0, 255])
        )

        XCTAssertEqual(buffer.apply(frame), frame)
        XCTAssertEqual(buffer.currentFrame, frame)
        XCTAssertNil(buffer.apply(frame))
        XCTAssertNil(buffer.apply(RDPRemoteDesktopFrame(
            sequence: 2,
            width: 2,
            height: 1,
            scale: 2,
            pixelFormat: .bgra8,
            data: Data([1, 2, 3])
        )))
        XCTAssertEqual(buffer.currentFrame, frame)
    }

    func testRDPTransportEventRouterDispatchesFramesRedirectionsAndDisconnects() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-rdp-router-\(UUID().uuidString)", isDirectory: true)
        let shared = root.appendingPathComponent("Termy", isDirectory: true)
        try FileManager.default.createDirectory(at: shared, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("read me".utf8).write(to: shared.appendingPathComponent("README.md"))

        let profile = ConnectionProfile.rdp(
            name: "Windows Build VM",
            host: "win.example.test",
            user: "builder",
            gateway: nil,
            credential: .keychain("rdp-build-vm")
        )
        let descriptor = try RDPSessionDescriptor(
            profile: profile,
            resolution: .init(width: 1440, height: 900),
            scale: 1,
            localFolderPath: root.path,
            reconnectPolicy: RDPReconnectPolicy(maxAttempts: 2, retryDelaySeconds: 3)
        )
        var lifecycle = RDPSessionLifecycle(descriptor: descriptor)
        lifecycle.markConnected()
        var router = RDPTransportEventRouter(descriptor: descriptor, lifecycle: lifecycle)
        var clipboardWrites: [String] = []
        var playedAudio: [RDPAudioOutputFrame] = []

        let frame = RDPRemoteDesktopFrame(
            sequence: 1,
            width: 1,
            height: 1,
            scale: 1,
            pixelFormat: .bgra8,
            data: Data([255, 0, 0, 255])
        )
        XCTAssertEqual(
            try router.handle(.desktopFrame(frame), writeClipboard: { clipboardWrites.append($0) }, playAudio: { playedAudio.append($0) }).desktopFrame,
            frame
        )

        XCTAssertEqual(
            try router.handle(.remoteClipboard(text: "from windows", sequence: 3), writeClipboard: { clipboardWrites.append($0) }, playAudio: { playedAudio.append($0) }).clipboardMessage,
            RDPClipboardMessage(direction: .remoteToLocal, text: "from windows", sequence: 3)
        )
        XCTAssertEqual(clipboardWrites, ["from windows"])

        let driveResult = try router.handle(
            .driveOperation(.readFile(remotePath: "Termy/README.md"), payload: Data()),
            writeClipboard: { clipboardWrites.append($0) },
            playAudio: { playedAudio.append($0) }
        )
        XCTAssertEqual(driveResult.driveResponse?.data, Data("read me".utf8))

        let audioFrame = RDPAudioOutputFrame(
            sequence: 8,
            sampleRate: 48_000,
            channelCount: 2,
            format: .pcmSigned16LittleEndian,
            data: Data([0, 0, 1, 0])
        )
        XCTAssertEqual(
            try router.handle(.audioOutput(audioFrame), writeClipboard: { clipboardWrites.append($0) }, playAudio: { playedAudio.append($0) }).audioFrame,
            audioFrame
        )
        XCTAssertEqual(playedAudio, [audioFrame])

        XCTAssertEqual(
            try router.handle(.disconnected(.networkFailure), writeClipboard: { clipboardWrites.append($0) }, playAudio: { playedAudio.append($0) }).reconnectPlan,
            RDPReconnectPlan(attempt: 1, delaySeconds: 3)
        )
    }

    func testRDPInputEventMapperBuildsPointerClickForAspectFitFrame() {
        let frame = RDPRemoteDesktopFrame(
            sequence: 1,
            width: 1920,
            height: 1080,
            scale: 1,
            pixelFormat: .bgra8,
            data: Data(repeating: 0, count: 1920 * 1080 * 4)
        )

        let events = RDPInputEventMapper.pointerClickEvents(
            at: RDPInputPoint(x: 500, y: 350),
            viewport: RDPInputViewportSize(width: 1000, height: 700),
            frame: frame,
            button: .left
        )

        XCTAssertEqual(events, [
            .pointer(flags: [.move, .button1, .down], x: 960, y: 540),
            .pointer(flags: [.move, .button1], x: 960, y: 540)
        ])
    }

    func testRDPInputEventMapperRejectsClicksOutsideAspectFitImage() {
        let frame = RDPRemoteDesktopFrame(
            sequence: 1,
            width: 1920,
            height: 1080,
            scale: 1,
            pixelFormat: .bgra8,
            data: Data(repeating: 0, count: 1920 * 1080 * 4)
        )

        XCTAssertEqual(
            RDPInputEventMapper.pointerClickEvents(
                at: RDPInputPoint(x: 500, y: 20),
                viewport: RDPInputViewportSize(width: 1000, height: 700),
                frame: frame,
                button: .left
            ),
            []
        )
    }

    func testRDPKeyboardInputMapperBuildsPrintableKeyPress() {
        XCTAssertEqual(
            RDPKeyboardInputMapper.keyPressEvents(.character("a")),
            [
                .keyboard(scancode: 0x1e, isDown: true, isExtended: false),
                .keyboard(scancode: 0x1e, isDown: false, isExtended: false)
            ]
        )
    }

    func testRDPKeyboardInputMapperAddsShiftForUppercaseCharacters() {
        XCTAssertEqual(
            RDPKeyboardInputMapper.keyPressEvents(.character("A")),
            [
                .keyboard(scancode: 0x2a, isDown: true, isExtended: false),
                .keyboard(scancode: 0x1e, isDown: true, isExtended: false),
                .keyboard(scancode: 0x1e, isDown: false, isExtended: false),
                .keyboard(scancode: 0x2a, isDown: false, isExtended: false)
            ]
        )
    }

    func testRDPKeyboardInputMapperBuildsExtendedArrowKeyPress() {
        XCTAssertEqual(
            RDPKeyboardInputMapper.keyPressEvents(.special(.rightArrow)),
            [
                .keyboard(scancode: 0x4d, isDown: true, isExtended: true),
                .keyboard(scancode: 0x4d, isDown: false, isExtended: true)
            ]
        )
    }

    func testRDPKeyboardInputMapperIgnoresUnsupportedCharacters() {
        XCTAssertEqual(RDPKeyboardInputMapper.keyPressEvents(.character("ł")), [])
    }

    func testRDPAudioVirtualChannelParsesServerFormatsAndBuildsClientPCMResponse() throws {
        let pcm = RDPAudioVirtualChannelFormat.pcmSigned16LittleEndian(sampleRate: 48_000, channelCount: 2)
        let unsupported = RDPAudioVirtualChannelFormat(
            formatTag: 0x0006,
            channelCount: 2,
            samplesPerSecond: 22_050,
            averageBytesPerSecond: 44_100,
            blockAlign: 2,
            bitsPerSample: 8,
            extraData: Data()
        )
        let serverMessage = RDPAudioVirtualChannelMessage.serverAudioFormats(
            version: 6,
            lastBlockConfirmed: 9,
            formats: [unsupported, pcm]
        )

        let parsed = try RDPAudioVirtualChannelMessage.parse(serverMessage.encoded)
        XCTAssertEqual(parsed, serverMessage)

        let exchange = RDPAudioVirtualChannelExchange()
        XCTAssertEqual(
            exchange.clientFormatResponse(for: parsed),
            .clientAudioFormats(version: 6, lastBlockConfirmed: 9, formats: [pcm])
        )
    }

    func testRDPAudioVirtualChannelBuildsPCMFrameFromWaveInfoAndWavePDU() throws {
        let pcm = RDPAudioVirtualChannelFormat.pcmSigned16LittleEndian(sampleRate: 48_000, channelCount: 2)
        let waveInfo = RDPAudioWaveInfo(
            timestamp: 123,
            formatIndex: 0,
            blockNumber: 7,
            bodySize: 16,
            firstAudioBytes: Data([0x01, 0x00, 0x02, 0x00])
        )
        let continuation = Data([0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x04, 0x00])

        let frame = try RDPAudioVirtualChannelExchange().audioFrame(
            from: .waveInfo(waveInfo),
            waveContinuation: continuation,
            negotiatedFormats: [pcm],
            sequence: 42
        )

        XCTAssertEqual(
            frame,
            RDPAudioOutputFrame(
                sequence: 42,
                sampleRate: 48_000,
                channelCount: 2,
                format: .pcmSigned16LittleEndian,
                data: Data([0x01, 0x00, 0x02, 0x00, 0x03, 0x00, 0x04, 0x00])
            )
        )
    }

    private func rdpBasicConnectionSequenceIncomingPackets() -> Data {
        [
            Data([
                0x03, 0x00, 0x00, 0x13,
                0x0e, 0xd0, 0x00, 0x00, 0x12, 0x34, 0x00,
                0x02, 0x00, 0x08, 0x00, 0x01, 0x00, 0x00, 0x00
            ]),
            Data([
                0x03, 0x00, 0x00, 0x39, 0x02, 0xf0, 0x80, 0x7f, 0x66, 0x82, 0x00, 0x25,
                0x0a, 0x01, 0x00, 0x02, 0x01, 0x00, 0x04, 0x1c,
                0x00, 0x05, 0x00, 0x14, 0x7c, 0x00, 0x01, 0x2a, 0x14, 0x76, 0x0a, 0x01,
                0x01, 0x00, 0x01, 0xc0, 0x00, 0x4d, 0x63, 0x44, 0x6e,
                0x03, 0x0c, 0x10, 0x00, 0xeb, 0x03, 0x03, 0x00, 0xec, 0x03, 0xed, 0x03, 0xee, 0x03, 0x00, 0x00
            ]),
            Data([0x03, 0x00, 0x00, 0x0c, 0x02, 0xf0, 0x80, 0x2e, 0x00, 0x00, 0x03, 0xef]),
            Data([0x03, 0x00, 0x00, 0x0f, 0x02, 0xf0, 0x80, 0x3e, 0x00, 0x00, 0x06, 0x03, 0xef, 0x03, 0xef]),
            Data([0x03, 0x00, 0x00, 0x0f, 0x02, 0xf0, 0x80, 0x3e, 0x00, 0x00, 0x06, 0x03, 0xeb, 0x03, 0xeb]),
            Data([0x03, 0x00, 0x00, 0x0f, 0x02, 0xf0, 0x80, 0x3e, 0x00, 0x00, 0x06, 0x03, 0xec, 0x03, 0xec]),
            Data([0x03, 0x00, 0x00, 0x0f, 0x02, 0xf0, 0x80, 0x3e, 0x00, 0x00, 0x06, 0x03, 0xed, 0x03, 0xed]),
            Data([0x03, 0x00, 0x00, 0x0f, 0x02, 0xf0, 0x80, 0x3e, 0x00, 0x00, 0x06, 0x03, 0xee, 0x03, 0xee]),
            Data([
                0x03, 0x00, 0x00, 0x36, 0x02, 0xf0, 0x80, 0x68, 0x00, 0x01, 0x03, 0xeb, 0x70, 0x28,
                0x20, 0x00, 0x11, 0x00, 0xea, 0x03, 0xea, 0x03, 0x01, 0x00, 0x04, 0x00, 0x16, 0x00,
                0x52, 0x44, 0x50, 0x00, 0x02, 0x00, 0x00, 0x00,
                0x09, 0x00, 0x08, 0x00, 0xea, 0x03, 0x00, 0x00,
                0x01, 0x00, 0x0a, 0x00, 0x01, 0x00, 0x03, 0x00, 0x00, 0x02
            ]),
            Data([
                0x03, 0x00, 0x00, 0x28, 0x02, 0xf0, 0x80, 0x68, 0x00, 0x01, 0x03, 0xeb, 0x70, 0x1a,
                0x1a, 0x00, 0x17, 0x00, 0xef, 0x03, 0xea, 0x03, 0x01, 0x00, 0x00, 0x01, 0x08, 0x00,
                0x28, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x04, 0x00
            ])
        ].reduce(into: Data()) { partialResult, packet in
            partialResult.append(packet)
        }
    }

    func testRDPAudioOutputBridgeAcceptsDeduplicatedRemoteOutputFrames() {
        var bridge = RDPAudioOutputBridge(redirections: [.audioOutput])
        let frame = RDPAudioOutputFrame(
            sequence: 9,
            sampleRate: 48_000,
            channelCount: 2,
            format: .pcmSigned16LittleEndian,
            byteCount: 960
        )

        XCTAssertTrue(bridge.isEnabled)
        XCTAssertEqual(bridge.receiveRemoteOutputFrame(frame), frame)
        XCTAssertNil(bridge.receiveRemoteOutputFrame(frame))
        XCTAssertNil(bridge.captureLocalInputFrame(frame))

        var disabled = RDPAudioOutputBridge(redirections: [.clipboard])
        XCTAssertFalse(disabled.isEnabled)
        XCTAssertNil(disabled.receiveRemoteOutputFrame(frame))
    }

    func testRDPAudioOutputSynchronizerForwardsAcceptedPCMFramesToPlayback() {
        var synchronizer = RDPAudioOutputSynchronizer(bridge: RDPAudioOutputBridge(redirections: [.audioOutput]))
        let frame = RDPAudioOutputFrame(
            sequence: 10,
            sampleRate: 44_100,
            channelCount: 2,
            format: .pcmSigned16LittleEndian,
            data: Data([0, 1, 2, 3, 4, 5, 6, 7])
        )
        var played: [RDPAudioOutputFrame] = []

        XCTAssertEqual(synchronizer.receiveRemoteOutputFrame(frame) { played.append($0) }, frame)
        XCTAssertEqual(played, [frame])
        XCTAssertNil(synchronizer.receiveRemoteOutputFrame(frame) { played.append($0) })
        XCTAssertEqual(played, [frame])

        var disabled = RDPAudioOutputSynchronizer(bridge: RDPAudioOutputBridge(redirections: [.clipboard]))
        XCTAssertNil(disabled.receiveRemoteOutputFrame(frame) { played.append($0) })
        XCTAssertEqual(played, [frame])
    }

    func testKeychainSecretStoreRoundTripsAndDeletesSecret() throws {
        let store = KeychainSecretStore(
            service: "pl.kacper.Termy.tests.\(UUID().uuidString)",
            synchronizesWithICloudKeychain: false
        )
        let reference = SecretReference.keychain("secret-\(UUID().uuidString)")
        let secret = Data("sensitive-value".utf8)

        try store.save(secret, for: reference)
        XCTAssertEqual(try store.load(reference), secret)

        try store.delete(reference)
        XCTAssertNil(try store.load(reference))
    }

    func testKeychainSecretStoreDefaultsToICloudSynchronizableSecrets() {
        let store = KeychainSecretStore(service: "pl.kacper.Termy.tests.\(UUID().uuidString)")
        let reference = SecretReference.keychain("secret-\(UUID().uuidString)")

        let addQuery = store.makeAddQueryForTesting(secret: Data("sync-value".utf8), reference: reference)
        XCTAssertEqual(addQuery[kSecAttrSynchronizable as String] as? Bool, true)
        XCTAssertEqual(addQuery[kSecAttrAccessible as String] as? String, kSecAttrAccessibleAfterFirstUnlock as String)
    }

    func testSSHPrivateKeyVaultStoresPrivateKeysInKeychainAndRestoresStrictFilePermissions() throws {
        let store = KeychainSecretStore(
            service: "pl.kacper.Termy.tests.\(UUID().uuidString)",
            synchronizesWithICloudKeychain: false
        )
        let vault = SSHPrivateKeyVault(secretStore: store)
        let sourcePath = "~/.ssh/id_ed25519_termy"
        let privateKey = """
        -----BEGIN OPENSSH PRIVATE KEY-----
        b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAA=
        -----END OPENSSH PRIVATE KEY-----

        """
        let keyData = Data(privateKey.utf8)

        let reference = try vault.savePrivateKey(keyData, identityPath: sourcePath)

        XCTAssertEqual(reference, .keychain("ssh.identity.~/.ssh/id_ed25519_termy"))
        XCTAssertEqual(try store.load(reference), keyData)

        let restoreDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-ssh-key-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: restoreDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: restoreDirectory) }
        let restoredURL = restoreDirectory.appendingPathComponent("id_ed25519_termy")

        try vault.restorePrivateKey(reference, to: restoredURL)

        XCTAssertEqual(try Data(contentsOf: restoredURL), keyData)
        let attributes = try FileManager.default.attributesOfItem(atPath: restoredURL.path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
    }

    func testSSHPrivateKeyVaultRejectsNonPrivateKeyMaterial() throws {
        let store = KeychainSecretStore(
            service: "pl.kacper.Termy.tests.\(UUID().uuidString)",
            synchronizesWithICloudKeychain: false
        )
        let vault = SSHPrivateKeyVault(secretStore: store)

        XCTAssertThrowsError(
            try vault.savePrivateKey(Data("not a private key".utf8), identityPath: "~/.ssh/id_ed25519_termy")
        ) { error in
            XCTAssertEqual(error as? SSHPrivateKeyVaultError, .invalidPrivateKey)
        }
    }

    func testSSHConfigImporterCreatesProfilesWithoutInlineSecrets() throws {
        let config = """
        Host prod bastion
          HostName bastion.example.test
          User deploy
          Port 2222
          IdentityFile ~/.ssh/id_ed25519
          ProxyJump jump.example.test
          Compression yes
          ServerAliveInterval 30

        Host *
          ForwardAgent yes
        """

        let profiles = try SSHConfigImporter().importProfiles(from: config)

        XCTAssertEqual(profiles.map(\.name), ["prod", "bastion"])
        XCTAssertTrue(profiles.allSatisfy { $0.kind == .ssh })
        XCTAssertTrue(profiles.allSatisfy { $0.host == "bastion.example.test" })
        XCTAssertTrue(profiles.allSatisfy { $0.user == "deploy" })
        XCTAssertTrue(profiles.allSatisfy { $0.port == 2222 })
        XCTAssertTrue(profiles.allSatisfy { $0.gateway == "jump.example.test" })
        XCTAssertTrue(profiles.allSatisfy { $0.sshOptions == ["Compression": "yes", "ServerAliveInterval": "30"] })
        XCTAssertTrue(profiles.allSatisfy { $0.inlineSecret == nil })
        XCTAssertEqual(profiles.first?.secretReferences, [.keychain("ssh.identity.~/.ssh/id_ed25519")])
    }

    func testSSHLaunchCommandBuildsUserInitiatedSystemSSHArguments() throws {
        let profile = ConnectionProfile.ssh(
            name: "Production",
            host: "bastion.example.test",
            user: "deploy",
            port: 2222,
            identity: .keychain("ssh.identity.~/.ssh/id_ed25519"),
            proxyJump: "jump.example.test",
            sshOptions: [
                "Compression": "yes",
                "ServerAliveInterval": "30"
            ]
        )

        let command = try SSHLaunchCommand(profile: profile)

        XCTAssertEqual(command.executablePath, "/usr/bin/ssh")
        XCTAssertEqual(
            command.arguments,
            [
                "-p", "2222",
                "-J", "jump.example.test",
                "-o", "Compression=yes",
                "-o", "ServerAliveInterval=30",
                "--",
                "deploy@bastion.example.test"
            ]
        )
        XCTAssertFalse(command.arguments.contains { $0.contains("id_ed25519") })
    }

    func testSSHTunnelLaunchCommandBuildsForwardingArgumentsWithoutSecrets() throws {
        let profile = ConnectionProfile.ssh(
            name: "Production",
            host: "bastion.example.test",
            user: "deploy",
            port: 2222,
            identity: .keychain("ssh.identity.prod"),
            proxyJump: "jump.example.test"
        )
        let command = try SSHTunnelLaunchCommand(
            profile: profile,
            tunnels: [
                .local(localPort: 8080, remoteHost: "127.0.0.1", remotePort: 80),
                .dynamic(localPort: 1080)
            ]
        )

        XCTAssertEqual(command.executablePath, "/usr/bin/ssh")
        XCTAssertEqual(
            command.arguments,
            [
                "-N",
                "-p", "2222",
                "-J", "jump.example.test",
                "-L", "8080:127.0.0.1:80",
                "-D", "1080",
                "--",
                "deploy@bastion.example.test"
            ]
        )
        XCTAssertFalse(command.arguments.contains { $0.localizedCaseInsensitiveContains("identity") })
    }

    func testSavedSSHTunnelStoresForwardingConfigurationWithoutSecrets() throws {
        let profile = ConnectionProfile.ssh(
            name: "Production",
            host: "bastion.example.test",
            user: "deploy",
            port: 2222,
            identity: .keychain("ssh.identity.prod")
        )

        let saved = try SavedSSHTunnel(
            name: "Prod Web",
            profile: profile,
            tunnels: [.local(localPort: 8080, remoteHost: "127.0.0.1", remotePort: 80)],
            autoReconnect: true
        )

        XCTAssertEqual(saved.profileName, "Production")
        XCTAssertEqual(saved.profileHost, "bastion.example.test")
        XCTAssertEqual(saved.tunnels, [.local(localPort: 8080, remoteHost: "127.0.0.1", remotePort: 80)])
        XCTAssertTrue(saved.autoReconnect)
        XCTAssertTrue(saved.secretReferences.isEmpty)
        XCTAssertEqual(try saved.launchCommand(profile: profile).arguments, [
            "-N",
            "-p", "2222",
            "-L", "8080:127.0.0.1:80",
            "--",
            "deploy@bastion.example.test"
        ])
    }

    func testSSHTunnelDraftBuildsLocalRemoteAndDynamicSpecs() throws {
        XCTAssertEqual(
            try SSHTunnelDraft(
                kind: .local,
                bindPort: "8080",
                targetHost: "127.0.0.1",
                targetPort: "80"
            ).spec(),
            .local(localPort: 8080, remoteHost: "127.0.0.1", remotePort: 80)
        )
        XCTAssertEqual(
            try SSHTunnelDraft(
                kind: .remote,
                bindPort: "9000",
                targetHost: "127.0.0.1",
                targetPort: "3000"
            ).spec(),
            .remote(remotePort: 9000, localHost: "127.0.0.1", localPort: 3000)
        )
        XCTAssertEqual(
            try SSHTunnelDraft(
                kind: .dynamic,
                bindPort: "1080",
                targetHost: "",
                targetPort: ""
            ).spec(),
            .dynamic(localPort: 1080)
        )
        XCTAssertThrowsError(
            try SSHTunnelDraft(kind: .local, bindPort: "abc", targetHost: "127.0.0.1", targetPort: "80").spec()
        ) { error in
            XCTAssertEqual(error as? SSHTunnelDraftError, .invalidPort)
        }
    }

    func testSSHTunnelReconnectPolicyLimitsAutomaticRetries() {
        let policy = SSHTunnelReconnectPolicy(maxAttempts: 2)

        XCTAssertTrue(policy.shouldReconnect(exitStatus: 255, completedAttempts: 0, autoReconnect: true))
        XCTAssertTrue(policy.shouldReconnect(exitStatus: 1, completedAttempts: 1, autoReconnect: true))
        XCTAssertFalse(policy.shouldReconnect(exitStatus: 0, completedAttempts: 0, autoReconnect: true))
        XCTAssertFalse(policy.shouldReconnect(exitStatus: 255, completedAttempts: 2, autoReconnect: true))
        XCTAssertFalse(policy.shouldReconnect(exitStatus: 255, completedAttempts: 0, autoReconnect: false))
    }

    func testSSHTunnelHealthTracksLifecycleAndReconnectAttempts() {
        var health = SSHTunnelHealth(tunnelName: "Prod SOCKS")

        XCTAssertEqual(health.status, .starting)
        XCTAssertEqual(health.summary, "Prod SOCKS: starting")

        health.markRunning()
        XCTAssertEqual(health.status, .running)
        XCTAssertEqual(health.summary, "Prod SOCKS: running")

        health.markReconnecting(attempt: 2)
        XCTAssertEqual(health.status, .reconnecting(attempt: 2))
        XCTAssertEqual(health.summary, "Prod SOCKS: reconnecting attempt 2")

        health.markExited(status: 255, willReconnect: false)
        XCTAssertEqual(health.status, .failed(exitStatus: 255))
        XCTAssertEqual(health.summary, "Prod SOCKS: failed with exit 255")

        health.markExited(status: 0, willReconnect: false)
        XCTAssertEqual(health.status, .stopped(exitStatus: 0))
        XCTAssertEqual(health.summary, "Prod SOCKS: stopped")
    }

    func testSSHTunnelProbeCommandChecksLocalAndDynamicForwardPorts() throws {
        let local = try SSHTunnelProbeCommand(tunnel: .local(localPort: 8080, remoteHost: "127.0.0.1", remotePort: 80))
        let dynamic = try SSHTunnelProbeCommand(tunnel: .dynamic(localPort: 1080))

        XCTAssertEqual(local.executablePath, "/usr/bin/nc")
        XCTAssertEqual(local.arguments, ["-z", "127.0.0.1", "8080"])
        XCTAssertEqual(dynamic.arguments, ["-z", "127.0.0.1", "1080"])
    }

    func testSSHTunnelProbeCommandChecksRemoteForwardPortsThroughSSH() throws {
        let profile = ConnectionProfile.ssh(
            name: "Production",
            host: "bastion.example.test",
            user: "deploy",
            port: 2222,
            identity: .keychain("ssh.identity.prod"),
            proxyJump: "jump.example.test"
        )
        let probe = try SSHTunnelProbeCommand(
            tunnel: .remote(remotePort: 9000, localHost: "127.0.0.1", localPort: 3000),
            profile: profile
        )

        XCTAssertEqual(probe.executablePath, "/usr/bin/ssh")
        XCTAssertEqual(probe.arguments, [
            "-p", "2222",
            "-J", "jump.example.test",
            "--",
            "deploy@bastion.example.test",
            "/usr/bin/nc", "-z", "127.0.0.1", "9000"
        ])
        XCTAssertFalse(probe.arguments.contains { $0.localizedCaseInsensitiveContains("identity") })
    }

    func testOpenSSHLaunchCommandsTerminateOptionsBeforeDestination() throws {
        let profile = ConnectionProfile.ssh(
            name: "Injected",
            host: "-oProxyCommand=sh",
            user: "",
            port: 22,
            identity: .keychain("ssh.identity.injected")
        )

        XCTAssertEqual(try SSHLaunchCommand(profile: profile).arguments.suffix(2), ["--", "-oProxyCommand=sh"])
        XCTAssertEqual(try SSHTunnelLaunchCommand(profile: profile, tunnels: [.dynamic(localPort: 1080)]).arguments.suffix(2), ["--", "-oProxyCommand=sh"])
        XCTAssertEqual(try SFTPLaunchCommand(profile: profile).arguments.suffix(2), ["--", "-oProxyCommand=sh"])
    }

    func testSSHKeyAndAgentCommandsAvoidInlinePassphrases() throws {
        let generate = try SSHKeyGenerationCommand(
            keyPath: "~/.ssh/id_ed25519_termy",
            comment: "kacper@mac"
        )
        let add = try SSHAgentAddCommand(keyPath: "~/.ssh/id_ed25519_termy")

        XCTAssertEqual(generate.executablePath, "/usr/bin/ssh-keygen")
        XCTAssertEqual(generate.arguments, ["-t", "ed25519", "-C", "kacper@mac", "-f", "~/.ssh/id_ed25519_termy"])
        XCTAssertEqual(add.executablePath, "/usr/bin/ssh-add")
        XCTAssertEqual(add.arguments, ["--apple-use-keychain", "~/.ssh/id_ed25519_termy"])
        XCTAssertFalse((generate.arguments + add.arguments).contains { $0.localizedCaseInsensitiveContains("pass") })
    }

    func testSFTPLaunchCommandUsesSystemSFTPWithoutSecrets() throws {
        let profile = ConnectionProfile.ssh(
            name: "Production",
            host: "bastion.example.test",
            user: "deploy",
            port: 2222,
            identity: .keychain("ssh.identity.prod"),
            proxyJump: "jump.example.test"
        )

        let command = try SFTPLaunchCommand(profile: profile)

        XCTAssertEqual(command.executablePath, "/usr/bin/sftp")
        XCTAssertEqual(command.arguments, ["-P", "2222", "-J", "jump.example.test", "--", "deploy@bastion.example.test"])
        XCTAssertFalse(command.arguments.contains { $0.localizedCaseInsensitiveContains("identity") })
    }

    func testSFTPDirectoryListingParsesOpenSSHLongListing() throws {
        let output = """
        drwxr-xr-x    2 deploy staff        64 May 17 12:00 src
        -rw-r--r--    1 deploy staff       123 May 17 12:01 README.md
        """

        let items = SFTPDirectoryListingParser().parse(output, currentDirectory: "/home/deploy")

        XCTAssertEqual(
            items,
            [
                .init(name: "src", path: "/home/deploy/src", isDirectory: true, size: 64),
                .init(name: "README.md", path: "/home/deploy/README.md", isDirectory: false, size: 123)
            ]
        )
    }

    func testSFTPBatchCommandsBuildUploadAndDownloadScripts() {
        XCTAssertEqual(
            SFTPBatchCommand.upload(localPath: "/tmp/a.txt", remotePath: "/home/deploy/a.txt").script,
            "put \"/tmp/a.txt\" \"/home/deploy/a.txt\"\n"
        )
        XCTAssertEqual(
            SFTPBatchCommand.download(remotePath: "/home/deploy/a.txt", localPath: "/tmp/a.txt").script,
            "get \"/home/deploy/a.txt\" \"/tmp/a.txt\"\n"
        )
    }

    func testSFTPBatchCommandsBuildRemoteMutationScripts() {
        XCTAssertEqual(
            SFTPBatchCommand.createDirectory(remotePath: "/home/deploy/logs").script,
            "mkdir \"/home/deploy/logs\"\n"
        )
        XCTAssertEqual(
            SFTPBatchCommand.rename(remotePath: "/home/deploy/old.txt", to: "/home/deploy/new.txt").script,
            "rename \"/home/deploy/old.txt\" \"/home/deploy/new.txt\"\n"
        )
        XCTAssertEqual(
            SFTPBatchCommand.delete(remotePath: "/home/deploy/old.txt", isDirectory: false).script,
            "rm \"/home/deploy/old.txt\"\n"
        )
        XCTAssertEqual(
            SFTPBatchCommand.delete(remotePath: "/home/deploy/logs", isDirectory: true).script,
            "rmdir \"/home/deploy/logs\"\n"
        )
    }

    func testSFTPBatchCommandsQuoteSpacesAndEscapeControlCharacters() {
        XCTAssertEqual(
            SFTPBatchCommand.upload(
                localPath: #"/Users/kacper/My Project/"quote".txt"#,
                remotePath: "/home/deploy/My File.txt\nrm /home/deploy/important.log"
            ).script,
            #"put "/Users/kacper/My Project/\"quote\".txt" "/home/deploy/My File.txt\nrm /home/deploy/important.log""# + "\n"
        )
        XCTAssertEqual(
            SFTPBatchCommand.listDirectory(remotePath: "/home/deploy/My Folder").script,
            "cd \"/home/deploy/My Folder\"\nls -l\n"
        )
    }

    func testSFTPTransferPlannerMapsDroppedLocalAndRemoteItemsToBatchCommands() {
        let planner = SFTPTransferPlanner(
            localRoot: URL(fileURLWithPath: "/Users/kacper/Projects/Termy"),
            remoteDirectory: "/home/deploy"
        )
        let remote = SFTPRemoteItem(name: "app.log", path: "/home/deploy/app.log", isDirectory: false, size: 42)

        XCTAssertEqual(
            planner.uploadDroppedLocalFile(URL(fileURLWithPath: "/Users/kacper/Projects/Termy/README.md")).script,
            "put \"/Users/kacper/Projects/Termy/README.md\" \"/home/deploy/README.md\"\n"
        )
        XCTAssertEqual(
            planner.downloadDroppedRemoteItem(remote).script,
            "get \"/home/deploy/app.log\" \"/Users/kacper/Projects/Termy/app.log\"\n"
        )
    }

    func testSFTPTransferPlannerBuildsRemoteCreateRenameDeleteAndMoveCommands() {
        let planner = SFTPTransferPlanner(
            localRoot: URL(fileURLWithPath: "/Users/kacper/Projects/Termy"),
            remoteDirectory: "/home/deploy"
        )
        let remote = SFTPRemoteItem(name: "app.log", path: "/home/deploy/app.log", isDirectory: false, size: 42)
        let folder = SFTPRemoteItem(name: "logs", path: "/home/deploy/logs", isDirectory: true, size: 0)

        XCTAssertEqual(
            planner.createDirectory(named: "archive").script,
            "mkdir \"/home/deploy/archive\"\n"
        )
        XCTAssertEqual(
            planner.rename(remote, to: "renamed.log").script,
            "rename \"/home/deploy/app.log\" \"/home/deploy/renamed.log\"\n"
        )
        XCTAssertEqual(
            planner.delete(remote).script,
            "rm \"/home/deploy/app.log\"\n"
        )
        XCTAssertEqual(
            planner.move(remote, toDirectory: "/home/deploy/archive").script,
            "rename \"/home/deploy/app.log\" \"/home/deploy/archive/app.log\"\n"
        )
        XCTAssertEqual(
            planner.delete(folder).script,
            "rmdir \"/home/deploy/logs\"\n"
        )
    }

    func testCommandRegistryFuzzySearchFindsRemoteSessionActions() {
        let registry = CommandRegistry(actions: FeatureCatalog.termDefault.commandCenterActions)

        XCTAssertEqual(registry.search("ssh").first?.id, "connect-ssh")
        XCTAssertEqual(registry.search("rdp").first?.id, "connect-rdp")
        XCTAssertTrue(registry.search("ai error").contains { $0.id == "explain-last-error" })
    }

    func testCompletionEngineSuggestsHistoryFilesSSHHostsAndGitBranches() {
        let engine = CompletionEngine(
            history: ["git status", "git checkout main", "ssh prod"],
            filePaths: ["Package.swift", "Sources/Termy/App/TermyApp.swift"],
            sshHosts: ["prod", "staging"],
            gitBranches: ["main", "feature/terminal"]
        )

        XCTAssertEqual(engine.suggestions(for: "git s").map(\.replacement), ["git status"])
        XCTAssertEqual(engine.suggestions(for: "ssh p").map(\.replacement), ["ssh prod"])
        XCTAssertEqual(engine.suggestions(for: "cat P").map(\.replacement), ["cat Package.swift"])
        XCTAssertEqual(engine.suggestions(for: "git checkout f").map(\.replacement), ["git checkout feature/terminal"])
    }

    func testCompletionEngineBuildsInlineAutosuggestionFromHistoryPrefix() {
        let engine = CompletionEngine(
            history: ["git commit -m init", "git checkout main", "git status"]
        )

        let suggestion = engine.inlineAutosuggestion(for: "git c")

        XCTAssertEqual(suggestion?.replacement, "git commit -m init")
        XCTAssertEqual(suggestion?.ghostText, "ommit -m init")
        XCTAssertNil(engine.inlineAutosuggestion(for: "git status"))
        XCTAssertNil(engine.inlineAutosuggestion(for: "status"))
    }

    func testCompletionEngineSuggestsCommandsAndFlags() {
        let engine = CompletionEngine(
            commandNames: ["git", "grep", "ssh"],
            commandFlags: [
                "git": ["--help", "--version"],
                "grep": ["--ignore-case", "--line-number"]
            ]
        )

        XCTAssertEqual(engine.suggestions(for: "gr").map(\.replacement), ["grep"])
        XCTAssertEqual(engine.suggestions(for: "git --").map(\.replacement), ["git --help", "git --version"])
        XCTAssertEqual(engine.suggestions(for: "grep --i").map(\.replacement), ["grep --ignore-case"])
        XCTAssertEqual(engine.suggestions(for: "ssh --").map(\.replacement), [])
    }

    func testTerminalTextIndexSearchesOutputAndDetectsLinks() {
        let index = TerminalTextIndex(lines: [
            "build started",
            "open https://example.test/docs and http://localhost:11434",
            "build finished"
        ])

        XCTAssertEqual(
            index.search("build"),
            [
                .init(line: 0, range: 0..<5, excerpt: "build started"),
                .init(line: 2, range: 0..<5, excerpt: "build finished")
            ]
        )
        XCTAssertEqual(
            index.links(),
            [
                .init(line: 1, urlString: "https://example.test/docs"),
                .init(line: 1, urlString: "http://localhost:11434")
            ]
        )
    }

    func testTerminalANSIParserSwallowsUnhandledEscapesInsteadOfRenderingGlyphs() {
        // ESC Z (unrecognized escape final) and a bare trailing ESC must be consumed,
        // not drawn as literal glyphs.
        let visible = TerminalANSIParser().parse("a\u{001B}Zb\u{001B}").map(\.text).joined()
        XCTAssertEqual(visible, "ab")
    }

    func testTerminalANSIParserStripsEscapesAndKeepsTrueColorRuns() {
        let runs = TerminalANSIParser().parse("plain \u{001B}[38;2;255;128;0morange\u{001B}[0m done")

        XCTAssertEqual(
            runs,
            [
                .init(text: "plain ", style: .plain),
                .init(text: "orange", style: .trueColor(red: 255, green: 128, blue: 0)),
                .init(text: " done", style: .plain)
            ]
        )
        XCTAssertEqual(runs.map(\.text).joined(), "plain orange done")
    }

    func testTerminalANSIParserHandlesColonDelimitedTrueColorRuns() {
        let runs = TerminalANSIParser().parse("plain \u{001B}[38:2:12:34:56mcolor\u{001B}[0m done")

        XCTAssertEqual(
            runs,
            [
                .init(text: "plain ", style: .plain),
                .init(text: "color", style: .trueColor(red: 12, green: 34, blue: 56)),
                .init(text: " done", style: .plain)
            ]
        )
        XCTAssertEqual(runs.map(\.text).joined(), "plain color done")
    }

    func testTerminalANSIParserHandlesColonDelimitedTrueColorWithEmptyColorSpace() {
        let runs = TerminalANSIParser().parse("plain \u{001B}[38:2::12:34:56mcolor\u{001B}[0m done")

        XCTAssertEqual(
            runs,
            [
                .init(text: "plain ", style: .plain),
                .init(text: "color", style: .trueColor(red: 12, green: 34, blue: 56)),
                .init(text: " done", style: .plain)
            ]
        )
        XCTAssertEqual(runs.map(\.text).joined(), "plain color done")
    }

    func testTerminalANSIParserHandlesColonDelimitedTrueColorWithColorSpaceID() {
        let runs = TerminalANSIParser().parse("plain \u{001B}[38:2:1:12:34:56mcolor\u{001B}[0m done")

        XCTAssertEqual(
            runs,
            [
                .init(text: "plain ", style: .plain),
                .init(text: "color", style: .trueColor(red: 12, green: 34, blue: 56)),
                .init(text: " done", style: .plain)
            ]
        )
        XCTAssertEqual(runs.map(\.text).joined(), "plain color done")
    }

    func testTerminalANSIParserMapsIndexedSGRColorRunsToTrueColor() {
        let runs = TerminalANSIParser().parse("plain \u{001B}[38;5;196mred\u{001B}[0m done")

        XCTAssertEqual(
            runs,
            [
                .init(text: "plain ", style: .plain),
                .init(text: "red", style: .trueColor(red: 255, green: 0, blue: 0)),
                .init(text: " done", style: .plain)
            ]
        )
        XCTAssertEqual(runs.map(\.text).joined(), "plain red done")
    }

    func testTerminalANSIParserTracksSGRBackgroundColors() {
        let runs = TerminalANSIParser().parse("plain \u{001B}[44mbluebg\u{001B}[38;2;1;2;3;48;5;196m combo\u{001B}[49m fg\u{001B}[0m done")

        XCTAssertEqual(
            runs,
            [
                .init(text: "plain ", style: .plain),
                .init(text: "bluebg", style: .styled(foreground: nil, background: .standardColor(44), isBold: false, isUnderlined: false, isInverted: false)),
                .init(
                    text: " combo",
                    style: .styled(
                        foreground: .trueColor(red: 1, green: 2, blue: 3),
                        background: .trueColor(red: 255, green: 0, blue: 0),
                        isBold: false,
                        isUnderlined: false,
                        isInverted: false
                    )
                ),
                .init(text: " fg", style: .trueColor(red: 1, green: 2, blue: 3)),
                .init(text: " done", style: .plain)
            ]
        )
        XCTAssertEqual(runs.map(\.text).joined(), "plain bluebg combo fg done")
    }

    func testTerminalANSIParserTracksSGRReverseVideoAttribute() {
        let runs = TerminalANSIParser().parse("plain \u{001B}[31;44;7mreverse\u{001B}[27m normal")

        XCTAssertEqual(
            runs,
            [
                .init(text: "plain ", style: .plain),
                .init(
                    text: "reverse",
                    style: .styled(
                        foreground: .standardColor(31),
                        background: .standardColor(44),
                        isBold: false,
                        isUnderlined: false,
                        isInverted: true
                    )
                ),
                .init(
                    text: " normal",
                    style: .styled(
                        foreground: .standardColor(31),
                        background: .standardColor(44),
                        isBold: false,
                        isUnderlined: false,
                        isInverted: false
                    )
                )
            ]
        )
        XCTAssertEqual(runs.map(\.text).joined(), "plain reverse normal")
    }

    func testTerminalANSIParserTracksBoldAndUnderlineSGRAttributes() {
        let runs = TerminalANSIParser().parse("plain \u{001B}[1mbold\u{001B}[4m both\u{001B}[22m underline\u{001B}[24m plain")

        XCTAssertEqual(
            runs,
            [
                .init(text: "plain ", style: .plain),
                .init(text: "bold", style: .styled(foreground: nil, background: nil, isBold: true, isUnderlined: false, isInverted: false)),
                .init(text: " both", style: .styled(foreground: nil, background: nil, isBold: true, isUnderlined: true, isInverted: false)),
                .init(text: " underline", style: .styled(foreground: nil, background: nil, isBold: false, isUnderlined: true, isInverted: false)),
                .init(text: " plain", style: .plain)
            ]
        )
        XCTAssertEqual(runs.map(\.text).joined(), "plain bold both underline plain")
    }

    func testTerminalANSIParserMapsDoubleUnderlineSGRAttributeToUnderline() {
        let runs = TerminalANSIParser().parse("plain \u{001B}[21mdouble\u{001B}[24m plain")

        XCTAssertEqual(
            runs,
            [
                .init(text: "plain ", style: .plain),
                .init(
                    text: "double",
                    style: .styled(
                        foreground: nil,
                        background: nil,
                        isBold: false,
                        isUnderlined: true,
                        isInverted: false
                    )
                ),
                .init(text: " plain", style: .plain)
            ]
        )
        XCTAssertEqual(runs.dropFirst().first?.style.isUnderlined, true)
        XCTAssertEqual(runs.map(\.text).joined(), "plain double plain")
    }

    func testTerminalANSIParserParsesColonDelimitedUnderlineStyleWithoutDim() {
        let runs = TerminalANSIParser().parse("plain \u{001B}[4:2mdouble\u{001B}[24m plain")

        XCTAssertEqual(
            runs,
            [
                .init(text: "plain ", style: .plain),
                .init(
                    text: "double",
                    style: .styled(
                        foreground: nil,
                        background: nil,
                        isBold: false,
                        isUnderlined: true,
                        isInverted: false
                    )
                ),
                .init(text: " plain", style: .plain)
            ]
        )
        XCTAssertEqual(runs[1].style.isUnderlined, true)
        XCTAssertEqual(runs[1].style.isDim, false)
    }

    func testTerminalANSIParserTracksDimSGRAttribute() {
        let runs = TerminalANSIParser().parse("plain \u{001B}[2mdim\u{001B}[22m plain")

        XCTAssertEqual(
            runs,
            [
                .init(text: "plain ", style: .plain),
                .init(
                    text: "dim",
                    style: .styled(
                        foreground: nil,
                        background: nil,
                        isBold: false,
                        isUnderlined: false,
                        isInverted: false,
                        isDim: true
                    )
                ),
                .init(text: " plain", style: .plain)
            ]
        )
        XCTAssertTrue(runs[1].style.isDim)
        XCTAssertEqual(runs.map(\.text).joined(), "plain dim plain")
    }

    func testTerminalANSIParserTracksConcealedSGRAttribute() {
        let runs = TerminalANSIParser().parse("plain \u{001B}[8msecret\u{001B}[28m plain")

        XCTAssertEqual(
            runs,
            [
                .init(text: "plain ", style: .plain),
                .init(
                    text: "secret",
                    style: .styled(
                        foreground: nil,
                        background: nil,
                        isBold: false,
                        isUnderlined: false,
                        isInverted: false,
                        isConcealed: true
                    )
                ),
                .init(text: " plain", style: .plain)
            ]
        )
        XCTAssertTrue(runs[1].style.isConcealed)
        XCTAssertEqual(runs.map(\.text).joined(), "plain secret plain")
    }

    func testTerminalANSIParserTracksBlinkSGRAttribute() {
        let runs = TerminalANSIParser().parse("plain \u{001B}[5mblink\u{001B}[25m plain")

        XCTAssertEqual(
            runs,
            [
                .init(text: "plain ", style: .plain),
                .init(
                    text: "blink",
                    style: .styled(
                        foreground: nil,
                        background: nil,
                        isBold: false,
                        isUnderlined: false,
                        isInverted: false,
                        isBlinking: true
                    )
                ),
                .init(text: " plain", style: .plain)
            ]
        )
        XCTAssertTrue(runs[1].style.isBlinking)
        XCTAssertEqual(runs.map(\.text).joined(), "plain blink plain")
    }

    func testTerminalANSIParserTracksItalicSGRAttribute() {
        let runs = TerminalANSIParser().parse("plain \u{001B}[3mitalic\u{001B}[23m plain")

        XCTAssertEqual(
            runs,
            [
                .init(text: "plain ", style: .plain),
                .init(
                    text: "italic",
                    style: .styled(
                        foreground: nil,
                        background: nil,
                        isBold: false,
                        isUnderlined: false,
                        isInverted: false,
                        isItalic: true
                    )
                ),
                .init(text: " plain", style: .plain)
            ]
        )
        XCTAssertTrue(runs[1].style.isItalic)
        XCTAssertEqual(runs.map(\.text).joined(), "plain italic plain")
    }

    func testTerminalANSIParserTracksStrikethroughSGRAttribute() {
        let runs = TerminalANSIParser().parse("plain \u{001B}[9mstrike\u{001B}[29m plain")

        XCTAssertEqual(
            runs,
            [
                .init(text: "plain ", style: .plain),
                .init(
                    text: "strike",
                    style: .styled(
                        foreground: nil,
                        background: nil,
                        isBold: false,
                        isUnderlined: false,
                        isInverted: false,
                        isStrikethrough: true
                    )
                ),
                .init(text: " plain", style: .plain)
            ]
        )
        XCTAssertTrue(runs[1].style.isStrikethrough)
        XCTAssertEqual(runs.map(\.text).joined(), "plain strike plain")
    }

    func testTerminalANSIParserTracksOverlineSGRAttribute() {
        let runs = TerminalANSIParser().parse("plain \u{001B}[53mover\u{001B}[55m plain")

        XCTAssertEqual(
            runs,
            [
                .init(text: "plain ", style: .plain),
                .init(
                    text: "over",
                    style: .styled(
                        foreground: nil,
                        background: nil,
                        isBold: false,
                        isUnderlined: false,
                        isInverted: false,
                        isOverlined: true
                    )
                ),
                .init(text: " plain", style: .plain)
            ]
        )
        XCTAssertTrue(runs[1].style.isOverlined)
        XCTAssertEqual(runs.map(\.text).joined(), "plain over plain")
    }

    func testTerminalANSIParserParsesC1CSIStyleRunsWithoutLeakingText() {
        let runs = TerminalANSIParser().parse("plain \u{009B}31mred\u{009B}0m done")

        XCTAssertEqual(
            runs,
            [
                .init(text: "plain ", style: .plain),
                .init(text: "red", style: .standardColor(31)),
                .init(text: " done", style: .plain)
            ]
        )
        XCTAssertEqual(runs.map(\.text).joined(), "plain red done")
    }

    func testTerminalANSIParserConsumesOSCSequencesWithoutLeakingText() {
        let runs = TerminalANSIParser().parse("hi \u{001B}]0;title\u{0007}there \u{001B}]8;;https://example.test\u{001B}\\link\u{001B}]8;;\u{001B}\\")

        XCTAssertEqual(
            runs,
            [
                .init(text: "hi there link", style: .plain)
            ]
        )
        XCTAssertEqual(runs.map(\.text).joined(), "hi there link")
    }

    func testTerminalANSIParserConsumesStringControlSequencesWithoutLeakingText() {
        let runs = TerminalANSIParser().parse("a\u{001B}P1$r q\u{001B}\\b\u{001B}_app-payload\u{001B}\\c\u{001B}^privacy\u{001B}\\d\u{001B}Xignored\u{001B}\\e")

        XCTAssertEqual(
            runs,
            [
                .init(text: "abcde", style: .plain)
            ]
        )
        XCTAssertEqual(runs.map(\.text).joined(), "abcde")
    }

    func testTerminalANSIParserConsumesOSCAndStringControlsTerminatedByC1ST() {
        let runs = TerminalANSIParser().parse("a\u{001B}]0;title\u{009C}b\u{001B}P1$r q\u{009C}c\u{001B}_payload\u{009C}d")

        XCTAssertEqual(
            runs,
            [
                .init(text: "abcd", style: .plain)
            ]
        )
        XCTAssertEqual(runs.map(\.text).joined(), "abcd")
    }

    func testTerminalANSIParserConsumesC1OSCAndStringControlStartsWithoutLeakingText() {
        let runs = TerminalANSIParser().parse("a\u{009D}0;title\u{009C}b\u{0090}1$r q\u{009C}c\u{009F}app\u{009C}d\u{009E}privacy\u{009C}e\u{0098}sos\u{009C}f")

        XCTAssertEqual(
            runs,
            [
                .init(text: "abcdef", style: .plain)
            ]
        )
        XCTAssertEqual(runs.map(\.text).joined(), "abcdef")
    }

    func testTerminalANSIParserConsumesSimpleTerminalModeEscapesWithoutLeakingText() {
        let runs = TerminalANSIParser().parse("a\u{001B}(Bb\u{001B})0c\u{001B}=d\u{001B}>e\u{001B}#8f")

        XCTAssertEqual(
            runs,
            [
                .init(text: "abcdef", style: .plain)
            ]
        )
        XCTAssertEqual(runs.map(\.text).joined(), "abcdef")
    }

    func testTerminalANSIParserConsumesCharacterEncodingEscapesWithoutLeakingText() {
        let runs = TerminalANSIParser().parse("a\u{001B}%Gb\u{001B}%@c")

        XCTAssertEqual(
            runs,
            [
                .init(text: "abc", style: .plain)
            ]
        )
        XCTAssertEqual(runs.map(\.text).joined(), "abc")
    }

    func testTerminalANSIParserConsumesC1ModeEscapesWithoutLeakingText() {
        let runs = TerminalANSIParser().parse("a\u{001B} Fb\u{001B} Gc\u{001B}Nd\u{001B}Oe\u{001B}Vf\u{001B}Wg")

        XCTAssertEqual(
            runs,
            [
                .init(text: "abcdefg", style: .plain)
            ]
        )
        XCTAssertEqual(runs.map(\.text).joined(), "abcdefg")
    }

    func testTerminalANSIParserConsumesBackAndForwardIndexEscapesWithoutLeakingText() {
        let runs = TerminalANSIParser().parse("ab\u{001B}6c\u{001B}9d")

        XCTAssertEqual(
            runs,
            [
                .init(text: "abcd", style: .plain)
            ]
        )
        XCTAssertEqual(runs.map(\.text).joined(), "abcd")
    }

    func testTerminalANSIParserMapsDECSpecialGraphicsLineDrawingCharacters() {
        let runs = TerminalANSIParser().parse("\u{001B}(0lqk\u{001B}(Bx\u{001B}(0mqj\u{001B}(B")

        XCTAssertEqual(
            runs,
            [
                .init(text: "┌─┐x└─┘", style: .plain)
            ]
        )
        XCTAssertEqual(runs.map(\.text).joined(), "┌─┐x└─┘")
    }

    func testTerminalANSIParserMapsDECSpecialGraphicsSymbolCharacters() {
        let runs = TerminalANSIParser().parse("\u{001B}(0`afgoprsyz{|}~\u{001B}(B")

        XCTAssertEqual(
            runs,
            [
                .init(text: "◆▒°±⎺⎻⎼⎽≤≥π≠£·", style: .plain)
            ]
        )
        XCTAssertEqual(runs.map(\.text).joined(), "◆▒°±⎺⎻⎼⎽≤≥π≠£·")
    }

    func testTerminalANSIParserMapsG1DECSpecialGraphicsWithShiftOutAndShiftIn() {
        let runs = TerminalANSIParser().parse("a\u{001B})0\u{000E}lqk\u{000F}x")

        XCTAssertEqual(
            runs,
            [
                .init(text: "a┌─┐x", style: .plain)
            ]
        )
        XCTAssertEqual(runs.map(\.text).joined(), "a┌─┐x")
    }

    func testTerminalANSIParserConsumesNonPrintingC0ControlsWithoutLeakingText() {
        let runs = TerminalANSIParser().parse("a\u{0000}b\u{0007}c\u{000E}d\u{000F}e")

        XCTAssertEqual(
            runs,
            [
                .init(text: "abcde", style: .plain)
            ]
        )
        XCTAssertEqual(runs.map(\.text).joined(), "abcde")
    }

    func testTerminalANSIParserConsumesVerticalTabAndFormFeedC0ControlsWithoutLeakingText() {
        let runs = TerminalANSIParser().parse("a\u{000B}b\u{000C}c")

        XCTAssertEqual(
            runs,
            [
                .init(text: "abc", style: .plain)
            ]
        )
        XCTAssertEqual(runs.map(\.text).joined(), "abc")
    }

    func testTerminalANSIParserConsumesOtherNonPrintingC0ControlsWithoutLeakingText() {
        let runs = TerminalANSIParser().parse("a\u{0005}b\u{0006}c\u{0018}d\u{001A}e\u{001F}f")

        XCTAssertEqual(
            runs,
            [
                .init(text: "abcdef", style: .plain)
            ]
        )
        XCTAssertEqual(runs.map(\.text).joined(), "abcdef")
    }

    func testTerminalANSIParserConsumesRemainingNonPrintingC0ControlsWithoutLeakingText() {
        let runs = TerminalANSIParser().parse("a\u{0001}b\u{0010}c\u{0011}d\u{0013}e\u{0019}f\u{001C}g\u{001D}h\u{001E}i")

        XCTAssertEqual(
            runs,
            [
                .init(text: "abcdefghi", style: .plain)
            ]
        )
        XCTAssertEqual(runs.map(\.text).joined(), "abcdefghi")
    }

    func testTerminalANSIParserConsumesC1MovementControlsWithoutLeakingText() {
        let runs = TerminalANSIParser().parse("a\u{0084}b\u{0085}c\u{0088}d\u{008D}e")

        XCTAssertEqual(
            runs,
            [
                .init(text: "abcde", style: .plain)
            ]
        )
        XCTAssertEqual(runs.map(\.text).joined(), "abcde")
    }

    func testTerminalANSIParserConsumesOtherNonPrintingC1ControlsWithoutLeakingText() {
        let runs = TerminalANSIParser().parse("a\u{0080}b\u{0081}c\u{0086}d\u{0089}e\u{008E}f\u{0091}g\u{0095}h\u{0099}i\u{009A}j\u{009C}k")

        XCTAssertEqual(
            runs,
            [
                .init(text: "abcdefghijk", style: .plain)
            ]
        )
        XCTAssertEqual(runs.map(\.text).joined(), "abcdefghijk")
    }

    func testTerminalANSIParserConsumesRemainingNonPrintingC1ControlsWithoutLeakingText() {
        let runs = TerminalANSIParser().parse("a\u{0082}b\u{0083}c\u{0087}d\u{008A}e\u{008B}f\u{008C}g\u{008F}h\u{0092}i\u{0093}j\u{0094}k\u{0096}l\u{0097}m")

        XCTAssertEqual(
            runs,
            [
                .init(text: "abcdefghijklm", style: .plain)
            ]
        )
        XCTAssertEqual(runs.map(\.text).joined(), "abcdefghijklm")
    }

    func testTerminalANSIParserConsumesNonSGRCSISequencesWithoutLeakingText() {
        let runs = TerminalANSIParser().parse("a\u{001B}[?25lb\u{001B}[2Kc\u{001B}[3;4Hd\u{001B}[1 qe")

        XCTAssertEqual(
            runs,
            [
                .init(text: "abcde", style: .plain)
            ]
        )
        XCTAssertEqual(runs.map(\.text).joined(), "abcde")
    }

    func testTerminalCommandBlockIndexerFindsCommandBoundariesAndOutput() {
        let entries: [TerminalTranscriptEntry] = [
            .init(role: .system, text: "Native PTY attached."),
            .init(role: .prompt, text: "$ swift test"),
            .init(role: .output, text: "Building\n"),
            .init(role: .output, text: "Passed\n"),
            .init(role: .system, text: "Exit 0"),
            .init(role: .prompt, text: "$ false"),
            .init(role: .system, text: "Exit 1")
        ]

        let blocks = TerminalCommandBlockIndexer().blocks(from: entries)

        XCTAssertEqual(
            blocks,
            [
                .init(command: "swift test", startLine: 1, endLine: 4, exitCode: 0, output: "Building\nPassed\n"),
                .init(command: "false", startLine: 5, endLine: 6, exitCode: 1, output: "")
            ]
        )
    }

    func testTerminalCommandBlockVisibilityHidesOutputAndNavigatesBlocks() {
        let blocks = [
            TerminalCommandBlock(command: "swift test", startLine: 1, endLine: 4, exitCode: 0, output: "Building\nPassed\n"),
            TerminalCommandBlock(command: "false", startLine: 5, endLine: 6, exitCode: 1, output: "")
        ]
        let visibility = TerminalCommandBlockVisibility()

        XCTAssertEqual(visibility.hiddenLineIndexes(for: blocks, foldedStartLines: [1]), [2, 3])
        XCTAssertEqual(visibility.nextBlockStart(after: nil, in: blocks), 1)
        XCTAssertEqual(visibility.nextBlockStart(after: 1, in: blocks), 5)
        XCTAssertEqual(visibility.nextBlockStart(after: 5, in: blocks), 1)
        XCTAssertEqual(visibility.previousBlockStart(before: 1, in: blocks), 5)
        XCTAssertEqual(visibility.previousBlockStart(before: 5, in: blocks), 1)
    }

    func testTerminalThemeCatalogProvidesBuiltInThemesAndFontBounds() {
        let catalog = TerminalThemeCatalog.builtIn

        XCTAssertEqual(catalog.defaultTheme.id, "system")
        XCTAssertTrue(catalog.themes.contains { $0.id == "solarized-dark" })
        XCTAssertEqual(catalog.theme(id: "missing")?.id, "system")
        XCTAssertEqual(TerminalFontPreferences(size: 6).size, 9)
        XCTAssertEqual(TerminalFontPreferences(size: 48).size, 32)
    }

    func testTerminalThemeAppliesIncreasedContrastWithoutChangingIdentity() {
        let theme = TerminalTheme(
            id: "custom-muted",
            name: "Muted",
            backgroundHex: "#242424",
            foregroundHex: "#9A9A9A",
            promptHex: "#5E8DB8",
            errorHex: "#C85A54",
            mutedHex: "#6E6E73"
        )

        let contrasted = theme.applyingIncreasedContrast()

        XCTAssertEqual(contrasted.id, "custom-muted")
        XCTAssertEqual(contrasted.name, "Muted")
        XCTAssertEqual(contrasted.backgroundHex, "#000000")
        XCTAssertEqual(contrasted.foregroundHex, "#FFFFFF")
        XCTAssertEqual(contrasted.promptHex, "#00D7FF")
        XCTAssertEqual(contrasted.errorHex, "#FF5C5C")
        XCTAssertEqual(contrasted.mutedHex, "#D0D0D0")
    }

    func testInterfaceTextScaleUsesStableSyncValues() {
        XCTAssertEqual(InterfaceTextScale(rawValue: "regular"), .regular)
        XCTAssertEqual(InterfaceTextScale(rawValue: "large"), .large)
        XCTAssertEqual(InterfaceTextScale(rawValue: "extra-large"), .extraLarge)
        XCTAssertNil(InterfaceTextScale(rawValue: "huge"))
    }

    func testTerminalThemeCatalogMergesCustomThemesAndSyncsDefinitions() {
        let custom = TerminalTheme(
            id: "custom-forest",
            name: "Forest",
            backgroundHex: "#101A14",
            foregroundHex: "#E6F2E8",
            promptHex: "#7DD87D",
            errorHex: "#FF6B6B",
            mutedHex: "#78917D"
        )

        let catalog = TerminalThemeCatalog.builtIn.merging(customThemes: [custom])

        XCTAssertEqual(catalog.theme(id: "custom-forest"), custom)

        let snapshot = PrivateSyncSnapshot(
            profiles: [],
            terminalThemeID: "custom-forest",
            terminalFontSize: 13,
            terminalUsesLigatures: true,
            customTerminalThemes: [custom],
            snippets: [],
            workspaces: [],
            terminalScrollback: [],
            aiConversationHistory: []
        )
        let appearanceRecord = PrivateSyncPlanner()
            .plan(for: snapshot)
            .records
            .first { $0.recordType == "Appearance" }

        // D3: collision-free JSON encoding (was `|`-within / `;`-between).
        XCTAssertEqual(
            appearanceRecord?.fields["customTerminalThemes"],
            "[[\"custom-forest\",\"Forest\",\"#101A14\",\"#E6F2E8\",\"#7DD87D\",\"#FF6B6B\",\"#78917D\"]]"
        )
    }

    func testGitRepositoryStagesAndCommitsDailyFlow() throws {
        let repoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-git-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repoURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: repoURL) }

        let bootstrap = ShellCommandRunner(workingDirectory: repoURL)
        _ = try bootstrap.run("git init && git config user.name Termy && git config user.email termy@example.test")
        try "hello\n".write(to: repoURL.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)

        let repository = GitRepository(root: repoURL)

        XCTAssertEqual(try repository.statusShort().entries, [.init(code: "??", path: "README.md")])

        try repository.stageAll()
        XCTAssertEqual(try repository.statusShort().entries, [.init(code: "A", path: "README.md")])

        let commit = try repository.commit(message: "Initial commit")
        XCTAssertTrue(commit.summary.contains("Initial commit"))
        XCTAssertEqual(try repository.statusShort().entries, [])
    }

    func testGitRepositoryListsLocalBranches() throws {
        let repoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-git-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repoURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: repoURL) }

        let bootstrap = ShellCommandRunner(workingDirectory: repoURL)
        _ = try bootstrap.run("""
        git init &&
        git config user.name Termy &&
        git config user.email termy@example.test &&
        touch README.md &&
        git add README.md &&
        git commit -m initial &&
        git branch -M main &&
        git checkout -b feature/terminal
        """)

        let branches = try GitRepository(root: repoURL).localBranches()

        XCTAssertEqual(Set(branches), ["main", "feature/terminal"])
    }

    func testGitRepositoryDiffAndBranchFlow() throws {
        let repoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-git-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repoURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: repoURL) }

        let bootstrap = ShellCommandRunner(workingDirectory: repoURL)
        try "hello\n".write(to: repoURL.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        _ = try bootstrap.run("""
        git init &&
        git config user.name Termy &&
        git config user.email termy@example.test &&
        git add README.md &&
        git commit -m initial &&
        git branch -M main
        """)
        try "hello world\n".write(to: repoURL.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)

        let repository = GitRepository(root: repoURL)

        XCTAssertTrue(try repository.diff().contains("-hello"))
        XCTAssertTrue(try repository.diff().contains("+hello world"))

        try repository.createBranch(named: "feature/git", checkout: true)
        XCTAssertEqual(try repository.currentBranch(), "feature/git")

        try repository.checkoutBranch("main")
        XCTAssertEqual(try repository.currentBranch(), "main")
    }

    func testGitRepositoryPushesAndPullsCurrentBranchWithLocalRemote() throws {
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-git-remote-\(UUID().uuidString)", isDirectory: true)
        let repoURL = parent.appendingPathComponent("repo", isDirectory: true)
        let bareURL = parent.appendingPathComponent("origin.git", isDirectory: true)
        let cloneURL = parent.appendingPathComponent("clone", isDirectory: true)
        try FileManager.default.createDirectory(at: repoURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }

        _ = try ShellCommandRunner(workingDirectory: parent).run("git init --bare '\(bareURL.path)'")
        let bootstrap = ShellCommandRunner(workingDirectory: repoURL)
        try "one\n".write(to: repoURL.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        _ = try bootstrap.run("""
        git init &&
        git config user.name Termy &&
        git config user.email termy@example.test &&
        git add README.md &&
        git commit -m initial &&
        git branch -M main &&
        git remote add origin '\(bareURL.path)'
        """)

        let repository = GitRepository(root: repoURL)
        _ = try repository.pushCurrentBranch(setUpstream: true)

        _ = try ShellCommandRunner(workingDirectory: parent).run("git clone -b main '\(bareURL.path)' '\(cloneURL.path)'")
        let cloneRunner = ShellCommandRunner(workingDirectory: cloneURL)
        _ = try cloneRunner.run("git config user.name Termy && git config user.email termy@example.test")
        try "two\n".write(to: cloneURL.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        _ = try cloneRunner.run("git add README.md && git commit -m remote-change && git push origin main")

        _ = try repository.pullCurrentBranch()

        XCTAssertEqual(try String(contentsOf: repoURL.appendingPathComponent("README.md"), encoding: .utf8), "two\n")
    }

    func testGitRepositoryReportsAheadBehindAgainstUpstream() throws {
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-git-ahead-\(UUID().uuidString)", isDirectory: true)
        let repoURL = parent.appendingPathComponent("repo", isDirectory: true)
        let bareURL = parent.appendingPathComponent("origin.git", isDirectory: true)
        try FileManager.default.createDirectory(at: repoURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }

        _ = try ShellCommandRunner(workingDirectory: parent).run("git init --bare '\(bareURL.path)'")
        let runner = ShellCommandRunner(workingDirectory: repoURL)
        try "one\n".write(to: repoURL.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        _ = try runner.run("""
        git init &&
        git config user.name Termy &&
        git config user.email termy@example.test &&
        git add README.md &&
        git commit -m initial &&
        git branch -M main &&
        git remote add origin '\(bareURL.path)' &&
        git push --set-upstream origin main
        """)

        try "two\n".write(to: repoURL.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        _ = try runner.run("git add README.md && git commit -m local-change")

        let divergence = try GitRepository(root: repoURL).aheadBehind()

        XCTAssertEqual(divergence, .init(ahead: 1, behind: 0))
    }

    func testGitConflictParserExtractsOursAndTheirsHunks() {
        let text = """
        title
        <<<<<<< HEAD
        local change
        local detail
        =======
        remote change
        >>>>>>> feature/login
        tail
        """

        let hunks = GitConflictParser().parse(text, path: "README.md")

        XCTAssertEqual(
            hunks,
            [
                GitConflictHunk(
                    path: "README.md",
                    oursLabel: "HEAD",
                    theirsLabel: "feature/login",
                    ours: "local change\nlocal detail",
                    theirs: "remote change"
                )
            ]
        )
    }

    func testGitRepositoryReadsConflictedFileHunks() throws {
        let repoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-git-conflict-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repoURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: repoURL) }

        let runner = ShellCommandRunner(workingDirectory: repoURL)
        try "base\n".write(to: repoURL.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        _ = try runner.run("""
        git init &&
        git config user.name Termy &&
        git config user.email termy@example.test &&
        git add README.md &&
        git commit -m initial &&
        git branch -M main &&
        git checkout -b feature/conflict
        """)
        try "feature\n".write(to: repoURL.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        _ = try runner.run("git add README.md && git commit -m feature")
        _ = try runner.run("git checkout main")
        try "main\n".write(to: repoURL.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        _ = try runner.run("git add README.md && git commit -m main")
        _ = try runner.run("git merge feature/conflict")

        let hunks = try GitRepository(root: repoURL).conflictHunks()

        XCTAssertEqual(hunks.count, 1)
        XCTAssertEqual(hunks.first?.path, "README.md")
        XCTAssertEqual(hunks.first?.ours, "main")
        XCTAssertEqual(hunks.first?.theirs, "feature")
    }

    func testLocalFileServiceCreatesRenamesAndDeletesFilesInsideRoot() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-files-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = LocalFileService(root: root)

        try service.createFile(named: "notes/today.md", contents: "# Today\n")
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("notes/today.md"), encoding: .utf8), "# Today\n")

        try service.rename("notes/today.md", to: "notes/tomorrow.md")
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("notes/today.md").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("notes/tomorrow.md").path))

        try service.delete("notes/tomorrow.md")
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("notes/tomorrow.md").path))
    }

    func testLocalFileServiceMovesItemsIntoDestinationFolderInsideRoot() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-files-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = LocalFileService(root: root)
        try service.createFile(named: "notes/today.md", contents: "# Today\n")

        let movedPath = try service.move("notes/today.md", toDirectory: "archive")

        XCTAssertEqual(movedPath, "archive/today.md")
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("notes/today.md").path))
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("archive/today.md"), encoding: .utf8), "# Today\n")
    }

    func testLocalFileServiceBuildsFileTreeWithDepthAndTypeIcons() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-files-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = LocalFileService(root: root)
        try service.createFile(named: "Sources/Termy/App.swift", contents: "let app = true\n")
        try service.createFile(named: "README.md", contents: "# Termy\n")
        try service.createFile(named: "Assets/logo.png", contents: "png")

        let tree = try service.tree()

        XCTAssertEqual(tree.map(\.item.relativePath), [
            "Assets",
            "Assets/logo.png",
            "Sources",
            "Sources/Termy",
            "Sources/Termy/App.swift",
            "README.md"
        ])
        XCTAssertEqual(tree.map(\.depth), [0, 1, 0, 1, 2, 0])
        XCTAssertEqual(tree.map(\.iconName), ["folder", "photo", "folder", "folder", "curlybraces", "doc.richtext"])
        XCTAssertEqual(tree.filter(\.isExpandable).map(\.item.relativePath), ["Assets", "Sources", "Sources/Termy"])
    }

    func testLocalFileServiceReadsAndWritesTextFilesInsideRoot() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-files-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = LocalFileService(root: root)

        try service.writeText("one", to: "notes.md")
        XCTAssertEqual(try service.readText("notes.md"), "one")

        try service.writeText("two", to: "notes.md")
        XCTAssertEqual(try service.readText("notes.md"), "two")
    }

    func testLocalFileServiceRejectsPathTraversal() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-files-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = LocalFileService(root: root)

        XCTAssertThrowsError(try service.createFile(named: "../escape.txt")) { error in
            XCTAssertEqual(error as? LocalFileServiceError, .pathEscapesRoot)
        }
        XCTAssertThrowsError(try service.move("notes.md", toDirectory: "../escape")) { error in
            XCTAssertEqual(error as? LocalFileServiceError, .pathEscapesRoot)
        }
    }

    func testLocalFileServiceRejectsSymlinkTraversal() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-files-\(UUID().uuidString)", isDirectory: true)
        let outside = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-outside-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: outside)
        }
        try "secret".write(to: outside.appendingPathComponent("secret.txt"), atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("outside"),
            withDestinationURL: outside
        )

        let service = LocalFileService(root: root)

        XCTAssertThrowsError(try service.readText("outside/secret.txt")) { error in
            XCTAssertEqual(error as? LocalFileServiceError, .pathEscapesRoot)
        }
        XCTAssertThrowsError(try service.writeText("overwrite", to: "outside/secret.txt")) { error in
            XCTAssertEqual(error as? LocalFileServiceError, .pathEscapesRoot)
        }
    }

    func testLocalFileSearchFiltersAndRanksByNameAndPath() {
        let items = [
            LocalFileItem(name: "README.md", relativePath: "README.md", isDirectory: false),
            LocalFileItem(name: "GitPanel.swift", relativePath: "Sources/Termy/Views/GitPanel.swift", isDirectory: false),
            LocalFileItem(name: "GitRepository.swift", relativePath: "Sources/TermyCore/GitRepository.swift", isDirectory: false),
            LocalFileItem(name: "docs", relativePath: "docs", isDirectory: true)
        ]

        let results = LocalFileSearch(items: items).search("git")

        XCTAssertEqual(results.map(\.relativePath), [
            "Sources/Termy/Views/GitPanel.swift",
            "Sources/TermyCore/GitRepository.swift"
        ])
        XCTAssertEqual(LocalFileSearch(items: items).search("term core").map(\.relativePath), [
            "Sources/TermyCore/GitRepository.swift"
        ])
        XCTAssertEqual(LocalFileSearch(items: items).search("").count, items.count)
    }

    func testProjectGuidanceLoaderReadsTermyAndAgentGuidanceFiles() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-guidance-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try "Termy memory".write(to: root.appendingPathComponent("TERMY.md"), atomically: true, encoding: .utf8)
        try "Claude rules".write(to: root.appendingPathComponent("CLAUDE.md"), atomically: true, encoding: .utf8)
        try "Agent rules".write(to: root.appendingPathComponent("AGENTS.md"), atomically: true, encoding: .utf8)

        let guidance = ProjectGuidanceLoader().load(from: root)

        XCTAssertEqual(guidance.documents.map(\.fileName), ["TERMY.md", "CLAUDE.md", "AGENTS.md"])
        XCTAssertTrue(guidance.combinedContext(maxCharacters: 80).contains("Termy memory"))
        XCTAssertLessThanOrEqual(guidance.combinedContext(maxCharacters: 10).count, 10)
    }

    func testSyntaxHighlighterTokenizesMarkdownJSONAndSwift() {
        let highlighter = SyntaxHighlighter()

        XCTAssertEqual(
            highlighter.highlight("# Title", fileName: "README.md"),
            [.init(text: "# Title", kind: .heading)]
        )
        XCTAssertEqual(
            highlighter.highlight(#"{"name": "Termy"}"#, fileName: "package.json"),
            [
                .init(text: "{", kind: .plain),
                .init(text: #""name""#, kind: .key),
                .init(text: ": ", kind: .plain),
                .init(text: #""Termy""#, kind: .string),
                .init(text: "}", kind: .plain)
            ]
        )
        XCTAssertEqual(
            highlighter.highlight("let value = \"Termy\"", fileName: "App.swift"),
            [
                .init(text: "let", kind: .keyword),
                .init(text: " value = ", kind: .plain),
                .init(text: "\"Termy\"", kind: .string)
            ]
        )
    }

    func testSyntaxHighlighterBoundsUnterminatedStringToItsLine() {
        // A stray/unterminated quote must not render the rest of the file as a
        // string — the `let` on the next line is still highlighted as a keyword.
        let tokens = SyntaxHighlighter().highlight("x = \"oops\nlet y = 1", fileName: "App.swift")
        XCTAssertTrue(tokens.contains { $0.text == "let" && $0.kind == .keyword },
                      "an unterminated string on line 1 must not swallow line 2's keyword")
        XCTAssertFalse(tokens.contains { $0.kind == .string && $0.text.contains("let") },
                       "the string token must stop at the newline")
    }

    func testSyntaxHighlighterCoversPRDEditorLanguages() {
        let highlighter = SyntaxHighlighter()

        let samples: [(String, String, SyntaxTokenKind, String)] = [
            ("app.ts", "const value = \"Termy\"", .keyword, "const"),
            ("app.js", "function run() { return true }", .keyword, "function"),
            ("main.py", "def run():\n    return 'ok'", .keyword, "def"),
            ("main.rs", "fn main() { let value = 1; }", .keyword, "fn"),
            ("index.html", "<main class=\"app\">Termy</main>", .keyword, "<main"),
            ("style.css", ".app { color: red; }", .key, "color")
        ]

        for (fileName, source, expectedKind, expectedText) in samples {
            let tokens = highlighter.highlight(source, fileName: fileName)
            XCTAssertTrue(
                tokens.contains { $0.kind == expectedKind && $0.text.contains(expectedText) },
                "Expected \(fileName) to highlight \(expectedText) as \(expectedKind), got \(tokens)"
            )
        }
    }

    func testVimEditorStateSupportsNormalModeMovementDeletionAndInsertSwitch() {
        var state = VimEditorState(buffer: "abc\ndef", cursorOffset: 1)

        state.apply(.moveRight)
        XCTAssertEqual(state.cursorOffset, 2)

        state.apply(.deleteCharacter)
        XCTAssertEqual(state.buffer, "ab\ndef")
        XCTAssertEqual(state.cursorOffset, 2)

        state.apply(.moveLeft)
        XCTAssertEqual(state.cursorOffset, 1)

        state.apply(.enterInsertMode)
        XCTAssertEqual(state.mode, .insert)
        state.insert("Z")
        XCTAssertEqual(state.buffer, "aZb\ndef")
        XCTAssertEqual(state.cursorOffset, 2)

        state.apply(.enterNormalMode)
        XCTAssertEqual(state.mode, .normal)
    }

    func testVimEditorStateSupportsAppendAndOpenLineInsertCommands() {
        var state = VimEditorState(buffer: "abc\ndef", cursorOffset: 1)

        state.apply(.enterAppendMode)
        XCTAssertEqual(state.mode, .insert)
        XCTAssertEqual(state.cursorOffset, 2)
        state.insert("Z")
        XCTAssertEqual(state.buffer, "abZc\ndef")

        state = VimEditorState(buffer: "abc\ndef", cursorOffset: 1)
        state.apply(.enterAppendLineMode)
        XCTAssertEqual(state.mode, .insert)
        XCTAssertEqual(state.cursorOffset, 3)
        state.insert("!")
        XCTAssertEqual(state.buffer, "abc!\ndef")

        state = VimEditorState(buffer: "abc\ndef", cursorOffset: 1)
        state.apply(.openLineBelow)
        XCTAssertEqual(state.mode, .insert)
        XCTAssertEqual(state.cursorOffset, 4)
        state.insert("new")
        XCTAssertEqual(state.buffer, "abc\nnew\ndef")

        state = VimEditorState(buffer: "abc\ndef", cursorOffset: 5)
        state.apply(.openLineAbove)
        XCTAssertEqual(state.mode, .insert)
        XCTAssertEqual(state.cursorOffset, 4)
        state.insert("new")
        XCTAssertEqual(state.buffer, "abc\nnew\ndef")
    }

    func testVimEditorStateMovesAcrossLines() {
        var state = VimEditorState(buffer: "abc\ndefg\nhi", cursorOffset: 1)

        state.apply(.moveDown)
        XCTAssertEqual(state.cursorOffset, 5)

        state.apply(.moveDown)
        XCTAssertEqual(state.cursorOffset, 10)

        state.apply(.moveUp)
        XCTAssertEqual(state.cursorOffset, 5)
    }

    func testVimEditorStateMovesToLineBoundsAndInsertsAtLineStart() {
        var state = VimEditorState(buffer: "abc\ndefg\nhi", cursorOffset: 5)

        state.apply(.moveLineStart)
        XCTAssertEqual(state.cursorOffset, 4)

        state.apply(.moveLineEnd)
        XCTAssertEqual(state.cursorOffset, 8)

        state.apply(.enterInsertLineStartMode)
        XCTAssertEqual(state.mode, .insert)
        XCTAssertEqual(state.cursorOffset, 4)

        state.insert(">")
        XCTAssertEqual(state.buffer, "abc\n>defg\nhi")
    }

    func testVimEditorStateMovesToCountedLineEnd() {
        var state = VimEditorState(buffer: "abc\ndefg\nhi", cursorOffset: 1)

        state.apply(.countDigit(2))
        state.apply(.moveLineEnd)
        XCTAssertEqual(state.cursorOffset, 8)

        state = VimEditorState(buffer: "abc\ndefg\nhi", cursorOffset: 1)
        state.apply(.deleteOperator)
        state.apply(.countDigit(2))
        state.apply(.moveLineEnd)

        XCTAssertEqual(state.buffer, "a\nhi")
        XCTAssertEqual(state.cursorOffset, 1)
    }

    func testVimEditorStateMovesToFirstNonBlankInLine() {
        var state = VimEditorState(buffer: "root\n  let value = 1", cursorOffset: 12)

        state.apply(.moveFirstNonBlankInLine)
        XCTAssertEqual(state.cursorOffset, 7)

        state = VimEditorState(buffer: "root\n  let value = 1", cursorOffset: 11)
        state.apply(.deleteOperator)
        state.apply(.moveFirstNonBlankInLine)

        XCTAssertEqual(state.buffer, "root\n  value = 1")
        XCTAssertEqual(state.cursorOffset, 7)
    }

    func testVimEditorStateMovesToFirstNonBlankLineWithCountsAndOperators() {
        var state = VimEditorState(buffer: "one\n  two\n    three", cursorOffset: 8)

        state.apply(.moveFirstNonBlankLine)
        XCTAssertEqual(state.cursorOffset, 6)

        state = VimEditorState(buffer: "one\n  two\n    three", cursorOffset: 0)
        state.apply(.countDigit(3))
        state.apply(.moveFirstNonBlankLine)
        XCTAssertEqual(state.cursorOffset, 14)

        state = VimEditorState(buffer: "one\n  two\n    three", cursorOffset: 4)
        state.apply(.deleteOperator)
        state.apply(.countDigit(2))
        state.apply(.moveFirstNonBlankLine)

        XCTAssertEqual(state.buffer, "one\nthree")
        XCTAssertEqual(state.cursorOffset, 4)
    }

    func testVimEditorStateMovesToLastNonBlankLineWithCountsAndOperators() {
        var state = VimEditorState(buffer: "one  \n  two  \n    three  ", cursorOffset: 5)

        state.apply(.moveLastNonBlankLine)
        XCTAssertEqual(state.cursorOffset, 2)

        state = VimEditorState(buffer: "one  \n  two  \n    three  ", cursorOffset: 0)
        state.apply(.countDigit(3))
        state.apply(.moveLastNonBlankLine)
        XCTAssertEqual(state.cursorOffset, 22)

        state = VimEditorState(buffer: "one  \n  two  \n    three  ", cursorOffset: 6)
        state.apply(.deleteOperator)
        state.apply(.moveLastNonBlankLine)

        XCTAssertEqual(state.buffer, "one  \n  \n    three  ")
        XCTAssertEqual(state.cursorOffset, 6)
    }

    func testVimEditorStateMovesToAdjacentFirstNonBlankLinesWithCountsAndOperators() {
        var state = VimEditorState(buffer: "one\n  two\n    three", cursorOffset: 0)

        state.apply(.moveFirstNonBlankLineDown)
        XCTAssertEqual(state.cursorOffset, 6)

        state.apply(.countDigit(2))
        state.apply(.moveFirstNonBlankLineUp)
        XCTAssertEqual(state.cursorOffset, 0)

        state.apply(.countDigit(2))
        state.apply(.moveFirstNonBlankLineDown)
        XCTAssertEqual(state.cursorOffset, 14)

        state = VimEditorState(buffer: "one\n  two\n    three", cursorOffset: 0)
        state.apply(.deleteOperator)
        state.apply(.moveFirstNonBlankLineDown)

        XCTAssertEqual(state.buffer, "two\n    three")
        XCTAssertEqual(state.cursorOffset, 0)
    }

    func testVimEditorStateMovesToColumnsWithCountsAndOperators() {
        var state = VimEditorState(buffer: "abc\ndefgh\nij", cursorOffset: 5)

        state.apply(.countDigit(4))
        state.apply(.moveToColumn)
        XCTAssertEqual(state.cursorOffset, 7)

        state.apply(.countDigit(2))
        state.apply(.countDigit(0))
        state.apply(.moveToColumn)
        XCTAssertEqual(state.cursorOffset, 9)

        state = VimEditorState(buffer: "abc\ndefgh\nij", cursorOffset: 8)
        state.apply(.deleteOperator)
        state.apply(.countDigit(2))
        state.apply(.moveToColumn)

        XCTAssertEqual(state.buffer, "abc\ndh\nij")
        XCTAssertEqual(state.cursorOffset, 5)
    }

    func testVimEditorStateJoinsCurrentLineWithNextLine() {
        var state = VimEditorState(buffer: "one\ntwo\nthree", cursorOffset: 1)

        state.apply(.joinLineBelow)

        XCTAssertEqual(state.buffer, "one two\nthree")
        XCTAssertEqual(state.cursorOffset, 3)

        state.apply(.moveDown)
        state.apply(.joinLineBelow)

        XCTAssertEqual(state.buffer, "one two\nthree")
        XCTAssertEqual(state.cursorOffset, 11)
    }

    func testVimEditorStateJoinsCountedLines() {
        var state = VimEditorState(buffer: "one\n  two\n  three\nfour", cursorOffset: 1)

        state.apply(.countDigit(3))
        state.apply(.joinLineBelow)

        XCTAssertEqual(state.buffer, "one two three\nfour")
        XCTAssertEqual(state.cursorOffset, 3)
    }

    func testVimEditorStateAppliesCountPrefixesToMotionAndDelete() {
        var state = VimEditorState(buffer: "abcdef\nghi", cursorOffset: 0)

        state.apply(.countDigit(3))
        XCTAssertEqual(state.pendingCount, 3)

        state.apply(.moveRight)
        XCTAssertEqual(state.cursorOffset, 3)
        XCTAssertNil(state.pendingCount)

        state.apply(.countDigit(2))
        state.apply(.deleteCharacter)
        XCTAssertEqual(state.buffer, "abcf\nghi")
        XCTAssertEqual(state.cursorOffset, 3)
        XCTAssertNil(state.pendingCount)

        state.apply(.countDigit(2))
        state.apply(.moveDown)
        XCTAssertEqual(state.cursorOffset, 8)
        XCTAssertNil(state.pendingCount)
    }

    func testVimEditorStateSupportsWordMotionsWithCounts() {
        var state = VimEditorState(buffer: "one two_three four", cursorOffset: 0)

        state.apply(.moveWordForward)
        XCTAssertEqual(state.cursorOffset, 4)

        state.apply(.moveWordEnd)
        XCTAssertEqual(state.cursorOffset, 12)

        state.apply(.moveWordBackward)
        XCTAssertEqual(state.cursorOffset, 4)

        state.apply(.moveWordBackward)
        XCTAssertEqual(state.cursorOffset, 0)

        state.apply(.countDigit(2))
        state.apply(.moveWordForward)
        XCTAssertEqual(state.cursorOffset, 14)
        XCTAssertNil(state.pendingCount)
    }

    func testVimEditorStateSupportsBigWordMotionsWithCountsAndOperators() {
        var state = VimEditorState(buffer: "foo.bar baz/qux end", cursorOffset: 0)

        state.apply(.moveBigWordForward)
        XCTAssertEqual(state.cursorOffset, 8)

        state.apply(.moveBigWordEnd)
        XCTAssertEqual(state.cursorOffset, 14)

        state.apply(.moveBigWordBackward)
        XCTAssertEqual(state.cursorOffset, 8)

        state.apply(.countDigit(2))
        state.apply(.moveBigWordForward)
        XCTAssertEqual(state.cursorOffset, 19)

        state = VimEditorState(buffer: "foo.bar baz/qux end", cursorOffset: 0)
        state.apply(.deleteOperator)
        state.apply(.moveBigWordForward)

        XCTAssertEqual(state.buffer, "baz/qux end")
        XCTAssertEqual(state.cursorOffset, 0)
    }

    func testVimEditorStateSupportsPreviousWordEndMotionsWithCountsAndOperators() {
        var state = VimEditorState(buffer: "foo bar_baz qux", cursorOffset: 14)

        state.apply(.moveWordEndBackward)
        XCTAssertEqual(state.cursorOffset, 10)

        state.apply(.countDigit(2))
        state.apply(.moveWordEndBackward)
        XCTAssertEqual(state.cursorOffset, 0)

        state = VimEditorState(buffer: "foo.bar baz/qux end", cursorOffset: 18)
        state.apply(.moveBigWordEndBackward)
        XCTAssertEqual(state.cursorOffset, 14)

        state.apply(.moveBigWordEndBackward)
        XCTAssertEqual(state.cursorOffset, 6)

        state = VimEditorState(buffer: "one two three", cursorOffset: 13)
        state.apply(.deleteOperator)
        state.apply(.moveWordEndBackward)

        XCTAssertEqual(state.buffer, "one two")
        XCTAssertEqual(state.cursorOffset, 7)
    }

    func testVimEditorStateDeletesWithPendingWordOperatorsAndCounts() {
        var state = VimEditorState(buffer: "one two three", cursorOffset: 0)

        state.apply(.deleteOperator)
        XCTAssertEqual(state.pendingOperator, .delete)

        state.apply(.moveWordForward)
        XCTAssertEqual(state.buffer, "two three")
        XCTAssertEqual(state.cursorOffset, 0)
        XCTAssertNil(state.pendingOperator)

        state = VimEditorState(buffer: "one two three", cursorOffset: 0)
        state.apply(.countDigit(2))
        state.apply(.deleteOperator)
        state.apply(.moveWordForward)
        XCTAssertEqual(state.buffer, "three")
        XCTAssertEqual(state.cursorOffset, 0)
        XCTAssertNil(state.pendingCount)
        XCTAssertNil(state.pendingOperator)

        state = VimEditorState(buffer: "one two", cursorOffset: 0)
        state.apply(.deleteOperator)
        state.apply(.moveWordEnd)
        XCTAssertEqual(state.buffer, " two")
        XCTAssertEqual(state.cursorOffset, 0)
    }

    func testVimEditorStateDeletesCurrentLineWithRepeatedDeleteOperatorAndCounts() {
        var state = VimEditorState(buffer: "one\ntwo\nthree\n", cursorOffset: 4)

        state.apply(.deleteOperator)
        state.apply(.deleteOperator)

        XCTAssertEqual(state.buffer, "one\nthree\n")
        XCTAssertEqual(state.cursorOffset, 4)
        XCTAssertNil(state.pendingOperator)

        state = VimEditorState(buffer: "one\ntwo\nthree\n", cursorOffset: 0)
        state.apply(.countDigit(2))
        state.apply(.deleteOperator)
        state.apply(.deleteOperator)

        XCTAssertEqual(state.buffer, "three\n")
        XCTAssertEqual(state.cursorOffset, 0)
        XCTAssertNil(state.pendingCount)
        XCTAssertNil(state.pendingOperator)
    }

    func testVimEditorStateChangesWordsAndLinesThenEntersInsertMode() {
        var state = VimEditorState(buffer: "one two", cursorOffset: 0)

        state.apply(.changeOperator)
        XCTAssertEqual(state.pendingOperator, .change)

        state.apply(.moveWordForward)

        XCTAssertEqual(state.buffer, "two")
        XCTAssertEqual(state.cursorOffset, 0)
        XCTAssertEqual(state.mode, .insert)
        XCTAssertNil(state.pendingOperator)

        state.insert("zero ")
        XCTAssertEqual(state.buffer, "zero two")

        state = VimEditorState(buffer: "one\ntwo\nthree", cursorOffset: 4)
        state.apply(.changeOperator)
        state.apply(.changeOperator)

        XCTAssertEqual(state.buffer, "one\n\nthree")
        XCTAssertEqual(state.cursorOffset, 4)
        XCTAssertEqual(state.mode, .insert)
        XCTAssertNil(state.pendingOperator)
    }

    func testVimEditorStateYanksMotionsLinesAndPastesRegister() {
        var state = VimEditorState(buffer: "one two three", cursorOffset: 0)

        state.apply(.yankOperator)
        XCTAssertEqual(state.pendingOperator, .yank)

        state.apply(.moveWordForward)
        XCTAssertEqual(state.buffer, "one two three")
        XCTAssertEqual(state.yankRegister, "one ")
        XCTAssertEqual(state.cursorOffset, 0)
        XCTAssertNil(state.pendingOperator)

        state.apply(.moveWordForward)
        state.apply(.pasteBefore)

        XCTAssertEqual(state.buffer, "one one two three")
        // Vim: cursor lands on the last char of the charwise paste ("one " → offset 7).
        XCTAssertEqual(state.cursorOffset, 7)

        state = VimEditorState(buffer: "one\ntwo\nthree", cursorOffset: 4)
        state.apply(.yankOperator)
        state.apply(.yankOperator)
        XCTAssertEqual(state.yankRegister, "two\n")

        state.apply(.moveDown)
        state.apply(.pasteAfter)

        XCTAssertEqual(state.buffer, "one\ntwo\nthree\ntwo\n")
        XCTAssertEqual(state.cursorOffset, 14)
    }

    func testVimEditorStatePastesRegisterWithCounts() {
        var state = VimEditorState(buffer: "one two", cursorOffset: 0)

        state.apply(.yankOperator)
        state.apply(.moveWordForward)
        state.apply(.countDigit(3))
        state.apply(.pasteBefore)

        XCTAssertEqual(state.buffer, "one one one one two")
        // Vim: cursor on the last char of the charwise paste ("one one one " → offset 11).
        XCTAssertEqual(state.cursorOffset, 11)

        state = VimEditorState(buffer: "one\ntwo\nthree", cursorOffset: 4)
        state.apply(.yankOperator)
        state.apply(.yankOperator)
        state.apply(.moveDown)
        state.apply(.countDigit(2))
        state.apply(.pasteAfter)

        XCTAssertEqual(state.buffer, "one\ntwo\nthree\ntwo\ntwo\n")
        XCTAssertEqual(state.cursorOffset, 14)
    }

    func testVimEditorStateDeletesChangesAndYanksToLineEnd() {
        var state = VimEditorState(buffer: "one two\nthree", cursorOffset: 4)

        state.apply(.deleteToLineEnd)

        XCTAssertEqual(state.buffer, "one \nthree")
        XCTAssertEqual(state.cursorOffset, 4)

        state = VimEditorState(buffer: "one two\nthree", cursorOffset: 4)
        state.apply(.changeToLineEnd)

        XCTAssertEqual(state.buffer, "one \nthree")
        XCTAssertEqual(state.cursorOffset, 4)
        XCTAssertEqual(state.mode, .insert)

        state = VimEditorState(buffer: "one two\nthree", cursorOffset: 4)
        state.apply(.yankToLineEnd)

        XCTAssertEqual(state.buffer, "one two\nthree")
        XCTAssertEqual(state.yankRegister, "two")
        XCTAssertEqual(state.cursorOffset, 4)
    }

    func testVimEditorStateDeletesChangesAndYanksToCountedLineEnd() {
        var state = VimEditorState(buffer: "abc\ndefg\nhi", cursorOffset: 1)

        state.apply(.countDigit(2))
        state.apply(.deleteToLineEnd)

        XCTAssertEqual(state.buffer, "a\nhi")
        XCTAssertEqual(state.cursorOffset, 1)

        state = VimEditorState(buffer: "abc\ndefg\nhi", cursorOffset: 1)
        state.apply(.countDigit(2))
        state.apply(.changeToLineEnd)

        XCTAssertEqual(state.buffer, "a\nhi")
        XCTAssertEqual(state.cursorOffset, 1)
        XCTAssertEqual(state.mode, .insert)

        state = VimEditorState(buffer: "abc\ndefg\nhi", cursorOffset: 1)
        state.apply(.countDigit(2))
        state.apply(.yankToLineEnd)

        XCTAssertEqual(state.buffer, "abc\ndefg\nhi")
        XCTAssertEqual(state.yankRegister, "bc\ndefg")
        XCTAssertEqual(state.cursorOffset, 1)
    }

    func testVimEditorStateUndoRestoresLastTextChange() {
        var state = VimEditorState(buffer: "one two", cursorOffset: 0)

        state.apply(.deleteOperator)
        state.apply(.moveWordForward)
        XCTAssertEqual(state.buffer, "two")

        state.apply(.undoLastChange)

        XCTAssertEqual(state.buffer, "one two")
        XCTAssertEqual(state.cursorOffset, 0)
        XCTAssertEqual(state.mode, .normal)

        state.apply(.enterInsertMode)
        state.insert("zero ")
        state.apply(.enterNormalMode)
        XCTAssertEqual(state.buffer, "zero one two")

        state.apply(.undoLastChange)

        XCTAssertEqual(state.buffer, "one two")
        XCTAssertEqual(state.cursorOffset, 0)
        XCTAssertEqual(state.mode, .normal)
    }

    func testVimEditorStateRedoRestoresUndoneTextChangeAndClearsOnNewEdit() {
        var state = VimEditorState(buffer: "one two", cursorOffset: 0)

        state.apply(.deleteOperator)
        state.apply(.moveWordForward)
        XCTAssertEqual(state.buffer, "two")

        state.apply(.undoLastChange)
        XCTAssertEqual(state.buffer, "one two")

        state.apply(.redoLastUndo)

        XCTAssertEqual(state.buffer, "two")
        XCTAssertEqual(state.cursorOffset, 0)
        XCTAssertEqual(state.mode, .normal)

        state.apply(.undoLastChange)
        state.apply(.enterInsertMode)
        state.insert("zero ")
        state.apply(.enterNormalMode)

        state.apply(.redoLastUndo)

        XCTAssertEqual(state.buffer, "zero one two")
        XCTAssertEqual(state.cursorOffset, 5)
    }

    func testVimEditorStateSubstitutesCharacterAndLineThenEntersInsertMode() {
        var state = VimEditorState(buffer: "one two", cursorOffset: 4)

        state.apply(.substituteCharacter)

        XCTAssertEqual(state.buffer, "one wo")
        XCTAssertEqual(state.cursorOffset, 4)
        XCTAssertEqual(state.mode, .insert)

        state.insert("T")
        XCTAssertEqual(state.buffer, "one Two")

        state = VimEditorState(buffer: "one\ntwo\nthree", cursorOffset: 5)
        state.apply(.substituteLine)

        XCTAssertEqual(state.buffer, "one\n\nthree")
        XCTAssertEqual(state.cursorOffset, 4)
        XCTAssertEqual(state.mode, .insert)
    }

    func testVimEditorStateTogglesCharacterCaseWithCountAndUndo() {
        var state = VimEditorState(buffer: "one TWO", cursorOffset: 0)

        state.apply(.toggleCharacterCase)
        XCTAssertEqual(state.buffer, "One TWO")
        XCTAssertEqual(state.cursorOffset, 1)

        state.apply(.countDigit(3))
        state.apply(.toggleCharacterCase)
        XCTAssertEqual(state.buffer, "ONE TWO")
        XCTAssertEqual(state.cursorOffset, 4)

        state.apply(.undoLastChange)
        XCTAssertEqual(state.buffer, "One TWO")
        XCTAssertEqual(state.cursorOffset, 1)
    }

    func testVimEditorStateDeletesCharactersBeforeCursorWithCountAndUndo() {
        var state = VimEditorState(buffer: "abcdef", cursorOffset: 3)

        state.apply(.deleteCharacterBeforeCursor)
        XCTAssertEqual(state.buffer, "abdef")
        XCTAssertEqual(state.cursorOffset, 2)

        state.apply(.countDigit(2))
        state.apply(.deleteCharacterBeforeCursor)
        XCTAssertEqual(state.buffer, "def")
        XCTAssertEqual(state.cursorOffset, 0)

        state.apply(.undoLastChange)
        XCTAssertEqual(state.buffer, "abdef")
        XCTAssertEqual(state.cursorOffset, 2)
    }

    func testVimEditorStateReplacesCharactersWithCountAndUndo() {
        var state = VimEditorState(buffer: "abcdef", cursorOffset: 2)

        state.apply(.replaceCharacter("Z"))
        XCTAssertEqual(state.buffer, "abZdef")
        XCTAssertEqual(state.cursorOffset, 3)
        XCTAssertEqual(state.mode, .normal)

        state.apply(.countDigit(2))
        state.apply(.replaceCharacter("x"))
        XCTAssertEqual(state.buffer, "abZxxf")
        XCTAssertEqual(state.cursorOffset, 5)

        state.apply(.undoLastChange)
        XCTAssertEqual(state.buffer, "abZdef")
        XCTAssertEqual(state.cursorOffset, 3)
    }

    func testVimEditorReplaceCharacterDoesNotCrossLineBoundary() {
        // `3r x` with only 1 char left on the line is a no-op in vim (it must not
        // replace the newline and merge the next line in).
        var state = VimEditorState(buffer: "ab\ncd", cursorOffset: 1)
        state.apply(.countDigit(3))
        state.apply(.replaceCharacter("x"))
        XCTAssertEqual(state.buffer, "ab\ncd")

        // A replace that fits on the line still works (1 char remains at offset 1).
        state.apply(.replaceCharacter("y"))
        XCTAssertEqual(state.buffer, "ay\ncd")
    }

    func testVimEditorDeleteWordDoesNotCrossLineBoundary() {
        // `dw` on the last word of a line deletes the word but keeps the newline —
        // it must not merge the next line in.
        var state = VimEditorState(buffer: "foo bar\nbaz", cursorOffset: 4)
        state.apply(.deleteOperator)
        state.apply(.moveWordForward)
        XCTAssertEqual(state.buffer, "foo \nbaz")
        XCTAssertEqual(state.cursorOffset, 4)
    }

    func testVimEditorStateMovesToMatchingBracket() {
        var state = VimEditorState(buffer: "call(foo[bar])", cursorOffset: 4)

        state.apply(.moveMatchingBracket)
        XCTAssertEqual(state.cursorOffset, 13)

        state = VimEditorState(buffer: "call(foo[bar])", cursorOffset: 12)
        state.apply(.moveMatchingBracket)
        XCTAssertEqual(state.cursorOffset, 8)

        state = VimEditorState(buffer: "call(foo[bar])", cursorOffset: 2)
        state.apply(.moveMatchingBracket)
        XCTAssertEqual(state.cursorOffset, 2)
    }

    func testVimEditorStateFindsCharactersForwardAndBackwardWithCounts() {
        var state = VimEditorState(buffer: "alpha beta gamma", cursorOffset: 0)

        state.apply(.findCharacterForward("a"))
        XCTAssertEqual(state.cursorOffset, 4)

        state.apply(.countDigit(2))
        state.apply(.findCharacterForward("a"))
        XCTAssertEqual(state.cursorOffset, 12)

        state.apply(.findCharacterBackward("a"))
        XCTAssertEqual(state.cursorOffset, 9)

        state.apply(.findCharacterForward("z"))
        XCTAssertEqual(state.cursorOffset, 9)
    }

    func testVimEditorStateMovesTillCharactersForwardAndBackwardWithCounts() {
        var state = VimEditorState(buffer: "alpha beta gamma", cursorOffset: 0)

        state.apply(.tillCharacterForward("a"))
        XCTAssertEqual(state.cursorOffset, 3)

        state.apply(.countDigit(2))
        state.apply(.tillCharacterForward("a"))
        XCTAssertEqual(state.cursorOffset, 8)

        state.apply(.tillCharacterBackward("a"))
        XCTAssertEqual(state.cursorOffset, 5)

        state.apply(.tillCharacterForward("z"))
        XCTAssertEqual(state.cursorOffset, 5)
    }

    func testVimEditorStateAppliesTillCharacterMotionsToOperators() {
        var state = VimEditorState(buffer: "alpha,beta,gamma", cursorOffset: 0)

        state.apply(.deleteOperator)
        state.apply(.tillCharacterForward(","))

        XCTAssertEqual(state.buffer, ",beta,gamma")
        XCTAssertEqual(state.cursorOffset, 0)

        state = VimEditorState(buffer: "alpha,beta,gamma", cursorOffset: 15)
        state.apply(.deleteOperator)
        state.apply(.tillCharacterBackward(","))

        XCTAssertEqual(state.buffer, "alpha,beta,a")
        XCTAssertEqual(state.cursorOffset, 11)
    }

    func testVimEditorStateRepeatsLastCharacterFindForwardAndReverse() {
        var state = VimEditorState(buffer: "alpha beta gamma", cursorOffset: 0)

        state.apply(.findCharacterForward("a"))
        XCTAssertEqual(state.cursorOffset, 4)

        state.apply(.repeatLastCharacterSearch)
        XCTAssertEqual(state.cursorOffset, 9)

        state.apply(.countDigit(2))
        state.apply(.repeatLastCharacterSearch)
        XCTAssertEqual(state.cursorOffset, 15)

        state.apply(.repeatLastCharacterSearchReversed)
        XCTAssertEqual(state.cursorOffset, 12)
    }

    func testVimEditorStateRepeatsLastTillCharacterSearch() {
        var state = VimEditorState(buffer: "alpha beta gamma", cursorOffset: 0)

        state.apply(.tillCharacterForward("a"))
        XCTAssertEqual(state.cursorOffset, 3)

        state.apply(.repeatLastCharacterSearch)
        XCTAssertEqual(state.cursorOffset, 8)

        state.apply(.repeatLastCharacterSearchReversed)
        XCTAssertEqual(state.cursorOffset, 5)
    }

    func testVimEditorStateAppliesRepeatedCharacterSearchToOperators() {
        var state = VimEditorState(buffer: "a,b,c,d", cursorOffset: 0)

        state.apply(.findCharacterForward(","))
        XCTAssertEqual(state.cursorOffset, 1)

        state.apply(.deleteOperator)
        state.apply(.repeatLastCharacterSearch)

        XCTAssertEqual(state.buffer, "ac,d")
        XCTAssertEqual(state.cursorOffset, 1)
    }

    func testVimEditorStateMovesToDocumentBounds() {
        var state = VimEditorState(buffer: "one\ntwo\nthree", cursorOffset: 5)

        state.apply(.moveDocumentEnd)
        XCTAssertEqual(state.cursorOffset, 13)

        state.apply(.moveDocumentStart)
        XCTAssertEqual(state.cursorOffset, 0)
    }

    func testVimEditorStateMovesToCountedDocumentLines() {
        var state = VimEditorState(buffer: "one\n  two\n    three\nfour", cursorOffset: 0)

        state.apply(.countDigit(3))
        state.apply(.moveDocumentEnd)
        XCTAssertEqual(state.cursorOffset, 14)

        state = VimEditorState(buffer: "one\n  two\n    three\nfour", cursorOffset: 18)
        state.apply(.countDigit(2))
        state.apply(.moveDocumentStart)
        XCTAssertEqual(state.cursorOffset, 6)
    }

    func testVimEditorStateSelectsVisualRangesWithMotions() {
        var state = VimEditorState(buffer: "one two three", cursorOffset: 4)

        state.apply(.enterVisualMode)
        XCTAssertEqual(state.mode, .visual)
        XCTAssertEqual(state.visualSelectionRange, 4..<5)

        state.apply(.countDigit(3))
        state.apply(.moveRight)

        XCTAssertEqual(state.cursorOffset, 7)
        XCTAssertEqual(state.visualSelectionRange, 4..<8)
        XCTAssertNil(state.pendingCount)
    }

    func testVimEditorStateDeletesVisualSelectionAndReturnsToNormalMode() {
        var state = VimEditorState(buffer: "one two three", cursorOffset: 4)

        state.apply(.enterVisualMode)
        state.apply(.moveWordForward)
        state.apply(.deleteOperator)

        XCTAssertEqual(state.buffer, "one three")
        XCTAssertEqual(state.cursorOffset, 4)
        XCTAssertEqual(state.mode, .normal)
        XCTAssertNil(state.visualSelectionRange)

        state = VimEditorState(buffer: "one two three", cursorOffset: 4)
        state.apply(.enterVisualMode)
        state.apply(.moveRight)
        state.apply(.deleteCharacter)

        XCTAssertEqual(state.buffer, "one o three")
        XCTAssertEqual(state.cursorOffset, 4)
        XCTAssertEqual(state.mode, .normal)
        XCTAssertNil(state.visualSelectionRange)
    }

    func testTextDiffPreviewShowsRemovedAndAddedLines() {
        let diff = TextDiffPreview.makeDiff(
            original: "one\ntwo\nthree\n",
            proposed: "one\nTWO\nthree\nfour\n"
        )

        XCTAssertEqual(
            diff,
            """
             one
            -two
            +TWO
             three
            +four
            """
        )
    }

    func testUnifiedTextPatchAppliesSingleHunkToEditorBuffer() throws {
        let patch = """
        --- a/notes.md
        +++ b/notes.md
        @@ -1,3 +1,4 @@
         one
        -two
        +TWO
         three
        +four
        """

        let result = try UnifiedTextPatch.apply(patch, to: "one\ntwo\nthree\n")

        XCTAssertEqual(result, "one\nTWO\nthree\nfour\n")
    }

    func testMultiFileUnifiedPatchAppliesChangesInsideLocalFileRoot() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-patch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = LocalFileService(root: root)
        try service.createFile(named: "README.md", contents: "one\ntwo\n")
        try service.createFile(named: "Sources/App.swift", contents: "let title = \"Old\"\n")

        let patch = """
        diff --git a/README.md b/README.md
        --- a/README.md
        +++ b/README.md
        @@ -1,2 +1,3 @@
         one
        -two
        +TWO
        +three
        diff --git a/Sources/App.swift b/Sources/App.swift
        --- a/Sources/App.swift
        +++ b/Sources/App.swift
        @@ -1 +1 @@
        -let title = "Old"
        +let title = "Termy"
        """

        let result = try MultiFileUnifiedPatch.apply(patch, using: service)

        XCTAssertEqual(result.changedPaths, ["README.md", "Sources/App.swift"])
        XCTAssertEqual(try service.readText("README.md"), "one\nTWO\nthree\n")
        XCTAssertEqual(try service.readText("Sources/App.swift"), "let title = \"Termy\"\n")
    }

    func testEditorAIProposalResolverAcceptsUnifiedDiffOrFullBuffer() {
        let patch = """
        --- a/notes.md
        +++ b/notes.md
        @@ -1,2 +1,2 @@
         title
        -draft
        +done
        """

        XCTAssertEqual(
            EditorAIProposalResolver.resolvedBuffer(from: patch, original: "title\ndraft\n"),
            "title\ndone\n"
        )
        XCTAssertEqual(
            EditorAIProposalResolver.resolvedBuffer(from: "full replacement", original: "title\ndraft\n"),
            "full replacement"
        )
    }

    func testEditorAIProposalResolverRecognizesMultiFilePatchForApproval() throws {
        let patch = """
        diff --git a/README.md b/README.md
        --- a/README.md
        +++ b/README.md
        @@ -1 +1 @@
        -old
        +new
        diff --git a/Sources/App.swift b/Sources/App.swift
        --- a/Sources/App.swift
        +++ b/Sources/App.swift
        @@ -1 +1 @@
        -let title = "Old"
        +let title = "Termy"
        """

        XCTAssertEqual(
            try MultiFileUnifiedPatch.changedPaths(in: patch),
            ["README.md", "Sources/App.swift"]
        )

        XCTAssertEqual(
            EditorAIProposalResolver.resolvedProposal(from: patch, original: "scratch"),
            .multiFilePatch(patch: patch, changedPaths: ["README.md", "Sources/App.swift"])
        )
    }

    func testLocalAIEndpointValidationAcceptsOnlyLocalModelHosts() {
        XCTAssertNoThrow(try LocalAIEndpoint(urlString: "http://localhost:11434"))
        XCTAssertNoThrow(try LocalAIEndpoint(urlString: "http://127.0.0.1:1234"))
        XCTAssertThrowsError(try LocalAIEndpoint(urlString: "https://api.openai.com/v1")) { error in
            XCTAssertEqual(error as? LocalAIEndpoint.ValidationError, .remoteHostsAreOutOfScope)
        }
    }

    func testCLIAgentLaunchCommandUsesKnownAgentExecutablesWithoutTermySecrets() throws {
        let codex = CLIAgentLaunchCommand(
            agent: .codex,
            executablePath: "/opt/homebrew/bin/codex",
            workingDirectory: URL(fileURLWithPath: "/tmp/project")
        )
        let claude = CLIAgentLaunchCommand(
            agent: .claudeCode,
            executablePath: "/usr/local/bin/claude",
            workingDirectory: URL(fileURLWithPath: "/tmp/project")
        )

        XCTAssertEqual(codex.executablePath, "/opt/homebrew/bin/codex")
        XCTAssertEqual(codex.arguments, [])
        XCTAssertEqual(codex.workingDirectory.path, "/tmp/project")
        XCTAssertEqual(claude.executablePath, "/usr/local/bin/claude")
        XCTAssertEqual(claude.arguments, [])
        XCTAssertFalse(codex.environmentOverrides.keys.contains { $0.localizedCaseInsensitiveContains("key") })
        XCTAssertFalse(claude.environmentOverrides.keys.contains { $0.localizedCaseInsensitiveContains("token") })
    }

    func testLocalAIClientPostsToLocalGenerateEndpointAndParsesSuggestion() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LocalAIURLProtocol.self]
        LocalAIURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.absoluteString, "http://localhost:11434/api/generate")
            XCTAssertEqual(request.httpMethod, "POST")

            let body = try XCTUnwrap(request.bodyData)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["model"] as? String, "qwen2.5-coder")
            XCTAssertEqual(json["stream"] as? Bool, false)
            XCTAssertTrue((json["prompt"] as? String)?.contains("list files") == true)

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(#"{"response":"ls -la"}"#.utf8))
        }
        defer { LocalAIURLProtocol.handler = nil }

        let client = LocalAIClient(
            endpoint: try LocalAIEndpoint(urlString: "http://localhost:11434"),
            model: "qwen2.5-coder",
            session: URLSession(configuration: configuration)
        )

        let suggestion = try await client.suggestCommand(for: "list files")

        XCTAssertEqual(suggestion.command, "ls -la")
    }

    func testLocalAIClientGeneratesCommitMessageFromDiff() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LocalAIURLProtocol.self]
        LocalAIURLProtocol.handler = { request in
            let body = try XCTUnwrap(request.bodyData)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let prompt = try XCTUnwrap(json["prompt"] as? String)
            XCTAssertTrue(prompt.contains("commit message"))
            XCTAssertTrue(prompt.contains("+Syntax preview"))

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(#"{"response":"Add syntax preview to editor\n\n"}"#.utf8))
        }
        defer { LocalAIURLProtocol.handler = nil }

        let client = LocalAIClient(
            endpoint: try LocalAIEndpoint(urlString: "http://localhost:11434"),
            model: "qwen2.5-coder",
            session: URLSession(configuration: configuration)
        )

        let suggestion = try await client.suggestCommitMessage(forDiff: "+Syntax preview")

        XCTAssertEqual(suggestion.text, "Add syntax preview to editor")
    }

    func testLocalAIClientAnswersQuickQuestionWithProjectGuidance() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LocalAIURLProtocol.self]
        LocalAIURLProtocol.handler = { request in
            let body = try XCTUnwrap(request.bodyData)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let prompt = try XCTUnwrap(json["prompt"] as? String)
            XCTAssertTrue(prompt.contains("Answer this developer question"))
            XCTAssertTrue(prompt.contains("How do I run tests?"))
            XCTAssertTrue(prompt.contains("Use SwiftPM"))

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(#"{"response":"Run swift test from the project root.\n"}"#.utf8))
        }
        defer { LocalAIURLProtocol.handler = nil }

        let client = LocalAIClient(
            endpoint: try LocalAIEndpoint(urlString: "http://localhost:11434"),
            model: "qwen2.5-coder",
            session: URLSession(configuration: configuration)
        )

        let answer = try await client.answerQuestion(
            "How do I run tests?",
            projectGuidance: "Use SwiftPM"
        )

        XCTAssertEqual(answer.text, "Run swift test from the project root.")
    }

    func testLocalAIClientExplainsFailedCommandOutput() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LocalAIURLProtocol.self]
        LocalAIURLProtocol.handler = { request in
            let body = try XCTUnwrap(request.bodyData)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let prompt = try XCTUnwrap(json["prompt"] as? String)
            XCTAssertTrue(prompt.contains("explain why this command failed"))
            XCTAssertTrue(prompt.contains("swift test"))
            XCTAssertTrue(prompt.contains("No such module"))

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(#"{"response":"The module is missing from the target dependencies."}"#.utf8))
        }
        defer { LocalAIURLProtocol.handler = nil }

        let client = LocalAIClient(
            endpoint: try LocalAIEndpoint(urlString: "http://localhost:11434"),
            model: "qwen2.5-coder",
            session: URLSession(configuration: configuration)
        )

        let explanation = try await client.explainFailedCommand(
            command: "swift test",
            output: "No such module",
            projectGuidance: "Use SwiftPM"
        )

        XCTAssertEqual(explanation.text, "The module is missing from the target dependencies.")
    }

    func testLocalAIClientExplainsGitConflictHunks() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LocalAIURLProtocol.self]
        LocalAIURLProtocol.handler = { request in
            let body = try XCTUnwrap(request.bodyData)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let prompt = try XCTUnwrap(json["prompt"] as? String)
            XCTAssertTrue(prompt.contains("Explain this git merge conflict"))
            XCTAssertTrue(prompt.contains("README.md"))
            XCTAssertTrue(prompt.contains("local change"))
            XCTAssertTrue(prompt.contains("remote change"))

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(#"{"response":"Keep the local heading and apply the remote detail."}"#.utf8))
        }
        defer { LocalAIURLProtocol.handler = nil }

        let client = LocalAIClient(
            endpoint: try LocalAIEndpoint(urlString: "http://localhost:11434"),
            model: "qwen2.5-coder",
            session: URLSession(configuration: configuration)
        )

        let explanation = try await client.explainGitConflict(
            hunks: [
                GitConflictHunk(
                    path: "README.md",
                    oursLabel: "HEAD",
                    theirsLabel: "feature",
                    ours: "local change",
                    theirs: "remote change"
                )
            ],
            projectGuidance: "Prefer safer merges"
        )

        XCTAssertEqual(explanation.text, "Keep the local heading and apply the remote detail.")
    }

    func testLocalAIClientSuggestsEditorEdit() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LocalAIURLProtocol.self]
        LocalAIURLProtocol.handler = { request in
            let body = try XCTUnwrap(request.bodyData)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let prompt = try XCTUnwrap(json["prompt"] as? String)
            XCTAssertTrue(prompt.contains("Rewrite this editor buffer"))
            XCTAssertTrue(prompt.contains("unified diff patch"))
            XCTAssertTrue(prompt.contains("Make concise"))
            XCTAssertTrue(prompt.contains("hello world"))

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(#"{"response":"hello"}"#.utf8))
        }
        defer { LocalAIURLProtocol.handler = nil }

        let client = LocalAIClient(
            endpoint: try LocalAIEndpoint(urlString: "http://localhost:11434"),
            model: "qwen2.5-coder",
            session: URLSession(configuration: configuration)
        )

        let edit = try await client.suggestEditorEdit(
            instruction: "Make concise",
            buffer: "hello world",
            projectGuidance: "Use short text"
        )

        XCTAssertEqual(edit.text, "hello")
    }

    func testLocalAIClientExplainsEditorSelectionWithProjectGuidance() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LocalAIURLProtocol.self]
        LocalAIURLProtocol.handler = { request in
            let body = try XCTUnwrap(request.bodyData)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let prompt = try XCTUnwrap(json["prompt"] as? String)
            XCTAssertTrue(prompt.contains("Explain this selected editor text"))
            XCTAssertTrue(prompt.contains("func deploy()"))
            XCTAssertTrue(prompt.contains("Prefer SwiftPM"))

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(#"{"response":"This function starts deployment."}"#.utf8))
        }
        defer { LocalAIURLProtocol.handler = nil }

        let client = LocalAIClient(
            endpoint: try LocalAIEndpoint(urlString: "http://localhost:11434"),
            model: "qwen2.5-coder",
            session: URLSession(configuration: configuration)
        )

        let explanation = try await client.explainEditorSelection(
            "func deploy()",
            projectGuidance: "Prefer SwiftPM"
        )

        XCTAssertEqual(explanation.text, "This function starts deployment.")
    }

    func testLocalAIClientSuggestsEditorCompletionAtCursor() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LocalAIURLProtocol.self]
        LocalAIURLProtocol.handler = { request in
            let body = try XCTUnwrap(request.bodyData)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let prompt = try XCTUnwrap(json["prompt"] as? String)
            XCTAssertTrue(prompt.contains("Complete this editor buffer at the cursor"))
            XCTAssertTrue(prompt.contains("Prefix:"))
            XCTAssertTrue(prompt.contains("func deploy()"))
            XCTAssertTrue(prompt.contains("Suffix:"))
            XCTAssertTrue(prompt.contains("Use Swift"))

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(#"{"response":" {\n    runDeploy()\n}"}"#.utf8))
        }
        defer { LocalAIURLProtocol.handler = nil }

        let client = LocalAIClient(
            endpoint: try LocalAIEndpoint(urlString: "http://localhost:11434"),
            model: "qwen2.5-coder",
            session: URLSession(configuration: configuration)
        )

        let completion = try await client.suggestEditorCompletion(
            prefix: "func deploy()",
            suffix: "\n",
            projectGuidance: "Use Swift"
        )

        XCTAssertEqual(completion.text, "{\n    runDeploy()\n}")
    }

    func testShellCommandRunnerExecutesLocalCommandsWithoutNetworkAssumptions() throws {
        let runner = ShellCommandRunner(shellPath: "/bin/zsh")

        let result = try runner.run("printf termy-core")

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.stdout, "termy-core")
        XCTAssertEqual(result.stderr, "")
    }

    func testShellCommandRunnerDrainsLargeOutputBeforeWaitingForExit() throws {
        let runner = ShellCommandRunner(shellPath: "/bin/zsh")

        let result = try runner.run("yes x | head -c 200000")

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.stdout.count, 200_000)
    }

    func testTerminalUTF8StreamDecoderPreservesSplitMultibyteCharacters() {
        var decoder = TerminalUTF8StreamDecoder()
        let bytes = Array("αβ".utf8)

        XCTAssertEqual(decoder.decode(Data(bytes.prefix(1))), "")
        XCTAssertEqual(decoder.decode(Data(bytes.dropFirst(1).prefix(2))), "α")
        XCTAssertEqual(decoder.decode(Data(bytes.dropFirst(3))), "β")
    }

    func testShellLaunchProfileBuildsZshBashAndCustomUserShells() {
        XCTAssertEqual(
            ShellLaunchProfile.zsh.command,
            ShellLaunchCommand(shellPath: "/bin/zsh", arguments: [])
        )
        XCTAssertEqual(
            ShellLaunchProfile.bash.command,
            ShellLaunchCommand(shellPath: "/bin/bash", arguments: ["--noprofile", "--norc"])
        )
        XCTAssertEqual(
            ShellLaunchProfile.custom(path: "/opt/homebrew/bin/fish", arguments: ["--login"]).command,
            ShellLaunchCommand(shellPath: "/opt/homebrew/bin/fish", arguments: ["--login"])
        )
    }

    func testShellIntegrationParserExtractsCommandBoundariesAndExitCode() {
        var parser = ShellIntegrationParser()

        let first = parser.consume("before \u{1B}]133;C;cmd=printf%20hi")
        let second = parser.consume("\u{7}hi\n\u{1B}]133;D;exit=0;pwd=/tmp/project\u{7}after")

        XCTAssertEqual(first, [.output("before ")])
        XCTAssertEqual(
            second,
            [
                .commandStarted("printf hi"),
                .output("hi\n"),
                .commandFinished(exitCode: 0, workingDirectory: "/tmp/project"),
                .output("after")
            ]
        )
    }

    func testShellIntegrationParserPassesThroughPlainOutput() {
        var parser = ShellIntegrationParser()

        XCTAssertEqual(parser.consume("plain output\n"), [.output("plain output\n")])
        XCTAssertEqual(parser.flush(), [])
    }

    func testShellIntegrationParserParsesInputBufferReport() {
        var parser = ShellIntegrationParser()
        let b = Data("git stat".utf8).base64EncodedString()
        let events = parser.consume("\u{1B}]133;T;b=\(b);c=8;n=8\u{7}")
        XCTAssertEqual(events, [.inputBufferChanged(text: "git stat", cursor: 8, length: 8)])
    }

    func testShellIntegrationParserInputBufferRoundTripsNewlineAndSemicolons() {
        var parser = ShellIntegrationParser()
        let raw = "echo a;b\nc"
        let b = Data(raw.utf8).base64EncodedString()
        let events = parser.consume("pre\u{1B}]133;T;b=\(b);c=3;n=10\u{7}post")
        XCTAssertEqual(events, [
            .output("pre"),
            .inputBufferChanged(text: raw, cursor: 3, length: 10),
            .output("post")
        ])
    }

    func testShellIntegrationParserDropsMalformedInputBufferReport() {
        var parser = ShellIntegrationParser()
        XCTAssertEqual(parser.consume("\u{1B}]133;T;b=!!!!;c=0;n=0\u{7}x"), [.output("x")])
        // `b` key absent entirely -> guard fires, marker dropped, output passes through
        var parser2 = ShellIntegrationParser()
        XCTAssertEqual(parser2.consume("\u{1B}]133;T;c=0;n=0\u{7}y"), [.output("y")])
    }

    // FB-1: region_highlight (OSC 133;H) parsing.
    func testInputHighlightSpanParsesHexUnderlineAndMemo() {
        XCTAssertEqual(
            InputHighlightSpan.parse(entry: "0 3 fg=#cdd6f4"),
            InputHighlightSpan(start: 0, end: 3, foregroundHex: "#cdd6f4", underline: false))
        // trailing comma + memo field (the real z-s-h shape) + underline token
        XCTAssertEqual(
            InputHighlightSpan.parse(entry: "4 7 fg=#f38ba8,underline, memo=zsh-syntax-highlighting"),
            InputHighlightSpan(start: 4, end: 7, foregroundHex: "#f38ba8", underline: true))
        // non-hex fg (default/named) -> no color, span still produced
        XCTAssertEqual(
            InputHighlightSpan.parse(entry: "0 0 fg=default"),
            InputHighlightSpan(start: 0, end: 0, foregroundHex: nil, underline: false))
        // missing start/end -> nil
        XCTAssertNil(InputHighlightSpan.parse(entry: "fg=#aaa"))
    }

    func testShellIntegrationParserParsesHighlightMarker() {
        var parser = ShellIntegrationParser()
        let joined = "0 3 fg=#cdd6f4|4 8 fg=#a6e3a1"
        let r = Data(joined.utf8).base64EncodedString()
        XCTAssertEqual(
            parser.consume("\u{1B}]133;H;r=\(r)\u{7}"),
            [.inputHighlightsChanged([
                InputHighlightSpan(start: 0, end: 3, foregroundHex: "#cdd6f4", underline: false),
                InputHighlightSpan(start: 4, end: 8, foregroundHex: "#a6e3a1", underline: false)
            ])])
        // empty region_highlight -> no spans
        var parser2 = ShellIntegrationParser()
        let empty = Data("".utf8).base64EncodedString()
        XCTAssertEqual(
            parser2.consume("\u{1B}]133;H;r=\(empty)\u{7}"),
            [.inputHighlightsChanged([])])
    }

    func testShellIntegrationScriptComposesPublishAndHighlighting() {
        let s = ShellIntegrationScript.zsh()
        // F-1 BUFFER publish preserved...
        XCTAssertTrue(s.contains(#"\033]133;T;b=%s;c=%d;n=%d\007"#))
        XCTAssertTrue(s.contains("print -rn -- \"$BUFFER\" | base64 | tr -d '\\n'"))
        // ...now registered via add-zle-hook-widget (composes with z-s-h, no clobber).
        XCTAssertTrue(s.contains("autoload -Uz add-zsh-hook add-zle-hook-widget"))
        XCTAssertTrue(s.contains("add-zle-hook-widget zle-line-pre-redraw termy_buffer_publish"))
        XCTAssertFalse(s.contains("termy_orig_zle_line_pre_redraw"), "old manual chaining removed")
        // FB-1+spec-HL highlighting scaffolding + guarded source (fail-open).
        XCTAssertTrue(s.contains("ZSH_HIGHLIGHT_HIGHLIGHTERS=(main termy_spec)"))
        XCTAssertTrue(s.contains("ZSH_HIGHLIGHT_MAXLENGTH=4096"))
        XCTAssertTrue(s.contains(#"[[ -n "$TERMY_SYNTAX_HL_DIR" && -r "$TERMY_SYNTAX_HL_DIR/zsh-syntax-highlighting.zsh" ]]"#))
        XCTAssertTrue(s.contains("source \"$TERMY_SYNTAX_HL_DIR/zsh-syntax-highlighting.zsh\""))
    }

    func testShellIntegrationScriptInjectsProvidedStyles() {
        let s = ShellIntegrationScript.zsh(highlightStyles: [
            "ZSH_HIGHLIGHT_STYLES[command]='fg=#64D2FF'",
            "ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#FF453A'",
        ])
        XCTAssertTrue(s.contains("ZSH_HIGHLIGHT_STYLES[command]='fg=#64D2FF'"))
        XCTAssertTrue(s.contains("ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#FF453A'"))
        XCTAssertTrue(s.contains("typeset -gA ZSH_HIGHLIGHT_STYLES"))
    }

}

private final class LocalAIURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            guard let handler = Self.handler else {
                throw URLError(.badServerResponse)
            }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private actor PrivateSyncOperationRecorder {
    private var recordedValues: [PrivateSyncOperationKind] = []

    func append(_ value: PrivateSyncOperationKind) {
        recordedValues.append(value)
    }

    func values() -> [PrivateSyncOperationKind] {
        recordedValues
    }
}

private extension URLRequest {
    var bodyData: Data? {
        if let httpBody {
            return httpBody
        }
        guard let stream = httpBodyStream else {
            return nil
        }
        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let count = stream.read(buffer, maxLength: bufferSize)
            if count > 0 {
                data.append(buffer, count: count)
            } else {
                break
            }
        }
        return data
    }
}
