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

// Spotlight-style chrome for the floating launcher: non-opaque, no traffic-light buttons,
// floats above other windows, draggable by its background. (esc-to-dismiss is wired in the view.)
struct LauncherWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async {
            guard let w = v.window else { return }
            w.isOpaque = false
            w.backgroundColor = .clear
            w.titlebarAppearsTransparent = true
            w.isMovableByWindowBackground = true
            w.level = .floating
            w.styleMask.insert(.fullSizeContentView)   // content fills under the hidden title bar
            w.standardWindowButton(.closeButton)?.isHidden = true
            w.standardWindowButton(.miniaturizeButton)?.isHidden = true
            w.standardWindowButton(.zoomButton)?.isHidden = true
            w.setFrameAutosaveName("")   // don't restore a stale frame

            // Force the window to EXACTLY the panel size. With .fullSizeContentView the content
            // fills the whole frame, so there is no title-bar height left as a transparent strip.
            let size = NSSize(width: 720, height: 540)
            if let screen = w.screen ?? NSScreen.main {
                let vf = screen.visibleFrame
                let origin = NSPoint(x: vf.midX - size.width / 2, y: vf.midY - size.height / 2 + 60)
                w.setFrame(NSRect(origin: origin, size: size), display: true)
            } else {
                w.setContentSize(size)
                w.center()
            }
        }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

// Transparent backing whose mouse-downs drag the window. Placed behind chrome so empty regions
// move the window while controls on top still receive clicks.
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        final class DragView: NSView { override var mouseDownCanMoveWindow: Bool { true } }
        return DragView()
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
