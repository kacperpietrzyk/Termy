#if canImport(AppKit)
import AppKit
import SwiftTerm
import TermyCore

/// Slice 5: the model-owned owner of one live terminal surface. Promoted from
/// `SwiftTermTerminalView.Coordinator`. The pool retains the controller; the
/// controller strongly retains its `view`; the view's `processDelegate` is a
/// WEAK back-reference to the controller (`MacLocalTerminalView.swift:92`) — so
/// there is no cycle, and the controller (hence the delegate) outlives any
/// single SwiftUI mount. That is what lets a session that exits *while its view
/// is unmounted* still deliver `processTerminated`.
final class TerminalSurfaceController: NSObject, LocalProcessTerminalViewDelegate, PooledSurface {
    /// Strong: the model owns the live view across mounts.
    var view: TappedLocalProcessTerminalView?
    /// The ZDOTDIR temp dir lifetime; freed in `terminateSurface()` (NOT in
    /// `dismantleNSView` — it must survive remounts).
    var launch: ShellIntegrationLaunch?
    /// One-shot focus guard. RESET to false on reuse (`makeNSView`) so the
    /// cached view re-acquires first-responder on its new host.
    var didFocus = false
    var callbacks: (title: (String) -> Void, dir: (String) -> Void, exit: (Int32?) -> Void)?

    /// Set the instant SwiftTerm reports the child gone, BEFORE forwarding the
    /// exit callback — so a subsequent `terminateSurface()` won't re-`kill` a
    /// dead (possibly recycled) pid.
    private(set) var processIsDead = false

    // MARK: PooledSurface
    func terminateSurface() {
        if !processIsDead { view?.terminate() }   // io.close() + SIGTERM + reap
        launch?.cleanup()                          // remove the ZDOTDIR temp dir (idempotent)
        launch = nil
        view = nil
    }

    // MARK: LocalProcessTerminalViewDelegate
    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        callbacks?.title(title)
    }
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        if let directory { callbacks?.dir(directory) }
    }
    func processTerminated(source: TerminalView, exitCode: Int32?) {
        processIsDead = true
        callbacks?.exit(exitCode)
    }
}
#endif
