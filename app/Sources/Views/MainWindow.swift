import SwiftUI
import KeyboardShortcuts

// Main window: sidebar + results, on the canvas background.
struct MainWindow: View {
    @EnvironmentObject var search: SearchCore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        NavigationSplitView {
            Sidebar()
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            ResultsView()
        }
        .navigationTitle("Tafuta")
        .background(Color.bgCanvas)
        .tint(Color.brand)
        .sheet(item: $search.playing) { r in
            PlayerView(url: r.videoURL, startTime: r.timestamp, title: r.videoName) {
                search.playing = nil
            }
        }
        .onAppear {
            // Register the global hotkey to summon the floating launcher from anywhere.
            KeyboardShortcuts.onKeyUp(for: .summon) {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "launcher")
            }
        }
    }
}
