import XCTest
@testable import Termy
import TermyCore
import TermySync

final class TermyStorePrivateSyncTests: XCTestCase {
    @MainActor
    func testStoreImportsAndRestoresSSHPrivateKeyThroughKeychainVault() throws {
        let secretStore = KeychainSecretStore(
            service: "com.kacperpietrzyk.Termy.tests.\(UUID().uuidString)",
            synchronizesWithICloudKeychain: false
        )
        let store = TermyStore(
            startInitialPTY: false,
            sshPrivateKeyVault: SSHPrivateKeyVault(secretStore: secretStore)
        )
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("termy-store-ssh-key-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let keyURL = directory.appendingPathComponent("id_ed25519_termy")
        let privateKey = """
        -----BEGIN OPENSSH PRIVATE KEY-----
        b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAA=
        -----END OPENSSH PRIVATE KEY-----

        """
        let keyData = Data(privateKey.utf8)
        try keyData.write(to: keyURL)
        store.sshKeyPath = keyURL.path

        store.importSSHPrivateKeyToKeychain()

        XCTAssertEqual(store.statusMessage, "Stored SSH private key in iCloud Keychain.")
        try FileManager.default.removeItem(at: keyURL)

        store.restoreSSHPrivateKeyFromKeychain()

        XCTAssertEqual(store.statusMessage, "Restored SSH private key from iCloud Keychain.")
        XCTAssertEqual(try Data(contentsOf: keyURL), keyData)
        let attributes = try FileManager.default.attributesOfItem(atPath: keyURL.path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
    }

    @MainActor
    func testPrivateSyncSnapshotIncludesLocalAIConversationHistory() {
        let store = TermyStore(startInitialPTY: false)
        store.aiPrompt = "deploy the current build"
        store.aiSuggestedCommand = "make deploy"
        store.aiExplanation = "The previous command failed because the module is missing."
        store.aiConversationHistory = ["agent: Codex launched in /Users/kacper/Projects/Termy"]

        store.stagePrivateSyncSnapshot(scheduleSync: false)

        let aiConversationRecords = store.privateSyncRecords
            .filter { $0.recordType == "AIConversation" }
            .sorted { $0.recordName < $1.recordName }
        XCTAssertEqual(
            aiConversationRecords.map { $0.fields["message"] },
            [
                "prompt: deploy the current build",
                "suggested-command: make deploy",
                "explanation: The previous command failed because the module is missing.",
                "agent: Codex launched in /Users/kacper/Projects/Termy"
            ]
        )
    }

    @MainActor
    func testApplyingPrivateSyncRecordsHydratesAppConfiguration() throws {
        let profileID = UUID()
        let store = TermyStore(startInitialPTY: false)
        store.privateSyncRecords = [
            PrivateSyncRecord(
                recordType: "ConnectionProfile",
                recordName: "connection-\(profileID.uuidString)",
                fields: [
                    "kind": "ssh",
                    "name": "Prod",
                    "host": "prod.example.test",
                    "user": "deploy",
                    "port": "2222",
                    "gateway": "jump.example.test",
                    "groupPath": "Production/Bastions",
                    "secretReferences": "ssh.identity.prod"
                ]
            ),
            PrivateSyncRecord(
                recordType: "Appearance",
                recordName: "appearance-default",
                fields: [
                    "terminalThemeID": "custom-night",
                    "terminalFontSize": "15",
                    "terminalFontFamily": "JetBrains Mono",
                    "terminalUsesLigatures": "false",
                    "terminalIncreasedContrast": "true",
                    "interfaceTextScale": "large",
                    "terminalShellPath": "/opt/homebrew/bin/fish",
                    "terminalShellArguments": "--login",
                    "terminalOutputMode": "blocks",
                    "customTerminalThemes": "custom-night|Night|#000000|#ffffff|#00ff00|#ff0000|#888888",
                    "keymapBindings": "open-command-center=commandShift:p"
                ]
            ),
            PrivateSyncRecord(
                recordType: "Snippet",
                recordName: "snippet-user-deploy",
                fields: ["title": "Deploy", "body": "make deploy"]
            ),
            PrivateSyncRecord(
                recordType: "Workspace",
                recordName: "workspace-debug",
                fields: [
                    "name": "Debug",
                    "panelIDs": "terminal,ai",
                    "paneTree": "h:0.50(terminal|ai)"
                ]
            ),
            PrivateSyncRecord(
                recordType: "AIConversation",
                recordName: "ai-history-0",
                fields: ["message": "prompt: explain failure"]
            )
        ]

        store.applyPrivateSyncRecordsToAppState()

        let restoredProfile = try XCTUnwrap(store.profiles.first { $0.id == profileID })
        XCTAssertEqual(restoredProfile.kind, .ssh)
        XCTAssertEqual(restoredProfile.host, "prod.example.test")
        XCTAssertEqual(restoredProfile.user, "deploy")
        XCTAssertEqual(restoredProfile.port, 2222)
        XCTAssertEqual(restoredProfile.gateway, "jump.example.test")
        XCTAssertEqual(restoredProfile.groupPath, "Production/Bastions")
        XCTAssertEqual(restoredProfile.secretReferences, [.keychain("ssh.identity.prod")])
        XCTAssertEqual(store.selectedTerminalThemeID, "custom-night")
        XCTAssertEqual(store.terminalFontSize, 15)
        XCTAssertEqual(store.terminalFontFamily, "JetBrains Mono")
        XCTAssertFalse(store.terminalUsesLigatures)
        XCTAssertTrue(store.terminalIncreasedContrast)
        XCTAssertEqual(store.interfaceTextScale, .large)
        XCTAssertEqual(store.terminalShellKind, "custom")
        XCTAssertEqual(store.terminalCustomShellPath, "/opt/homebrew/bin/fish")
        XCTAssertEqual(store.terminalCustomShellArguments, "--login")
        XCTAssertEqual(store.terminalOutputMode, "blocks")
        XCTAssertEqual(store.customTerminalThemes.first?.id, "custom-night")
        XCTAssertEqual(store.keymapProfile.bindings["open-command-center"], .commandShift("p"))
        XCTAssertEqual(store.userPromptSnippets, [
            UserPromptSnippet(id: "deploy", title: "Deploy", body: "make deploy")
        ])
        XCTAssertEqual(store.workspaceStore.restore(id: "debug")?.paneTree, .split(axis: .horizontal, ratio: 0.50, first: .leaf(.terminal), second: .leaf(.ai)))
        XCTAssertEqual(store.aiConversationHistory, ["prompt: explain failure"])
    }

    @MainActor
    func testPrivateSyncEngineFetchedChangesHydrateAppStateAndToken() async {
        let store = TermyStore(startInitialPTY: false)
        store.privateSyncRecords = [
            PrivateSyncRecord(
                recordType: "Snippet",
                recordName: "snippet-user-old",
                fields: ["title": "Old", "body": "stale"]
            )
        ]

        let step = await store.handlePrivateSyncEngineEvent(
            .fetchedDatabaseChanges(
                .init(
                    changedRecords: [
                        PrivateSyncRecord(
                            recordType: "Snippet",
                            recordName: "snippet-user-runtime",
                            fields: ["title": "Runtime", "body": "sync"]
                        )
                    ],
                    deletedRecordNames: ["snippet-user-old"],
                    newChangeToken: .init(rawValue: "runtime-token-2")
                )
            ),
            at: 100
        )

        XCTAssertEqual(step.appliedChangeCount, 2)
        XCTAssertEqual(store.privateSyncChangeToken?.rawValue, "runtime-token-2")
        XCTAssertEqual(store.privateSyncRecords.map(\.recordName), ["snippet-user-runtime"])
        XCTAssertEqual(store.userPromptSnippets, [
            UserPromptSnippet(id: "runtime", title: "Runtime", body: "sync")
        ])
        XCTAssertEqual(store.privateSyncStatus, "Applied 2 runtime change(s)")
    }

    @MainActor
    func testPushWithoutEntitlementKeepsPreciseStatusNotGenericSyncFailed() async {
        // X2: the unsigned test binary has no iCloud entitlement
        // (hasCloudKitPrivateSyncEntitlement == false) while canImport(CloudKit)
        // is true — exactly the dev-build state. `.appLaunch` schedules a fetch
        // that is due immediately, so the throwing no-entitlement closure runs and
        // produces a FAILED operation outcome. That failure must keep the precise
        // "CloudKit entitlement unavailable" string, not the generic "Sync failed"
        // that the failure branch used to overwrite it with.
        let store = TermyStore(startInitialPTY: false)
        store.stagePrivateSyncSnapshot(scheduleSync: false)
        _ = await store.runPrivateSyncEvent(.appLaunch)

        XCTAssertEqual(store.privateSyncStatus, "CloudKit entitlement unavailable")
        XCTAssertNotEqual(store.privateSyncStatus, "Sync failed")
    }

    @MainActor
    func testStagedSyncRecordsCarryMutationStampedModifiedAtAndPreserveIt() throws {
        // D1: editing a profile stamps its record's `modifiedAt`; re-staging without an
        // edit preserves that stamp (no churn). ai-history is never stamped.
        let store = TermyStore(startInitialPTY: false)
        defer { store.shutdown() }
        store.sshProfileNameDraft = "Prod"
        store.sshProfileHostDraft = "prod.example"
        store.sshProfileUserDraft = "kacper"
        store.sshProfilePortDraft = "22"
        store.sshProfileIdentityDraft = "~/.ssh/id_ed25519"
        store.aiConversationHistory = ["question", "answer"]

        store.createSSHProfileFromDraft()

        // The store seeds sample profiles; locate the one we just edited by host.
        let record = try XCTUnwrap(store.privateSyncRecords.first { $0.fields["host"] == "prod.example" })
        let stamp = try XCTUnwrap(record.fields["modifiedAt"].flatMap(Double.init))
        XCTAssertGreaterThan(stamp, 0, "an edited profile record must carry a real modifiedAt")

        // ai-history is excluded from the timestamp model.
        let aiRecords = store.privateSyncRecords.filter { $0.recordType == "AIConversation" }
        XCTAssertFalse(aiRecords.isEmpty, "test should exercise ai-history records")
        XCTAssertTrue(aiRecords.allSatisfy { $0.fields["modifiedAt"] == nil },
                      "ai-history records must never be timestamp-stamped")

        // Re-stage without editing → the stamp is preserved, not bumped to now.
        store.stagePrivateSyncSnapshot()
        let restaged = try XCTUnwrap(store.privateSyncRecords.first { $0.fields["host"] == "prod.example" })
        XCTAssertEqual(restaged.fields["modifiedAt"], record.fields["modifiedAt"],
                       "an untouched record must keep its prior stamp across staging")
    }

    // MARK: - CK-S8 palette aliases

    @MainActor
    func testAddAliasStagesAndStampsMatchingRecordName() throws {
        let store = TermyStore(startInitialPTY: false)
        store.aliasPrefixDraft = "gs"
        store.aliasExpansionDraft = "git status"

        store.addAlias()

        XCTAssertEqual(store.paletteAliases, [
            PaletteAlias(id: "gs", prefix: "gs", expansion: "git status")
        ])
        // The encoder uses recordName `alias-<id>`; the stamp must match it (D1) so
        // the record carries a real modifiedAt.
        let record = try XCTUnwrap(store.privateSyncRecords.first { $0.recordName == "alias-gs" })
        XCTAssertEqual(record.recordType, "Alias")
        XCTAssertEqual(record.fields["prefix"], "gs")
        XCTAssertEqual(record.fields["expansion"], "git status")
        let stamp = try XCTUnwrap(record.fields["modifiedAt"].flatMap(Double.init))
        XCTAssertGreaterThan(stamp, 0, "an added alias record must carry a real modifiedAt")
    }

    @MainActor
    func testRestoreHydratesAliasesFromSyncedRecords() {
        let store = TermyStore(startInitialPTY: false)
        store.privateSyncRecords = [
            PrivateSyncRecord(
                recordType: "Alias",
                recordName: "alias-gs",
                fields: ["prefix": "gs", "expansion": "git status"]
            )
        ]

        store.applyPrivateSyncRecordsToAppState()

        XCTAssertEqual(store.paletteAliases, [
            PaletteAlias(id: "gs", prefix: "gs", expansion: "git status")
        ])
    }

    @MainActor
    func testAliasResolvesFeedToShellFallbackBeforeFuzzy() {
        let store = TermyStore(startInitialPTY: false)
        store.paletteAliases = [PaletteAlias(id: "gs", prefix: "gs", expansion: "git status")]

        store.commandQuery = "gs"
        guard case .fallback(.runInSession(let command)) = store.filteredCommandCenterItems.first else {
            return XCTFail("exact alias prefix must resolve to its target as the sole feed item")
        }
        XCTAssertEqual(command, "git status")
        XCTAssertEqual(store.filteredCommandCenterItems.count, 1)

        // Strict: typing past the prefix falls back to normal fuzzy search (no
        // single-item alias short-circuit).
        store.commandQuery = "gstatus"
        XCTAssertFalse(store.filteredCommandCenterItems.contains {
            if case .fallback(.runInSession("git status")) = $0 { return true }
            return false
        })
    }

    @MainActor
    func testAliasResolvesToCommandActionByTitle() {
        let store = TermyStore(startInitialPTY: false)
        store.paletteAliases = [PaletteAlias(id: "d", prefix: "d", expansion: "Connect SSH")]

        store.commandQuery = "d"
        guard case .action(let action) = store.filteredCommandCenterItems.first else {
            return XCTFail("an alias whose expansion names an action title resolves to that action")
        }
        XCTAssertEqual(action.id, "connect-ssh")
    }

    @MainActor
    func testAliasDoesNotResolveUnderExplicitScopeSigil() {
        let store = TermyStore(startInitialPTY: false)
        store.paletteAliases = [PaletteAlias(id: "gs", prefix: "gs", expansion: "git status")]

        // A `>` scope is an explicit command search; an alias must not hijack it.
        store.commandQuery = ">gs"
        XCTAssertFalse(store.filteredCommandCenterItems.contains {
            if case .fallback(.runInSession("git status")) = $0 { return true }
            return false
        })
    }
}
