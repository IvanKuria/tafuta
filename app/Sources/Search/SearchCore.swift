import SwiftUI
import AppKit
import Combine

// A group of results that all come from the same source video (for grouped grid view).
struct ResultGroup: Identifiable {
    let id: String          // standardized video path
    let videoURL: URL
    let name: String
    let items: [SearchResult]
}

enum Grouping: String { case grouped, flat }

// Shared search engine for the main window and the launcher.
// On-device pipeline: index frames (Core ML) → text query → cosine rank → preview in Inspector.
@MainActor
final class SearchCore: ObservableObject {
    @Published var query: String = ""
    @Published var results: [SearchResult] = []
    @Published var strictness: Double = 0.18           // cosine threshold; ~0.10 noise, ~0.25 strong
    @Published var isIndexing: Bool = false
    @Published var indexedCount: Int = 0
    @Published var statusText: String = ""
    @Published var loadError: String? = nil

    // Inspector preview (replaces the old modal player).
    @Published var inspectorMoment: SearchResult? = nil
    @Published var isPlayingInline: Bool = false

    @Published var similarLabel: String? = nil         // banner for image-similarity mode
    @Published var selectedID: SearchResult.ID? = nil  // keyboard-nav cursor + grid ring

    // Grouping
    @Published var grouping: Grouping = .grouped
    @Published var collapsedVideos: Set<String> = []

    // Toast
    @Published var toast: Toast? = nil

    @Published private(set) var recentSearches: [String] =
        UserDefaults.standard.stringArray(forKey: "tafuta.recents") ?? []

    let examples = [
        "a person holding an e-reader",
        "close-up of a screen showing text",
        "a desk with a laptop and monitor",
        "sunset over the ocean",
    ]

    private var frames: [IndexedFrame] = []
    private var indexedVideoPaths = Set<String>()
    private var queryVector: [Float]?
    private let embedder: Embedder?

    init() {
        do { embedder = try Embedder() }
        catch { embedder = nil; loadError = "Failed to load model: \(error)" }
        for folder in FolderBookmarks.savedFolders() { indexFolder(folder, remember: false) }
        if let dir = ProcessInfo.processInfo.environment["TAFUTA_INDEX_DIR"] {
            indexFolder(URL(fileURLWithPath: (dir as NSString).expandingTildeInPath))
        }
    }

    var hasQuery: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }
    var hasIndex: Bool { !frames.isEmpty }
    var hasResults: Bool { !results.isEmpty }

    // MARK: - Indexing

    func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Add Videos"
        panel.message = "Choose a folder of videos to search. Everything stays on your Mac."
        if panel.runModal() == .OK, let url = panel.url { indexFolder(url, remember: true) }
    }

    func indexFolder(_ folder: URL, remember: Bool = true) {
        if remember { FolderBookmarks.save(folder) }
        let videos = VideoIndexer.videoFiles(in: folder)
            .filter { !indexedVideoPaths.contains($0.standardizedFileURL.path) }
        ingest(videos)
    }

    /// Drag-and-drop entry: accepts folders and video files.
    func indexURLs(_ urls: [URL]) {
        var loose: [URL] = []
        for url in urls {
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { continue }
            if isDir.boolValue {
                indexFolder(url, remember: true)
            } else if VideoIndexer.videoExtensions.contains(url.pathExtension.lowercased()) {
                loose.append(url)
                FolderBookmarks.save(url.deletingLastPathComponent())
            }
        }
        let fresh = loose.filter { !indexedVideoPaths.contains($0.standardizedFileURL.path) }
        if !fresh.isEmpty { ingest(fresh) }
    }

    /// Shared indexing worker: cache-hit or embed, then append on the main actor.
    private func ingest(_ videos: [URL]) {
        guard let embedder, !videos.isEmpty else { return }
        isIndexing = true
        statusText = "Indexing \(videos.count) videos…"
        showToast("Indexing \(videos.count) video\(videos.count == 1 ? "" : "s")…", "arrow.triangle.2.circlepath")

        Task.detached(priority: .userInitiated) {
            for video in videos {
                let cached = IndexStore.load(for: video)
                var batch: [IndexedFrame] = cached ?? []
                if cached == nil {
                    VideoIndexer.index(video: video, using: embedder) { batch.append($0) }
                    IndexStore.save(batch, for: video)
                }
                let toAdd = batch
                let path = video.standardizedFileURL.path
                await MainActor.run {
                    guard !self.indexedVideoPaths.contains(path) else { return }
                    self.indexedVideoPaths.insert(path)
                    self.frames.append(contentsOf: toAdd)
                    self.indexedCount = self.frames.count
                    if self.hasQuery || self.similarLabel != nil { self.rank() }
                }
            }
            await MainActor.run { self.isIndexing = false; self.statusText = "" ; if self.hasQuery { self.rank() } }
        }
    }

    // MARK: - Search

    func runSearch() {
        similarLabel = nil
        inspectorMoment = nil            // a fresh search closes the preview
        guard hasQuery, let embedder else { results = []; queryVector = nil; selectedID = nil; return }
        queryVector = try? embedder.embed(text: query)
        rank()
    }

    func runExample(_ q: String) { query = q; runSearch() }

    private func rank() {
        guard let qv = queryVector else { results = []; selectedID = nil; return }
        let scored = frames.map { SearchResult(frame: $0, score: Double(Embedder.cosine(qv, $0.vector))) }
        let ranked = Array(scored.filter { $0.score >= strictness }
                                 .sorted { $0.score > $1.score }
                                 .prefix(60))
        withAnimation(Motion.standard) { results = ranked }
        selectedID = ranked.first?.id
        if !ranked.isEmpty, hasQuery { addRecent(query) }
    }

    // MARK: - Selection & Inspector

    func select(_ r: SearchResult) { selectedID = r.id; inspectorMoment = r; isPlayingInline = false }

    func inspect(_ r: SearchResult) {
        inspectorMoment = r
        isPlayingInline = false
        if results.contains(where: { $0.id == r.id }) { selectedID = r.id }
    }

    func toggleInspector() {
        if inspectorMoment == nil {
            if let id = selectedID, let r = results.first(where: { $0.id == id }) { inspectorMoment = r }
            else { inspectorMoment = results.first }
            isPlayingInline = false
        } else { inspectorMoment = nil }
    }

    func closeInspector() { inspectorMoment = nil; isPlayingInline = false }
    func playInline() { isPlayingInline = true }
    func togglePlayInline() { isPlayingInline.toggle() }

    /// Image-to-image: rank by similarity to a chosen frame; keeps the inspector open.
    func findSimilar(to r: SearchResult) {
        query = ""
        queryVector = r.frame.vector
        similarLabel = "Similar to \(r.videoName) @ \(r.timecode)"
        rank()
        inspect(r)
    }

    // MARK: - Related moments (over the full frame set)

    private struct FrameSnap: Sendable {
        let id: UUID; let vector: [Float]; let videoPath: String; let timestamp: Double
    }

    /// Related moments computed OFF the main thread (cosine over all frames), so opening the
    /// inspector stays smooth. Returns (same video, visually similar).
    func relatedMoments(to r: SearchResult, limit: Int = 12) async -> (same: [SearchResult], similar: [SearchResult]) {
        let targetVec = r.frame.vector
        let targetID = r.frame.id
        let targetVideo = r.videoURL.standardizedFileURL.path
        let qv = queryVector
        let snaps = frames.map {
            FrameSnap(id: $0.id, vector: $0.vector,
                      videoPath: $0.videoURL.standardizedFileURL.path, timestamp: $0.timestamp)
        }
        let (sameIDs, simIDs) = await Task.detached(priority: .userInitiated) { () -> ([UUID], [UUID]) in
            let same = snaps.filter { $0.videoPath == targetVideo && $0.id != targetID }
                .sorted { $0.timestamp < $1.timestamp }.prefix(limit).map(\.id)
            let sim = snaps.filter { $0.id != targetID }
                .map { ($0.id, Embedder.cosine(targetVec, $0.vector)) }
                .sorted { $0.1 > $1.1 }.prefix(limit).map(\.0)
            return (Array(same), Array(sim))
        }.value
        let byID = Dictionary(frames.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        func toResult(_ id: UUID) -> SearchResult? {
            guard let f = byID[id] else { return nil }
            let s = qv.map { Double(Embedder.cosine($0, f.vector)) } ?? 0
            return SearchResult(frame: f, score: s)
        }
        return (sameIDs.compactMap(toResult), simIDs.compactMap(toResult))
    }

    func removeFromIndex(_ r: SearchResult) {
        frames.removeAll { $0.id == r.frame.id }
        withAnimation(Motion.standard) { results.removeAll { $0.frame.id == r.frame.id } }
        indexedCount = frames.count
        if selectedID == r.id { selectedID = results.first?.id }
        if inspectorMoment?.id == r.id { inspectorMoment = results.first(where: { $0.id == selectedID }) }
        showToast("Removed from index", "trash", .destructive)
    }

    // MARK: - Grouping

    var groupedResults: [ResultGroup] {
        var order: [String] = []
        var buckets: [String: (URL, String, [SearchResult])] = [:]
        for r in results {
            let key = r.videoURL.standardizedFileURL.path
            if buckets[key] == nil { buckets[key] = (r.videoURL, r.videoName, []); order.append(key) }
            buckets[key]!.2.append(r)
        }
        return order.map { ResultGroup(id: $0, videoURL: buckets[$0]!.0, name: buckets[$0]!.1, items: buckets[$0]!.2) }
    }

    /// Flattened visible order for keyboard nav (skips collapsed sections).
    var navigationOrder: [SearchResult] {
        grouping == .flat ? results
            : groupedResults.filter { !collapsedVideos.contains($0.id) }.flatMap { $0.items }
    }

    func toggleCollapse(_ group: ResultGroup) {
        withAnimation(Motion.standard) {
            if collapsedVideos.contains(group.id) { collapsedVideos.remove(group.id) }
            else { collapsedVideos.insert(group.id) }
        }
    }

    // MARK: - Keyboard navigation

    func moveSelection(_ delta: Int) {
        let order = navigationOrder
        guard !order.isEmpty else { return }
        let idx = order.firstIndex { $0.id == selectedID } ?? 0
        let next = min(max(idx + delta, 0), order.count - 1)
        selectedID = order[next].id
    }

    func playSelected() {
        if let id = selectedID, let r = navigationOrder.first(where: { $0.id == id }) {
            select(r); isPlayingInline = true
        }
    }

    // MARK: - Toast + optimistic actions

    func showToast(_ text: String, _ systemImage: String, _ style: Toast.Style = .info) {
        let t = Toast(text: text, systemImage: systemImage, style: style)
        withAnimation(Motion.spring) { toast = t }
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            if toast?.id == t.id { withAnimation(Motion.standard) { toast = nil } }
        }
    }

    func copyLink(_ r: SearchResult) {
        ClipExporter.copyTimestampLink(videoURL: r.videoURL, seconds: r.timestamp)
        showToast("Timestamp link copied", "link", .success)
    }
    func saveFrame(_ r: SearchResult) {
        ClipExporter.saveFrame(r.thumbnail, suggestedName: "\(r.videoName) @ \(r.timecode).png") { ok in
            if ok { self.showToast("Frame saved", "photo", .success) }
        }
    }
    func exportClip(_ r: SearchResult) {
        ClipExporter.exportClip(videoURL: r.videoURL, around: r.timestamp) { result in
            if case .success = result { self.showToast("Clip exported", "scissors", .success) }
        }
    }
    func reveal(_ r: SearchResult) { ClipExporter.revealInFinder(r.videoURL) }

    // MARK: - Recent searches

    private func addRecent(_ q: String) {
        let trimmed = q.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var list = recentSearches.filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
        list.insert(trimmed, at: 0)
        recentSearches = Array(list.prefix(8))
        UserDefaults.standard.set(recentSearches, forKey: "tafuta.recents")
    }
}
