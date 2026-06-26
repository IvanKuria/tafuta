import SwiftUI
import KeyboardShortcuts

// Main window: native NavigationSplitView (flat vibrant sidebar, single system
// collapse toggle) + crisp content. No window-border hacks, no custom toggle.
struct MainWindow: View {
    @EnvironmentObject var search: SearchCore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        NavigationSplitView {
            Sidebar()
                .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 300)
        } detail: {
            ResultsView()
        }
        .navigationTitle("Tafuta")
        .tint(Color.brand)
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
