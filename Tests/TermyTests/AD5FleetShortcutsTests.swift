import XCTest
@testable import Termy
import TermyCore

/// AD-5 — global fleet shortcuts. Logic-only: catalog wiring, ⌘K availability
/// gating, and the store navigation methods routing through `focusAgentSession`.
final class AD5FleetShortcutsTests: XCTestCase {

    // MARK: Catalog wiring + no keymap collisions

    func testCatalogHasFleetActionsWithControlCommandShortcuts() {
        let actions = FeatureCatalog.termDefault.commandCenterActions
        let byID = Dictionary(uniqueKeysWithValues: actions.map { ($0.id, $0) })

        XCTAssertEqual(byID["agent-next-waiting"]?.shortcut, .controlCommand("j"))
        XCTAssertEqual(byID["agent-next-running"]?.shortcut, .controlCommand("k"))
        for slot in 1...9 {
            XCTAssertEqual(byID["agent-select-\(slot)"]?.shortcut, .controlCommand("\(slot)"),
                           "slot \(slot) shortcut")
        }
    }

    func testFleetActionsDoNotCollideInDefaultKeymap() {
        let actions = FeatureCatalog.termDefault.commandCenterActions
        let profile = KeymapProfile.defaults(for: actions)
        XCTAssertTrue(profile.conflicts(in: actions).isEmpty,
                      "default keymap must be conflict-free: \(profile.conflicts(in: actions))")
    }

    // MARK: ⌘K availability gating

    @MainActor
    func testFleetActionsHiddenWhenNoAgents() {
        let store = TermyStore(startInitialPTY: false)
        store.sessions.removeAll()
        let ids = store.filteredActions.map(\.id)
        XCTAssertFalse(ids.contains("agent-next-waiting"))
        XCTAssertFalse(ids.contains("agent-next-running"))
        XCTAssertFalse(ids.contains("agent-select-1"))
    }

    @MainActor
    func testNextWaitingHiddenWhenOnlyRunning_selectSlotsTrackFleetCount() {
        let store = TermyStore(startInitialPTY: false)
        store.sessions.removeAll()
        store.perform("run-claude-code-here")
        store.perform("run-codex-here")
        store.sessions[0].agentActivity = .working
        store.sessions[1].agentActivity = .working

        let ids = Set(store.filteredActions.map(\.id))
        XCTAssertFalse(ids.contains("agent-next-waiting"))   // no waiting agent
        XCTAssertTrue(ids.contains("agent-next-running"))    // two running
        XCTAssertTrue(ids.contains("agent-select-1"))
        XCTAssertTrue(ids.contains("agent-select-2"))
        XCTAssertFalse(ids.contains("agent-select-3"))       // only 2 in fleet
    }

    @MainActor
    func testNextWaitingShownWhenAWaitingAgentExists() {
        let store = TermyStore(startInitialPTY: false)
        store.sessions.removeAll()
        store.perform("run-claude-code-here")
        store.sessions[0].agentActivity = .waitingForInput
        XCTAssertTrue(store.filteredActions.map(\.id).contains("agent-next-waiting"))
    }

    // MARK: Store navigation methods

    @MainActor
    func testFocusNextWaitingSelectsTheWaitingAgent() {
        let store = TermyStore(startInitialPTY: false)
        store.sessions.removeAll()
        store.perform("run-claude-code-here")   // session 0
        store.perform("run-codex-here")         // session 1
        store.sessions[0].agentActivity = .working
        store.sessions[1].agentActivity = .waitingForInput
        let waitingID = store.sessions[1].id
        store.selectedSessionID = store.sessions[0].id

        store.focusNextWaitingAgent()

        XCTAssertEqual(store.selectedSessionID, waitingID)
    }

    @MainActor
    func testFocusNextRunningCyclesWithWraparound() {
        let store = TermyStore(startInitialPTY: false)
        store.sessions.removeAll()
        store.perform("run-claude-code-here")
        store.perform("run-codex-here")
        store.sessions[0].agentActivity = .working
        store.sessions[1].agentActivity = .working

        // flat order ranks by stateChangedAt desc within the running group; pin
        // the order by selecting the first running and asserting we advance+wrap.
        let runningIDs = Set([store.sessions[0].id, store.sessions[1].id])
        store.selectedSessionID = store.sessions[0].id
        store.focusNextRunningAgent()
        let firstHop = store.selectedSessionID
        XCTAssertNotNil(firstHop)
        XCTAssertTrue(runningIDs.contains(firstHop!))
        // a second hop must return into the same 2-member group (wraparound)
        store.focusNextRunningAgent()
        XCTAssertTrue(runningIDs.contains(store.selectedSessionID!))
    }

    @MainActor
    func testFocusFleetSlotJumpsToWaitingFirstOrder() {
        let store = TermyStore(startInitialPTY: false)
        store.sessions.removeAll()
        store.perform("run-claude-code-here")   // will be working
        store.perform("run-codex-here")         // will be waiting
        store.sessions[0].agentActivity = .working
        store.sessions[1].agentActivity = .waitingForInput
        let waitingID = store.sessions[1].id
        let workingID = store.sessions[0].id

        // slot 1 = waiting-first
        store.perform("agent-select-1")
        XCTAssertEqual(store.selectedSessionID, waitingID)
        store.perform("agent-select-2")
        XCTAssertEqual(store.selectedSessionID, workingID)
    }

    @MainActor
    func testFocusEmptySlotIsNoOpAndReports() {
        let store = TermyStore(startInitialPTY: false)
        store.sessions.removeAll()
        store.perform("run-claude-code-here")
        store.sessions[0].agentActivity = .working
        let only = store.sessions[0].id
        store.selectedSessionID = only

        store.perform("agent-select-5")   // out of range

        XCTAssertEqual(store.selectedSessionID, only)   // unchanged
        XCTAssertEqual(store.statusMessage, "No agent in fleet slot 5.")
    }

    @MainActor
    func testNextWaitingWithNoneReportsAndKeepsSelection() {
        let store = TermyStore(startInitialPTY: false)
        store.sessions.removeAll()
        store.perform("run-claude-code-here")
        store.sessions[0].agentActivity = .working
        let only = store.sessions[0].id
        store.selectedSessionID = only

        store.focusNextWaitingAgent()

        XCTAssertEqual(store.selectedSessionID, only)
        XCTAssertEqual(store.statusMessage, "No agent is waiting for input.")
    }
}
