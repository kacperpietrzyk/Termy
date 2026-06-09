import XCTest
@testable import TermyCore

final class ActionPanelTests: XCTestCase {

    // MARK: helpers

    private func action(id: String = "connect-ssh") -> CommandAction {
        CommandAction(id: id, title: "Connect SSH", subtitle: "Open a saved SSH session",
                      area: .ssh, keywords: ["ssh"], shortcut: nil)
    }

    private func vitals(state: AgentActivityState, id: UUID = UUID()) -> AgentSessionVitals {
        AgentSessionVitals(
            id: id, name: "claude #1", agentType: .claudeCode, state: state,
            cwd: "/work", branch: "main", dirtyCount: 2, ahead: 0, behind: 0,
            isolation: .here, ports: [], startedAt: Date(), stateChangedAt: Date())
    }

    private func handlerIDs(_ actions: [SecondaryAction]) -> [String] {
        actions.map { $0.handlerID.split(separator: ":").first.map(String.init) ?? $0.handlerID }
    }

    // MARK: action

    func testActionResolvesPrimaryCopyIdSetAlias() {
        let resolved = ActionPanelResolver.resolve(.action(action(id: "toggle-git-panel")))
        XCTAssertEqual(handlerIDs(resolved),
                       ["action.perform", "action.copy-id", "action.set-alias"])
        // primary is first, with the enter hint
        XCTAssertEqual(resolved.first?.inlineHotkey, "↵")
        // ids carry the originating command id
        XCTAssertEqual(resolved[0].handlerID, "action.perform:toggle-git-panel")
        XCTAssertEqual(resolved[1].handlerID, "action.copy-id:toggle-git-panel")
        XCTAssertEqual(resolved[2].handlerID, "action.set-alias:toggle-git-panel")
        XCTAssertFalse(resolved.contains { $0.isDestructive })
    }

    // MARK: profile — SSH

    func testSSHProfileOffersConnectSFTPTunnelEdit() {
        let profile = ConnectionProfile.ssh(
            name: "prod", host: "h", user: "u", identity: .keychain("k"))
        let resolved = ActionPanelResolver.resolve(.profile(profile))
        XCTAssertEqual(handlerIDs(resolved),
                       ["profile.connect", "profile.sftp", "profile.tunnel", "profile.edit"])
        XCTAssertEqual(resolved.first?.title, "Connect")
        XCTAssertEqual(resolved.first?.inlineHotkey, "↵")
        // id is the profile uuid so the dispatch site can route it
        XCTAssertTrue(resolved.allSatisfy { $0.handlerID.hasSuffix(profile.id.uuidString) })
    }

    // MARK: profile — RDP

    func testRDPProfileOffersConnectAndEditButNotSFTPorTunnel() {
        let profile = ConnectionProfile.rdp(
            name: "win", host: "h", user: "u", gateway: nil, credential: .keychain("k"))
        let resolved = ActionPanelResolver.resolve(.profile(profile))
        XCTAssertEqual(handlerIDs(resolved), ["profile.connect", "profile.edit"])
    }

    // MARK: profile — local

    func testLocalProfileOffersConnectOnly() {
        let profile = ConnectionProfile.local()
        let resolved = ActionPanelResolver.resolve(.profile(profile))
        // local shell is not an editable connection record → connect only
        XCTAssertEqual(handlerIDs(resolved), ["profile.connect"])
    }

    // MARK: agent — live states

    func testWorkingAgentOffersFullLifecycle() {
        let resolved = ActionPanelResolver.resolve(.agentSession(vitals(state: .working)))
        XCTAssertEqual(handlerIDs(resolved),
                       ["agent.focus", "agent.interrupt", "agent.restart",
                        "agent.review", "agent.steer", "agent.close"])
        // Steer is present on a live agent — this is where AD-5 lands.
        XCTAssertTrue(resolved.contains { $0.handlerID.hasPrefix("agent.steer") })
        // Close is the destructive one.
        XCTAssertEqual(resolved.filter { $0.isDestructive }.map { $0.handlerID.split(separator: ":").first.map(String.init) },
                       ["agent.close"])
    }

    func testWaitingAndIdleAgentsAlsoGetFullLifecycle() {
        for state in [AgentActivityState.waitingForInput, .idle] {
            let resolved = ActionPanelResolver.resolve(.agentSession(vitals(state: state)))
            XCTAssertTrue(resolved.contains { $0.handlerID.hasPrefix("agent.interrupt") },
                          "state \(state) should be live")
            XCTAssertTrue(resolved.contains { $0.handlerID.hasPrefix("agent.steer") })
        }
    }

    // MARK: agent — exited

    func testExitedAgentOffersOnlyFocusAndClose() {
        let resolved = ActionPanelResolver.resolve(.agentSession(vitals(state: .exited)))
        XCTAssertEqual(handlerIDs(resolved), ["agent.focus", "agent.close"])
        // No lifecycle action that the store would no-op on an exited process.
        XCTAssertFalse(resolved.contains { $0.handlerID.hasPrefix("agent.interrupt") })
        XCTAssertFalse(resolved.contains { $0.handlerID.hasPrefix("agent.restart") })
        XCTAssertFalse(resolved.contains { $0.handlerID.hasPrefix("agent.steer") })
        XCTAssertFalse(resolved.contains { $0.handlerID.hasPrefix("agent.review") })
    }

    // MARK: id carries the originating uuid (dispatch needs it)

    func testAgentActionsCarryTheSessionUUID() {
        let id = UUID()
        let resolved = ActionPanelResolver.resolve(.agentSession(vitals(state: .working, id: id)))
        XCTAssertTrue(resolved.allSatisfy { $0.handlerID.hasSuffix(id.uuidString) })
    }

    // MARK: stable Identifiable id

    func testSecondaryActionIdentifiableIsHandlerID() {
        let a = SecondaryAction(handlerID: "x.y:1", title: "T")
        XCTAssertEqual(a.id, "x.y:1")
        XCTAssertTrue(a.children.isEmpty)
        XCTAssertNil(a.inlineHotkey)
    }

    // MARK: CK-S5 — handlerID → intent parser

    func testActionIntentsCarryCommandID() {
        XCTAssertEqual(SecondaryActionIntent(handlerID: "action.perform:toggle-git-panel"),
                       .performAction("toggle-git-panel"))
        XCTAssertEqual(SecondaryActionIntent(handlerID: "action.copy-id:toggle-git-panel"),
                       .copyActionID("toggle-git-panel"))
        XCTAssertEqual(SecondaryActionIntent(handlerID: "action.set-alias:toggle-git-panel"),
                       .setAlias("toggle-git-panel"))
    }

    func testProfileIntentsParseUUID() {
        let id = UUID()
        XCTAssertEqual(SecondaryActionIntent(handlerID: "profile.connect:\(id.uuidString)"),
                       .connectProfile(id))
        XCTAssertEqual(SecondaryActionIntent(handlerID: "profile.sftp:\(id.uuidString)"),
                       .sftpProfile(id))
        XCTAssertEqual(SecondaryActionIntent(handlerID: "profile.tunnel:\(id.uuidString)"),
                       .tunnelProfile(id))
        XCTAssertEqual(SecondaryActionIntent(handlerID: "profile.edit:\(id.uuidString)"),
                       .editProfile(id))
    }

    func testAgentIntentsParseUUID() {
        let id = UUID()
        XCTAssertEqual(SecondaryActionIntent(handlerID: "agent.focus:\(id.uuidString)"),
                       .focusAgent(id))
        XCTAssertEqual(SecondaryActionIntent(handlerID: "agent.interrupt:\(id.uuidString)"),
                       .interruptAgent(id))
        XCTAssertEqual(SecondaryActionIntent(handlerID: "agent.restart:\(id.uuidString)"),
                       .restartAgent(id))
        XCTAssertEqual(SecondaryActionIntent(handlerID: "agent.review:\(id.uuidString)"),
                       .reviewAgent(id))
        XCTAssertEqual(SecondaryActionIntent(handlerID: "agent.steer:\(id.uuidString)"),
                       .steerAgent(id))
        XCTAssertEqual(SecondaryActionIntent(handlerID: "agent.close:\(id.uuidString)"),
                       .closeAgent(id))
    }

    func testIntentRejectsUnknownVerbAndMalformedID() {
        XCTAssertNil(SecondaryActionIntent(handlerID: "agent.frobnicate:\(UUID().uuidString)"))
        XCTAssertNil(SecondaryActionIntent(handlerID: "no-colon-here"))
        XCTAssertNil(SecondaryActionIntent(handlerID: "agent.focus:"))
        // UUID-domain id with a non-UUID payload → nil, never a guessed dispatch.
        XCTAssertNil(SecondaryActionIntent(handlerID: "profile.connect:not-a-uuid"))
    }

    /// The whole point: every handlerID the resolver can emit must parse back to a
    /// dispatchable intent (no resolver/parser drift).
    func testEveryResolvedActionParsesToAnIntent() {
        let id = UUID()
        let targets: [ActionPanelTarget] = [
            .action(action(id: "toggle-git-panel")),
            .profile(.ssh(name: "p", host: "h", user: "u", identity: .keychain("k"))),
            .profile(.rdp(name: "w", host: "h", user: "u", gateway: nil, credential: .keychain("k"))),
            .agentSession(vitals(state: .working, id: id)),
            .agentSession(vitals(state: .exited, id: id))
        ]
        for target in targets {
            for secondary in ActionPanelResolver.resolve(target) {
                XCTAssertNotNil(SecondaryActionIntent(handlerID: secondary.handlerID),
                                "unparseable handlerID: \(secondary.handlerID)")
            }
        }
    }
}
