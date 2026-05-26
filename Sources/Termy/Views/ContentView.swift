import AppKit
import SwiftUI
import TermyCore

struct ContentView: View {
    @ObservedObject var store: TermyStore

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                TabBarView(store: store)
                StageView(store: store)
                StatusBarView(store: store)
            }
            .background(Color(DesignTokens.bg0))

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

/// Applies the v3 window chrome (DESIGN.md §1) once the SwiftUI window exists:
/// transparent full-size-content title bar, hidden title. Traffic lights stay
/// system-drawn; the tab bar reserves their leading inset.
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
        }
    }

    /// Tracks whether the one-time chrome has been applied (DESIGN.md §1: applied once).
    final class Coordinator { var applied = false }
}
