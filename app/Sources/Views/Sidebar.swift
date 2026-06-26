import SwiftUI

// Left rail: library sources + saved searches. Reserves the traffic-light drag zone up top.
struct Sidebar: View {
    @EnvironmentObject var search: SearchCore
    @State private var selection: String? = "all"

    var body: some View {
        List(selection: $selection) {
            Section("Library") {
                Label("All Videos", systemImage: "square.grid.2x2").tag("all")
                Button { search.addFolder() } label: {
                    Label("Add Folder…", systemImage: "plus.rectangle.on.folder")
                        .foregroundStyle(Color.textSecondary)
                }
                .buttonStyle(.plain)
            }
            Section("Saved Searches") {
                Label("Recent moments", systemImage: "clock")
                    .foregroundStyle(Color.textSecondary).tag("recent")
            }
        }
        .listStyle(.sidebar)
        // Keep the top ~28pt clear so content never collides with the traffic lights.
        .safeAreaInset(edge: .top) { Color.clear.frame(height: 28) }
        .safeAreaInset(edge: .bottom) {
            IndexingStatus().padding(Space.m)
        }
    }
}

// Ambient indexing status (incremental availability messaging).
struct IndexingStatus: View {
    @EnvironmentObject var search: SearchCore
    var body: some View {
        HStack(spacing: Space.s) {
            Image(systemName: search.isIndexing ? "arrow.triangle.2.circlepath" : "checkmark.circle")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(search.isIndexing ? Color.brand : Color.textTertiary)
            Text(search.isIndexing
                 ? "Indexing… \(search.indexedCount) moments"
                 : (search.hasIndex ? "\(search.indexedCount) moments ready" : "No library yet"))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.textSecondary)
            Spacer()
        }
        .padding(.horizontal, Space.s).padding(.vertical, Space.xs)
        .frame(maxWidth: .infinity)
        .cardStyle(radius: Radius.control, fill: .bgInset, border: .borderSubtle)
    }
}
