import XCTest
import TermyCore
@testable import Termy

@MainActor
final class TunnelReconnectDispatchTests: XCTestCase {
    private func storeWithOneSession() -> (TermyStore, UUID) {
        let store = TermyStore(startInitialPTY: false)
        return (store, store.sessions.first!.id)
    }

    func testTunnelSessionExitTriggersAutoReconnectWhenEnabled() throws {
        let (store, id) = storeWithOneSession()
        let profile = ConnectionProfile.ssh(
            name: "Production",
            host: "bastion.example.test",
            user: "deploy",
            port: 2222,
            identity: .keychain("ssh.identity.prod")
        )
        let tunnel = try SavedSSHTunnel(
            name: "Prod Web",
            profile: profile,
            tunnels: [.local(localPort: 8080, remoteHost: "127.0.0.1", remotePort: 80)],
            autoReconnect: true
        )
        store.registerTunnelReconnectContext(tunnel: tunnel, profile: profile, for: id)
        store.noteSessionProcessExited(exitCode: 1, for: id)
        // The "Auto-reconnect attempt 1" system line is appended by
        // handleTunnelReconnect BEFORE startSavedTunnel runs, so it is robust
        // even if startSavedTunnel's launchCommand later throws in-test.
        let texts = store.sessions.first { $0.id == id }!.lines.map(\.text)
        XCTAssertTrue(texts.contains { $0.contains("Auto-reconnect attempt 1") },
                      "tunnel-session exit must trigger the reconnect path")
        XCTAssertEqual(texts.filter { $0.hasPrefix("Process exited") }.count, 1,
                       "exit line appended exactly once (no double-append)")
        // launchCommand(profile:) succeeds for this constructible tunnel/profile,
        // so the reconnect reaches startSavedTunnel -> bumpTerminalLaunchGeneration
        // (initial register sets generation 0; sessionID != nil bumps to 1).
        XCTAssertEqual(store.terminalLaunchGeneration(for: id), 1)
    }

    func testTunnelSessionExitDoesNotReconnectWhenDisabled() throws {
        let (store, id) = storeWithOneSession()
        let profile = ConnectionProfile.ssh(
            name: "Production",
            host: "bastion.example.test",
            user: "deploy",
            port: 2222,
            identity: .keychain("ssh.identity.prod")
        )
        let tunnel = try SavedSSHTunnel(
            name: "Prod Web",
            profile: profile,
            tunnels: [.local(localPort: 8080, remoteHost: "127.0.0.1", remotePort: 80)],
            autoReconnect: false
        )
        store.registerTunnelReconnectContext(tunnel: tunnel, profile: profile, for: id)
        store.noteSessionProcessExited(exitCode: 1, for: id)
        let texts = store.sessions.first { $0.id == id }!.lines.map(\.text)
        XCTAssertFalse(texts.contains { $0.contains("Auto-reconnect attempt") },
                       "auto-reconnect disabled -> no reconnect attempt")
        XCTAssertEqual(texts.filter { $0.hasPrefix("Process exited") }.count, 1)
    }
}
