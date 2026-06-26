import SwiftUI

// Main content area: search field, strictness, result grid (or contextual empty state).
struct ResultsView: View {
    @EnvironmentObject var search: SearchCore

    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 300), spacing: Space.l)]

    var body: some View {
        VStack(spacing: 0) {
            // Search bar + (progressively disclosed) strictness control.
            HStack(spacing: Space.m) {
                SearchField()
                if search.hasResults {
                    StrictnessControl()
                        .frame(width: 170)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .padding(Space.l)
            .animation(Motion.standard, value: search.hasResults)

            Divider().overlay(Color.borderSubtle)

            if search.hasResults {
                resultsScroll
            } else {
                EmptyState()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgCanvas)
    }

    private var resultsScroll: some View {
        ScrollView {
            // Result count / similar-mode breadcrumb.
            HStack(spacing: Space.s) {
                if let label = search.similarLabel {
                    Pill(text: label, systemImage: "square.on.square", tint: .textSecondary)
                }
                Text("\(search.results.count) moments")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.textTertiary)
                Spacer()
            }
            .padding(.horizontal, Space.l)
            .padding(.top, Space.m)

            LazyVGrid(columns: columns, spacing: Space.l) {
                ForEach(search.results) { result in
                    ResultCard(result: result)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
            .padding(Space.l)
            .animation(Motion.standard, value: search.results.map(\.id))
        }
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

// Contextual empty state: error → no-library → no-results → ready-with-examples.
struct EmptyState: View {
    @EnvironmentObject var search: SearchCore
    var body: some View {
        VStack(spacing: Space.l) {
            Spacer()
            if let err = search.loadError {
                icon("exclamationmark.triangle"); title("Couldn’t load the search model"); subtitle(err)
            } else if !search.hasIndex {
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
                icon("magnifyingglass"); title("No matches")
                subtitle("Try loosening strictness or rephrasing.")
            } else {
                icon("sparkle.magnifyingglass"); title("Search inside your videos")
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
        Text(t).font(.system(size: 22, weight: .bold)).tracking(-0.4)
            .foregroundStyle(Color.textPrimary)
    }
    private func subtitle(_ s: String) -> some View {
        Text(s).font(.system(size: 13)).foregroundStyle(Color.textSecondary)
            .multilineTextAlignment(.center).frame(maxWidth: 420)
    }
}

// Wrapping rows of tappable example-query pills.
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
