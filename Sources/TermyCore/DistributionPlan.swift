import Foundation

public enum DistributionChannel: Equatable, Sendable {
    case directDMG
}

public struct DistributionPlan: Equatable, Sendable {
    public let appName: String
    public let bundleIdentifier: String
    public let channel: DistributionChannel
    public let requiresDeveloperIDApplicationCertificate: Bool
    public let requiresNotarization: Bool
    public let requiresHardenedRuntime: Bool
    public let usesAppSandbox: Bool

    public init(
        appName: String,
        bundleIdentifier: String,
        channel: DistributionChannel,
        requiresDeveloperIDApplicationCertificate: Bool,
        requiresNotarization: Bool,
        requiresHardenedRuntime: Bool,
        usesAppSandbox: Bool
    ) {
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.channel = channel
        self.requiresDeveloperIDApplicationCertificate = requiresDeveloperIDApplicationCertificate
        self.requiresNotarization = requiresNotarization
        self.requiresHardenedRuntime = requiresHardenedRuntime
        self.usesAppSandbox = usesAppSandbox
    }

    public func dmgName(version: String) -> String {
        "\(appName)-\(version).dmg"
    }

    public static let termDefault = DistributionPlan(
        appName: "Termy",
        bundleIdentifier: "pl.kacper.Termy",
        channel: .directDMG,
        requiresDeveloperIDApplicationCertificate: true,
        requiresNotarization: true,
        requiresHardenedRuntime: true,
        usesAppSandbox: false
    )
}

public enum DistributionRequirement: String, Equatable, Sendable {
    case developerIDApplicationSignature
    case hardenedRuntime
    case notarizedAndStapledDMG
    case appSandboxDisabled
}

public struct DistributionAudit: Equatable, Sendable {
    public let appBundleSignedWithDeveloperID: Bool
    public let hardenedRuntimeEnabled: Bool
    public let dmgNotarizedAndStapled: Bool
    public let appSandboxEnabled: Bool

    public init(
        appBundleSignedWithDeveloperID: Bool,
        hardenedRuntimeEnabled: Bool,
        dmgNotarizedAndStapled: Bool,
        appSandboxEnabled: Bool
    ) {
        self.appBundleSignedWithDeveloperID = appBundleSignedWithDeveloperID
        self.hardenedRuntimeEnabled = hardenedRuntimeEnabled
        self.dmgNotarizedAndStapled = dmgNotarizedAndStapled
        self.appSandboxEnabled = appSandboxEnabled
    }

    public func missingRequirements(for plan: DistributionPlan) -> [DistributionRequirement] {
        var missing: [DistributionRequirement] = []
        if plan.requiresDeveloperIDApplicationCertificate && !appBundleSignedWithDeveloperID {
            missing.append(.developerIDApplicationSignature)
        }
        if plan.requiresHardenedRuntime && !hardenedRuntimeEnabled {
            missing.append(.hardenedRuntime)
        }
        if plan.requiresNotarization && !dmgNotarizedAndStapled {
            missing.append(.notarizedAndStapledDMG)
        }
        if !plan.usesAppSandbox && appSandboxEnabled {
            missing.append(.appSandboxDisabled)
        }
        return missing
    }

    public func satisfies(_ plan: DistributionPlan) -> Bool {
        missingRequirements(for: plan).isEmpty
    }
}
