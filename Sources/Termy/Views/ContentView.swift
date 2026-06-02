import AppKit
import SwiftUI
import TermyCore

struct ContentView: View {
    @ObservedObject var store: TermyStore

    var body: some View {
        ZStack {
            // Native translucent glass under the whole window (DESIGN.md), tinted
            // toward glass-base so it reads as near-neutral charcoal.
            GlassMaterial(material: .underWindowBackground).ignoresSafeArea()
            DesignTokens.Glass.base.opacity(0.5).ignoresSafeArea()

            HStack(spacing: 0) {
                SidebarView(store: store)
                VStack(spacing: 0) {
                    StageView(store: store)
                    StatusBarView(store: store)
                }
            }

            if store.isCommandCenterPresented {
                CommandCenterView(store: store)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .background(WindowAccessor())
        .sheet(isPresented: Binding(
            get: { store.activePanel == .ai },
            set: { presented in if !presented { store.activePanel = nil } }
        )) {
            OverlayPanelView(panel: .ai, store: store)
                .frame(minWidth: 520, minHeight: 560)
        }
        .dynamicTypeSize(store.interfaceTextScale.dynamicTypeSize)
    }
}

private extension InterfaceTextScale {
    var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .regular:
            return .medium
        case .large:
            return .large
        case .extraLarge:
            return .xLarge
        }
    }
}

/// Applies the glass window chrome once the SwiftUI window exists: a transparent,
/// full-size-content title bar with the title hidden. Traffic lights stay
/// system-drawn (top-left over the sidebar, which reserves their inset).
struct WindowAccessor: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard !context.coordinator.applied else { return }
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            context.coordinator.applied = true
            window.styleMask.insert(.fullSizeContentView)
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.backgroundColor = .clear
        }
    }

    /// Tracks whether the one-time chrome has been applied.
    final class Coordinator { var applied = false }
}
