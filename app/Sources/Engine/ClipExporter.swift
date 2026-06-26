//
//  ClipExporter.swift
//  Engine
//
//  Utilities to act on a found video moment:
//   - export a short clip around a timestamp
//   - save the current frame image to disk
//   - copy a "deep link" string (file URL + #t=<seconds>) to the pasteboard
//   - reveal a file in Finder
//
//  Target: macOS 14+. Uses AVFoundation + AppKit. Written to compile cleanly
//  on macOS 14 while preferring modern APIs where they exist on that SDK.
//

import AppKit
import AVFoundation
import UniformTypeIdentifiers

/// Namespace for clip / frame / link export helpers. All members are static;
/// there is intentionally nothing to instantiate.
public enum ClipExporter {

    // MARK: - Errors

    /// Errors surfaced by `ClipExporter` operations.
    public enum ExportError: LocalizedError {
        /// The user dismissed the save panel without choosing a destination.
        case cancelled
        /// An `NSImage` could not be converted into PNG data.
        case imageEncodingFailed
        /// The asset reported no usable duration / no exportable range.
        case invalidTimeRange
        /// `AVAssetExportSession` could not be created for the chosen preset.
        case exportSessionUnavailable
        /// The export session finished in a non-completed state.
        case exportFailed(underlying: Error?)

        public var errorDescription: String? {
            switch self {
            case .cancelled:
                return "The operation was cancelled."
            case .imageEncodingFailed:
                return "The image could not be encoded as PNG."
            case .invalidTimeRange:
                return "The requested time range is not valid for this video."
            case .exportSessionUnavailable:
                return "An export session could not be created for this video."
            case .exportFailed(let underlying):
                if let underlying = underlying {
                    return "The clip export failed: \(underlying.localizedDescription)"
                }
                return "The clip export failed."
            }
        }
    }

    // MARK: - Reveal in Finder

    /// Selects (reveals) the given file URL in a Finder window.
    /// - Parameter url: The file URL to reveal.
    public static func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    // MARK: - Copy timestamp link

    /// Builds a `file://…#t=<intSeconds>` link for the given video position and
    /// writes it to the general pasteboard as a plain string.
    ///
    /// The fragment uses whole seconds (floored, never negative) following the
    /// common media-fragment convention `#t=<seconds>`.
    ///
    /// - Parameters:
    ///   - videoURL: The source video file URL.
    ///   - seconds: The position within the video, in seconds.
    public static func copyTimestampLink(videoURL: URL, seconds: Double) {
        let intSeconds = Self.clampedWholeSeconds(seconds)

        // Use the canonical absolute file-URL string (e.g. "file:///path"),
        // then append the media fragment.
        let link = "\(videoURL.absoluteString)#t=\(intSeconds)"

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(link, forType: .string)
    }

    // MARK: - Save frame image

    /// Presents a save panel (PNG) and writes the supplied image to the chosen
    /// location as PNG data.
    ///
    /// This is a UI operation and must be called on the main thread.
    ///
    /// - Parameters:
    ///   - image: The frame image to save.
    ///   - suggestedName: The default file name to pre-fill in the save panel.
    public static func saveFrame(_ image: NSImage, suggestedName: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true

        // `runModal` returns `.OK` when the user confirms a destination.
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        guard let data = pngData(from: image) else {
            Self.presentError(ExportError.imageEncodingFailed)
            return
        }

        do {
            try data.write(to: url, options: .atomic)
        } catch {
            Self.presentError(error)
        }
    }

    // MARK: - Export clip

    /// Presents a save panel (MPEG-4) and exports a short clip centered on the
    /// requested timestamp.
    ///
    /// The requested range is `[seconds - duration/2, seconds + duration/2]`,
    /// clamped into the asset's valid duration. The completion handler is always
    /// invoked on the main queue.
    ///
    /// - Parameters:
    ///   - videoURL: The source video file URL.
    ///   - seconds: The timestamp (seconds) to center the clip on.
    ///   - duration: The desired clip length in seconds (default `6`).
    ///   - completion: Called on the main queue with the output URL or an error.
    public static func exportClip(videoURL: URL,
                                  around seconds: Double,
                                  duration: Double = 6,
                                  completion: @escaping (Result<URL, Error>) -> Void) {

        // --- Choose a destination (UI; must be on the main thread). ----------
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.nameFieldStringValue = suggestedClipName(for: videoURL, at: seconds)
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let outputURL = panel.url else {
            finish(.failure(ExportError.cancelled), completion)
            return
        }

        // AVAssetExportSession refuses to write to an existing file; remove any
        // stale file the user may have chosen to overwrite.
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }

        let asset = AVURLAsset(url: videoURL)

        // --- Resolve duration and compute a clamped time range. --------------
        // `asset.duration` is available and synchronous on macOS 14; the async
        // `load(.duration)` variant exists too, but the synchronous property
        // keeps this path simple and compiling cleanly on the 14 SDK.
        let assetDuration = asset.duration
        let totalSeconds = CMTimeGetSeconds(assetDuration)

        guard totalSeconds.isFinite, totalSeconds > 0 else {
            finish(.failure(ExportError.invalidTimeRange), completion)
            return
        }

        let safeDuration = max(0.1, duration)
        var start = max(0, seconds - safeDuration / 2)
        if start >= totalSeconds {
            // Center is past the end of the media; clamp so we still grab a tail.
            start = max(0, totalSeconds - safeDuration)
        }

        // Don't let the requested length run past the end of the asset.
        let available = totalSeconds - start
        let clipSeconds = max(0.0, min(safeDuration, available))

        guard clipSeconds > 0 else {
            finish(.failure(ExportError.invalidTimeRange), completion)
            return
        }

        let timescale: CMTimeScale = 600
        let startTime = CMTime(seconds: start, preferredTimescale: timescale)
        let durationTime = CMTime(seconds: clipSeconds, preferredTimescale: timescale)
        let timeRange = CMTimeRange(start: startTime, duration: durationTime)

        // --- Configure and run the export session. ---------------------------
        guard let session = AVAssetExportSession(asset: asset,
                                                 presetName: AVAssetExportPresetHighestQuality) else {
            finish(.failure(ExportError.exportSessionUnavailable), completion)
            return
        }

        session.outputURL = outputURL
        session.outputFileType = .mp4
        session.timeRange = timeRange
        session.shouldOptimizeForNetworkUse = true

        session.exportAsynchronously {
            // `status` / `error` are read inside the completion handler, then we
            // hop to the main queue to notify the caller.
            switch session.status {
            case .completed:
                finish(.success(outputURL), completion)
            case .cancelled:
                finish(.failure(ExportError.cancelled), completion)
            default:
                finish(.failure(ExportError.exportFailed(underlying: session.error)), completion)
            }
        }
    }

    // MARK: - Helpers

    /// Converts an `NSImage` to PNG `Data`, or `nil` if no suitable bitmap
    /// representation is available.
    private static func pngData(from image: NSImage) -> Data? {
        // Prefer an existing bitmap rep; otherwise rasterize via the CGImage.
        if let bitmap = image.representations.compactMap({ $0 as? NSBitmapImageRep }).first {
            return bitmap.representation(using: .png, properties: [:])
        }

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        return bitmap.representation(using: .png, properties: [:])
    }

    /// Floors `seconds` to a non-negative whole number for use in a `#t=` link.
    private static func clampedWholeSeconds(_ seconds: Double) -> Int {
        guard seconds.isFinite, seconds > 0 else { return 0 }
        return Int(seconds.rounded(.down))
    }

    /// Suggests a clip file name based on the source name plus a timestamp tag,
    /// e.g. `Lecture-clip-92s.mp4`.
    private static func suggestedClipName(for videoURL: URL, at seconds: Double) -> String {
        let base = videoURL.deletingPathExtension().lastPathComponent
        let safeBase = base.isEmpty ? "clip" : base
        return "\(safeBase)-clip-\(clampedWholeSeconds(seconds))s.mp4"
    }

    /// Dispatches `result` to `completion` on the main queue.
    private static func finish(_ result: Result<URL, Error>,
                               _ completion: @escaping (Result<URL, Error>) -> Void) {
        if Thread.isMainThread {
            // Still hop async to keep delivery semantics consistent.
            DispatchQueue.main.async { completion(result) }
        } else {
            DispatchQueue.main.async { completion(result) }
        }
    }

    /// Presents a simple modal alert describing an error (main-thread UI helper).
    private static func presentError(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.runModal()
    }
}
