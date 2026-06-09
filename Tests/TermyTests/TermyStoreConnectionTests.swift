import XCTest
import TermyCore
@testable import Termy

final class TermyStoreConnectionTests: XCTestCase {
    @MainActor
    func testCreateRDPProfileFromDraftAddsProfileAndStagesPrivateSync() throws {
        let store = TermyStore(startInitialPTY: false)
        store.profiles = [.local()]
        store.rdpProfileNameDraft = "Windows Build"
        store.rdpProfileHostDraft = "win-build.example.test"
        store.rdpProfileUserDraft = "builder"
        store.rdpProfileGatewayDraft = "gateway.example.test"
        store.rdpProfileCredentialDraft = "rdp.build"
        store.rdpProfileGroupDraft = "Windows"

        store.createRDPProfileFromDraft()

        let profile = try XCTUnwrap(store.profiles.first { $0.name == "Windows Build" })
        XCTAssertEqual(profile.kind, .rdp)
        XCTAssertEqual(profile.host, "win-build.example.test")
        XCTAssertEqual(profile.user, "builder")
        XCTAssertEqual(profile.gateway, "gateway.example.test")
        XCTAssertEqual(profile.groupPath, "Windows")
        XCTAssertEqual(profile.secretReferences, [.keychain("rdp.build")])
        XCTAssertEqual(store.statusMessage, "Created RDP profile Windows Build.")
        XCTAssertEqual(store.rdpProfileNameDraft, "")
        XCTAssertEqual(
            store.privateSyncRecords.first { $0.recordName == "connection-\(profile.id.uuidString)" }?.fields["gateway"],
            "gateway.example.test"
        )
    }

    @MainActor
    func testCreateRDPProfileRequiresCredentialReference() {
        let store = TermyStore(startInitialPTY: false)
        store.rdpProfileNameDraft = "Windows Build"
        store.rdpProfileHostDraft = "win-build.example.test"
        store.rdpProfileUserDraft = "builder"
        store.rdpProfileCredentialDraft = ""

        store.createRDPProfileFromDraft()

        XCTAssertFalse(store.profiles.contains { $0.name == "Windows Build" })
        XCTAssertEqual(store.statusMessage, "RDP profile name, host, user, and credential reference are required.")
    }

    @MainActor
    func testCreateSSHProfileFromDraftAddsProfileAndStagesPrivateSync() throws {
        let store = TermyStore(startInitialPTY: false)
        store.profiles = [.local()]
        store.sshProfileNameDraft = "Production"
        store.sshProfileHostDraft = "bastion.example.test"
        store.sshProfileUserDraft = "deploy"
        store.sshProfilePortDraft = "2222"
        store.sshProfileIdentityDraft = "~/.ssh/id_ed25519"
        store.sshProfileGroupDraft = "Production/Bastions"
        store.sshOptionsDraft = """
        Compression yes
        IdentityFile ~/.ssh/ignored
        """

        store.createSSHProfileFromDraft()

        let profile = try XCTUnwrap(store.profiles.first { $0.name == "Production" })
        XCTAssertEqual(profile.kind, .ssh)
        XCTAssertEqual(profile.host, "bastion.example.test")
        XCTAssertEqual(profile.user, "deploy")
        XCTAssertEqual(profile.port, 2222)
        XCTAssertEqual(profile.groupPath, "Production/Bastions")
        XCTAssertEqual(profile.sshOptions, ["Compression": "yes"])
        XCTAssertEqual(profile.secretReferences, [.keychain("ssh.identity.~/.ssh/id_ed25519")])
        XCTAssertEqual(store.statusMessage, "Created SSH profile Production.")
        XCTAssertEqual(store.sshProfileNameDraft, "")
        XCTAssertEqual(
            store.privateSyncRecords.first { $0.recordName == "connection-\(profile.id.uuidString)" }?.fields["sshOptions"],
            "Compression=yes"
        )
    }

    @MainActor
    func testCreateSSHProfileRejectsInvalidPort() {
        let store = TermyStore(startInitialPTY: false)
        store.sshProfileNameDraft = "Production"
        store.sshProfileHostDraft = "bastion.example.test"
        store.sshProfileUserDraft = "deploy"
        store.sshProfilePortDraft = "bad"
        store.sshProfileIdentityDraft = "~/.ssh/id_ed25519"

        store.createSSHProfileFromDraft()

        XCTAssertFalse(store.profiles.contains { $0.name == "Production" })
        XCTAssertEqual(store.statusMessage, "SSH profile port must be a number.")
    }

    @MainActor
    func testSSHOptionsDraftUpdatesProfileAndStagesPrivateSync() throws {
        let profile = ConnectionProfile.ssh(
            id: UUID(),
            name: "Production",
            host: "bastion.example.test",
            user: "deploy",
            port: 2222,
            identity: .keychain("ssh.identity.prod"),
            sshOptions: ["Compression": "no"]
        )
        let store = TermyStore(startInitialPTY: false)
        store.profiles = [.local(), profile]

        store.selectConnectionProfileForEditing(profile)
        XCTAssertEqual(store.sshOptionsDraft, "Compression=no")

        store.sshOptionsDraft = """
        Compression yes
        ServerAliveInterval=30
        IdentityFile ~/.ssh/id_ed25519
        """
        store.saveSSHOptionsForSelectedProfile()

        let updated = try XCTUnwrap(store.profiles.first { $0.id == profile.id })
        XCTAssertEqual(updated.sshOptions, ["Compression": "yes", "ServerAliveInterval": "30"])
        XCTAssertEqual(store.statusMessage, "Updated SSH options for Production.")
        XCTAssertEqual(
            store.privateSyncRecords.first { $0.recordName == "connection-\(profile.id.uuidString)" }?.fields["sshOptions"],
            "Compression=yes;ServerAliveInterval=30"
        )
    }

    // ----- X3: no example placeholder hosts ship in the product -----

    @MainActor
    func testFreshStoreSeedsNoExampleHosts() {
        let store = TermyStore(startInitialPTY: false)
        let remotes = store.profiles.filter { $0.kind == .ssh || $0.kind == .rdp }
        XCTAssertTrue(remotes.isEmpty, "no SSH/RDP hosts should be seeded")
        XCTAssertFalse(
            store.profiles.contains { $0.host.hasSuffix(".example.test") },
            "no *.example.test placeholder hosts should ship"
        )
    }

    @MainActor
    func testFreshStoreRetainsOnlyLocalProfile() {
        let store = TermyStore(startInitialPTY: false)
        XCTAssertEqual(store.profiles.count, 1)
        XCTAssertEqual(store.profiles.first?.kind, .local)
    }

    // ----- M4: real profile delete (editable groups) -----

    @MainActor
    func testDeleteProfileRemovesItAndRestagesSync() {
        let ssh = ConnectionProfile.ssh(
            name: "Production",
            host: "bastion.example.test",
            user: "deploy",
            port: 22,
            identity: .keychain("ssh.identity.prod"),
            groupPath: "Production/Bastions"
        )
        let store = TermyStore(startInitialPTY: false)
        store.profiles = [.local(), ssh]

        store.deleteProfile(ssh.id)

        XCTAssertFalse(store.profiles.contains { $0.id == ssh.id })
        XCTAssertEqual(store.profiles.count, 1)
        XCTAssertEqual(store.statusMessage, "Removed connection Production.")
        // stagePrivateSyncSnapshot rebuilds records from the live (now-shorter)
        // profiles, so the deleted connection's record drops out of the snapshot
        // (no tombstone is staged — cross-device delete does not yet propagate).
        XCTAssertNil(
            store.privateSyncRecords.first { $0.recordName == "connection-\(ssh.id.uuidString)" }
        )
    }

    @MainActor
    func testDeleteProfileNeverRemovesLocalShell() {
        let store = TermyStore(startInitialPTY: false)
        let local = store.profiles.first { $0.kind == .local }
        let localID = try? XCTUnwrap(local?.id)

        store.deleteProfile(localID ?? UUID())

        XCTAssertTrue(store.profiles.contains { $0.kind == .local })
        XCTAssertEqual(store.profiles.count, 1)
    }

    @MainActor
    func testDeleteSelectedProfileClearsSelection() {
        let ssh = ConnectionProfile.ssh(
            name: "Production",
            host: "bastion.example.test",
            user: "deploy",
            port: 22,
            identity: .keychain("ssh.identity.prod")
        )
        let store = TermyStore(startInitialPTY: false)
        store.profiles = [.local(), ssh]
        store.selectedConnectionProfileID = ssh.id

        store.deleteProfile(ssh.id)

        XCTAssertNil(store.selectedConnectionProfileID)
    }
}
