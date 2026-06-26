import Foundation

// A single retrieval result: a moment (video + timestamp) and its relevance score.
struct SearchResult: Identifiable, Hashable {
    let id = UUID()
    let videoName: String
    let timestamp: Double   // seconds into the video
    let score: Double       // cosine similarity, ~0...0.4 in practice (see docs/PHASE0.md)

    var timecode: String {
        String(format: "%d:%02d", Int(timestamp) / 60, Int(timestamp) % 60)
    }
}
