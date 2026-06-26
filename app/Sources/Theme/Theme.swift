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
    // Brand accent referenced *literally* (indigo), so it ignores the user's system accent
    // override. Use `.brand` for branded elements; `.tint(.brand)` makes native controls match.
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

// Continuous (squircle) radii.
enum Radius {
    static let tag:     CGFloat = 4
    static let control: CGFloat = 6
    static let card:    CGFloat = 8
    static let sheet:   CGFloat = 12
}

// Fast, non-bouncy motion (Linear-style).
enum Motion {
    static let quick    = Animation.easeOut(duration: 0.14)
    static let standard = Animation.easeOut(duration: 0.20)
}
