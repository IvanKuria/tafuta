import SwiftUI

// Menu-bar status item: indexing state + quick actions (the discoverable status surface).
struct MenuBarView: View {
    @EnvironmentObject var search: SearchCore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(spacing: Space.s) {
                Image(systemName: search.isIndexing ? "arrow.triangle.2.circlepath" : "checkmark.circle")
                    .foregroundStyle(search.isIndexing ? Color.brand : Color.textTertiary)
                Text(search.isIndexing
                     ? "Indexing…"
                     : (search.hasIndex ? "Ready" : "No videos yet"))
                    .font(.system(size: 13, weight: .medium))
            }

            Divider()

            Button("Open Tafuta") { openWindow(id: "main") }
            Button("Quick Search…") { openWindow(id: "launcher") }
            Divider()
            Button("Quit Tafuta") { NSApplication.shared.terminate(nil) }
        }
        .padding(Space.m)
        .frame(width: 240)
        .tint(Color.brand)
    }
}
