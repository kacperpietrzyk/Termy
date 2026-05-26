#if canImport(AppKit)
import XCTest
import SwiftTerm
@testable import Termy
import TermyCore

// SLICE 5 TEARDOWN CONTRACT LOCK (inverts the former M3-2 reap-on-dismantle lock).
//
// Contract under lock: SwiftTermTerminalView.dismantleNSView MUST NOT reap the
// child. The PTY is model-owned (TerminalSurfacePool) and survives view teardown
// so terminals persist across tab/session switches. Reaping happens ONLY via
// TerminalSurfaceController.terminateSurface() (called by the store's explicit
// close/restart/self-exit/quit paths). SwiftTerm 1.13.0's LocalProcess has no
// fd-closing deinit, so terminate() remains the sole io.close()+SIGTERM path —
// this test asserts dismantle does NOT call it and terminateSurface() does.
@MainActor
final class SwiftTermTeardownRegressionTests: XCTestCase {
    func testDismantleNSViewDetachesAndTerminateSurfaceReaps() throws {
        let sessionID = UUID()
        let launch: ShellIntegrationLaunch
        do {
            launch = try ShellIntegrationLaunch(profile: .zsh, sessionID: sessionID)
        } catch {
            throw XCTSkip("ShellIntegrationLaunch(.zsh) unavailable in this environment: \(error.localizedDescription)")
        }

        let view = TappedLocalProcessTerminalView(
            frame: CGRect(x: 0, y: 0, width: 800, height: 480))
        let coordinator = SwiftTermTerminalView.Coordinator()   // == TerminalSurfaceController
        coordinator.launch = launch
        coordinator.view = view   // model owns the view (required for terminateSurface to reap)
        // Belt-and-suspenders: always reap so the test process never leaks the
        // child, even if an assertion throws mid-test.
        var reaped = false
        defer { if !reaped { view.terminate(); launch.cleanup() } }

        view.startProcess(
            executable: launch.shellPath,
            args: launch.arguments,
            environment: launch.environmentArray,
            currentDirectory: NSHomeDirectory()
        )
        XCTAssertTrue(view.process.running,
                      "precondition: child must be running before teardown")

        // Exercise the exact SwiftUI teardown entry point.
        SwiftTermTerminalView.dismantleNSView(view, coordinator: coordinator)

        // Slice 5 lock #1: dismantle DETACHES only — the child must SURVIVE so
        // the terminal persists across tab/session switches.
        XCTAssertTrue(view.process.running,
                      "dismantleNSView must NOT reap the child (keep-alive: the PTY is model-owned)")

        // Slice 5 lock #2: terminateSurface() is the sole reaping path now —
        // terminate()->childStopped() flips running synchronously.
        coordinator.terminateSurface()
        reaped = true
        XCTAssertFalse(view.process.running,
                       "terminateSurface() must reap the child (io.close()+SIGTERM)")
    }
}
#endif
