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

// Empty / first-run state: privacy reassurance + tappable example queries.
struct EmptyState: View {
    @EnvironmentObject var search: SearchCore
    var body: some View {
        VStack(spacing: Space.l) {
            Spacer()
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Color.textTertiary)
            VStack(spacing: Space.xs) {
                Text(search.hasQuery ? "No matches" : "Search inside your videos")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text(search.hasQuery
                     ? "Try loosening strictness or rephrasing."
                     : "Everything stays on your Mac — no uploads, no account.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
            }
            if !search.hasQuery {
                FlowExamples(examples: search.examples) { search.runExample($0) }
                    .frame(maxWidth: 460)
            }
            Spacer(); Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Space.xl)
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
