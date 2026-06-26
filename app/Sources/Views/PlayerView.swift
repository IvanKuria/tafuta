import SwiftUI
import AVKit
import AVFoundation

// AppKit AVPlayerView wrapped for SwiftUI — avoids the SwiftUI `VideoPlayer`
// (_AVKit_SwiftUI) generic-metadata crash, and gives native transport controls.
private struct PlayerSurface: NSViewRepresentable {
    let player: AVPlayer
    func makeNSView(context: Context) -> AVPlayerView {
        let v = AVPlayerView()
        v.player = player
        v.controlsStyle = .inline
        v.videoGravity = .resizeAspect
        v.showsFullScreenToggleButton = true
        return v
    }
    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if nsView.player !== player { nsView.player = player }
    }
}

// A modal player that plays a local file seeked to a specific moment.
struct PlayerView: View {
    private let url: URL
    private let startTime: Double
    private let title: String
    private let onClose: () -> Void

    @State private var player: AVPlayer

    init(url: URL, startTime: Double, title: String, onClose: @escaping () -> Void = {}) {
        self.url = url
        self.startTime = startTime
        self.title = title
        self.onClose = onClose
        _player = State(initialValue: AVPlayer(url: url))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            PlayerSurface(player: player)
        }
        .frame(minWidth: 760, minHeight: 500)
        .background(Color.bgCanvas)
        .onAppear {
            let t = CMTime(seconds: startTime, preferredTimescale: 600)
            player.seek(to: t, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                player.play()
            }
        }
        .onDisappear { player.pause() }
        .background(
            Button(action: onClose) { EmptyView() }
                .keyboardShortcut(.cancelAction).opacity(0).accessibilityHidden(true)
        )
    }

    private var header: some View {
        HStack(spacing: Space.s) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.textPrimary).lineLimit(1).truncationMode(.middle)
                Text(timecode).font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer(minLength: Space.m)
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 11, weight: .semibold))
                    .frame(width: 22, height: 22).contentShape(Rectangle())
            }
            .buttonStyle(.plain).foregroundStyle(Color.textSecondary).help("Close")
        }
        .padding(.horizontal, Space.m).padding(.vertical, Space.s)
        .background(Color.bgSurface)
        .overlay(alignment: .bottom) { Divider().overlay(Color.borderSubtle) }
    }

    private var timecode: String {
        let s = max(0, Int(startTime)); return String(format: "%d:%02d", s / 60, s % 60)
    }
}
