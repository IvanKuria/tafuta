import SwiftUI

// Card surface: fill + 1px hairline border + continuous radius. No gradients, no heavy shadow.
struct CardStyle: ViewModifier {
    var radius: CGFloat = Radius.card
    var fill: Color = .bgSurface
    var border: Color = .borderDefault
    func body(content: Content) -> some View {
        content
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(border, lineWidth: 1)
            )
    }
}

extension View {
    func cardStyle(radius: CGFloat = Radius.card,
                   fill: Color = .bgSurface,
                   border: Color = .borderDefault) -> some View {
        modifier(CardStyle(radius: radius, fill: fill, border: border))
    }
}

// Quiet, low-contrast status pill (Linear-style tag).
struct Pill: View {
    let text: String
    var systemImage: String? = nil
    var tint: Color = .textSecondary
    var body: some View {
        HStack(spacing: Space.xs) {
            if let s = systemImage {
                Image(systemName: s).font(.system(size: 10, weight: .medium))
            }
            Text(text).font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, Space.s)
        .padding(.vertical, 3)
        .background(Color.bgInset, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.borderSubtle, lineWidth: 1))
    }
}

// Keyboard-shortcut chip (e.g. ⌘K) — quiet, monospaced, hairline.
struct KBD: View {
    let key: String
    var body: some View {
        Text(key)
            .font(.system(size: 11, weight: .medium).monospaced())
            .foregroundStyle(Color.textTertiary)
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(Color.bgInset, in: RoundedRectangle(cornerRadius: Radius.tag, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.tag, style: .continuous)
                .strokeBorder(Color.borderSubtle, lineWidth: 1))
    }
}

// A thin relevance/confidence bar (0...1).
struct ScoreBar: View {
    let score: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.bgInset)
                Capsule().fill(Color.brand)
                    .frame(width: max(2, geo.size.width * CGFloat(min(max(score, 0), 1))))
            }
        }
        .frame(height: 3)
    }
}

// Sleek primary button.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.accentFg)
            .padding(.horizontal, Space.m)
            .padding(.vertical, Space.s)
            .background(Color.brand.opacity(configuration.isPressed ? 0.85 : 1),
                        in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
    }
}
