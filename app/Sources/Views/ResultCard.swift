import SwiftUI

// A moment result: real frame thumbnail + filename + timecode + relevance.
// Click to play at the timestamp; right-click for actions; drag the frame out to Finder.
struct ResultCard: View {
    @EnvironmentObject var search: SearchCore
    let result: SearchResult
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            ZStack(alignment: .bottomTrailing) {
                Image(nsImage: result.thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                    .overlay(alignment: .center) {
                        if hovering {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 34))
                                .foregroundStyle(.white.opacity(0.92))
                                .shadow(radius: 6)
                                .transition(.opacity)
                        }
                    }
                Text(result.timecode)
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.black.opacity(0.55), in: Capsule())
                    .padding(Space.s)
            }

            Text(result.videoName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1).truncationMode(.middle)

            HStack(spacing: Space.s) {
                ScoreBar(score: result.normalizedScore)
                Text(String(format: "%.0f%%", result.normalizedScore * 100))
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .padding(Space.m)
        .cardStyle(fill: .bgSurface, border: hovering ? .borderStrong : .borderSubtle)
        .scaleEffect(hovering ? 1.01 : 1.0)
        .animation(Motion.quick, value: hovering)
        .onHover { hovering = $0 }
        .contentShape(Rectangle())
        .onTapGesture { search.play(result) }
        .help("Click to play at \(result.timecode)")
        // Drag the frame image out to Finder / other apps.
        .onDrag { NSItemProvider(object: result.thumbnail) }
        .contextMenu {
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
    }

    private var frameName: String {
        let base = (result.videoName as NSString).deletingPathExtension
        return "\(base) @ \(result.timecode).png"
    }
}
