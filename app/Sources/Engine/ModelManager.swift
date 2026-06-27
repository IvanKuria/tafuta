import CoreML
import Foundation

// Downloads and caches the MobileCLIP S0 Core ML models on first run instead of bundling them
// in the app (they are ~108MB, which keeps the shipped app small and the download light).
// The .mlpackage files are fetched from Apple's Hugging Face repo, reassembled, compiled to
// .mlmodelc, and cached in Application Support so the download happens only once.
enum ModelManager {
    static let baseURL = URL(string: "https://huggingface.co/apple/coreml-mobileclip/resolve/main")!
    static let modelNames = ["mobileclip_s0_image", "mobileclip_s0_text"]

    // The three files that make up each .mlpackage on disk.
    private static let packageFiles = [
        "Manifest.json",
        "Data/com.apple.CoreML/model.mlmodel",
        "Data/com.apple.CoreML/weights/weight.bin",
    ]

    static var modelsDir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Tafuta/Models", isDirectory: true)
    }

    static func compiledURL(_ name: String) -> URL {
        modelsDir.appendingPathComponent("\(name).mlmodelc", isDirectory: true)
    }

    // A model is available if it is bundled in the app (dev builds may still bundle it) or already
    // compiled in our cache.
    static func isAvailable(_ name: String) -> Bool {
        if Bundle.main.url(forResource: name, withExtension: "mlmodelc") != nil { return true }
        return FileManager.default.fileExists(atPath: compiledURL(name).path)
    }

    static var allModelsAvailable: Bool { modelNames.allSatisfy(isAvailable) }

    // Download (if needed), compile, and cache any missing models. `progress` reports a 0...1
    // fraction and a short status label; it may be called from a background queue.
    static func ensureModels(progress: @escaping @Sendable (Double, String) -> Void) async throws {
        let missing = modelNames.filter { !isAvailable($0) }
        guard !missing.isEmpty else { progress(1, ""); return }

        let fm = FileManager.default
        try fm.createDirectory(at: modelsDir, withIntermediateDirectories: true)

        // Build the job list and total byte count up front so progress is smooth.
        var jobs: [(name: String, rel: String, url: URL)] = []
        var total: Int64 = 0
        for name in missing {
            for rel in packageFiles {
                let url = baseURL.appendingPathComponent("\(name).mlpackage/\(rel)")
                total += (try? await contentLength(url)) ?? 0
                jobs.append((name, rel, url))
            }
        }
        let counter = ProgressCounter(total: total)
        progress(0, "Downloading search model…")

        let tmpRoot = fm.temporaryDirectory.appendingPathComponent("tafuta-dl-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: tmpRoot) }

        for job in jobs {
            let dest = tmpRoot.appendingPathComponent("\(job.name).mlpackage/\(job.rel)")
            try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            let downloaded = try await FileDownloader { delta in
                if let f = counter.add(delta) { progress(f, "Downloading search model…") }
            }.run(job.url)
            try? fm.removeItem(at: dest)
            try fm.moveItem(at: downloaded, to: dest)
        }

        // Compile each reassembled package and move it into the cache.
        for name in missing {
            progress(0.97, "Preparing search model…")
            let pkg = tmpRoot.appendingPathComponent("\(name).mlpackage")
            let compiled = try await MLModel.compileModel(at: pkg)
            let target = compiledURL(name)
            try? fm.removeItem(at: target)
            do { try fm.moveItem(at: compiled, to: target) }
            catch {
                try fm.copyItem(at: compiled, to: target)
                try? fm.removeItem(at: compiled)
            }
        }
        progress(1, "")
    }

    private static func contentLength(_ url: URL) async throws -> Int64 {
        var req = URLRequest(url: url)
        req.httpMethod = "HEAD"
        let (_, resp) = try await URLSession.shared.data(for: req)
        let len = resp.expectedContentLength
        return len > 0 ? len : 0
    }
}

// Thread-safe progress accumulator. Reports a new fraction only when it advances meaningfully,
// to avoid flooding the UI with updates.
private final class ProgressCounter: @unchecked Sendable {
    private let lock = NSLock()
    private let total: Int64
    private var bytes: Int64 = 0
    private var lastReported = -1.0

    init(total: Int64) { self.total = max(total, 1) }

    func add(_ delta: Int64) -> Double? {
        lock.lock(); defer { lock.unlock() }
        bytes += delta
        let f = min(0.96, Double(bytes) / Double(total))
        if f - lastReported >= 0.005 { lastReported = f; return f }
        return nil
    }
}

// Streams a single URL to a temp file (constant memory) and reports per-callback byte deltas.
private final class FileDownloader: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private var continuation: CheckedContinuation<URL, Error>?
    private let onDelta: @Sendable (Int64) -> Void

    init(onDelta: @escaping @Sendable (Int64) -> Void) {
        self.onDelta = onDelta
        super.init()
    }

    func run(_ url: URL) async throws -> URL {
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        return try await withCheckedThrowingContinuation { c in
            continuation = c
            session.downloadTask(with: url).resume()
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        onDelta(bytesWritten)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        // The temp file at `location` is removed once this returns, so move it out synchronously.
        let dst = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.moveItem(at: location, to: dst)
            continuation?.resume(returning: dst)
        } catch {
            continuation?.resume(throwing: error)
        }
        continuation = nil
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}
