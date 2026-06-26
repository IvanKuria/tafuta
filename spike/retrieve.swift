// Phase 0 end-to-end retrieval spike.
// Samples ~1 fps from each video, embeds frames with MobileCLIP S0 image encoder,
// then ranks frames against each text query (tokens precomputed in tokens.json).
// Run: swift spike/retrieve.swift "<video1>" "<video2>" ...
import CoreML
import AVFoundation
import CoreImage
import Foundation

let root = FileManager.default.currentDirectoryPath

// ---- Load models on the Neural Engine ----
func loadModel(_ name: String) throws -> MLModel {
    let url = URL(fileURLWithPath: "\(root)/models/\(name).mlpackage")
    let compiled = try MLModel.compileModel(at: url)
    let cfg = MLModelConfiguration(); cfg.computeUnits = .cpuAndNeuralEngine
    return try MLModel(contentsOf: compiled, configuration: cfg)
}
let imageModel = try loadModel("mobileclip_s0_image")
let textModel  = try loadModel("mobileclip_s0_text")
let imageConstraint = imageModel.modelDescription.inputDescriptionsByName["image"]!.imageConstraint!

func readEmb(_ provider: MLFeatureProvider) -> [Float] {
    let arr = provider.featureValue(for: "final_emb_1")!.multiArrayValue!
    let n = arr.count
    var v = [Float](repeating: 0, count: n)
    let ptr = arr.dataPointer.assumingMemoryBound(to: Float32.self)
    for i in 0..<n { v[i] = ptr[i] }
    // L2 normalize for cosine via dot product.
    var s: Float = 0; for x in v { s += x*x }; s = max(s.squareRoot(), 1e-8)
    for i in 0..<n { v[i] /= s }
    return v
}

func embedImage(_ cg: CGImage) throws -> [Float] {
    let fv = try MLFeatureValue(cgImage: cg, constraint: imageConstraint, options: nil)
    let input = try MLDictionaryFeatureProvider(dictionary: ["image": fv])
    return readEmb(try imageModel.prediction(from: input))
}

func embedText(_ tokens: [Int]) throws -> [Float] {
    let arr = try MLMultiArray(shape: [1, 77], dataType: .int32)
    let ptr = arr.dataPointer.assumingMemoryBound(to: Int32.self)
    for i in 0..<77 { ptr[i] = Int32(tokens[i]) }
    let input = try MLDictionaryFeatureProvider(dictionary: ["text": MLFeatureValue(multiArray: arr)])
    return readEmb(try textModel.prediction(from: input))
}

func dot(_ a: [Float], _ b: [Float]) -> Float { var s: Float = 0; for i in 0..<a.count { s += a[i]*b[i] }; return s }
func mmss(_ t: Double) -> String { String(format: "%d:%02d", Int(t)/60, Int(t)%60) }

// ---- Index videos ----
struct Frame { let video: String; let t: Double; let vec: [Float] }
var frames: [Frame] = []
let videos = Array(CommandLine.arguments.dropFirst())
guard !videos.isEmpty else { print("usage: swift retrieve.swift <video> ..."); exit(1) }

let indexStart = Date()
for path in videos {
    let url = URL(fileURLWithPath: path)
    let asset = AVURLAsset(url: url)
    let dur = CMTimeGetSeconds(asset.duration)
    let gen = AVAssetImageGenerator(asset: asset)
    gen.appliesPreferredTrackTransform = true
    gen.requestedTimeToleranceBefore = CMTime(seconds: 0.4, preferredTimescale: 600)
    gen.requestedTimeToleranceAfter  = CMTime(seconds: 0.4, preferredTimescale: 600)
    let name = url.lastPathComponent
    var n = 0
    var t = 0.0
    while t < dur {
        let time = CMTime(seconds: t, preferredTimescale: 600)
        if let cg = try? gen.copyCGImage(at: time, actualTime: nil) {
            if let v = try? embedImage(cg) { frames.append(Frame(video: name, t: t, vec: v)); n += 1 }
        }
        t += 1.0
    }
    print(String(format: "indexed %-46@ %5.1fs  %4d frames", name as NSString, dur, n))
}
let indexSecs = Date().timeIntervalSince(indexStart)
print(String(format: "\nINDEX: %d frames from %d videos in %.1fs  (%.0f frames/s incl. decode+resize)\n",
             frames.count, videos.count, indexSecs, Double(frames.count)/indexSecs))

// ---- Load queries & rank ----
let tokData = try Data(contentsOf: URL(fileURLWithPath: "\(root)/spike/tokens.json"))
let tokens = try JSONSerialization.jsonObject(with: tokData) as! [String: [Int]]
for (query, ids) in tokens.sorted(by: { $0.key < $1.key }) {
    let q = try embedText(ids)
    let ranked = frames.map { ($0, dot(q, $0.vec)) }.sorted { $0.1 > $1.1 }.prefix(3)
    print("“\(query)”")
    for (f, score) in ranked {
        print(String(format: "    %.3f  %@ @ %@", score, f.video, mmss(f.t)))
    }
}
