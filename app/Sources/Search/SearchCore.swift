import SwiftUI
import AppKit
import Combine

// Shared search engine for the main window and the launcher.
// Real on-device pipeline: pick a folder → index frames (Core ML) → text query → cosine rank.
@MainActor
final class SearchCore: ObservableObject {
    @Published var query: String = ""
    @Published var results: [SearchResult] = []
    @Published var strictness: Double = 0.18      // cosine threshold; ~0.10 noise, ~0.25 strong
    @Published var isIndexing: Bool = false
    @Published var indexedCount: Int = 0
    @Published var statusText: String = ""
    @Published var loadError: String? = nil

    let examples = [
        "a person holding an e-reader",
        "close-up of a screen showing text",
        "a desk with a laptop and monitor",
        "sunset over the ocean",
    ]

    private var frames: [IndexedFrame] = []
    private var queryVector: [Float]?
    private let embedder: Embedder?

    init() {
        do { embedder = try Embedder() }
        catch { embedder = nil; loadError = "Failed to load model: \(error)" }
        // Dev hook: auto-index a folder for testing (set TAFUTA_INDEX_DIR).
        if let dir = ProcessInfo.processInfo.environment["TAFUTA_INDEX_DIR"] {
            indexFolder(URL(fileURLWithPath: (dir as NSString).expandingTildeInPath))
        }
    }

    var hasQuery: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }
    var hasIndex: Bool { !frames.isEmpty }

    // MARK: Folder selection + indexing

    func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Index Folder"
        panel.message = "Choose a folder of videos to index. Everything stays on your Mac."
        if panel.runModal() == .OK, let url = panel.url { indexFolder(url) }
    }

    func indexFolder(_ folder: URL) {
        guard let embedder else { return }
        let videos = VideoIndexer.videoFiles(in: folder)
        guard !videos.isEmpty else { statusText = "No videos found in that folder"; return }

        frames = []
        results = []
        indexedCount = 0
        isIndexing = true
        statusText = "Indexing \(videos.count) videos…"

        Task.detached(priority: .userInitiated) {
            for video in videos {
                var batch: [IndexedFrame] = []
                VideoIndexer.index(video: video, using: embedder) { batch.append($0) }
                let toAdd = batch
                await MainActor.run {
                    self.frames.append(contentsOf: toAdd)
                    self.indexedCount = self.frames.count
                    if self.hasQuery { self.rank() }   // incremental availability
                }
            }
            await MainActor.run {
                self.isIndexing = false
                self.statusText = ""
                if self.hasQuery { self.rank() }
            }
        }
    }

    // MARK: Search

    func runSearch() {
        guard hasQuery, let embedder else { results = []; queryVector = nil; return }
        queryVector = try? embedder.embed(text: query)
        rank()
    }

    func runExample(_ q: String) { query = q; runSearch() }

    private func rank() {
        guard let qv = queryVector else { results = []; return }
        let scored = frames.map { SearchResult(frame: $0, score: Double(Embedder.cosine(qv, $0.vector))) }
        withAnimation(Motion.standard) {
            results = Array(scored.filter { $0.score >= strictness }
                                  .sorted { $0.score > $1.score }
                                  .prefix(60))
        }
    }
}
