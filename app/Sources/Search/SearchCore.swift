import SwiftUI
import Combine

// Shared search engine driving both the main window and the launcher.
// Phase 1: a stub seeded with the verified Phase 0 spike results so the UI renders
// realistic data. Phase 2 replaces `runSearch` with the real Core ML + sqlite-vec pipeline.
@MainActor
final class SearchCore: ObservableObject {
    @Published var query: String = ""
    @Published var results: [SearchResult] = []
    @Published var strictness: Double = 0.18      // cosine threshold; ~0.10 noise, ~0.25 strong
    @Published var isIndexing: Bool = false
    @Published var indexedCount: Int = 431
    @Published var totalCount: Int = 431

    // Mock corpus mirroring docs/PHASE0.md (real retrieval scores on real footage).
    private let corpus: [SearchResult] = [
        .init(videoName: "The Xteink X4 After 3 Months.mp4", timestamp: 173, score: 0.297),
        .init(videoName: "The Xteink X4 After 3 Months.mp4", timestamp: 177, score: 0.293),
        .init(videoName: "The Xteink X4 After 3 Months.mp4", timestamp: 168, score: 0.280),
        .init(videoName: "The Xteink X4 After 3 Months.mp4", timestamp: 143, score: 0.248),
        .init(videoName: "My Aesthetic Mac Setup.mp4",        timestamp: 132, score: 0.217),
        .init(videoName: "My Aesthetic Mac Setup.mp4",        timestamp: 136, score: 0.210),
        .init(videoName: "IMG_1879.MOV",                      timestamp: 5,   score: 0.269),
        .init(videoName: "letterboxd-promo.mp4",              timestamp: 18,  score: 0.154),
    ]

    var hasQuery: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }

    // Suggested example queries shown in the empty state (teaches the natural-language model).
    let examples = [
        "a person holding an e-reader",
        "close-up of a screen showing text",
        "a desk with a laptop and monitor",
        "sunset over the ocean",
    ]

    func runSearch() {
        guard hasQuery else { results = []; return }
        // Stub ranking: filter the corpus by the strictness threshold. The real engine
        // (Phase 2) will embed `query` with MobileCLIP and rank actual frame vectors.
        withAnimation(Motion.standard) {
            results = corpus
                .filter { $0.score >= strictness }
                .sorted { $0.score > $1.score }
        }
    }

    func runExample(_ q: String) {
        query = q
        runSearch()
    }
}
