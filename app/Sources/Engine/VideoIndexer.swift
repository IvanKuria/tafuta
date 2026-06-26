import AVFoundation
import CoreGraphics
import AppKit

// Samples frames from a video (~1 fps), embeds each, and produces displayable thumbnails.
// Phase 2 (this slice): in-memory, AVAssetImageGenerator. Later: AVAssetReader streaming,
// scene-change dedup, sqlite-vec persistence, sprite sheets.
struct IndexedFrame: Identifiable {
    let id = UUID()
    let videoURL: URL
    let videoName: String
    let timestamp: Double
    let vector: [Float]
    let thumbnail: NSImage
}

enum VideoIndexer {
    static let videoExtensions: Set<String> = ["mov", "mp4", "m4v", "avi", "mkv"]
    private static let thumbWidth: CGFloat = 480

    static func videoFiles(in folder: URL) -> [URL] {
        let fm = FileManager.default
        guard let en = fm.enumerator(at: folder, includingPropertiesForKeys: nil,
                                     options: [.skipsHiddenFiles]) else { return [] }
        var urls: [URL] = []
        for case let url as URL in en where videoExtensions.contains(url.pathExtension.lowercased()) {
            urls.append(url)
        }
        // Recent-first ordering (early results feel relevant) — by modification date.
        return urls.sorted {
            let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return a > b
        }
    }

    /// Index one video, calling `onFrame` for each sampled frame as it's processed.
    static func index(video url: URL, using embedder: Embedder, onFrame: (IndexedFrame) -> Void) {
        let asset = AVURLAsset(url: url)
        let duration = CMTimeGetSeconds(asset.duration)
        guard duration.isFinite, duration > 0 else { return }

        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.requestedTimeToleranceBefore = CMTime(seconds: 0.4, preferredTimescale: 600)
        gen.requestedTimeToleranceAfter = CMTime(seconds: 0.4, preferredTimescale: 600)
        let name = url.lastPathComponent

        var t = 0.0
        while t < duration {
            let time = CMTime(seconds: t, preferredTimescale: 600)
            if let cg = try? gen.copyCGImage(at: time, actualTime: nil),
               let vec = try? embedder.embed(image: cg) {
                let thumb = makeThumbnail(cg)
                onFrame(IndexedFrame(videoURL: url, videoName: name, timestamp: t,
                                     vector: vec, thumbnail: thumb))
            }
            t += 1.0
        }
    }

    private static func makeThumbnail(_ cg: CGImage) -> NSImage {
        let scale = thumbWidth / CGFloat(cg.width)
        let w = Int(thumbWidth), h = max(1, Int(CGFloat(cg.height) * scale))
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        }
        ctx.interpolationQuality = .medium
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        let scaled = ctx.makeImage() ?? cg
        return NSImage(cgImage: scaled, size: NSSize(width: w, height: h))
    }
}
