import Foundation
import Observation
// canImport(Sparkle) is always true (both Termy and TermyTests link Sparkle).
// The guards are defensive for a hypothetical future Sparkle-free build variant.
#if canImport(Sparkle)
import Sparkle
#endif

/// Update-domain controller (M4) — replaces the bespoke `UpdateModel`.
/// All access goes through the `UpdaterDriving` seam so unit tests never
/// construct a real `SPUStandardUpdaterController` (needs a host bundle).
/// The app swaps in the live Sparkle driver at launch via
/// `activateLiveUpdater()`; until then a harmless in-memory driver backs it.
@MainActor
protocol UpdaterDriving: AnyObject {
    var canCheckForUpdates: Bool { get }
    var automaticallyChecksForUpdates: Bool { get set }
    func checkForUpdates()
}

/// Default driver: no Sparkle, no host bundle, no network. Used by
/// `AppModel`/tests so constructing app state is side-effect free.
@MainActor
final class InMemoryUpdaterDriver: UpdaterDriving {
    var canCheckForUpdates = true
    var automaticallyChecksForUpdates = false
    func checkForUpdates() {}
}

@MainActor
// @Observable is kept for future stored state. The current properties are
// driver-forwarded computed values with NO stored backing, so SwiftUI does
// NOT observe them — consumers needing reactivity use an explicit Binding
// (see SettingsView toggle, M4 Task 4) or read them in a recomputed body.
@Observable
final class SparkleUpdateController {
    @ObservationIgnored private var driver: UpdaterDriving

    /// True once the live Sparkle updater has been activated. Stays false in
    /// dev/unsigned builds (no SUFeedURL), which keeps "Check for Updates…"
    /// disabled and prevents the launch-time SUNoFeedURLError alert.
    private(set) var isLiveUpdaterActive = false

    /// Designated init — accepts any `UpdaterDriving` driver (tests pass a fake).
    init(driver: UpdaterDriving) {
        self.driver = driver
    }

    /// Convenience init — uses the harmless in-memory driver (app default / test default).
    /// Split from `init(driver:)` so the default driver is NOT an init default
    /// argument — a @MainActor-isolated `InMemoryUpdaterDriver()` cannot be
    /// evaluated as a default-arg expression (non-isolated context). Do not
    /// re-merge into `init(driver: UpdaterDriving = InMemoryUpdaterDriver())`.
    convenience init() {
        self.init(driver: InMemoryUpdaterDriver())
    }

    /// Whether the running bundle is configured for updates. Dev/unsigned builds
    /// (`build_and_run.sh`) write no `SUFeedURL`, so this is false and the live
    /// updater is never started. Release builds (`package_dmg.sh` with
    /// `UPDATE_FEED_URL`) carry it. `nonisolated` so it is usable as a default
    /// argument from the @MainActor call site.
    nonisolated static var bundleHasFeedURL: Bool {
        Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil
    }

    var canCheckForUpdates: Bool { driver.canCheckForUpdates }

    var automaticallyChecksForUpdates: Bool {
        get { driver.automaticallyChecksForUpdates }
        set { driver.automaticallyChecksForUpdates = newValue }
    }

    func checkForUpdates() { driver.checkForUpdates() }

    /// App-only: replace the in-memory driver with the live Sparkle updater.
    /// No-ops unless the bundle carries an `SUFeedURL` (release builds only), so
    /// an unconfigured dev build never constructs `SPUStandardUpdaterController`
    /// (which would fail with SUNoFeedURLError and alert on launch). Guarded so a
    /// second call is a no-op — without it, a second call would construct a
    /// redundant updater and start a second update cycle.
    func activateLiveUpdater(feedConfigured: Bool = SparkleUpdateController.bundleHasFeedURL) {
        guard feedConfigured else { return }
        guard driver is InMemoryUpdaterDriver else { return }
        #if canImport(Sparkle)
        driver = SparkleUpdaterDriver()
        isLiveUpdaterActive = true
        #endif
    }
}

#if canImport(Sparkle)
@MainActor
final class SparkleUpdaterDriver: UpdaterDriving {
    private let controller: SPUStandardUpdaterController

    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var canCheckForUpdates: Bool { controller.updater.canCheckForUpdates }

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    func checkForUpdates() { controller.checkForUpdates(nil) }
}
#endif
