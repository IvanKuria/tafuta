import SwiftUI
import AVKit
import AVFoundation

/// A modal-style video player that plays a local file seeked to a specific
/// timestamp ("jump to the moment"). Built for macOS 14+ with SwiftUI + AVKit.
struct PlayerView: View {
    private let url: URL
    private let startTime: Double
    private let title: String
    private let onClose: () -> Void

    @State private var player: AVPlayer?

    init(url: URL, startTime: Double, title: String, onClose: @escaping () -> Void = {}) {
        self.url = url
        self.startTime = startTime
        self.title = title
        self.onClose = onClose
    }

    var body: some View {
        ZStack(alignment: .top) {
            backgroundColor
                .ignoresSafeArea()

            videoLayer

            header
        }
        .frame(minWidth: 720, minHeight: 480)
        .background(backgroundColor)
        .onAppear(perform: startPlayback)
        .onDisappear(perform: tearDownPlayer)
        // Escape key closes the player.
        .onExitCommand(perform: onClose)
        // Hidden button gives the Escape shortcut a concrete responder as well.
        .background(
            Button(action: onClose) { EmptyView() }
                .keyboardShortcut(.cancelAction)
                .opacity(0)
                .accessibilityHidden(true)
        )
    }

    // MARK: - Subviews

    @ViewBuilder
    private var videoLayer: some View {
        if let player {
            VideoPlayer(player: player)
                .aspectRatio(contentMode: .fit)
        } else {
            ProgressView()
                .controlSize(.large)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(primaryTextColor)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(timecode(from: startTime))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(secondaryTextColor)
            }

            Spacer(minLength: 12)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(primaryTextColor)
            .help("Close")
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Rectangle())
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(borderColor)
                .frame(height: 1)
        }
    }

    // MARK: - Playback lifecycle

    private func startPlayback() {
        guard player == nil else { return }

        let newPlayer = AVPlayer(url: url)
        let target = CMTime(seconds: startTime, preferredTimescale: 600)
        newPlayer.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
            newPlayer.play()
        }
        player = newPlayer
    }

    private func tearDownPlayer() {
        player?.pause()
        player = nil
    }

    // MARK: - Formatting

    private func timecode(from seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    // MARK: - Colors (prefer asset catalog names, fall back gracefully)

    private var backgroundColor: Color { Color("BgCanvas") }
    private var primaryTextColor: Color { Color("TextPrimary") }
    private var secondaryTextColor: Color { Color("TextSecondary") }
    private var borderColor: Color { Color("BorderDefault") }
}

#Preview {
    PlayerView(
        url: URL(fileURLWithPath: "/tmp/sample.mp4"),
        startTime: 92,
        title: "Sample Recording"
    )
}
