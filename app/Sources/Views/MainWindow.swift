import SwiftUI

// Main window: sidebar + results, on the canvas background.
struct MainWindow: View {
    @EnvironmentObject var search: SearchCore

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
    }
}
