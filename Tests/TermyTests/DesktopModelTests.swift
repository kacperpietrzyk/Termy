import XCTest
@testable import Termy
import TermyCore

final class DesktopModelTests: XCTestCase {
    // Build a vitals fixture with only the fields the helpers read.
    private func vitals(name: String, state: AgentActivityState,
                        dirty: Int = 0, branch: String? = nil,
                        changedAt: Date = Date()) -> AgentSessionVitals {
        AgentSessionVitals(
            id: UUID(), name: name, agentType: .claudeCode, state: state,
            cwd: nil, branch: branch, dirtyCount: dirty, ahead: 0, behind: 0,
            isolation: .here, ports: [], startedAt: Date(), stateChangedAt: changedAt)
    }

    private func date(hour: Int) -> Date {
        var c = DateComponents(); c.year = 2026; c.month = 5; c.day = 22
        c.hour = hour; c.minute = 0
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    func testGreetingByTimeOfDay() {
        XCTAssertEqual(DesktopModel.greeting(at: date(hour: 0), name: "Kacper").lead, "Good morning")
        XCTAssertEqual(DesktopModel.greeting(at: date(hour: 11), name: "Kacper").lead, "Good morning")
        XCTAssertEqual(DesktopModel.greeting(at: date(hour: 12), name: "Kacper").lead, "Good afternoon")
        XCTAssertEqual(DesktopModel.greeting(at: date(hour: 17), name: "Kacper").lead, "Good afternoon")
        XCTAssertEqual(DesktopModel.greeting(at: date(hour: 18), name: "Kacper").lead, "Good evening")
        XCTAssertEqual(DesktopModel.greeting(at: date(hour: 23), name: "Kacper").name, "Kacper")
    }

    func testRadialOrbPositionStartsAtTopAndGoesClockwise() {
        let top = DesktopModel.radialOrbPosition(index: 0, count: 8, radius: 240)
        XCTAssertEqual(top.x, 0, accuracy: 0.001)
        XCTAssertEqual(top.y, -240, accuracy: 0.001)   // top (-π/2)
        let right = DesktopModel.radialOrbPosition(index: 2, count: 8, radius: 240)
        XCTAssertEqual(right.x, 240, accuracy: 0.001)  // right (angle 0)
        XCTAssertEqual(right.y, 0, accuracy: 0.001)
        let bottom = DesktopModel.radialOrbPosition(index: 4, count: 8, radius: 240)
        XCTAssertEqual(bottom.y, 240, accuracy: 0.001) // bottom (π/2)
    }

    func testAttentionSignalPriority() {
        XCTAssertEqual(DesktopModel.attentionSignal([]), .calm)
        XCTAssertEqual(
            DesktopModel.attentionSignal([vitals(name: "a", state: .working)]),
            .running(count: 1))
        XCTAssertEqual(
            DesktopModel.attentionSignal([
                vitals(name: "run", state: .working),
                vitals(name: "auth-refactor", state: .waitingForInput)]),
            .waiting(name: "auth-refactor"))   // waiting wins over running
    }

    func testHeroSubTextComposesAndFallsBack() {
        let calm = DesktopModel.heroSubText(vitals: [], gitDirty: 0, branch: nil)
        XCTAssertEqual(calm.count, 1)
        XCTAssertTrue(calm[0].text.hasPrefix("All clear"))

        let busy = DesktopModel.heroSubText(
            vitals: [vitals(name: "x", state: .waitingForInput)],
            gitDirty: 3, branch: "feat/inline")
        let joined = busy.map(\.text).joined()
        XCTAssertTrue(joined.contains("1 agent waiting"))
        XCTAssertTrue(joined.contains("3 dirty files"))
        XCTAssertTrue(joined.contains("feat/inline"))
        XCTAssertTrue(busy.contains { $0.accent == .agent })
        XCTAssertTrue(busy.contains { $0.accent == .git })
    }

    func testGitMiniRowsAndDirtyCount() {
        let status = " M Sources/a.swift\n?? new.txt\nUU Sources/b.swift\n"
        let rows = DesktopModel.gitMiniRows(from: status, limit: 2)
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0], DesktopModel.GitMiniRow(code: "M", path: "Sources/a.swift"))
        XCTAssertEqual(rows[1], DesktopModel.GitMiniRow(code: "??", path: "new.txt"))
        XCTAssertEqual(DesktopModel.gitDirtyCount(status), 3)
        XCTAssertEqual(DesktopModel.gitDirtyCount(""), 0)
    }

    func testGitHasConflict() {
        XCTAssertTrue(DesktopModel.gitHasConflict("UU Sources/b.swift\n"))
        XCTAssertTrue(DesktopModel.gitHasConflict("AA x\n"))
        XCTAssertFalse(DesktopModel.gitHasConflict(" M Sources/a.swift\n?? new.txt\n"))
    }

    func testGitParsersRejectNonPorcelainDisplayStrings() {
        // TermyStore.gitStatus is a shared display string, not raw porcelain —
        // these must never be mistaken for dirty entries.
        for sentinel in ["Working tree clean.",
                         "Run Git Status to inspect the current repository.",
                         "Add feature X",
                         "fatal: not a git repository"] {
            XCTAssertEqual(DesktopModel.gitMiniRows(from: sentinel), [], "rows for: \(sentinel)")
            XCTAssertEqual(DesktopModel.gitDirtyCount(sentinel), 0, "dirtyCount for: \(sentinel)")
            XCTAssertFalse(DesktopModel.gitHasConflict(sentinel), "conflict for: \(sentinel)")
        }
    }

    func testRelativeAge() {
        XCTAssertEqual(DesktopModel.relativeAge(24), "24s")
        XCTAssertEqual(DesktopModel.relativeAge(200), "3m")
        XCTAssertEqual(DesktopModel.relativeAge(7200), "2h")
        XCTAssertEqual(DesktopModel.relativeAge(-5), "0s")
    }
}
