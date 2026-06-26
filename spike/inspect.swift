// Quick Core ML model I/O inspector for the MobileCLIP S0 image + text encoders.
// Run: swift spike/inspect.swift
import CoreML
import Foundation

func describe(_ label: String, _ path: String) {
    let url = URL(fileURLWithPath: path)
    do {
        let compiled = try MLModel.compileModel(at: url)
        let model = try MLModel(contentsOf: compiled)
        let d = model.modelDescription
        print("=== \(label) ===")
        print("inputs:")
        for (name, desc) in d.inputDescriptionsByName {
            print("  \(name): type=\(desc.type.rawValue)")
            if let m = desc.multiArrayConstraint {
                print("    multiArray shape=\(m.shape) dtype=\(m.dataType.rawValue)")
            }
            if let i = desc.imageConstraint {
                print("    image \(i.pixelsWide)x\(i.pixelsHigh) pixelFormat=\(i.pixelFormatType)")
            }
        }
        print("outputs:")
        for (name, desc) in d.outputDescriptionsByName {
            print("  \(name): type=\(desc.type.rawValue)")
            if let m = desc.multiArrayConstraint {
                print("    multiArray shape=\(m.shape) dtype=\(m.dataType.rawValue)")
            }
        }
        print("")
    } catch {
        print("ERROR \(label): \(error)")
    }
}

let root = FileManager.default.currentDirectoryPath
describe("S0 IMAGE", "\(root)/models/mobileclip_s0_image.mlpackage")
describe("S0 TEXT", "\(root)/models/mobileclip_s0_text.mlpackage")
