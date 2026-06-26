import Foundation
import AppKit
import CryptoKit

// On-disk cache of a video's indexed frames (timestamp + embedding + thumbnail JPEG),
// keyed by file path and invalidated by modification date / size. Lets the app remember
// indexed libraries across launches instead of re-embedding every time.
enum IndexStore {
    private static let magic: [UInt8] = Array("TFI1".utf8)

    private static var cacheDir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Tafuta/index", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    private static func cacheURL(for videoURL: URL) -> URL {
        let digest = SHA256.hash(data: Data(videoURL.standardizedFileURL.path.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return cacheDir.appendingPathComponent(name).appendingPathExtension("tfi")
    }

    private static func stat(_ url: URL) -> (mtime: Double, size: Int64)? {
        guard let v = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]) else { return nil }
        let m = v.contentModificationDate?.timeIntervalSince1970 ?? 0
        let s = Int64(v.fileSize ?? 0)
        return (m, s)
    }

    /// Returns cached frames if the cache exists and matches the file's mtime+size.
    static func load(for videoURL: URL) -> [IndexedFrame]? {
        guard let (mtime, size) = stat(videoURL),
              let data = try? Data(contentsOf: cacheURL(for: videoURL)),
              data.count > 24 else { return nil }
        var c = 0
        func read<T>(_ t: T.Type) -> T { defer { c += MemoryLayout<T>.size }
            return data.subdata(in: c..<c + MemoryLayout<T>.size).withUnsafeBytes { $0.loadUnaligned(as: T.self) } }

        guard Array(data[0..<4]) == magic else { return nil }
        c = 4
        let cm = read(Double.self), cs = read(Int64.self)
        guard abs(cm - mtime) < 0.5, cs == size else { return nil }   // stale
        let count = Int(read(Int32.self))

        var frames: [IndexedFrame] = []
        frames.reserveCapacity(count)
        for _ in 0..<count {
            guard c + 12 <= data.count else { break }
            let t = read(Double.self)
            let vlen = Int(read(Int32.self))
            guard c + vlen * 4 + 4 <= data.count else { break }
            var vec = [Float](repeating: 0, count: vlen)
            for i in 0..<vlen { vec[i] = read(Float32.self) }
            let tlen = Int(read(Int32.self))
            guard c + tlen <= data.count else { break }
            let jpeg = data.subdata(in: c..<c + tlen); c += tlen
            let thumb = NSImage(data: jpeg) ?? NSImage()
            frames.append(IndexedFrame(videoURL: videoURL, videoName: videoURL.lastPathComponent,
                                       timestamp: t, vector: vec, thumbnail: thumb))
        }
        return frames
    }

    static func save(_ frames: [IndexedFrame], for videoURL: URL) {
        guard let (mtime, size) = stat(videoURL) else { return }
        var data = Data(magic)
        func append<T>(_ v: T) { var v = v; withUnsafeBytes(of: &v) { data.append(contentsOf: $0) } }
        append(mtime); append(size); append(Int32(frames.count))
        for f in frames {
            append(f.timestamp)
            append(Int32(f.vector.count))
            f.vector.forEach { append($0) }
            let jpeg = jpegData(f.thumbnail) ?? Data()
            append(Int32(jpeg.count))
            data.append(jpeg)
        }
        try? data.write(to: cacheURL(for: videoURL))
    }

    private static func jpegData(_ image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.7])
    }
}
