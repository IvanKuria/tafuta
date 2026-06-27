import SwiftUI
import AppKit

// Inter is Raycast's typeface. The signature is the `ss03` stylistic set (single-story "g")
// plus contextual alternates — without it, the type reads as "Inter default", not "Raycast".
// SwiftUI has no stylistic-set API, so we build an NSFont with AAT feature settings and bridge
// it to a SwiftUI Font (NSFont is a CTFont).
enum AppFonts {
    static func register() {
        let urls = (Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [])
                 + (Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? [])
        for url in urls { CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil) }
    }

    // Resolve whatever family the registered Inter exposes.
    static let family: String = {
        for name in ["Inter", "Inter Variable", "InterVariable"] where NSFont(name: name, size: 12) != nil {
            return name
        }
        return "Inter"
    }()

    static var available: Bool { NSFont(name: family, size: 12) != nil }
}

extension Font {
    /// Inter at a given size/weight with ss03 + contextual alternates. Falls back to the system
    /// font if Inter didn't register.
    static func inter(_ size: CGFloat, _ weight: NSFont.Weight = .regular) -> Font {
        guard let base = NSFont(name: AppFonts.family, size: size) else {
            return .system(size: size, weight: weight.swiftUI)
        }
        let desc = base.fontDescriptor.addingAttributes([
            .traits: [NSFontDescriptor.TraitKey.weight: weight.rawValue],
            .featureSettings: [
                // AAT: stylistic alternatives type (35), selector 6 = stylistic set 3 ON (ss03)
                [NSFontDescriptor.FeatureKey.typeIdentifier: 35,
                 NSFontDescriptor.FeatureKey.selectorIdentifier: 6],
                // contextual alternates type (36), selector 0 = ON (calt)
                [NSFontDescriptor.FeatureKey.typeIdentifier: 36,
                 NSFontDescriptor.FeatureKey.selectorIdentifier: 0],
            ]
        ])
        let nsFont = NSFont(descriptor: desc, size: size) ?? base
        return Font(nsFont as CTFont)
    }
}

private extension NSFont.Weight {
    var swiftUI: Font.Weight {
        switch self {
        case .bold: return .bold
        case .semibold: return .semibold
        case .medium: return .medium
        case .light: return .light
        default: return .regular
        }
    }
}
