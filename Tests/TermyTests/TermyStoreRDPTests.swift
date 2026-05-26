import XCTest
@testable import Termy
import TermyCore
import TermyRDP

/// Post-Task-6 reduction: the previous bespoke-probe-driven suite injected a
/// `RDPLiveConnectionBootstrap` fake (now deleted) and asserted protocol-PDU
/// wire bytes flowed through the read loop. After the FreeRDP cutover, that
/// machinery is gone — the on-the-wire protocol is owned by FreeRDP and the
/// PDU-codec tests live in upstream FreeRDP, not here. What survives is the
/// engine-agnostic TermyStore behaviour: the disconnect→reconnect-notification
/// scheduler. (See umbrella §5 conscious test-count reset.)
///
/// The injected `rdpConnect` deliberately throws (after the dispatch happens)
/// to keep the test off the live FreeRDP path — a real `FreeRDPSession.start`
/// would block in `ctermyrdp_connect` doing a TCP/TLS handshake against the
/// (intentionally invalid) test host. The error fans out through the store's
/// `failLiveRDPConnection` path, which is its own resilience contract.
private struct StubRDPConnectError: Error {}

final class TermyStoreRDPTests: XCTestCase {
    @MainActor
    func testRDPDisconnectSchedulesNativeReconnectNotification() throws {
        let profile = ConnectionProfile.rdp(
            name: "Windows",
            host: "win.example.test",
            user: "kacper",
            gateway: nil,
            credential: .keychain("rdp-secret")
        )
        var notifications: [RemoteSessionNotification] = []
        let store = TermyStore(
            startInitialPTY: false,
            remoteNotificationSink: { notifications.append($0) },
            rdpConnect: { _ in throw StubRDPConnectError() }
        )
        store.rdpWidth = "2"
        store.rdpHeight = "1"

        store.openRDPSession(profile)
        let sessionID = try XCTUnwrap(store.selectedSessionID)

        _ = store.handleRDPTransportEvent(.disconnected(.networkFailure), for: sessionID)

        XCTAssertEqual(notifications, [
            .rdpReconnectScheduled(profileName: "Windows", attempt: 1, delaySeconds: 5)
        ])
    }
}
