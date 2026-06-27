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
    // Cosine threshold; ~0.10 noise, ~0.25 strong. Persisted; changing it re-ranks off the cached vector.
    @Published var strictness: Double = UserDefaults.standard.object(forKey: "tafuta.strictness") as? Double ?? 0.18 {
        didSet {
            guard strictness != oldValue else { return }
            UserDefaults.standard.set(strictness, forKey: "tafuta.strictness")
            if queryVector != nil { rank() }            // re-filter using cached vector, no re-embed
        }
    }
    // Active filters (date / duration / folder / file-type). Re-ranks live, never re-embeds.
    @Published var filters = SearchFilters() {
        didSet {
            guard filters != oldValue else { return }
            if queryVector != nil { rank() }
        }
    }
    @Published private(set) var bestCosine: Double = 0  // top RAW cosine of the current query (0 = none)
    @Published var isIndexing: Bool = false
    @Published var indexedCount: Int = 0
    @Published var statusText: String = ""
    @Published var loadError: String? = nil

    // First-run model download (models are fetched on demand, not bundled).
    @Published var isPreparingModel: Bool = false
    @Published var modelProgress: Double = 0
    @Published var modelStatusText: String = "Downloading search model…"

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
    private var embedder: Embedder?
    private var macScanStarted = false

    // Metadata (filename/folder) only acts as a near-tie tie-breaker, never overriding semantics:
    private static let metaBand: Float = 0.05   // eligible only within 0.05 cosine of the best frame
    private static let metaMax:  Float = 0.02   // max affinity nudge (< a typical meaningful cosine gap)
    private var lastSuppressed: [SearchResult] = []  // top sub-threshold results, ready for "show closest"

    init() {
        Task { await bootstrap() }
    }

    // Ensure the on-device models are present (downloading on first run), then load the embedder
    // and kick off any initial indexing. Runs on the main actor; the download itself runs off-main.
    private func bootstrap() async {
        if ModelManager.allModelsAvailable {
            makeEmbedder()
        } else {
            isPreparingModel = true
            do {
                try await ModelManager.ensureModels { [weak self] frac, label in
                    Task { @MainActor in
                        self?.modelProgress = frac
                        if !label.isEmpty { self?.modelStatusText = label }
                    }
                }
                makeEmbedder()
            } catch {
                loadError = "Couldn’t download the search model. Check your connection and reopen Tafuta."
            }
            isPreparingModel = false
        }
        startInitialIndexing()
    }

    private func makeEmbedder() {
        do { embedder = try Embedder() }
        catch { embedder = nil; loadError = "Failed to load model: \(error)" }
    }

    private func startInitialIndexing() {
        guard embedder != nil else { return }
        for folder in FolderBookmarks.savedFolders() { indexFolder(folder, remember: false) }
        if let dir = ProcessInfo.processInfo.environment["TAFUTA_INDEX_DIR"] {
            indexFolder(URL(fileURLWithPath: (dir as NSString).expandingTildeInPath))
        }
    }

    var hasQuery: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }
    var hasIndex: Bool { !frames.isEmpty }
    var hasResults: Bool { !results.isEmpty }

    // Filter facets derived from what's actually indexed, so the UI never offers an empty bucket.
    var availableFolders: [URL] {
        let dirs = Set(frames.map { $0.videoURL.deletingLastPathComponent().standardizedFileURL })
        return dirs.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }
    var availableTypes: [String] {
        Array(Set(frames.map { $0.videoURL.pathExtension.lowercased() })).sorted()
    }

    // MARK: - Indexing

    func indexMacVideos(force: Bool = false) {
        if isIndexing || (macScanStarted && !force) { return }
        macScanStarted = true
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let candidates: [URL?] = [
            fm.urls(for: .moviesDirectory, in: .userDomainMask).first,
            fm.urls(for: .downloadsDirectory, in: .userDomainMask).first,
            fm.urls(for: .desktopDirectory, in: .userDomainMask).first,
            fm.urls(for: .picturesDirectory, in: .userDomainMask).first,
            fm.urls(for: .documentDirectory, in: .userDomainMask).first,
            home,
        ]
        let folders = Array(Set(candidates.compactMap(\.self).map { $0.standardizedFileURL }))
        let videos = folders
            .flatMap { VideoIndexer.videoFiles(in: $0) }
            .reduce(into: [String: URL]()) { unique, url in
                unique[url.standardizedFileURL.path] = url
            }
            .values
            .filter { !indexedVideoPaths.contains($0.standardizedFileURL.path) }
        guard !videos.isEmpty else {
            showToast("No new videos found", "magnifyingglass", .info)
            return
        }
        showToast("Scanning this Mac for videos", "internaldrive", .info)
        ingest(Array(videos))
    }

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

    private var searchGen = 0

    // Text search runs entirely OFF the main thread (embed + cosine over all frames), so typing
    // in the launcher / main window never blocks the UI. Stale runs are dropped via a generation token.
    func runSearch(record: Bool = false) {
        similarLabel = nil
        inspectorMoment = nil            // a fresh search closes the preview
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty, let embedder else {
            results = []; queryVector = nil; selectedID = nil; bestCosine = 0; lastSuppressed = []; return
        }
        searchGen += 1
        let gen = searchGen
        let threshold = Float(strictness)
        // Filter on existing metadata BEFORE scoring; affinity captured per surviving frame.
        let snaps = frames.filter { filters.matches($0) }
            .map { ($0.id, $0.vector, metadataAffinity(for: $0, query: q)) }

        Task.detached(priority: .userInitiated) {
            // Prompt-template ensemble: short queries land in a stronger region of text space.
            guard let qv = try? embedder.embed(text: q, templates: Embedder.zeroShotTemplates) else { return }
            let raw = snaps.map { (id: $0.0, cos: Embedder.cosine(qv, $0.1), meta: $0.2) }
            let topCos = raw.map(\.cos).max() ?? 0
            // Gated tie-breaker: affinity applies only to frames already within metaBand of the best.
            let scored = raw.map { r -> (id: UUID, cos: Float, final: Float) in
                let boost = (topCos - r.cos) <= Self.metaBand ? r.meta : 0
                return (r.id, r.cos, r.cos + boost)
            }
            // Honest threshold on RAW cosine (not the boosted score) — no "show top anyway" fallback.
            let kept = Array(scored.filter { $0.cos >= threshold }.sorted { $0.final > $1.final }.prefix(60))
            let suppressed = Array(scored.sorted { $0.final > $1.final }.prefix(60))
            await MainActor.run {
                guard gen == self.searchGen else { return }   // a newer query superseded this one
                self.queryVector = qv
                self.bestCosine = Double(topCos)
                let byID = Dictionary(self.frames.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
                func build(_ rows: [(id: UUID, cos: Float, final: Float)]) -> [SearchResult] {
                    rows.compactMap { row in byID[row.id].map { SearchResult(frame: $0, score: Double(row.final)) } }
                }
                let ranked = build(kept)
                self.lastSuppressed = build(suppressed)
                withAnimation(Motion.standard) { self.results = ranked }
                self.selectedID = ranked.first?.id
                if record, !ranked.isEmpty { self.addRecent(q) }
            }
        }
    }

    /// Reveal the best sub-threshold matches when a query produced no confident results.
    func revealClosest() {
        withAnimation(Motion.standard) { results = lastSuppressed }
        selectedID = lastSuppressed.first?.id
    }

    func runExample(_ q: String) {
        query = q
        if !hasIndex, !isIndexing { indexMacVideos() }
        runSearch(record: true)
    }

    // Shared re-rank path (streaming batches, strictness/filter changes, find-similar). Reuses the
    // cached queryVector — never re-embeds. Math MUST stay identical to runSearch's detached body.
    private func rank() {
        guard let qv = queryVector else {
            results = []; selectedID = nil; bestCosine = 0; lastSuppressed = []; return
        }
        let isSimilar = similarLabel != nil
        let threshold = Float(strictness)
        let work = frames.filter { filters.matches($0) }
        let raw = work.map { frame -> (frame: IndexedFrame, cos: Float, meta: Float) in
            let meta = isSimilar ? 0 : metadataAffinity(for: frame, query: query)
            return (frame, Embedder.cosine(qv, frame.vector), meta)
        }
        let topCos = raw.map(\.cos).max() ?? 0
        bestCosine = Double(topCos)
        let scored = raw.map { r -> (frame: IndexedFrame, cos: Float, final: Float) in
            let boost = (topCos - r.cos) <= Self.metaBand ? r.meta : 0
            return (r.frame, r.cos, r.cos + boost)
        }
        let sortedAll = scored.sorted { $0.final > $1.final }
        lastSuppressed = sortedAll.prefix(60).map { SearchResult(frame: $0.frame, score: Double($0.final)) }
        // Find-similar (image→image) browses freely — text strictness must not blank it.
        let visible = isSimilar
            ? Array(sortedAll.prefix(60))
            : Array(scored.filter { $0.cos >= threshold }.sorted { $0.final > $1.final }.prefix(60))
        let ranked = visible.map { SearchResult(frame: $0.frame, score: Double($0.final)) }
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
        queryVector = r.frame.vector
        similarLabel = "Similar to \(r.videoName) @ \(r.timecode)"
        rank()
        inspect(r)
    }

    // Filename/folder keyword affinity. Capped tiny (metaMax) so it can only break near-ties, not
    // override a clearly-better semantic match. Applied gated-by-metaBand in runSearch/rank.
    private func metadataAffinity(for frame: IndexedFrame, query: String) -> Float {
        let terms = metadataTerms(for: query)
        guard !terms.isEmpty else { return 0 }
        let parent = frame.videoURL.deletingLastPathComponent().lastPathComponent
        let haystack = "\(frame.videoName) \(parent)"
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression)

        var matched = 0
        for term in terms where haystack.contains(term) { matched += 1 }
        guard matched > 0 else { return 0 }
        return min(Self.metaMax, 0.012 + Float(matched - 1) * 0.004)
    }

    private func metadataTerms(for query: String) -> Set<String> {
        let normalized = query
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression)
        let words = normalized.split(separator: " ").map(String.init)
            .filter { $0.count >= 3 }

        var terms = Set(words)
        if normalized.contains("macbook") || normalized.contains("mac book") {
            terms.formUnion(["mac", "macbook", "laptop"])
        }
        if normalized.contains("iphone") {
            terms.formUnion(["phone", "iphone"])
        }
        return terms
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
