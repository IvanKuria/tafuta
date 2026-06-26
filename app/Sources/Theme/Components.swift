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

// Pill / tag. `filled` tints the background with the accent for prominent metadata.
struct Pill: View {
    let text: String
    var systemImage: String? = nil
    var tint: Color = .textSecondary
    var filled: Bool = false
    var body: some View {
        HStack(spacing: Space.xs) {
            if let s = systemImage {
                Image(systemName: s).font(.system(size: 10, weight: .semibold))
            }
            Text(text).font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(filled ? tint : .textSecondary)
        .padding(.horizontal, Space.s)
        .padding(.vertical, 3)
        .background(filled ? tint.opacity(0.14) : Color.bgInset, in: Capsule())
        .overlay(Capsule().strokeBorder(filled ? tint.opacity(0.22) : Color.borderSubtle, lineWidth: 1))
    }
}

// Signature motif: a tinted rounded-square icon chip (the "premium brand-icon" feel).
struct IconChip: View {
    let systemName: String
    var tint: Color = .brand
    var size: CGFloat = 22
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.52, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.16),
                        in: RoundedRectangle(cornerRadius: size * 0.30, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                .strokeBorder(tint.opacity(0.18), lineWidth: 1))
    }
}

// Subtle monochrome shimmer for loading/skeleton states.
struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -1.2
    func body(content: Content) -> some View {
        content.overlay(
            GeometryReader { geo in
                LinearGradient(colors: [.clear, .white.opacity(0.10), .clear],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: phase * geo.size.width)
            }
            .allowsHitTesting(false)
        )
        .mask(content)
        .onAppear {
            withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) { phase = 1.4 }
        }
    }
}

extension View {
    func shimmering() -> some View { modifier(Shimmer()) }
    // Layered, soft shadow for genuinely-floating surfaces (launcher/popovers only).
    func floatingShadow() -> some View {
        shadow(color: .black.opacity(0.20), radius: 24, y: 8)
            .shadow(color: .black.opacity(0.10), radius: 2, y: 1)
    }
}

// Skeleton placeholder card shown while indexing (shimmering loading state).
struct SkeletonCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                .fill(Color.bgInset).aspectRatio(16.0 / 9.0, contentMode: .fit)
            RoundedRectangle(cornerRadius: Radius.tag).fill(Color.bgInset)
                .frame(height: 10).frame(maxWidth: 150, alignment: .leading)
            RoundedRectangle(cornerRadius: Radius.tag).fill(Color.bgInset)
                .frame(height: 6).frame(maxWidth: 90, alignment: .leading)
        }
        .padding(Space.m)
        .cardStyle()
        .shimmering()
    }
}

// Per-item staggered entrance for grid results.
struct StaggeredAppear: ViewModifier {
    let index: Int
    @State private var shown = false
    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 8)
            .onAppear {
                withAnimation(Motion.spring.delay(min(Double(index) * 0.018, 0.28))) { shown = true }
            }
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
