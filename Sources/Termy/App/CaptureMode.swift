import AppKit

/// Dev-only capture mode for parallel visual work (see `script/capture-*.sh`).
///
/// When an AI agent does visual design passes it must build → launch → screenshot →
/// kill repeatedly. By default that yanks focus and pops a window onto the user's
/// desktop, making the machine unusable in parallel. Capture mode instead:
///
///   - launches WITHOUT activating (no focus theft, no Space switch), and
///   - moves the window onto a dedicated off-screen virtual display (a BetterDisplay
///     `VirtualScreen` the user never looks at), and
///   - publishes the window's CGWindowID so `screencapture -l <id>` can grab just the
///     window — no fragile display-index mapping, no desktop margin.
///
/// Entirely gated on `TERMY_CAPTURE_SCREEN`. With that env var unset (every normal
/// run, CI, and shipped builds) this code is inert and the app behaves exactly as before.
enum CaptureMode {
    /// Name of the target `NSScreen` (matches the BetterDisplay virtual screen name).
    /// `nil` → capture mode off; the app launches and activates normally.
    static var targetScreenName: String? {
        let raw = ProcessInfo.processInfo.environment["TERMY_CAPTURE_SCREEN"]
        guard let raw, !raw.isEmpty else { return nil }
        return raw
    }

    static var isActive: Bool { targetScreenName != nil }

    /// Where to publish the window's CGWindowID for the screenshot helper to read.
    private static var windowIDFile: String {
        ProcessInfo.processInfo.environment["TERMY_CAPTURE_WINDOWID_FILE"]
            ?? "/tmp/termy-capture-windowid"
    }

    private static var placementTimer: Timer?

    /// Park the window on the virtual display, then return focus to the user.
    ///
    /// SwiftUI will not materialize its WindowGroup window while the app stays in the
    /// background, and macOS suppresses self-`activate` for a background-launched app —
    /// so capture mode is launched FOREGROUND (`open -n`, which creates the window) and
    /// we immediately (a) move it, alpha-masked, onto the virtual display and (b) hand
    /// focus back to the app the user was in (its bundle id is passed via
    /// `TERMY_CAPTURE_RESTORE_BUNDLE`, captured by the shell BEFORE launch since by the
    /// time we run, Termy is already frontmost). Residual cost: a ~0.2s focus blip at
    /// launch only — no persistent window on the user's display.
    static func activate() {
        guard let name = targetScreenName else { return }
        var ticks = 0
        let timer = Timer(timeInterval: 0.05, repeats: true) { t in
            ticks += 1
            guard targetScreen(name) != nil, let window = captureWindow() else {
                if ticks >= 200 { // ~10s ceiling
                    NSLog("CaptureMode: gave up — screen '\(name)' found="
                        + "\(targetScreen(name) != nil), windows=\(NSApp.windows.count)")
                    t.invalidate()
                }
                return
            }
            move(window, toScreenNamed: name)
            restoreFocusToUser()
            t.invalidate()
        }
        // Keep it firing while no run-loop input source is active in a background app.
        RunLoop.main.add(timer, forMode: .common)
        placementTimer = timer

        // macOS restores the last saved frame (on the main display) on relaunch —
        // re-assert placement whenever the window becomes key (e.g. if Termy is later
        // activated to interact with it).
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { note in
            if let window = note.object as? NSWindow {
                move(window, toScreenNamed: name)
            }
        }
    }

    /// Re-activate the app the user was in before `open -n` foregrounded Termy.
    private static func restoreFocusToUser() {
        guard let bundle = ProcessInfo.processInfo.environment["TERMY_CAPTURE_RESTORE_BUNDLE"],
              !bundle.isEmpty
        else { return }
        NSRunningApplication
            .runningApplications(withBundleIdentifier: bundle)
            .first?
            .activate(options: [])
    }

    private static func targetScreen(_ name: String) -> NSScreen? {
        NSScreen.screens.first { $0.localizedName == name }
    }

    private static func captureWindow() -> NSWindow? {
        // The SwiftUI WindowGroup window: a real content window (not a panel/menu),
        // with a content view and a non-trivial size.
        NSApp.windows.first {
            !($0 is NSPanel)
                && $0.contentView != nil
                && $0.frame.width > 200
                && $0.frame.height > 200
        }
    }

    private static func move(_ window: NSWindow, toScreenNamed name: String) {
        guard let screen = targetScreen(name) else { return }
        window.isRestorable = false
        // Mask any sub-frame flash on the user's display while the window is relocated
        // from its birth position to the virtual screen.
        window.alphaValue = 0
        let visible = screen.visibleFrame
        let size = window.frame.size
        let origin = NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2
        )
        window.setFrameOrigin(origin)
        // orderFront (NOT makeKeyAndOrderFront) shows the window without making the app
        // active/key — so the user's focus on the main display is never disturbed.
        window.orderFront(nil)
        window.alphaValue = 1
        publishWindowID(window)
    }

    private static func publishWindowID(_ window: NSWindow) {
        let id = window.windowNumber
        guard id > 0 else { return }
        try? "\(id)\n".write(toFile: windowIDFile, atomically: true, encoding: .utf8)
    }
}
