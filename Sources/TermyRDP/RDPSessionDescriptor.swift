// RDPSessionDescriptor — pure-config seam for an RDP session.
//
// M5 Task 6: this file is the residue of the (~6.3k-line) bespoke RDP
// engine after cutover to FreeRDP via the CTermyRDP shim. Everything
// removed — CredSSP/NTLMv2/SPNEGO/DER, MCS/connection-sequence,
// RDPSecurityUpgrade*, RDPLiveConnectionBootstrapper /
// RDPActivatedByteTransportSession / RDPInputEventWriter /
// RDPDesktopUpdateStream / RDPNetworkTransportAdapter, the bespoke
// bitmap-update parser, all rdpdr/rdpsnd/cliprdr PDU codecs, and the
// bespoke `RDPCredSSPNTLMv2CredentialResolver` (Task 4 migrated the
// Keychain resolution into FreeRDPSession). Engine-agnostic seam value
// types previously sharing this file moved to:
//   • Sources/TermyRDP/RDPInputMapping.swift — RDPSlowPathInputEvent /
//     RDPPointerFlags / RDPKeyboardInput / RDPInputEventMapper et al.
// RDPSessionModel.swift retains the rest of the engine-agnostic contract
// (RDPTransportEvent, RDPTransportEventRouter, frame/clipboard/drive/audio
// types). Engine: FreeRDPSession in this same module.

import Foundation
import TermyCore

public struct RDPSessionDescriptor: Equatable, Sendable {
    public let host: String
    public let user: String
    public let gateway: String?
    public let resolution: RDPResolution
    public let scale: Double
    public let redirections: [RDPRedirection]
    public let secretReferences: [SecretReference]
    public let reconnectPolicy: RDPReconnectPolicy

    public var inlinePassword: String? { nil }

    public init(
        profile: ConnectionProfile,
        resolution: RDPResolution,
        scale: Double,
        localFolderPath: String?,
        reconnectPolicy: RDPReconnectPolicy = RDPReconnectPolicy()
    ) throws {
        guard profile.kind == .rdp else {
            throw RDPSessionDescriptorError.requiresRDPProfile
        }
        guard let user = profile.user, !user.isEmpty else {
            throw RDPSessionDescriptorError.missingUser
        }

        self.host = profile.host
        self.user = user
        self.gateway = profile.gateway
        self.resolution = resolution
        self.scale = scale
        self.secretReferences = profile.secretReferences
        self.reconnectPolicy = reconnectPolicy

        var redirections: [RDPRedirection] = [.clipboard]
        if let localFolderPath, !localFolderPath.isEmpty {
            redirections.append(.folderDrive(localFolderPath))
        }
        redirections.append(.audioOutput)
        self.redirections = redirections
    }
}
