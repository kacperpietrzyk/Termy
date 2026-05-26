import SwiftUI
import TermyCore

/// Bridge an OKLCH token to a Display-P3 SwiftUI `Color`.
extension Color {
    init(_ oklch: OKLCH) {
        let p = oklch.displayP3Components()
        self.init(.displayP3, red: p.red, green: p.green, blue: p.blue, opacity: p.alpha)
    }
}

/// The v3 design palette. OKLCH literals are verbatim from
/// design_handoff_termy_v3/DESIGN.md §2 (the single source of truth) and are
/// resolved to Display-P3 `Color` via `Color(_:)` at use sites.
enum DesignTokens {
    /// A status hue in its three roles: solid, chip-background (translucent), border.
    struct Accent {
        let base: OKLCH
        let bg: OKLCH
        let edge: OKLCH
    }

    // MARK: Neutrals (cool-violet near-black)
    static let bg0 = OKLCH(l: 0.085, c: 0.012, h: 285)
    static let bg1 = OKLCH(l: 0.11,  c: 0.014, h: 285)
    static let bg2 = OKLCH(l: 0.14,  c: 0.016, h: 285)
    static let bg3 = OKLCH(l: 0.17,  c: 0.018, h: 285)
    static let bg4 = OKLCH(l: 0.21,  c: 0.02,  h: 285)
    static let hair       = OKLCH(l: 0.20, c: 0.014, h: 285)
    static let hair2      = OKLCH(l: 0.26, c: 0.016, h: 285)
    static let hairStrong = OKLCH(l: 0.34, c: 0.02,  h: 285)
    static let fg1 = OKLCH(l: 0.98, c: 0.005, h: 285)
    static let fg2 = OKLCH(l: 0.88, c: 0.008, h: 285)
    static let fg3 = OKLCH(l: 0.74, c: 0.012, h: 285)
    static let fg4 = OKLCH(l: 0.54, c: 0.014, h: 285)
    static let fg5 = OKLCH(l: 0.36, c: 0.014, h: 285)

    // MARK: Primary (purple)
    static let primary    = OKLCH(l: 0.72, c: 0.18, h: 295)
    static let primary2   = OKLCH(l: 0.60, c: 0.20, h: 295)
    static let primaryDim = OKLCH(l: 0.40, c: 0.13, h: 295)

    // MARK: Status accents (DESIGN.md §2.2)
    static let neutral = Accent(
        base: OKLCH(l: 0.88, c: 0.008, h: 285),
        bg:   OKLCH(l: 0.28, c: 0.016, h: 285, alpha: 0.5),
        edge: OKLCH(l: 0.34, c: 0.02,  h: 285))
    static let ai = Accent(
        base: OKLCH(l: 0.74, c: 0.18, h: 295),
        bg:   OKLCH(l: 0.35, c: 0.14, h: 295, alpha: 0.22),
        edge: OKLCH(l: 0.48, c: 0.16, h: 295))
    static let agent = Accent(
        base: OKLCH(l: 0.82, c: 0.16, h: 70),
        bg:   OKLCH(l: 0.35, c: 0.12, h: 70, alpha: 0.22),
        edge: OKLCH(l: 0.52, c: 0.14, h: 70))
    static let git = Accent(
        base: OKLCH(l: 0.76, c: 0.14, h: 230),
        bg:   OKLCH(l: 0.34, c: 0.12, h: 230, alpha: 0.22),
        edge: OKLCH(l: 0.48, c: 0.14, h: 230))
    static let sync = Accent(
        base: OKLCH(l: 0.80, c: 0.14, h: 145),
        bg:   OKLCH(l: 0.32, c: 0.10, h: 145, alpha: 0.22),
        edge: OKLCH(l: 0.46, c: 0.13, h: 145))
    static let error = Accent(
        base: OKLCH(l: 0.72, c: 0.20, h: 25),
        bg:   OKLCH(l: 0.34, c: 0.14, h: 25, alpha: 0.22),
        edge: OKLCH(l: 0.50, c: 0.16, h: 25))
    static let host = Accent(
        base: OKLCH(l: 0.78, c: 0.14, h: 200),
        bg:   OKLCH(l: 0.32, c: 0.10, h: 200, alpha: 0.22),
        edge: OKLCH(l: 0.48, c: 0.13, h: 200))

    // MARK: Desktop layered background (DESIGN.md §3.4) — verbatim OKLCH.
    enum Background {
        /// Top-right corner bloom.
        static let violetBloom  = OKLCH(l: 0.48, c: 0.22, h: 295, alpha: 0.55)
        /// Bottom-left corner bloom.
        static let blueBloom    = OKLCH(l: 0.46, c: 0.20, h: 230, alpha: 0.50)
        /// Top-left corner bloom.
        static let magentaBloom = OKLCH(l: 0.42, c: 0.18, h: 325, alpha: 0.28)
        /// Bottom-right corner bloom.
        static let cyanBloom    = OKLCH(l: 0.44, c: 0.18, h: 200, alpha: 0.32)
        /// Central elliptical calm wash — bg0 at 78% (pulls dark over the centre).
        static let calmWash     = OKLCH(l: 0.085, c: 0.012, h: 285, alpha: 0.78)
    }

    // MARK: Radii (pt)
    enum Radius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 14
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 28   // design token r.2xl
    }

    // MARK: Timing (s) + easing curves (DESIGN.md §2.6)
    enum Motion {
        static let micro: Double = 0.14
        static let hero: Double = 0.34
        static let easeOut = Animation.timingCurve(0.22, 1, 0.36, 1, duration: hero)
        static let easeOutSnappy = Animation.timingCurve(0.16, 1.08, 0.30, 1, duration: hero)
        static let easeInOut = Animation.timingCurve(0.65, 0, 0.35, 1, duration: hero)
    }

    // MARK: Shadows (DESIGN.md §2.5) — approximated as single SwiftUI shadows;
    // the two-part originals are layered at use sites where it matters.
    // single-layer approximation: y = midpoint of the two CSS layer offsets,
    // blur ≈ the larger layer halved, opacity ≈ mean of the two layer alphas.
    enum Shadow {
        static let cardColor = Color.black.opacity(0.5)
        static let cardRadius: CGFloat = 12
        static let cardY: CGFloat = 6
        static let popColor = Color.black.opacity(0.6)
        static let popRadius: CGFloat = 30
        static let popY: CGFloat = 18
    }
}
