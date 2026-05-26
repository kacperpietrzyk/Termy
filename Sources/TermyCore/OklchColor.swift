import Foundation

/// A color expressed in OKLCH (the cylindrical form of Oklab) — the authoritative
/// representation for the v3 design tokens (see design_handoff_termy_v3/DESIGN.md §2).
///
/// Pure value type: no SwiftUI/AppKit, so it lives in Foundation-only `TermyCore`
/// and is unit-testable. Conversion targets **Display P3** because several v3
/// accents (chroma up to 0.20) clip in sRGB.
public struct OKLCH: Equatable, Sendable {
    /// Perceptual lightness, 0...1.
    public let l: Double
    /// Chroma (≈0...0.4 in practice).
    public let c: Double
    /// Hue angle in degrees, 0...360.
    public let h: Double
    /// Alpha, 0...1.
    public let alpha: Double

    public init(l: Double, c: Double, h: Double, alpha: Double = 1) {
        self.l = l
        self.c = c
        self.h = h
        self.alpha = alpha
    }

    /// Gamma-encoded Display-P3 components in 0...1, ready for
    /// `Color(.displayP3, red:green:blue:opacity:)`.
    ///
    /// Pipeline: OKLCH → Oklab → linear LMS → linear sRGB (Björn Ottosson) →
    /// linear Display-P3 (D65 basis change) → clamp → sRGB transfer (P3 shares it).
    public func displayP3Components() -> (red: Double, green: Double, blue: Double, alpha: Double) {
        // 1. OKLCH → Oklab
        let hr = h * .pi / 180
        let a = c * cos(hr)
        let b = c * sin(hr)

        // 2. Oklab → nonlinear LMS → linear LMS
        let lp = l + 0.3963377774 * a + 0.2158037573 * b
        let mp = l - 0.1055613458 * a - 0.0638541728 * b
        let sp = l - 0.0894841775 * a - 1.2914855480 * b
        let lLin = lp * lp * lp
        let mLin = mp * mp * mp
        let sLin = sp * sp * sp

        // 3. linear LMS → linear sRGB
        let rs =  4.0767416621 * lLin - 3.3077115913 * mLin + 0.2309699292 * sLin
        let gs = -1.2684380046 * lLin + 2.6097574011 * mLin - 0.3413193965 * sLin
        let bs = -0.0041960863 * lLin - 0.7034186147 * mLin + 1.7076147010 * sLin

        // 4. linear sRGB → linear Display-P3 (both D65)
        let rp = 0.8224621 * rs + 0.1775380 * gs + 0.0000000 * bs
        let gp = 0.0331941 * rs + 0.9668058 * gs + 0.0000000 * bs
        let bp = 0.0170827 * rs + 0.0723974 * gs + 0.9105199 * bs

        // 5. clamp to gamut, then gamma-encode
        return (Self.encode(rp), Self.encode(gp), Self.encode(bp), alpha)
    }

    /// sRGB transfer function (shared by Display P3) with [0,1] clamp on both ends.
    private static func encode(_ linear: Double) -> Double {
        let v = min(max(linear, 0), 1)
        let e = v <= 0.0031308 ? 12.92 * v : 1.055 * pow(v, 1 / 2.4) - 0.055
        return min(max(e, 0), 1) // belt-and-braces; inner clamp already bounds input
    }
}
