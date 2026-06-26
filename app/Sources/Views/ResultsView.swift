import SwiftUI

// Main content area: search field, strictness, result grid (or contextual empty state).
struct ResultsView: View {
    @EnvironmentObject var search: SearchCore

    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 300), spacing: Space.l)]
    @State private var columnCount = 3
    @FocusState private var gridFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Flat search/header bar (no boxed material), subtle bottom divider.
            HStack(spacing: Space.m) {
                SearchField()
                if search.hasResults {
                    StrictnessControl()
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .padding(.horizontal, Space.l).padding(.vertical, Space.m)
            .overlay(alignment: .bottom) { Divider().overlay(Color.borderSubtle) }
            .animation(Motion.standard, value: search.hasResults)

            if search.hasResults {
                resultsScroll
            } else if search.isIndexing && search.hasQuery {
                skeletonGrid
            } else {
                EmptyState()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgCanvas)
    }

    private var skeletonGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Space.l) {
                ForEach(0..<6, id: \.self) { _ in SkeletonCard() }
            }
            .padding(Space.l)
        }
    }

    private var resultsScroll: some View {
        ScrollViewReader { proxy in
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
                    Text("↑↓ navigate · ↵ play · ⌘K actions")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.textTertiary)
                }
                .padding(.horizontal, Space.l)
                .padding(.top, Space.m)

                GeometryReader { geo in
                    Color.clear.onAppear { updateColumns(geo.size.width) }
                        .onChange(of: geo.size.width) { _, w in updateColumns(w) }
                }
                .frame(height: 0)

                LazyVGrid(columns: columns, spacing: Space.l) {
                    ForEach(Array(search.results.enumerated()), id: \.element.id) { i, result in
                        ResultCard(result: result, selected: result.id == search.selectedID)
                            .id(result.id)
                            .modifier(StaggeredAppear(index: i))
                    }
                }
                .padding(Space.l)
            }
            .focusable()
            .focused($gridFocused)
            .onAppear { gridFocused = true }
            .onMoveCommand { dir in
                switch dir {
                case .left:  search.moveSelection(-1)
                case .right: search.moveSelection(1)
                case .up:    search.moveSelection(-columnCount)
                case .down:  search.moveSelection(columnCount)
                @unknown default: break
                }
                if let id = search.selectedID { withAnimation(Motion.quick) { proxy.scrollTo(id, anchor: .center) } }
            }
            .onKeyPress(.return) { search.playSelected(); return .handled }
        }
    }

    private func updateColumns(_ width: CGFloat) {
        columnCount = max(1, Int(width / (236 + Space.l)))
    }
}

// Match strictness as a clean dropdown (Codex-style), not a raw slider.
struct StrictnessControl: View {
    @EnvironmentObject var search: SearchCore

    private var label: String {
        switch search.strictness {
        case ..<0.14: return "Loose"
        case ..<0.22: return "Balanced"
        default:      return "Strict"
        }
    }

    var body: some View {
        Menu {
            Button("Loose")    { set(0.10) }
            Button("Balanced") { set(0.18) }
            Button("Strict")   { set(0.26) }
        } label: {
            HStack(spacing: Space.xs) {
                Image(systemName: "slider.horizontal.3").font(.system(size: 10, weight: .semibold))
                Text("Match: \(label)").font(.system(size: 11, weight: .semibold))
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold))
            }
            .foregroundStyle(Color.textSecondary)
            .padding(.horizontal, Space.s).padding(.vertical, 5)
            .background(Color.bgInset, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.borderSubtle, lineWidth: 1))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private func set(_ v: Double) { search.strictness = v; search.runSearch() }
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
                IconChip(systemName: "sparkle.magnifyingglass", tint: .brand, size: 64)
                title(search.isIndexing ? "Indexing…" : "Welcome to Tafuta")
                subtitle(search.isIndexing
                         ? "\(search.indexedCount) moments indexed so far…"
                         : "Search inside your videos by describing a moment. Everything stays on your Mac — no uploads, no account.")
                if !search.isIndexing {
                    Button { search.addFolder() } label: { Text("Choose Folder…") }
                        .buttonStyle(PrimaryButtonStyle())
                    HStack(spacing: Space.xs) {
                        Text("Then press").font(Typo.caption).foregroundStyle(Color.textTertiary)
                        KBD(key: "⌘"); KBD(key: "K")
                        Text("to search from anywhere").font(Typo.caption).foregroundStyle(Color.textTertiary)
                    }
                    .padding(.top, Space.xs)
                }
            } else if search.hasQuery {
                icon("magnifyingglass"); title("No matches")
                subtitle("Try loosening strictness or rephrasing.")
            } else {
                icon("sparkle.magnifyingglass"); title("Search inside your videos")
                subtitle("\(search.indexedCount) moments ready. Try one:")
                FlowExamples(examples: search.examples) { search.runExample($0) }
                    .frame(maxWidth: 460)
                if !search.recentSearches.isEmpty {
                    Text("RECENT").font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.textTertiary).tracking(0.5).padding(.top, Space.s)
                    FlowExamples(examples: Array(search.recentSearches.prefix(4))) { search.runExample($0) }
                        .frame(maxWidth: 460)
                }
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
