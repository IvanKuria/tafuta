import SwiftUI
import AVKit

// AppKit AVPlayerView wrapped for SwiftUI — avoids the SwiftUI `VideoPlayer`
// (_AVKit_SwiftUI) generic-metadata crash, and gives native transport controls.
// Shared by the inline Inspector preview.
struct PlayerSurface: NSViewRepresentable {
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
