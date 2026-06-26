import SwiftUI

// Clean, flat, monochrome sidebar (Codex-style): native vibrancy, no borders,
// no colored icons, system collapse toggle (no custom duplicate).
struct Sidebar: View {
    @EnvironmentObject var search: SearchCore
    @State private var selection: String? = "all"

    var body: some View {
        List(selection: $selection) {
            Section("Library") {
                Label("All Videos", systemImage: "square.grid.2x2").tag("all")
                Button { search.addFolder() } label: {
                    Label("Add Folder…", systemImage: "plus")
                }
                .buttonStyle(.plain)
            }
            Section("Saved Searches") {
                Label("Recent moments", systemImage: "clock").tag("recent")
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) { statusBar }
    }

    private var statusBar: some View {
        HStack(spacing: 6) {
            if search.isIndexing {
                ProgressView().controlSize(.mini).scaleEffect(0.8)
            } else {
                Image(systemName: search.hasIndex ? "checkmark.circle" : "tray")
                    .font(.system(size: 11))
            }
            Text(search.isIndexing
                 ? "Indexing… \(search.indexedCount)"
                 : (search.hasIndex ? "\(search.indexedCount) moments" : "No library yet"))
                .font(.system(size: 11))
            Spacer()
        }
        .foregroundStyle(Color.textTertiary)
        .padding(.horizontal, Space.m).padding(.vertical, Space.s)
    }
}
