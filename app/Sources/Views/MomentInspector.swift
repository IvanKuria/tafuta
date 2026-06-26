import SwiftUI
import AVKit
import AVFoundation

// Native Inspector slide-out preview for a selected video "moment".
// Monochrome + single blue accent, pills for metadata, soft shadows on floating layers only.
struct MomentInspector: View {
    let moment: SearchResult
    @EnvironmentObject var search: SearchCore

    @State private var player = AVPlayer()
    @State private var sameVideo: [SearchResult] = []
    @State private var similarMoments: [SearchResult] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                hero
                titleBlock
                actionBar
                rail(title: "More from this video", items: sameVideo)
                rail(title: "Similar moments", items: similarMoments)
            }
            .padding(Space.l)
        }
        .task(id: moment.id) {
            sameVideo = search.sameVideo(of: moment)
            similarMoments = search.similar(to: moment)
        }
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
        .background(Color.bgInset)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(Color.borderSubtle, lineWidth: 1)
        )
    }

    private var thumbnailHero: some View {
        GeometryReader { geo in
            Image(nsImage: moment.thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
                .overlay(
                    Button { search.playInline() } label: {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 56, weight: .regular))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white)
                            .softShadow(2)
                    }
                    .buttonStyle(.plain)
                )
                .overlay(alignment: .bottomTrailing) {
                    HStack(spacing: Space.xs) {
                        badge(moment.timecode)
                        if !moment.durationLabel.isEmpty { badge(moment.durationLabel) }
                    }
                    .padding(Space.s)
                }
        }
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(Typo.mono)
            .foregroundStyle(.white)
            .padding(.horizontal, Space.s)
            .padding(.vertical, 3)
            .background(Color.black.opacity(0.6), in: Capsule())
    }

    // MARK: - Title

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(moment.videoName)
                .font(Typo.title3)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(2)
            Button { search.reveal(moment) } label: {
                HStack(spacing: Space.xs) {
                    Image(systemName: "folder")
                    Text(moment.prettyPath)
                }
                .font(Typo.caption)
                .foregroundStyle(Color.textTertiary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Action bar

    private var actionBar: some View {
        HStack(spacing: Space.m) {
            actionButton("play.fill", help: "Play / pause") { search.togglePlayInline() }
            actionButton("square.on.square", help: "Find similar moments") { search.findSimilar(to: moment) }
            actionButton("scissors", help: "Export clip") { search.exportClip(moment) }
            actionButton("photo", help: "Save frame") { search.saveFrame(moment) }
            actionButton("link", help: "Copy timestamp link") { search.copyLink(moment) }
            actionButton("folder", help: "Reveal in Finder") { search.reveal(moment) }
            actionButton("trash", help: "Remove from index", tint: .red) { search.removeFromIndex(moment) }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Space.l)
        .padding(.vertical, Space.s)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.borderSubtle, lineWidth: 1))
        .softShadow(2)
    }

    private func actionButton(_ symbol: String,
                              help: String,
                              tint: Color = .textPrimary,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    // MARK: - Related rails

    @ViewBuilder
    private func rail(title: String, items: [SearchResult]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: Space.s) {
                Text(title.uppercased())
                    .font(Typo.caption)
                    .tracking(0.6)
                    .foregroundStyle(Color.textTertiary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.s) {
                        ForEach(items) { item in
                            railItem(item)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func railItem(_ item: SearchResult) -> some View {
        let isCurrent = item.id == moment.id
        return Button { search.inspect(item) } label: {
            Image(nsImage: item.thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 120, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    Text(item.timecode)
                        .font(Typo.mono)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.6), in: Capsule())
                        .padding(Space.xs)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                        .strokeBorder(isCurrent ? Color.brand : Color.borderSubtle,
                                      lineWidth: isCurrent ? 2 : 1)
                )
        }
        .buttonStyle(.plain)
    }
}
