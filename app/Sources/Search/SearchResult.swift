import AppKit

// A scored moment: the indexed frame plus its similarity to the current query.
struct SearchResult: Identifiable {
    let id = UUID()
    let frame: IndexedFrame
    let score: Double

    var videoName: String { frame.videoName }
    var videoURL: URL { frame.videoURL }
    var timestamp: Double { frame.timestamp }
    var thumbnail: NSImage { frame.thumbnail }

    var timecode: String {
        String(format: "%d:%02d", Int(timestamp) / 60, Int(timestamp) % 60)
    }
}
