import SwiftUI

// Full-width results surface (search/strictness/grouping live in TopBar now).
// Grouped-by-video (collapsible) or flat grid; drag videos/folder in; keyboard nav.
struct ResultsView: View {
    @EnvironmentObject var search: SearchCore

    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 300), spacing: Space.l)]
    @State private var columnCount = 3
    @State private var dropTargeted = false

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.bgCanvas)
            .dropDestination(for: URL.self) { urls, _ in
                search.indexURLs(urls); return true
            } isTargeted: { dropTargeted = $0 }
            .overlay { if dropTargeted { dropHighlight } }
    }

    @ViewBuilder private var content: some View {
        if search.hasResults {
            resultsScroll
        } else if search.isIndexing && search.hasQuery {
            skeletonGrid
        } else {
            EmptyState()
        }
    }

    // MARK: Results

    private var resultsScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                countRow
                GeometryReader { geo in
                    Color.clear
                        .onAppear { updateColumns(geo.size.width) }
                        .onChange(of: geo.size.width) { _, w in updateColumns(w) }
                }
                .frame(height: 0)

                if search.grouping == .flat { flatGrid } else { groupedGrid }
            }
            .focusable()
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

    private var flatGrid: some View {
        LazyVGrid(columns: columns, spacing: Space.l) {
            ForEach(Array(search.results.enumerated()), id: \.element.id) { i, result in
                ResultCard(result: result, selected: result.id == search.selectedID)
                    .id(result.id)
                    .modifier(StaggeredAppear(index: i))
            }
        }
        .padding(Space.l)
    }

    private var groupedGrid: some View {
        LazyVStack(spacing: Space.m, pinnedViews: [.sectionHeaders]) {
            ForEach(search.groupedResults) { group in
                Section {
                    if !search.collapsedVideos.contains(group.id) {
                        LazyVGrid(columns: columns, spacing: Space.l) {
                            ForEach(Array(group.items.enumerated()), id: \.element.id) { i, result in
                                ResultCard(result: result, selected: result.id == search.selectedID)
                                    .id(result.id)
                                    .modifier(StaggeredAppear(index: i))
                            }
                        }
                        .padding(.horizontal, Space.l)
                        .padding(.bottom, Space.m)
                    }
                } header: {
                    VideoSectionHeader(
                        group: group,
                        collapsed: search.collapsedVideos.contains(group.id),
                        onToggle: { search.toggleCollapse(group) },
                        onReveal: { ClipExporter.revealInFinder(group.videoURL) }
                    )
                }
            }
        }
        .padding(.top, Space.m)
    }

    private var countRow: some View {
        HStack(spacing: Space.s) {
            if let label = search.similarLabel {
                Pill(text: label, systemImage: "square.on.square", tint: .textSecondary)
            }
            Text("\(search.results.count) moments")
                .font(Typo.caption).foregroundStyle(Color.textTertiary)
            Spacer()
            Text("↑↓ navigate · ↵ play · ⌘I inspector")
                .font(.system(size: 10, weight: .medium)).foregroundStyle(Color.textTertiary)
        }
        .padding(.horizontal, Space.l).padding(.top, Space.m)
    }

    private var skeletonGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Space.l) {
                ForEach(0..<6, id: \.self) { _ in SkeletonCard() }
            }
            .padding(Space.l)
        }
    }

    private var dropHighlight: some View {
        ZStack {
            Color.brand.opacity(0.06)
            RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous)
                .strokeBorder(Color.brand, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .padding(Space.m)
            VStack(spacing: Space.s) {
                IconChip(systemName: "tray.and.arrow.down", tint: .brand, size: 44)
                Text("Drop videos or a folder to index")
                    .font(Typo.title3).foregroundStyle(Color.textPrimary)
            }
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private func updateColumns(_ width: CGFloat) {
        columnCount = max(1, Int(width / (236 + Space.l)))
    }
}

// Collapsible per-video section header for grouped results.
struct VideoSectionHeader: View {
    let group: ResultGroup
    let collapsed: Bool
    let onToggle: () -> Void
    let onReveal: () -> Void

    var body: some View {
        HStack(spacing: Space.s) {
            Button(action: onToggle) {
                Image(systemName: collapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 16)
            }
            .buttonStyle(.plain)

            Text(group.name)
                .font(Typo.title3).foregroundStyle(Color.textPrimary)
                .lineLimit(1).truncationMode(.middle)
            Pill(text: "\(group.items.count)")
            Spacer()
            Button(action: onReveal) {
                Image(systemName: "folder").font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.textTertiary)
            }
            .buttonStyle(.plain).help("Reveal in Finder")
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
        .padding(.horizontal, Space.l).padding(.vertical, Space.s)
        .background(Color.bgCanvas.opacity(0.92))
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
                IconChip(systemName: "sparkle.magnifyingglass", tint: .brand, size: 64)
                title(search.isIndexing ? "Indexing…" : "Add your videos")
                subtitle(search.isIndexing
                         ? "\(search.indexedCount) moments indexed so far…"
                         : "Point Tafuta at a folder of videos — or drag them in. Everything stays on your Mac.")
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
        Image(systemName: name).font(.system(size: 40, weight: .light)).foregroundStyle(Color.textTertiary)
    }
    private func title(_ t: String) -> some View {
        Text(t).font(Typo.title).tracking(-0.4).foregroundStyle(Color.textPrimary)
    }
    private func subtitle(_ s: String) -> some View {
        Text(s).font(Typo.body).foregroundStyle(Color.textSecondary)
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
