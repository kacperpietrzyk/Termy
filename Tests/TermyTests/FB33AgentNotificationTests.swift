import XCTest
@testable import Termy
import TermyCore

final class FB33AgentNotificationTests: XCTestCase {
    private var cleanupURLs: [URL] = []

    override func tearDown() {
        for url in cleanupURLs { try? FileManager.default.removeItem(at: url) }
        cleanupURLs = []
        super.tearDown()
    }

    private func makeTempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FB33-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        cleanupURLs.append(url)
        return url
    }

    @MainActor
    private func makeStore(
        notifications: @escaping (RemoteSessionNotification) -> Void,
        appActive: @escaping () -> Bool
    ) -> TermyStore {
        TermyStore(
            startInitialPTY: false,
            agentStateRoot: makeTempDir(),
            agentHookHelperPath: "/tmp/termy-agent-hook.sh",
            remoteNotificationSink: notifications,
            appIsActive: appActive
        )
    }

    @MainActor
    func testWaitingTransitionFiresWhenAppInactive() throws {
        var posted: [RemoteSessionNotification] = []
        let store = makeStore(notifications: { posted.append($0) }, appActive: { false })
        store.launchCLIAgent(.claudeCode, isolation: .here, baseCwd: "/tmp/cc")
        let id = try XCTUnwrap(store.sessions.last?.id)

        store.applyAgentHookSignal(.waiting, for: id)

        let agentNotes = posted.filter { $0.category == .agentState }
        XCTAssertEqual(agentNotes.count, 1)
        XCTAssertEqual(agentNotes.first?.body, "Waiting for your input")
        XCTAssertEqual(agentNotes.first?.sessionID, id)
    }

    @MainActor
    func testFocusedAgentIsSuppressedWhenAppActive() throws {
        var posted: [RemoteSessionNotification] = []
        // launchCLIAgent selects the new session, so it IS the selected session.
        let store = makeStore(notifications: { posted.append($0) }, appActive: { true })
        store.launchCLIAgent(.claudeCode, isolation: .here, baseCwd: "/tmp/cc")
        let id = try XCTUnwrap(store.sessions.last?.id)
        XCTAssertEqual(store.selectedSessionID, id, "precondition: launched agent session is selected")

        store.applyAgentHookSignal(.waiting, for: id)

        XCTAssertTrue(posted.filter { $0.category == .agentState }.isEmpty,
                      "no banner for the agent you're actively viewing")
    }

    @MainActor
    func testExitFiresFinishedNotification() throws {
        var posted: [RemoteSessionNotification] = []
        let store = makeStore(notifications: { posted.append($0) }, appActive: { false })
        store.launchCLIAgent(.codex, isolation: .here, baseCwd: "/tmp/cx")
        let id = try XCTUnwrap(store.sessions.last?.id)

        store.noteSessionProcessExited(exitCode: 0, for: id)

        XCTAssertEqual(
            posted.filter { $0.category == .agentState }.map(\.body),
            ["Finished (status 0)"])
    }

    @MainActor
    func testIdleTransitionDoesNotFire() throws {
        var posted: [RemoteSessionNotification] = []
        let store = makeStore(notifications: { posted.append($0) }, appActive: { false })
        store.launchCLIAgent(.claudeCode, isolation: .here, baseCwd: "/tmp/cc")
        let id = try XCTUnwrap(store.sessions.last?.id)

        store.agentQuiescenceFired(for: id)   // → idle

        XCTAssertTrue(posted.filter { $0.category == .agentState }.isEmpty)
    }

    @MainActor
    func testFocusAgentSessionSelectsExistingAndIgnoresUnknown() throws {
        let store = makeStore(notifications: { _ in }, appActive: { false })
        store.launchCLIAgent(.claudeCode, isolation: .here, baseCwd: "/tmp/cc")
        let agentID = try XCTUnwrap(store.sessions.last?.id)
        // Select a different (the first / local) session first.
        store.selectedSessionID = store.sessions.first?.id
        XCTAssertNotEqual(store.selectedSessionID, agentID)

        store.focusAgentSession(agentID)
        XCTAssertEqual(store.selectedSessionID, agentID)

        store.focusAgentSession(UUID())   // unknown
        XCTAssertEqual(store.selectedSessionID, agentID, "unknown id is a no-op")
    }

    @MainActor
    func testWaitingBounceReusesStableIdentifier() throws {
        var posted: [RemoteSessionNotification] = []
        let store = makeStore(notifications: { posted.append($0) }, appActive: { false })
        store.launchCLIAgent(.claudeCode, isolation: .here, baseCwd: "/tmp/cc")
        let id = try XCTUnwrap(store.sessions.last?.id)

        store.applyAgentHookSignal(.waiting, for: id)   // fires
        store.noteAgentActivity(for: id)                // → working (policy: no fire)
        store.applyAgentHookSignal(.waiting, for: id)   // fires again

        let ids = posted.filter { $0.category == .agentState }.map(\.identifier)
        XCTAssertEqual(ids, ["agent-state-\(id.uuidString)", "agent-state-\(id.uuidString)"],
                       "bounce must reuse the per-session identifier so the OS replaces the banner")
    }
}
