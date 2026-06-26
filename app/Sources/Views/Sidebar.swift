import SwiftUI

// Left rail: translucent (vibrant) library + saved searches, with tinted icon chips.
// Reserves the traffic-light drag zone up top; collapsible via the system toggle.
struct Sidebar: View {
    @EnvironmentObject var search: SearchCore
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @State private var selection: String? = "all"

    var body: some View {
        List(selection: $selection) {
            Section("Library") {
                row(id: "all", "All Videos", "square.grid.2x2", Tint.teal)
                Button { search.addFolder() } label: {
                    chipRow("Add Folder…", "folder.badge.plus", Tint.indigo, muted: true)
                }
                .buttonStyle(.plain)
            }
            Section("Saved Searches") {
                row(id: "recent", "Recent moments", "clock.arrow.circlepath", Tint.amber)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)        // let the window vibrancy show through
        .safeAreaInset(edge: .top) {
            // Premium collapse toggle, offset to clear the traffic lights.
            HStack {
                Spacer()
                Button {
                    withAnimation(Motion.spring) {
                        columnVisibility = (columnVisibility == .all) ? .detailOnly : .all
                    }
                } label: {
                    Image(systemName: "sidebar.leading")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Toggle Sidebar (⌃⌘S)")
                .keyboardShortcut("s", modifiers: [.command, .control])
            }
            .padding(.trailing, Space.s)
            .padding(.leading, 72)
            .frame(height: 38)
        }
        .safeAreaInset(edge: .bottom) {
            IndexingStatus().padding(Space.m)
        }
    }

    private func row(id: String, _ title: String, _ icon: String, _ tint: Color) -> some View {
        chipRow(title, icon, tint).tag(id)
    }

    private func chipRow(_ title: String, _ icon: String, _ tint: Color, muted: Bool = false) -> some View {
        HStack(spacing: Space.s) {
            IconChip(systemName: icon, tint: tint, size: 22)
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(muted ? Color.textSecondary : Color.textPrimary)
        }
        .padding(.vertical, 1)
    }
}

// Ambient indexing status — shimmers while indexing (subtle loading cue).
struct IndexingStatus: View {
    @EnvironmentObject var search: SearchCore
    var body: some View {
        HStack(spacing: Space.s) {
            Image(systemName: search.isIndexing ? "arrow.triangle.2.circlepath" : "checkmark.circle")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(search.isIndexing ? Color.brand : Color.textTertiary)
                .symbolEffect(.pulse, isActive: search.isIndexing)
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
        .modifier(ConditionalShimmer(active: search.isIndexing))
    }
}

// Applies a shimmer only while active.
struct ConditionalShimmer: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        if active { content.shimmering() } else { content }
    }
}
