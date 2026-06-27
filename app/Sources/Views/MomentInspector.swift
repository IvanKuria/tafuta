import SwiftUI
import AVKit
import AVFoundation

// Raycast Detail-style inspector for a selected video "moment".
// Surface-color depth, hairlines, Inter, keycaps, no drop shadows on chrome.
struct MomentInspector: View {
    let moment: SearchResult
    @EnvironmentObject var search: SearchCore

    @State private var player = AVPlayer()
    @State private var related: [SearchResult] = []

    var body: some View {
        // No ActionBar here — the single global ActionBar lives at the bottom of the main window
        // and reflects the inspected moment (avoids duplicate Play / ⌘K controls).
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                hero
                title
                metadata
                relatedSection
            }
            .padding(Space.l)
        }
        .task(id: moment.id) {
            let (_, sim) = await search.relatedMoments(to: moment)
            related = sim
        }
    }

    // MARK: - AVPlayer lifecycle

    private func loadCurrentMoment() {
        player.replaceCurrentItem(with: AVPlayerItem(url: moment.videoURL))
        player.seek(to: CMTime(seconds: moment.timestamp, preferredTimescale: 600),
                    toleranceBefore: .zero, toleranceAfter: .zero)
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack {
            if search.isPlayingInline {
                PlayerSurface(player: player)
            } else {
                thumbnailHero
            }
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(Color.borderDefault, lineWidth: 1)
        )
        .onAppear {
            loadCurrentMoment()
            if search.isPlayingInline { player.play() }
        }
        .onChange(of: moment.id) { _, _ in
            loadCurrentMoment()
        }
        .onChange(of: search.isPlayingInline) { _, playing in
            if playing { player.play() } else { player.pause() }
        }
        .onDisappear { player.pause() }
    }

    private var thumbnailHero: some View {
        Image(nsImage: moment.thumbnail)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .clipped()
            .overlay {
                Button { search.playInline() } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 56, weight: .regular))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
            .overlay(alignment: .bottomTrailing) {
                HStack(spacing: Space.xs) {
                    badge(moment.timecode)
                    if !moment.durationLabel.isEmpty { badge(moment.durationLabel) }
                }
                .padding(Space.s)
            }
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(Typo.mono)
            .foregroundStyle(.white)
            .padding(.horizontal, Space.s)
            .padding(.vertical, 3)
            .background(Color.black.opacity(0.55), in: Capsule())
    }

    // MARK: - Title

    private var title: some View {
        Text(moment.videoName)
            .font(Typo.title3)
            .foregroundStyle(Color.textPrimary)
            .lineLimit(2)
    }

    // MARK: - Metadata

    private var metadata: some View {
        DetailMetadata(pairs: [
            ("Location", moment.prettyPath),
            ("Duration", moment.durationLabel),
            ("Timestamp", moment.timecode),
            ("Match", "\(Int(moment.normalizedScore * 100))%")
        ])
    }

    // MARK: - Related

    private var relatedSection: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("RELATED")
                .font(Typo.caption)
                .foregroundStyle(Color.textTertiary)
            VStack(spacing: 0) {
                ForEach(related.prefix(6)) { item in
                    Button { search.inspect(item) } label: {
                        CommandRow(
                            thumbnail: item.thumbnail,
                            icon: nil,
                            title: item.videoName,
                            subtitle: item.timecode,
                            accessories: [],
                            trailingKey: nil,
                            selected: item.id == moment.id
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
