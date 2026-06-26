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

    // Cosine ~0.4 is a very strong CLIP match; normalize to 0...1 for display (see docs/PHASE0.md).
    var normalizedScore: Double { min(max(score / 0.4, 0), 1) }

    // Friendly location breadcrumb (Finder-style), not a raw path.
    var prettyPath: String {
        let dir = frame.videoURL.deletingLastPathComponent()
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = dir.path.replacingOccurrences(of: home, with: "~")
        let parts = path.split(separator: "/").map(String.init)
        return parts.count <= 2 ? path : "…/" + parts.suffix(2).joined(separator: "/")
    }

    var durationLabel: String {
        let s = Int(frame.videoDuration)
        return s > 0 ? String(format: "%d:%02d", s / 60, s % 60) : ""
    }
    var dateLabel: String? {
        frame.videoModified.map { $0.formatted(.relative(presentation: .named)) }
    }
}
