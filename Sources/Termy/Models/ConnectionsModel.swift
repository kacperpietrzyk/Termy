import Foundation
import Observation
import TermyCore

/// Connection-profile / SSH-tunnel / RDP-draft-domain state, extracted from
/// the `TermyStore` god-object as part of the strangler-facade decomposition
/// (M2c-2). `@Observable` + `@MainActor`: the future state is views observing
/// this model directly via `@Environment(AppModel.self)`; until then
/// `TermyStore` forwards to it. `profiles` defaults to `[]`; the real seed
/// list is written by `TermyStore.init` (see the M2c-2 init note).
@MainActor
@Observable
final class ConnectionsModel {
    var profiles: [ConnectionProfile] = []
    var tunnelKind = SSHTunnelKind.local
    var tunnelLocalPort = "8080"
    var tunnelRemoteHost = "127.0.0.1"
    var tunnelRemotePort = "80"
    var savedTunnels: [SavedSSHTunnel] = []
    var tunnelHealth: [String: SSHTunnelHealth] = [:]
    var tunnelProbeStatus: [String: String] = [:]
    var selectedConnectionProfileID: UUID?
    var sshProfileNameDraft = ""
    var sshProfileHostDraft = ""
    var sshProfileUserDraft = NSUserName()
    var sshProfilePortDraft = "22"
    var sshProfileIdentityDraft = "~/.ssh/id_ed25519"
    var sshProfileGroupDraft = ""
    var sshOptionsDraft = ""
    var sshKeyPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".ssh/id_ed25519_termy").path
    var sshKeyComment = "\(NSUserName())@Termy"
    var rdpWidth = "1920"
    var rdpHeight = "1080"
    var rdpScale = "1.0"
    var rdpLocalFolderPath = FileManager.default.homeDirectoryForCurrentUser.path
    var rdpProfileNameDraft = ""
    var rdpProfileHostDraft = ""
    var rdpProfileUserDraft = NSUserName()
    var rdpProfileGatewayDraft = ""
    var rdpProfileCredentialDraft = ""
    var rdpProfileGroupDraft = ""

    init() {}
}
