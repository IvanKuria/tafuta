import SwiftUI

// Left rail: library sources + saved searches (static in Phase 1).
struct Sidebar: View {
    @EnvironmentObject var search: SearchCore

    var body: some View {
        List {
            Section("Library") {
                Label("All Videos", systemImage: "square.grid.2x2")
                Button { search.addFolder() } label: {
                    Label("Add Folder…", systemImage: "plus.rectangle.on.folder")
                        .foregroundStyle(Color.textSecondary)
                }
                .buttonStyle(.plain)
            }
            Section("Saved Searches") {
                Label("Recent moments", systemImage: "clock")
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            IndexingStatus()
                .padding(Space.m)
        }
    }
}

// Ambient indexing status (incremental availability messaging from the plan).
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
