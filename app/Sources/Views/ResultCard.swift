import SwiftUI

// A single moment result rendered as a pill card: frame thumbnail + filename + timecode + score.
struct ResultCard: View {
    let result: SearchResult
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            // Thumbnail placeholder (Phase 2: the actual frame at this timestamp + hover-scrub).
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .fill(Color.bgInset)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .overlay(
                        Image(systemName: "film")
                            .font(.system(size: 22, weight: .light))
                            .foregroundStyle(Color.textTertiary)
                    )
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
                ScoreBar(score: result.score / 0.4)   // normalize: ~0.4 is a very strong match
                Text(String(format: "%.0f%%", min(result.score / 0.4, 1) * 100))
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .padding(Space.s)
        .cardStyle(fill: .bgSurface,
                   border: hovering ? .borderStrong : .borderSubtle)
        .scaleEffect(hovering ? 1.01 : 1.0)
        .animation(Motion.quick, value: hovering)
        .onHover { hovering = $0 }
    }
}
