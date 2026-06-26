import CoreML
import CoreGraphics
import Foundation

// Wraps the MobileCLIP S0 image + text encoders (Core ML, Neural Engine) and the tokenizer.
// Produces L2-normalized 512-d embeddings in a shared space, so image↔text similarity = dot product.
final class Embedder {
    enum EmbedderError: Error { case missingModel(String), missingVocab }

    private let imageModel: MLModel
    private let textModel: MLModel
    private let imageConstraint: MLImageConstraint
    let tokenizer: CLIPTokenizer

    init() throws {
        func load(_ name: String) throws -> MLModel {
            guard let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc") else {
                throw EmbedderError.missingModel(name)
            }
            let cfg = MLModelConfiguration()
            cfg.computeUnits = .cpuAndNeuralEngine
            return try MLModel(contentsOf: url, configuration: cfg)
        }
        imageModel = try load("mobileclip_s0_image")
        textModel = try load("mobileclip_s0_text")
        imageConstraint = imageModel.modelDescription.inputDescriptionsByName["image"]!.imageConstraint!

        guard let vocab = Bundle.main.url(forResource: "bpe_simple_vocab_16e6", withExtension: "txt"),
              let tok = CLIPTokenizer(vocabURL: vocab) else { throw EmbedderError.missingVocab }
        tokenizer = tok
    }

    private func normalizedEmbedding(_ provider: MLFeatureProvider) -> [Float] {
        let arr = provider.featureValue(for: "final_emb_1")!.multiArrayValue!
        let n = arr.count
        let ptr = arr.dataPointer.assumingMemoryBound(to: Float32.self)
        var v = [Float](repeating: 0, count: n)
        var sumSq: Float = 0
        for i in 0..<n { v[i] = ptr[i]; sumSq += ptr[i] * ptr[i] }
        let inv = 1 / max(sumSq.squareRoot(), 1e-8)
        for i in 0..<n { v[i] *= inv }
        return v
    }

    func embed(image cg: CGImage) throws -> [Float] {
        let fv = try MLFeatureValue(cgImage: cg, constraint: imageConstraint, options: nil)
        let input = try MLDictionaryFeatureProvider(dictionary: ["image": fv])
        return normalizedEmbedding(try imageModel.prediction(from: input))
    }

    func embed(text: String) throws -> [Float] {
        let ids = tokenizer.tokenize(text)
        let arr = try MLMultiArray(shape: [1, 77], dataType: .int32)
        let ptr = arr.dataPointer.assumingMemoryBound(to: Int32.self)
        for i in 0..<ids.count { ptr[i] = ids[i] }
        let input = try MLDictionaryFeatureProvider(dictionary: ["text": MLFeatureValue(multiArray: arr)])
        return normalizedEmbedding(try textModel.prediction(from: input))
    }

    static func cosine(_ a: [Float], _ b: [Float]) -> Float {
        var s: Float = 0
        for i in 0..<min(a.count, b.count) { s += a[i] * b[i] }
        return s
    }
}
