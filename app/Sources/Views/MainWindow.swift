import SwiftUI
import KeyboardShortcuts

// Main window: vibrant collapsible sidebar + crisp content, premium translucent feel.
struct MainWindow: View {
    @EnvironmentObject var search: SearchCore
    @Environment(\.openWindow) private var openWindow
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            Sidebar(columnVisibility: $columnVisibility)
                .navigationSplitViewColumnWidth(min: 220, ideal: 248, max: 300)
                .background(VisualEffectView(material: .sidebar, blending: .behindWindow).ignoresSafeArea())
        } detail: {
            ResultsView()
        }
        .navigationSplitViewStyle(.balanced)
        .navigationTitle("Tafuta")
        .tint(Color.brand)
        .background(WindowConfigurator())          // non-opaque window so vibrancy shows
        .sheet(item: $search.playing) { r in
            PlayerView(url: r.videoURL, startTime: r.timestamp, title: r.videoName) {
                search.playing = nil
            }
        }
        .onAppear {
            KeyboardShortcuts.onKeyUp(for: .summon) {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "launcher")
            }
        }
    }
}
