import SwiftUI
import TermyCore

/// §3 Desktop scene (Tab 0): hero → radial dock → featured cards, over the §3.4
/// layered background. Scrollable so the stack survives the min window height;
/// the background stays fixed behind it.
struct DesktopSceneView: View {
    @ObservedObject var store: TermyStore

    var body: some View {
        // A plain ZStack centers the (compacted, stage-fitting) content reliably
        // — the structure proven correct by the bring-up diagnostic. The dock is
        // sized so hero + dock + cards fit the stage, so there is no overflow to
        // mis-anchor; the scene sits centered over the §3.4 background.
        ZStack {
            DesktopBackground()
            VStack(spacing: 20) {
                DesktopHeroView(store: store)
                RadialDockView(store: store)
                FeaturedCardsView(store: store)
            }
            .padding(.horizontal, 40)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
    }
}

/// DESIGN.md §3.4 — four corner blooms + central calm wash over bg0. (Relocated
/// from the retired `DesktopPlaceholderView`; body unchanged.)
struct DesktopBackground: View {
    var body: some View {
        ZStack {
            Color(DesignTokens.bg0)
            bloom(DesignTokens.Background.violetBloom,  at: .topTrailing,    radius: 760)
            bloom(DesignTokens.Background.blueBloom,     at: .bottomLeading,  radius: 720)
            bloom(DesignTokens.Background.magentaBloom,  at: .topLeading,     radius: 540)
            bloom(DesignTokens.Background.cyanBloom,     at: .bottomTrailing, radius: 600)
            // Central calm wash — dark pull over the middle so content stays readable.
            RadialGradient(colors: [Color(DesignTokens.Background.calmWash), .clear],
                           center: .center, startRadius: 0, endRadius: 520)
        }
    }

    /// A corner-anchored bloom matching `styles.css` §3.4
    /// `radial-gradient(circle <radius> at <corner>, <token>, transparent 65%)`:
    /// the gradient *originates at the corner* (only its inner arc shows) rather
    /// than being a centered gradient nudged toward the corner — the latter put
    /// the brightest point near the stage middle and read far too saturated.
    /// A plain `RadialGradient` fills the container and imposes no min size.
    private func bloom(_ token: OKLCH, at corner: UnitPoint, radius: CGFloat) -> some View {
        RadialGradient(
            gradient: Gradient(stops: [
                .init(color: Color(token), location: 0),
                .init(color: .clear, location: 0.65),
            ]),
            center: corner, startRadius: 0, endRadius: radius
        )
    }
}
