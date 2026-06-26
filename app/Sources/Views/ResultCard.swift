import SwiftUI

// A moment result card. Takes plain values + action closures (no @EnvironmentObject), and is
// Equatable on (id, selected) so changing the grid selection only re-renders the two affected
// cards — not all of them. This is the main fix for the janky inspector-open animation.
struct ResultCard: View, Equatable {
    let result: SearchResult
    var selected: Bool = false
    var onSelect: () -> Void = {}
    var onPlay: () -> Void = {}
    var onFindSimilar: () -> Void = {}
    var onExport: () -> Void = {}
    var onSaveFrame: () -> Void = {}
    var onCopyLink: () -> Void = {}
    var onReveal: () -> Void = {}
    var onRemove: () -> Void = {}

    @State private var hovering = false

    static func == (l: ResultCard, r: ResultCard) -> Bool {
        l.result.id == r.result.id && l.selected == r.selected
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            thumbnail

            Text(result.videoName)
                .font(Typo.callout)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1).truncationMode(.middle)

            HStack(spacing: Space.xs) {
                Pill(text: "\(Int(result.normalizedScore * 100))% match", tint: .brand, filled: true)
                Spacer(minLength: 0)
                Button(action: onReveal) { Pill(text: "Finder", systemImage: "folder") }
                    .buttonStyle(.plain).help("Reveal in Finder")
            }
        }
        .padding(Space.m)
        .cardStyle(fill: .bgSurface,
                   border: selected ? .brand : (hovering ? .borderStrong : .borderDefault))
        .overlay {
            if selected {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(Color.brand, lineWidth: 2)
            }
        }
        .softShadow(hovering || selected ? 2 : 1)
        .scaleEffect(hovering ? 1.01 : 1.0)
        .animation(Motion.quick, value: hovering)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(perform: onSelect)
        .onDrag { NSItemProvider(object: result.thumbnail) }
        .contextMenu { menu }
    }

    private var thumbnail: some View {
        Image(nsImage: result.thumbnail)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(maxWidth: .infinity)
            .frame(height: 132)
            .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            .overlay(alignment: .topLeading) {
                if hovering { hoverActions.padding(Space.s) }
            }
            .overlay(alignment: .bottomTrailing) {
                HStack(spacing: Space.xs) {
                    if !result.durationLabel.isEmpty { badge(result.durationLabel, "clock") }
                    badge(result.timecode, "scope")
                }
                .padding(Space.s)
            }
    }

    private var hoverActions: some View {
        HStack(spacing: 2) {
            iconButton("play.fill", action: onPlay)
            iconButton("square.on.square", action: onFindSimilar)
            iconButton("scissors", action: onExport)
        }
        .padding(3)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.borderSubtle, lineWidth: 1))
        .softShadow(2)
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }

    private func badge(_ text: String, _ icon: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 8, weight: .semibold))
            Text(text).font(.system(size: 11, weight: .semibold).monospacedDigit())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(.black.opacity(0.6), in: Capsule())
    }

    private func iconButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
                .frame(width: 26, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var menu: some View {
        Button(action: onSelect) { Label("Show Details", systemImage: "sidebar.right") }
        Button(action: onPlay) { Label("Play at \(result.timecode)", systemImage: "play.fill") }
        Button(action: onFindSimilar) { Label("Find Similar Moments", systemImage: "square.on.square") }
        Divider()
        Button(action: onExport) { Label("Export Clip…", systemImage: "scissors") }
        Button(action: onSaveFrame) { Label("Save Frame…", systemImage: "photo") }
        Button(action: onCopyLink) { Label("Copy Timestamp Link", systemImage: "link") }
        Divider()
        Button(action: onReveal) { Label("Reveal in Finder", systemImage: "folder") }
        Button(role: .destructive, action: onRemove) { Label("Remove", systemImage: "trash") }
    }
}
