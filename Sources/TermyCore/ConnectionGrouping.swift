import Foundation

/// Groups saved connections into displayable sections by their `groupPath`
/// (Connections G4: folders / project-client groups). Pure + testable; the
/// Connections UI renders one section per returned entry.
public enum ConnectionGrouping {
    public struct Section: Equatable, Sendable {
        /// The group name, or `nil` for the "ungrouped" catch-all section.
        public let title: String?
        public let profiles: [ConnectionProfile]
        public init(title: String?, profiles: [ConnectionProfile]) {
            self.title = title
            self.profiles = profiles
        }
    }

    /// Named groups first (case-insensitive alphabetical), then a single
    /// `nil`-titled section for connections with no (or whitespace-only) group.
    /// Profiles within a section are name-sorted. Empty input → empty result.
    public static func grouped(_ profiles: [ConnectionProfile]) -> [Section] {
        var byGroup: [String: [ConnectionProfile]] = [:]
        var ungrouped: [ConnectionProfile] = []
        for profile in profiles {
            if let group = ConnectionProfile.normalizedGroupPath(profile.groupPath) {
                byGroup[group, default: []].append(profile)
            } else {
                ungrouped.append(profile)
            }
        }

        func byName(_ lhs: ConnectionProfile, _ rhs: ConnectionProfile) -> Bool {
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        var sections = byGroup
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            .map { Section(title: $0.key, profiles: $0.value.sorted(by: byName)) }

        if !ungrouped.isEmpty {
            sections.append(Section(title: nil, profiles: ungrouped.sorted(by: byName)))
        }
        return sections
    }
}
