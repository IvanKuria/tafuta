import SwiftUI

// Main content area: search field, strictness control, and the results grid (or empty state).
struct ResultsView: View {
    @EnvironmentObject var search: SearchCore

    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 300), spacing: Space.m)]

    var body: some View {
        VStack(spacing: 0) {
            // Search bar + strictness.
            HStack(spacing: Space.m) {
                SearchField()
                StrictnessControl()
                    .frame(width: 180)
            }
            .padding(Space.l)

            Divider().overlay(Color.borderSubtle)

            if search.hasQuery && !search.results.isEmpty {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: Space.m) {
                        ForEach(search.results) { ResultCard(result: $0) }
                    }
                    .padding(Space.l)
                }
            } else {
                EmptyState()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgCanvas)
    }
}

// Semantic strictness slider — thresholds out weak matches (validated in Phase 0).
struct StrictnessControl: View {
    @EnvironmentObject var search: SearchCore
    var body: some View {
        HStack(spacing: Space.s) {
            Text("Strictness").font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.textSecondary)
            Slider(value: $search.strictness, in: 0.05...0.35)
                .controlSize(.small)
                .onChange(of: search.strictness) { _, _ in search.runSearch() }
        }
    }
}

// Empty / first-run state, branching on whether a library has been indexed yet.
struct EmptyState: View {
    @EnvironmentObject var search: SearchCore
    var body: some View {
        VStack(spacing: Space.l) {
            Spacer()
            if let err = search.loadError {
                icon("exclamationmark.triangle")
                title("Couldn’t load the search model")
                subtitle(err)
            } else if !search.hasIndex {
                // No library yet → invite to add a folder.
                icon("plus.rectangle.on.folder")
                title(search.isIndexing ? "Indexing…" : "Add your videos")
                subtitle(search.isIndexing
                         ? "\(search.indexedCount) moments indexed so far…"
                         : "Point Tafuta at a folder of videos. Everything stays on your Mac — no uploads, no account.")
                if !search.isIndexing {
                    Button { search.addFolder() } label: { Text("Choose Folder…") }
                        .buttonStyle(PrimaryButtonStyle())
                }
            } else if search.hasQuery {
                icon("magnifyingglass")
                title("No matches")
                subtitle("Try loosening strictness or rephrasing.")
            } else {
                // Index ready, no query → teach with examples.
                icon("sparkle.magnifyingglass")
                title("Search inside your videos")
                subtitle("\(search.indexedCount) moments ready. Try one:")
                FlowExamples(examples: search.examples) { search.runExample($0) }
                    .frame(maxWidth: 460)
            }
            Spacer(); Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Space.xl)
    }

    private func icon(_ name: String) -> some View {
        Image(systemName: name).font(.system(size: 40, weight: .light))
            .foregroundStyle(Color.textTertiary)
    }
    private func title(_ t: String) -> some View {
        Text(t).font(.system(size: 18, weight: .semibold)).foregroundStyle(Color.textPrimary)
    }
    private func subtitle(_ s: String) -> some View {
        Text(s).font(.system(size: 13)).foregroundStyle(Color.textSecondary)
            .multilineTextAlignment(.center).frame(maxWidth: 420)
    }
}

// Simple wrapping row of example-query pills.
struct FlowExamples: View {
    let examples: [String]
    let onTap: (String) -> Void
    var body: some View {
        ViewThatFits(in: .horizontal) {
            row(examples)
            VStack(spacing: Space.s) {
                row(Array(examples.prefix(2)))
                row(Array(examples.suffix(from: min(2, examples.count))))
            }
        }
    }
    private func row(_ items: [String]) -> some View {
        HStack(spacing: Space.s) {
            ForEach(items, id: \.self) { ex in
                Button { onTap(ex) } label: {
                    Pill(text: ex, systemImage: "text.magnifyingglass", tint: .textPrimary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
