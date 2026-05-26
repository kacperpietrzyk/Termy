import XCTest
import Combine
@testable import Termy
import TermyCore
import TermySync

final class AppModelFilesConnectionsTests: XCTestCase {
    @MainActor
    func testFilesModelDefaultsMatchLegacyPublishedDefaults() {
        let model = FilesModel()
        XCTAssertEqual(model.fileItems, [])
        XCTAssertEqual(model.fileTreeItems, [])
        XCTAssertEqual(model.sftpRemoteItems, [])
        XCTAssertEqual(model.sftpRemotePath, ".")
        XCTAssertNil(model.selectedSFTPRemotePath)
        XCTAssertNil(model.selectedFilePath)
        XCTAssertEqual(model.fileSearchQuery, "")
        XCTAssertEqual(model.fileDraftName, "")
        XCTAssertEqual(model.fileRenameName, "")
        XCTAssertEqual(model.fileMoveDestination, "")
    }

    @MainActor
    func testConnectionsModelDefaultsMatchLegacyPublishedDefaults() {
        let model = ConnectionsModel()
        XCTAssertEqual(model.profiles, [])
        XCTAssertEqual(model.tunnelKind, SSHTunnelKind.local)
        XCTAssertEqual(model.tunnelLocalPort, "8080")
        XCTAssertEqual(model.tunnelRemoteHost, "127.0.0.1")
        XCTAssertEqual(model.tunnelRemotePort, "80")
        XCTAssertEqual(model.savedTunnels, [])
        XCTAssertEqual(model.tunnelHealth, [:])
        XCTAssertEqual(model.tunnelProbeStatus, [:])
        XCTAssertNil(model.selectedConnectionProfileID)
        XCTAssertEqual(model.sshProfileNameDraft, "")
        XCTAssertEqual(model.sshProfileHostDraft, "")
        XCTAssertEqual(model.sshProfileUserDraft, NSUserName())
        XCTAssertEqual(model.sshProfilePortDraft, "22")
        XCTAssertEqual(model.sshProfileIdentityDraft, "~/.ssh/id_ed25519")
        XCTAssertEqual(model.sshProfileGroupDraft, "")
        XCTAssertEqual(model.sshOptionsDraft, "")
        XCTAssertEqual(
            model.sshKeyPath,
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".ssh/id_ed25519_termy").path
        )
        XCTAssertEqual(model.sshKeyComment, "\(NSUserName())@Termy")
        XCTAssertEqual(model.rdpWidth, "1920")
        XCTAssertEqual(model.rdpHeight, "1080")
        XCTAssertEqual(model.rdpScale, "1.0")
        XCTAssertEqual(model.rdpLocalFolderPath, FileManager.default.homeDirectoryForCurrentUser.path)
        XCTAssertEqual(model.rdpProfileNameDraft, "")
        XCTAssertEqual(model.rdpProfileHostDraft, "")
        XCTAssertEqual(model.rdpProfileUserDraft, NSUserName())
        XCTAssertEqual(model.rdpProfileGatewayDraft, "")
        XCTAssertEqual(model.rdpProfileCredentialDraft, "")
        XCTAssertEqual(model.rdpProfileGroupDraft, "")
    }

    @MainActor
    func testWorkspaceModelDefaultsMatchLegacyPublishedDefaults() {
        let model = WorkspaceModel()
        XCTAssertEqual(model.workspaceStore, WorkspaceStore())
        XCTAssertEqual(model.paneLayout, WorkspacePaneLayout())
        XCTAssertNil(model.selectedWorkspaceID)
    }

    @MainActor
    func testSyncModelDefaultsMatchLegacyPublishedDefaults() {
        let model = SyncModel()
        XCTAssertEqual(model.privateSyncRecords, [])
        XCTAssertEqual(model.privateSyncStatus, "Not checked")
        XCTAssertEqual(model.privateSyncPendingOperations, [])
        XCTAssertEqual(model.privateSyncLastOperationResults, [])
        XCTAssertNil(model.privateSyncChangeToken)
        XCTAssertNil(model.privateSyncEngineAccountState)
    }

    @MainActor
    func testAppModelExposesFilesConnectionsWorkspaceSyncModels() {
        let app = AppModel()
        app.files.fileSearchQuery = "files-changed"
        app.connections.sshProfileNameDraft = "conn-changed"
        app.workspace.selectedWorkspaceID = "ws-changed"
        app.sync.privateSyncStatus = "sync-changed"
        XCTAssertEqual(app.files.fileSearchQuery, "files-changed")
        XCTAssertEqual(app.connections.sshProfileNameDraft, "conn-changed")
        XCTAssertEqual(app.workspace.selectedWorkspaceID, "ws-changed")
        XCTAssertEqual(app.sync.privateSyncStatus, "sync-changed")
    }

    @MainActor
    func testStoreFilesForwardersReadAndWriteAppModel() {
        let store = TermyStore(startInitialPTY: false)

        store.sftpRemotePath = "/remote"
        store.selectedSFTPRemotePath = "/remote/x"
        store.selectedFilePath = "/local/y"
        store.fileSearchQuery = "q"
        store.fileDraftName = "draft"
        store.fileRenameName = "rename"
        store.fileMoveDestination = "/dest"

        XCTAssertEqual(store.appModel.files.sftpRemotePath, "/remote")
        XCTAssertEqual(store.appModel.files.selectedSFTPRemotePath, "/remote/x")
        XCTAssertEqual(store.appModel.files.selectedFilePath, "/local/y")
        XCTAssertEqual(store.appModel.files.fileSearchQuery, "q")
        XCTAssertEqual(store.appModel.files.fileDraftName, "draft")
        XCTAssertEqual(store.appModel.files.fileRenameName, "rename")
        XCTAssertEqual(store.appModel.files.fileMoveDestination, "/dest")

        store.appModel.files.fileSearchQuery = "back-prop"
        XCTAssertEqual(store.fileSearchQuery, "back-prop")
    }

    @MainActor
    func testStoreConnectionsForwardersReadAndWriteAppModel() {
        let store = TermyStore(startInitialPTY: false)
        let profile = ConnectionProfile.local()

        store.profiles = [profile]
        store.tunnelKind = .remote
        store.tunnelLocalPort = "9000"
        store.sshProfileNameDraft = "ssh-name"
        store.sshKeyPath = "/keys/id"
        store.rdpProfileHostDraft = "win.example"
        store.selectedConnectionProfileID = profile.id

        XCTAssertEqual(store.appModel.connections.profiles, [profile])
        XCTAssertEqual(store.appModel.connections.tunnelKind, .remote)
        XCTAssertEqual(store.appModel.connections.tunnelLocalPort, "9000")
        XCTAssertEqual(store.appModel.connections.sshProfileNameDraft, "ssh-name")
        XCTAssertEqual(store.appModel.connections.sshKeyPath, "/keys/id")
        XCTAssertEqual(store.appModel.connections.rdpProfileHostDraft, "win.example")
        XCTAssertEqual(store.appModel.connections.selectedConnectionProfileID, profile.id)

        store.appModel.connections.sshProfileNameDraft = "back-prop"
        XCTAssertEqual(store.sshProfileNameDraft, "back-prop")
    }

    @MainActor
    func testStoreWorkspaceForwardersReadAndWriteAppModel() {
        let store = TermyStore(startInitialPTY: false)

        store.selectedWorkspaceID = "ws-1"
        XCTAssertEqual(store.appModel.workspace.selectedWorkspaceID, "ws-1")

        store.appModel.workspace.selectedWorkspaceID = "back-prop"
        XCTAssertEqual(store.selectedWorkspaceID, "back-prop")
    }

    @MainActor
    func testStoreSyncForwardersReadAndWriteAppModel() {
        let store = TermyStore(startInitialPTY: false)

        store.privateSyncStatus = "Syncing"
        XCTAssertEqual(store.appModel.sync.privateSyncStatus, "Syncing")

        store.appModel.sync.privateSyncStatus = "back-prop"
        XCTAssertEqual(store.privateSyncStatus, "back-prop")
    }

    @MainActor
    func testStoreFilesForwardersFireObjectWillChangePerProperty() {
        let store = TermyStore(startInitialPTY: false)
        var fireCount = 0
        let cancellable = store.objectWillChange.sink { fireCount += 1 }
        defer { cancellable.cancel() }

        func assertOneFire(_ label: String, _ mutate: () -> Void) {
            fireCount = 0
            mutate()
            XCTAssertEqual(fireCount, 1, "\(label): exactly one objectWillChange must fire so @ObservedObject views re-render")
        }

        assertOneFire("fileItems") { store.fileItems = [] }
        assertOneFire("fileTreeItems") { store.fileTreeItems = [] }
        assertOneFire("sftpRemoteItems") { store.sftpRemoteItems = [] }
        assertOneFire("sftpRemotePath") { store.sftpRemotePath = "/p" }
        assertOneFire("selectedSFTPRemotePath") { store.selectedSFTPRemotePath = "/q" }
        assertOneFire("selectedFilePath") { store.selectedFilePath = "/r" }
        assertOneFire("fileSearchQuery") { store.fileSearchQuery = "s" }
        assertOneFire("fileDraftName") { store.fileDraftName = "d" }
        assertOneFire("fileRenameName") { store.fileRenameName = "rn" }
        assertOneFire("fileMoveDestination") { store.fileMoveDestination = "/m" }
    }

    @MainActor
    func testStoreConnectionsForwardersFireObjectWillChangePerProperty() {
        let store = TermyStore(startInitialPTY: false)
        var fireCount = 0
        let cancellable = store.objectWillChange.sink { fireCount += 1 }
        defer { cancellable.cancel() }

        func assertOneFire(_ label: String, _ mutate: () -> Void) {
            fireCount = 0
            mutate()
            XCTAssertEqual(fireCount, 1, "\(label): exactly one objectWillChange must fire so @ObservedObject views re-render")
        }

        assertOneFire("profiles") { store.profiles = [ConnectionProfile.local()] }
        assertOneFire("tunnelKind") { store.tunnelKind = .remote }
        assertOneFire("tunnelLocalPort") { store.tunnelLocalPort = "1" }
        assertOneFire("tunnelRemoteHost") { store.tunnelRemoteHost = "h" }
        assertOneFire("tunnelRemotePort") { store.tunnelRemotePort = "2" }
        assertOneFire("savedTunnels") { store.savedTunnels = [] }
        assertOneFire("tunnelHealth") { store.tunnelHealth = [:] }
        assertOneFire("tunnelProbeStatus") { store.tunnelProbeStatus = [:] }
        assertOneFire("selectedConnectionProfileID") { store.selectedConnectionProfileID = UUID() }
        assertOneFire("sshProfileNameDraft") { store.sshProfileNameDraft = "n" }
        assertOneFire("sshProfileHostDraft") { store.sshProfileHostDraft = "h" }
        assertOneFire("sshProfileUserDraft") { store.sshProfileUserDraft = "u" }
        assertOneFire("sshProfilePortDraft") { store.sshProfilePortDraft = "p" }
        assertOneFire("sshProfileIdentityDraft") { store.sshProfileIdentityDraft = "i" }
        assertOneFire("sshProfileGroupDraft") { store.sshProfileGroupDraft = "g" }
        assertOneFire("sshOptionsDraft") { store.sshOptionsDraft = "o" }
        assertOneFire("sshKeyPath") { store.sshKeyPath = "k" }
        assertOneFire("sshKeyComment") { store.sshKeyComment = "c" }
        assertOneFire("rdpWidth") { store.rdpWidth = "w" }
        assertOneFire("rdpHeight") { store.rdpHeight = "h" }
        assertOneFire("rdpScale") { store.rdpScale = "s" }
        assertOneFire("rdpLocalFolderPath") { store.rdpLocalFolderPath = "/f" }
        assertOneFire("rdpProfileNameDraft") { store.rdpProfileNameDraft = "n" }
        assertOneFire("rdpProfileHostDraft") { store.rdpProfileHostDraft = "h" }
        assertOneFire("rdpProfileUserDraft") { store.rdpProfileUserDraft = "u" }
        assertOneFire("rdpProfileGatewayDraft") { store.rdpProfileGatewayDraft = "gw" }
        assertOneFire("rdpProfileCredentialDraft") { store.rdpProfileCredentialDraft = "cr" }
        assertOneFire("rdpProfileGroupDraft") { store.rdpProfileGroupDraft = "gr" }
    }

    @MainActor
    func testStoreWorkspaceForwardersFireObjectWillChangePerProperty() {
        let store = TermyStore(startInitialPTY: false)
        var fireCount = 0
        let cancellable = store.objectWillChange.sink { fireCount += 1 }
        defer { cancellable.cancel() }

        func assertOneFire(_ label: String, _ mutate: () -> Void) {
            fireCount = 0
            mutate()
            XCTAssertEqual(fireCount, 1, "\(label): exactly one objectWillChange must fire so @ObservedObject views re-render")
        }

        assertOneFire("workspaceStore") { store.workspaceStore = WorkspaceStore() }
        assertOneFire("paneLayout") { store.paneLayout = WorkspacePaneLayout() }
        assertOneFire("selectedWorkspaceID") { store.selectedWorkspaceID = "w" }
    }

    @MainActor
    func testStoreSyncForwardersFireObjectWillChangePerProperty() {
        let store = TermyStore(startInitialPTY: false)
        var fireCount = 0
        let cancellable = store.objectWillChange.sink { fireCount += 1 }
        defer { cancellable.cancel() }

        func assertOneFire(_ label: String, _ mutate: () -> Void) {
            fireCount = 0
            mutate()
            XCTAssertEqual(fireCount, 1, "\(label): exactly one objectWillChange must fire so @ObservedObject views re-render")
        }

        assertOneFire("privateSyncRecords") { store.privateSyncRecords = [] }
        assertOneFire("privateSyncStatus") { store.privateSyncStatus = "s" }
        assertOneFire("privateSyncPendingOperations") { store.privateSyncPendingOperations = [] }
        assertOneFire("privateSyncLastOperationResults") { store.privateSyncLastOperationResults = [] }
        assertOneFire("privateSyncChangeToken") { store.privateSyncChangeToken = nil }
        assertOneFire("privateSyncEngineAccountState") { store.privateSyncEngineAccountState = nil }
    }
}
