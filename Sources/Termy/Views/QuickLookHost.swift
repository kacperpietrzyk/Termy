import SwiftUI
import AppKit
import Quartz

/// Native Quick Look bridge for the Files module (M6). SwiftUI has no Quick Look
/// API, so a zero-size `NSView` joins the responder chain and drives the shared
/// `QLPreviewPanel`:
///
/// - The Space key (when this view is the panel controller in the responder
///   chain) toggles the panel — Finder-style.
/// - A `trigger` counter lets SwiftUI ask for a toggle from a button / context
///   menu item ("Quick Look"), a keyboard-free path that does not depend on the
///   responder chain.
///
/// The panel data source returns the single `url` (absolute path under
/// `projectRoot`), keyed off `TermyStore.selectedFileURL` — the same seam a
/// future terminal/editor Quick Look could reuse. Quick Look needs no entitlement
/// here because Termy runs outside the App Sandbox.
struct QuickLookHost: NSViewRepresentable {
    let url: URL?
    /// Monotonic counter; an increment requests a panel toggle.
    let trigger: Int

    func makeNSView(context: Context) -> QuickLookHostView {
        let view = QuickLookHostView()
        view.url = url
        view.lastTrigger = trigger
        return view
    }

    func updateNSView(_ view: QuickLookHostView, context: Context) {
        view.url = url
        if trigger != view.lastTrigger {
            view.lastTrigger = trigger
            view.toggleQuickLook()
        }
        // Keep a live panel's content in sync with the current selection.
        if let panel = QLPreviewPanel.shared(), panel.isVisible, panel.dataSource === view {
            panel.reloadData()
        }
    }
}

/// Backing view: holds the previewed URL, becomes the Quick Look panel controller
/// via the responder chain, and acts as both data source and delegate.
final class QuickLookHostView: NSView, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    var url: URL?
    var lastTrigger = 0

    override var acceptsFirstResponder: Bool { true }

    /// Space toggles Quick Look, matching Finder.
    override func keyDown(with event: NSEvent) {
        if event.charactersIgnoringModifiers == " " {
            toggleQuickLook()
        } else {
            super.keyDown(with: event)
        }
    }

    func toggleQuickLook() {
        guard url != nil, let panel = QLPreviewPanel.shared() else { return }
        if QLPreviewPanel.sharedPreviewPanelExists() && panel.isVisible {
            panel.orderOut(nil)
        } else {
            // Become first responder so the responder chain routes panel control
            // to us, then show the panel.
            window?.makeFirstResponder(self)
            panel.makeKeyAndOrderFront(nil)
        }
    }

    // MARK: - Responder-chain panel control

    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        url != nil
    }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = self
        panel.delegate = self
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        if panel.dataSource === self { panel.dataSource = nil }
        if panel.delegate === self { panel.delegate = nil }
    }

    // MARK: - QLPreviewPanelDataSource

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        url == nil ? 0 : 1
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        url as NSURL?
    }
}
