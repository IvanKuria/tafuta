import SwiftUI

// A moment result: real frame thumbnail + filename + relevance pill + Finder action.
// Click to play; hover for quick actions; right-click for the full menu; drag the frame out.
struct ResultCard: View {
    @EnvironmentObject var search: SearchCore
    let result: SearchResult
    var selected: Bool = false
    @State private var hovering = false

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
                Button { search.reveal(result) } label: {
                    Pill(text: "Finder", systemImage: "folder")
                }
                .buttonStyle(.plain)
                .help("Reveal in Finder")
            }
        }
        .padding(Space.m)
        .cardStyle(fill: .bgSurface,
                   border: selected ? .brand : (hovering ? .borderStrong : .borderSubtle))
        .overlay {
            if selected {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(Color.brand, lineWidth: 2)
            }
        }
        .softShadow(hovering || selected ? 2 : 0)
        .scaleEffect(hovering ? 1.01 : 1.0)
        .animation(Motion.quick, value: hovering)
        .onHover { hovering = $0 }
        .contentShape(Rectangle())
        .onTapGesture { search.select(result) }
        .onDrag { NSItemProvider(object: result.thumbnail) }
        .contextMenu { menu }
    }

    // Fixed 16:9 frame — overlays must NOT stretch it (use .overlay, not a sizing ZStack).
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
            iconButton("play.fill") { search.select(result); search.playInline() }
            iconButton("square.on.square") { search.findSimilar(to: result) }
            iconButton("scissors") { search.exportClip(result) }
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
        Button { search.select(result) } label: { Label("Show in Inspector", systemImage: "sidebar.right") }
        Button { search.select(result); search.playInline() } label: { Label("Play at \(result.timecode)", systemImage: "play.fill") }
        Button { search.findSimilar(to: result) } label: { Label("Find Similar Moments", systemImage: "square.on.square") }
        Divider()
        Button { search.exportClip(result) } label: { Label("Export Clip…", systemImage: "scissors") }
        Button { search.saveFrame(result) } label: { Label("Save Frame…", systemImage: "photo") }
        Button { search.copyLink(result) } label: { Label("Copy Timestamp Link", systemImage: "link") }
        Divider()
        Button { search.reveal(result) } label: { Label("Reveal in Finder", systemImage: "folder") }
        Button(role: .destructive) { search.removeFromIndex(result) } label: { Label("Remove from Index", systemImage: "trash") }
    }
}
