// Dump a frame at a given time to PNG for visual verification.
// Run: swift spike/dump_frame.swift <video> <seconds> <outPNG>
import AVFoundation
import CoreImage
import Foundation
import AppKit

let a = CommandLine.arguments
let url = URL(fileURLWithPath: a[1]); let secs = Double(a[2])!; let out = a[3]
let gen = AVAssetImageGenerator(asset: AVURLAsset(url: url))
gen.appliesPreferredTrackTransform = true
gen.requestedTimeToleranceBefore = CMTime(seconds: 0.4, preferredTimescale: 600)
gen.requestedTimeToleranceAfter = CMTime(seconds: 0.4, preferredTimescale: 600)
let cg = try gen.copyCGImage(at: CMTime(seconds: secs, preferredTimescale: 600), actualTime: nil)
let rep = NSBitmapImageRep(cgImage: cg)
let png = rep.representation(using: .png, properties: [:])!
try png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
