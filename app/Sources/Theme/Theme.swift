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
    static let tag:     CGFloat = 4    // keycap / badge
    static let row:     CGFloat = 6    // command-palette rows
    static let control: CGFloat = 8    // buttons / inputs / tiles / thumbnails
    static let card:    CGFloat = 10
    static let sheet:   CGFloat = 16   // launcher / panels
}

// Native-feeling motion: quick enough for keyboard browsing, with a gentle spring for arrivals.
enum Motion {
    static let quick    = Animation.easeOut(duration: 0.14)
    static let standard = Animation.easeOut(duration: 0.20)
    static let spring    = Animation.spring(response: 0.34, dampingFraction: 0.82)
    static let gentle    = Animation.easeInOut(duration: 0.9)
}

// Type ramp on the platform font. The app should feel at home beside Finder, Photos, and QuickTime.
enum Typo {
    static let title   = Font.title2.weight(.semibold)
    static let title3  = Font.subheadline.weight(.semibold)
    static let body    = Font.callout
    static let callout = Font.callout.weight(.medium)
    static let caption = Font.caption.weight(.medium)
    static let mono    = Font.caption.monospacedDigit().weight(.semibold)
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
