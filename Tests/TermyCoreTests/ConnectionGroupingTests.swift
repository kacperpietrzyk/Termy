import XCTest
@testable import TermyCore

final class ConnectionGroupingTests: XCTestCase {
    private func ssh(_ name: String, group: String?) -> ConnectionProfile {
        .ssh(name: name, host: "h", user: "u", identity: .keychain("k"), groupPath: group)
    }

    func test_groupsByGroupPath_namedBeforeUngrouped_sorted() {
        let profiles = [
            ssh("zeta", group: "Client B"),
            ssh("alpha", group: "Client A"),
            ssh("loose", group: nil),
            ssh("beta", group: "Client A"),
            ssh("solo", group: "   "),   // whitespace-only == ungrouped
        ]
        let groups = ConnectionGrouping.grouped(profiles)

        // Named groups (case-insensitive alphabetical) first, ungrouped (nil title) last.
        XCTAssertEqual(groups.map(\.title), ["Client A", "Client B", nil])
        // Within "Client A", profiles are name-sorted.
        XCTAssertEqual(groups[0].profiles.map(\.name), ["alpha", "beta"])
        XCTAssertEqual(groups[1].profiles.map(\.name), ["zeta"])
        // Ungrouped collects nil AND whitespace-only group paths.
        XCTAssertEqual(Set(groups[2].profiles.map(\.name)), ["loose", "solo"])
    }

    func test_allUngrouped_singleNilSection() {
        let groups = ConnectionGrouping.grouped([ssh("a", group: nil), ssh("b", group: nil)])
        XCTAssertEqual(groups.count, 1)
        XCTAssertNil(groups[0].title)
        XCTAssertEqual(groups[0].profiles.map(\.name), ["a", "b"])
    }

    func test_empty_returnsEmpty() {
        XCTAssertTrue(ConnectionGrouping.grouped([]).isEmpty)
    }

    func test_caseInsensitiveGroupNameSort() {
        let groups = ConnectionGrouping.grouped([ssh("x", group: "prod"), ssh("y", group: "Dev")])
        XCTAssertEqual(groups.map(\.title), ["Dev", "prod"])
    }
}
