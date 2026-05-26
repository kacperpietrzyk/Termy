import XCTest
@testable import TermyCore

final class AgentVitalsTests: XCTestCase {
    private func vitals(
        _ state: AgentActivityState,
        name: String = "a",
        changed: Date = Date(timeIntervalSince1970: 1000)
    ) -> AgentSessionVitals {
        AgentSessionVitals(
            id: UUID(), name: name, agentType: .claudeCode, state: state,
            cwd: "/tmp", branch: nil, dirtyCount: 0, ahead: 0, behind: 0,
            isolation: .here, ports: [], startedAt: changed, stateChangedAt: changed)
    }

    func testGroupingPartitionsByState() {
        let grouped = groupAgentVitals([
            vitals(.working), vitals(.waitingForInput), vitals(.idle),
            vitals(.exited), vitals(.working)
        ])
        XCTAssertEqual(grouped.waiting.count, 1)
        XCTAssertEqual(grouped.running.count, 2)
        XCTAssertEqual(grouped.idle.count, 1)
        XCTAssertEqual(grouped.recent.count, 1)
    }

    func testFlatOrderIsWaitingFirstThenRunningIdleRecent() {
        let order = agentVitalsFlatOrder([
            vitals(.exited, name: "exited"),
            vitals(.idle, name: "idle"),
            vitals(.working, name: "working"),
            vitals(.waitingForInput, name: "waiting")
        ])
        XCTAssertEqual(order.map(\.name), ["waiting", "working", "idle", "exited"])
    }

    func testFlatOrderWithinGroupNewestStateChangeFirst() {
        let older = vitals(.working, name: "older", changed: Date(timeIntervalSince1970: 100))
        let newer = vitals(.working, name: "newer", changed: Date(timeIntervalSince1970: 200))
        XCTAssertEqual(agentVitalsFlatOrder([older, newer]).map(\.name), ["newer", "older"])
    }

    func testMergeUsesCachedGitFactsAndDefaultsToUnknown() {
        let cachedID = UUID()
        let uncachedID = UUID()
        let snapshots = [
            AgentVitalsSnapshot(id: cachedID, name: "cached", agentType: .claudeCode,
                state: .working, cwd: "/repo", isolation: .worktree(path: "/wt"),
                startedAt: Date(timeIntervalSince1970: 1), stateChangedAt: Date(timeIntervalSince1970: 2)),
            AgentVitalsSnapshot(id: uncachedID, name: "uncached", agentType: .codex,
                state: .idle, cwd: nil, isolation: .here,
                startedAt: Date(timeIntervalSince1970: 3), stateChangedAt: Date(timeIntervalSince1970: 4))
        ]
        let cache = [cachedID: GitVitals(branch: "feat/x", dirtyCount: 5, ahead: 2, behind: 1)]

        let merged = mergeAgentVitals(snapshots: snapshots, gitCache: cache)

        let cached = try! XCTUnwrap(merged.first { $0.id == cachedID })
        XCTAssertEqual(cached.branch, "feat/x")
        XCTAssertEqual(cached.dirtyCount, 5)
        XCTAssertEqual(cached.ahead, 2)
        XCTAssertEqual(cached.isolation, .worktree(path: "/wt"))
        XCTAssertTrue(cached.ports.isEmpty)

        let uncached = try! XCTUnwrap(merged.first { $0.id == uncachedID })
        XCTAssertNil(uncached.branch)
        XCTAssertEqual(uncached.dirtyCount, 0)
        XCTAssertEqual(uncached.agentType, .codex)
    }

    func testMergePassesPlanAndTouchedThrough() {
        let id = UUID()
        let step = AgentPlanStep(id: "t1", text: "A", state: .active, sub: nil)
        let snapshot = AgentVitalsSnapshot(
            id: id, name: "a", agentType: .claudeCode, state: .working, cwd: "/repo",
            isolation: .here, startedAt: Date(), stateChangedAt: Date(),
            plan: [step], touched: ["/repo/A.swift"])
        let merged = mergeAgentVitals(snapshots: [snapshot], gitCache: [:])
        XCTAssertEqual(merged.first?.plan, [step])
        XCTAssertEqual(merged.first?.touched, ["/repo/A.swift"])
    }
}
