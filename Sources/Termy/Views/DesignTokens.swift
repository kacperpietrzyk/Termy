import AppKit
import SwiftUI
import TermyCore

/// Bridge an OKLCH token to a Display-P3 SwiftUI `Color`.
extension Color {
    init(_ oklch: OKLCH) {
        let p = oklch.displayP3Components()
        self.init(.displayP3, red: p.red, green: p.green, blue: p.blue, opacity: p.alpha)
    }
}

/// The Termy palette — **Raycast v2 "macOS Tahoe" glass** (root `DESIGN.md` +
/// `tokens.json`). A near-neutral charcoal shell, system-blue as the single
/// interactive accent, translucent white fills for selection/controls/hairlines,
/// and color carried only by content/module icons.
///
/// The legacy `bgN` / `fgN` / `hair*` / `primary*` / status-accent names are kept
/// (the existing component set is OKLCH-typed) but their **values** are remapped to
/// the charcoal/blue palette, so every existing view instantly takes the new look.
/// New glass-specific surfaces use the exact-sRGB `Glass` Colors below.
enum DesignTokens {
    /// A status hue in its three roles: solid, chip-background (translucent), border.
    struct Accent {
        let base: OKLCH
        let bg: OKLCH
        let edge: OKLCH
    }

    // MARK: Neutrals (near-neutral charcoal — DESIGN.md surfaces 0–3)
    // OKLCH greys (tiny cool tint) tuned to the glass-deep…overlay ramp; the exact
    // sRGB equivalents live in `Glass` below and are the source of truth for new chrome.
    static let bg0 = OKLCH(l: 0.15,  c: 0.002, h: 285)   // glass-deep   #0d0d0d (deepest recess)
    static let bg1 = OKLCH(l: 0.205, c: 0.002, h: 285)   // glass-base   #161616 (window body)
    static let bg2 = OKLCH(l: 0.255, c: 0.003, h: 285)   // glass-raised #1f1f1f (panels/cards)
    static let bg3 = OKLCH(l: 0.30,  c: 0.003, h: 285)   // glass-overlay#282828 (controls/raised)
    static let bg4 = OKLCH(l: 0.35,  c: 0.004, h: 285)   // hover / elevated
    static let hair       = OKLCH(l: 0.28, c: 0.002, h: 285)   // soft divider
    static let hair2      = OKLCH(l: 0.34, c: 0.003, h: 285)   // border-divider #3a3a3a
    static let hairStrong = OKLCH(l: 0.42, c: 0.004, h: 285)
    static let fg1 = OKLCH(l: 1.0,  c: 0.0,   h: 285)   // text-primary    #ffffff
    static let fg2 = OKLCH(l: 0.90, c: 0.003, h: 285)
    static let fg3 = OKLCH(l: 0.70, c: 0.004, h: 285)   // text-secondary  #9a9a9a
    static let fg4 = OKLCH(l: 0.55, c: 0.004, h: 285)   // text-tertiary   #6e6e6e
    static let fg5 = OKLCH(l: 0.44, c: 0.004, h: 285)   // text-quaternary #545454

    // MARK: Primary (system blue — the single interactive accent; replaces v3 purple)
    static let primary    = OKLCH(l: 0.66, c: 0.15, h: 255)   // accent-blue        #4c8cf5
    static let primary2   = OKLCH(l: 0.72, c: 0.14, h: 255)   // accent-blue-bright #65a1f1
    static let primaryDim = OKLCH(l: 0.46, c: 0.11, h: 255)

    // MARK: Status accents — content punctuation only (status dots, live chips).
    // Per DESIGN.md, content/icons keep their own brand hues; the chrome stays
    // monochrome charcoal + the blue accent.
    static let neutral = Accent(
        base: OKLCH(l: 0.90, c: 0.003, h: 285),
        bg:   OKLCH(l: 0.30, c: 0.004, h: 285, alpha: 0.6),
        edge: OKLCH(l: 0.36, c: 0.004, h: 285))
    static let ai = Accent(
        base: OKLCH(l: 0.66, c: 0.15, h: 255),                 // AI = the blue accent
        bg:   OKLCH(l: 0.40, c: 0.12, h: 255, alpha: 0.20),
        edge: OKLCH(l: 0.52, c: 0.14, h: 255))
    static let agent = Accent(
        base: OKLCH(l: 0.82, c: 0.16, h: 70),                  // amber — "agent waiting"
        bg:   OKLCH(l: 0.40, c: 0.12, h: 70, alpha: 0.20),
        edge: OKLCH(l: 0.52, c: 0.14, h: 70))
    static let git = Accent(
        base: OKLCH(l: 0.72, c: 0.13, h: 250),
        bg:   OKLCH(l: 0.38, c: 0.11, h: 250, alpha: 0.20),
        edge: OKLCH(l: 0.50, c: 0.13, h: 250))
    static let sync = Accent(
        base: OKLCH(l: 0.80, c: 0.15, h: 150),                 // success-green family
        bg:   OKLCH(l: 0.36, c: 0.10, h: 150, alpha: 0.20),
        edge: OKLCH(l: 0.48, c: 0.13, h: 150))
    static let error = Accent(
        base: OKLCH(l: 0.70, c: 0.20, h: 25),                  // brand-red — destructive only
        bg:   OKLCH(l: 0.38, c: 0.14, h: 25, alpha: 0.20),
        edge: OKLCH(l: 0.52, c: 0.16, h: 25))
    static let host = Accent(
        base: OKLCH(l: 0.78, c: 0.13, h: 215),                 // cyan — host/SSH
        bg:   OKLCH(l: 0.36, c: 0.10, h: 215, alpha: 0.20),
        edge: OKLCH(l: 0.48, c: 0.13, h: 215))

    /// Exact-sRGB glass surfaces & translucent fills (root `tokens.json`).
    /// Source of truth for the new chrome (sidebar, window, atoms). The window's
    /// actual translucency is provided by `GlassMaterial` (NSVisualEffectView);
    /// these tints layer on top of it.
    enum Glass {
        static let deep    = Color(hex6: 0x0D0D0D)
        static let base    = Color(hex6: 0x161616)
        static let raised  = Color(hex6: 0x1F1F1F)
        static let overlay = Color(hex6: 0x282828)
        static let divider = Color(hex6: 0x3A3A3A)

        static let fillSelection = Color.white.opacity(0.07)
        static let fillControl   = Color.white.opacity(0.05)
        static let fillChip      = Color.white.opacity(0.08)
        static let hairline      = Color.white.opacity(0.08)
        static let hairlineStrong = Color.white.opacity(0.12)

        static let accent       = Color(hex6: 0x4C8CF5)
        static let accentBright = Color(hex6: 0x65A1F1)
        static let textPrimary    = Color.white
        static let textSecondary  = Color(hex6: 0x9A9A9A)
        static let textTertiary   = Color(hex6: 0x6E6E6E)
        static let textQuaternary = Color(hex6: 0x545454)

        static let brandRed     = Color(hex6: 0xFF6363)   // destructive only
        static let successGreen = Color(hex6: 0x59D499)
        static let warningGold  = Color(hex6: 0xFDE65A)

        /// The single soft ambient drop shadow under floating glass (DESIGN.md
        /// §Elevation: one shadow + one hairline, no bevels).
        static let windowShadow = Color.black.opacity(0.55)
    }

    // MARK: Radii (pt) — DESIGN.md radius scale
    enum Radius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 6     // keycap / chip / icon
        static let md: CGFloat = 10    // selected row / control-ish
        static let control: CGFloat = 8
        static let row: CGFloat = 10
        static let lg: CGFloat = 14
        static let panel: CGFloat = 18
        static let xl: CGFloat = 20
        static let window: CGFloat = 22
        static let xxl: CGFloat = 28
        static let pill: CGFloat = 999
    }

    // MARK: Timing (s) + easing curves
    enum Motion {
        static let micro: Double = 0.14
        static let hero: Double = 0.30
        static let easeOut = Animation.timingCurve(0.22, 1, 0.36, 1, duration: hero)
        static let easeOutSnappy = Animation.timingCurve(0.16, 1.08, 0.30, 1, duration: hero)
        static let easeInOut = Animation.timingCurve(0.65, 0, 0.35, 1, duration: hero)
    }

    // MARK: Shadows — one soft ambient under floating glass; flat hairlines for controls.
    enum Shadow {
        static let cardColor = Color.black.opacity(0.4)
        static let cardRadius: CGFloat = 16
        static let cardY: CGFloat = 8
        static let popColor = Color.black.opacity(0.55)
        static let popRadius: CGFloat = 40
        static let popY: CGFloat = 18
    }
}

extension Color {
    /// Build a Display-P3 `Color` from a 24-bit sRGB hex literal (e.g. `0x4C8CF5`).
    /// Hex tokens are interpreted in the sRGB space then rendered through P3.
    init(hex6: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex6 >> 16) & 0xFF) / 255,
            green: Double((hex6 >> 8) & 0xFF) / 255,
            blue: Double(hex6 & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// Native macOS translucency for the floating-glass window/sidebar (DESIGN.md:
/// "translucent glass" = `NSVisualEffectView` vibrancy, not a flat fill). A
/// persistent window can't bleed the live wallpaper through like a transient HUD,
/// so this is the honest native read of the material; charcoal tints layer on top.
struct GlassMaterial: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .underWindowBackground
    var blending: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blending
        v.state = .active
        v.appearance = NSAppearance(named: .vibrantDark)
        return v
    }

    func updateNSView(_ v: NSVisualEffectView, context: Context) {
        v.material = material
        v.blendingMode = blending
    }
}
