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

    private func vitals(
        _ state: AgentActivityState, id: UUID, name: String = "a",
        changed: Date = Date(timeIntervalSince1970: 1000)
    ) -> AgentSessionVitals {
        AgentSessionVitals(
            id: id, name: name, agentType: .claudeCode, state: state,
            cwd: "/tmp", branch: nil, dirtyCount: 0, ahead: 0, behind: 0,
            isolation: .here, ports: [], startedAt: changed, stateChangedAt: changed)
    }

    // MARK: - AD-2 attention list

    func testAttentionItemsAreWaitingFirstAndTaggedByKind() {
        let waiting = UUID(), cleanExit = UUID(), failed = UUID()
        let items = agentAttentionItems([
            vitals(.exited, id: cleanExit, name: "clean",
                   changed: Date(timeIntervalSince1970: 200)),
            vitals(.working, id: UUID(), name: "busy"),    // not an attention kind
            vitals(.exited, id: failed, name: "failed",
                   changed: Date(timeIntervalSince1970: 100)),
            vitals(.waitingForInput, id: waiting, name: "waiting")
        ]) { id in id == failed ? 1 : (id == cleanExit ? 0 : nil) }

        // working is dropped; waiting is first; within exited, newest first.
        XCTAssertEqual(items.map { $0.vitals.name }, ["waiting", "clean", "failed"])
        XCTAssertEqual(items.map(\.kind), [.waitingForInput, .exited, .error])
    }

    func testAttentionItemsEmptyWhenNoneNeedAttention() {
        let items = agentAttentionItems([
            vitals(.working, id: UUID()), vitals(.idle, id: UUID())
        ]) { _ in nil }
        XCTAssertTrue(items.isEmpty)
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

    // MARK: - AD-5 fleet navigation

    func testFleetTargetResolves1BasedIndexAgainstFlatOrder() {
        let waiting = UUID(), working = UUID(), idle = UUID()
        let fleet = [
            vitals(.working, id: working, name: "working"),
            vitals(.idle, id: idle, name: "idle"),
            vitals(.waitingForInput, id: waiting, name: "waiting")
        ]
        // flat order is waiting, working, idle → slots 1,2,3
        XCTAssertEqual(agentFleetTarget(index: 1, in: fleet), waiting)
        XCTAssertEqual(agentFleetTarget(index: 2, in: fleet), working)
        XCTAssertEqual(agentFleetTarget(index: 3, in: fleet), idle)
    }

    func testFleetTargetOutOfRangeOrNonPositiveIsNil() {
        let fleet = [vitals(.working, id: UUID())]
        XCTAssertNil(agentFleetTarget(index: 0, in: fleet))
        XCTAssertNil(agentFleetTarget(index: -1, in: fleet))
        XCTAssertNil(agentFleetTarget(index: 2, in: fleet))
        XCTAssertNil(agentFleetTarget(index: 1, in: []))
    }

    func testNextInGroupJumpsToFirstWhenSelectionOutsideGroup() {
        let w1 = UUID(), w2 = UUID(), running = UUID()
        let fleet = [
            vitals(.waitingForInput, id: w1, name: "w1", changed: Date(timeIntervalSince1970: 200)),
            vitals(.waitingForInput, id: w2, name: "w2", changed: Date(timeIntervalSince1970: 100)),
            vitals(.working, id: running, name: "running")
        ]
        // no selection → first waiting (newest within group, w1)
        XCTAssertEqual(nextAgentInGroup(state: .waitingForInput, after: nil, in: fleet), w1)
        // selection is a running agent (different group) → first waiting
        XCTAssertEqual(nextAgentInGroup(state: .waitingForInput, after: running, in: fleet), w1)
    }

    func testNextInGroupAdvancesWithWraparound() {
        let w1 = UUID(), w2 = UUID()
        let fleet = [
            vitals(.waitingForInput, id: w1, name: "w1", changed: Date(timeIntervalSince1970: 200)),
            vitals(.waitingForInput, id: w2, name: "w2", changed: Date(timeIntervalSince1970: 100))
        ]
        // group flat order is [w1, w2]; from w1 → w2; from w2 wraps → w1
        XCTAssertEqual(nextAgentInGroup(state: .waitingForInput, after: w1, in: fleet), w2)
        XCTAssertEqual(nextAgentInGroup(state: .waitingForInput, after: w2, in: fleet), w1)
    }

    func testNextInGroupNilWhenGroupEmpty() {
        let fleet = [vitals(.working, id: UUID())]
        XCTAssertNil(nextAgentInGroup(state: .waitingForInput, after: nil, in: fleet))
    }

    func testNextRunningSingleMemberSelectsItselfOnWrap() {
        let r1 = UUID()
        let fleet = [vitals(.working, id: r1)]
        XCTAssertEqual(nextAgentInGroup(state: .working, after: r1, in: fleet), r1)
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
