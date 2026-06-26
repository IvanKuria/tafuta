import SwiftUI
import AppKit

// Native vibrancy (NSVisualEffectView) — the real macOS translucency, unlike SwiftUI
// `.ultraThinMaterial` which only blurs within-window. Use `.behindWindow` for the sidebar
// (shows the desktop) and `.withinWindow` for top bars / launcher / popovers.
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .sidebar
    var blending: NSVisualEffectView.BlendingMode = .behindWindow
    var emphasized: Bool = false

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blending
        v.state = .followsWindowActiveState
        v.isEmphasized = emphasized
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) {
        v.material = material
        v.blendingMode = blending
        v.isEmphasized = emphasized
    }
}

// One-time window setup so behind-window vibrancy can show through (non-opaque backing).
struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async {
            guard let w = v.window else { return }
            w.isOpaque = false
            w.backgroundColor = .clear
            w.titlebarAppearsTransparent = true
        }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
