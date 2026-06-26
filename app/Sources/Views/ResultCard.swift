import SwiftUI

// A moment result: real frame thumbnail + filename + location + badges + relevance.
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

            // Tappable location breadcrumb → reveal in Finder.
            Button { ClipExporter.revealInFinder(result.videoURL) } label: {
                HStack(spacing: Space.xs) {
                    Image(systemName: "folder").font(.system(size: 9, weight: .medium))
                    Text(result.prettyPath).font(Typo.caption)
                        .lineLimit(1).truncationMode(.head)
                }
                .foregroundStyle(Color.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Reveal in Finder")

            HStack(spacing: Space.s) {
                ScoreBar(score: result.normalizedScore)
                Text(String(format: "%.0f%%", result.normalizedScore * 100))
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(Color.textTertiary)
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
        .onTapGesture { search.play(result) }
        .onDrag { NSItemProvider(object: result.thumbnail) }
        .contextMenu { menu }
    }

    private var thumbnail: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(nsImage: result.thumbnail)
                .resizable().aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))

            // Hover quick-action bar — monochrome, minimal.
            if hovering {
                HStack(spacing: Space.xs) {
                    chipButton("play.fill") { search.play(result) }
                    chipButton("square.on.square") { search.findSimilar(to: result) }
                    chipButton("scissors") {
                        ClipExporter.exportClip(videoURL: result.videoURL, around: result.timestamp) { _ in }
                    }
                }
                .padding(Space.xs)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.borderSubtle, lineWidth: 1))
                .softShadow(2)
                .padding(Space.s)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            // Timecode + duration badges.
            HStack(spacing: Space.xs) {
                if !result.durationLabel.isEmpty {
                    badge(result.durationLabel, icon: "clock")
                }
                badge(result.timecode, icon: "scope")
            }
            .padding(Space.s)
        }
    }

    private func badge(_ text: String, icon: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 8, weight: .semibold))
            Text(text).font(.system(size: 11, weight: .semibold).monospacedDigit())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(.black.opacity(0.55), in: Capsule())
    }

    private func chipButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var menu: some View {
        Button { search.play(result) } label: { Label("Play at \(result.timecode)", systemImage: "play.fill") }
        Button { search.findSimilar(to: result) } label: { Label("Find Similar Moments", systemImage: "square.on.square") }
        Divider()
        Button { ClipExporter.exportClip(videoURL: result.videoURL, around: result.timestamp) { _ in } } label: {
            Label("Export Clip…", systemImage: "scissors")
        }
        Button { ClipExporter.saveFrame(result.thumbnail, suggestedName: frameName) } label: {
            Label("Save Frame…", systemImage: "photo")
        }
        Button { ClipExporter.copyTimestampLink(videoURL: result.videoURL, seconds: result.timestamp) } label: {
            Label("Copy Timestamp Link", systemImage: "link")
        }
        Divider()
        Button { ClipExporter.revealInFinder(result.videoURL) } label: {
            Label("Reveal in Finder", systemImage: "folder")
        }
    }

    private var frameName: String {
        let base = (result.videoName as NSString).deletingPathExtension
        return "\(base) @ \(result.timecode).png"
    }
}
