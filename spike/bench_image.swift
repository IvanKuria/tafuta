// Phase 0 throughput benchmark: MobileCLIP S0 image encoder on this Mac.
// Measures cold-start + sustained frames/sec across compute-unit configs.
// Run: swift spike/bench_image.swift
import CoreML
import Foundation
import CoreVideo

func makePixelBuffer(_ w: Int, _ h: Int) -> CVPixelBuffer {
    var pb: CVPixelBuffer?
    let attrs = [kCVPixelBufferCGImageCompatibilityKey: true,
                 kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary
    CVPixelBufferCreate(kCFAllocatorDefault, w, h, kCVPixelFormatType_32BGRA, attrs, &pb)
    let buf = pb!
    CVPixelBufferLockBaseAddress(buf, [])
    if let base = CVPixelBufferGetBaseAddress(buf) {
        // Fill with a deterministic gradient so it's not all-zero.
        let bpr = CVPixelBufferGetBytesPerRow(buf)
        let ptr = base.assumingMemoryBound(to: UInt8.self)
        for y in 0..<h { for x in 0..<w {
            let o = y*bpr + x*4
            ptr[o] = UInt8((x ^ y) & 0xff); ptr[o+1] = UInt8(x & 0xff)
            ptr[o+2] = UInt8(y & 0xff); ptr[o+3] = 255
        }}
    }
    CVPixelBufferUnlockBaseAddress(buf, [])
    return buf
}

func bench(_ units: MLComputeUnits, _ name: String) {
    let root = FileManager.default.currentDirectoryPath
    let url = URL(fileURLWithPath: "\(root)/models/mobileclip_s0_image.mlpackage")
    do {
        let compiled = try MLModel.compileModel(at: url)
        let cfg = MLModelConfiguration(); cfg.computeUnits = units
        let model = try MLModel(contentsOf: compiled, configuration: cfg)
        let pb = makePixelBuffer(256, 256)
        let input = try MLDictionaryFeatureProvider(dictionary: ["image": MLFeatureValue(pixelBuffer: pb)])

        // Cold start (first inference includes ANE compile/load).
        let t0 = Date(); _ = try model.prediction(from: input); let cold = Date().timeIntervalSince(t0)

        // Warm sustained throughput.
        let N = 300; let t1 = Date()
        for _ in 0..<N { _ = try model.prediction(from: input) }
        let warm = Date().timeIntervalSince(t1)
        let fps = Double(N) / warm
        print(String(format: "%-22@ cold=%.1fms  warm=%.2fms/frame  %.0f fps  (%d frames in %.2fs)",
                     name as NSString, cold*1000, warm/Double(N)*1000, fps, N, warm))
    } catch { print("ERROR \(name): \(error)") }
}

print("MobileCLIP S0 image encoder — throughput on this Mac\n")
bench(.cpuAndNeuralEngine, "cpuAndNeuralEngine")
bench(.all,                "all")
bench(.cpuOnly,            "cpuOnly")
