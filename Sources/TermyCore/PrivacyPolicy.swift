import Foundation

public enum OutboundTraffic: String, CaseIterable, Equatable, Sendable {
    case userInitiatedSSH
    /// RDP uses vendored, pinned, offline-built FreeRDP 3.26.0 with no
    /// telemetry and no library-initiated network beyond the user's own RDP
    /// connection (spec §2). The `.userInitiatedRDP` outbound case covers
    /// exactly that: a user-typed RDP host, with no telemetry, no profiling,
    /// no auto-update probe, no Termy server callback.
    case userInitiatedRDP
    case userLaunchedCLIAgent
    case privateICloudSync
    /// The updater is Sparkle 2.9.2, configured with system profiling
    /// disabled and automatic checks off by default. An update check is a
    /// plain HTTPS GET to the user's own build-time-pinned appcast feed —
    /// no telemetry or profiling.
    case userInitiatedUpdateCheck
    case optedInAutomaticUpdateCheck
}

public struct PrivacyPolicy: Equatable, Sendable {
    public let allowsTelemetry: Bool
    public let allowsTermyAccount: Bool
    public let allowsCloudAIProviders: Bool
    public let requiresLocalBuiltInAI: Bool
    public let allowedOutboundTraffic: [OutboundTraffic]

    public static let termDefault = PrivacyPolicy(
        allowsTelemetry: false,
        allowsTermyAccount: false,
        allowsCloudAIProviders: false,
        requiresLocalBuiltInAI: true,
        allowedOutboundTraffic: [
            .userInitiatedSSH,
            .userInitiatedRDP,
            .userLaunchedCLIAgent,
            .privateICloudSync,
            .userInitiatedUpdateCheck,
            .optedInAutomaticUpdateCheck
        ]
    )
}
