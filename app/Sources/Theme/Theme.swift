import SwiftUI

// Semantic color tokens — backed by the Asset Catalog (light/dark variants).
// Single source of truth lives in tools/gen_colors.py.
extension Color {
    static let bgCanvas          = Color("BgCanvas")
    static let bgSurface         = Color("BgSurface")
    static let bgSurfaceElevated = Color("BgSurfaceElevated")
    static let bgInset           = Color("BgInset")
    static let borderSubtle      = Color("BorderSubtle")
    static let borderDefault     = Color("BorderDefault")
    static let borderStrong      = Color("BorderStrong")
    static let textPrimary       = Color("TextPrimary")
    static let textSecondary     = Color("TextSecondary")
    static let textTertiary      = Color("TextTertiary")
    static let accentFg          = Color("AccentFg")
    // Near-monochrome graphite accent, referenced literally so it ignores the macOS system
    // accent. Apply `.tint(.brand)` on every scene so no control falls back to system purple.
    static let brand             = Color("AccentColor")
}

// 8px spacing scale.
enum Space {
    static let xxs: CGFloat = 2
    static let xs:  CGFloat = 4
    static let s:   CGFloat = 8
    static let m:   CGFloat = 12
    static let l:   CGFloat = 16
    static let xl:  CGFloat = 24
    static let xxl: CGFloat = 32
}

// Continuous (squircle) radii — one consistent family across the whole app.
// tag = tiny tags; control = fields/buttons/thumbnails; card = result cards; sheet = panels.
enum Radius {
    static let tag:     CGFloat = 6
    static let control: CGFloat = 8
    static let card:    CGFloat = 12
    static let sheet:   CGFloat = 16
}

// Fast, non-bouncy motion + one signature spring for "arrival" moments.
enum Motion {
    static let quick    = Animation.easeOut(duration: 0.14)
    static let standard = Animation.easeOut(duration: 0.20)
    static let spring    = Animation.spring(response: 0.34, dampingFraction: 0.82)
    static let gentle    = Animation.easeInOut(duration: 0.9)
}

// Named type ramp (Apple scale) so views stop hand-rolling sizes.
enum Typo {
    static let title   = Font.system(size: 22, weight: .bold)
    static let title3  = Font.system(size: 15, weight: .semibold)
    static let body    = Font.system(size: 13, weight: .regular)
    static let callout = Font.system(size: 12, weight: .medium)
    static let caption = Font.system(size: 11, weight: .medium)
    static let mono    = Font.system(size: 11, weight: .semibold).monospacedDigit()
}

extension View {
    // Layered macOS shadow: 0 = barely-there rest, 1 = card, 2 = floating.
    @ViewBuilder func softShadow(_ level: Int = 1) -> some View {
        switch level {
        case 0: shadow(color: .black.opacity(0.05), radius: 1, y: 0.5)
        case 2: self.shadow(color: .black.opacity(0.18), radius: 22, y: 8)
                    .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
        default: self.shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                     .shadow(color: .black.opacity(0.04), radius: 1, y: 0.5)
        }
    }
}
