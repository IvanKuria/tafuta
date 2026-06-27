import SwiftUI

// Floating ⌘⇧K command palette — a pixel-faithful Raycast command palette. Surface-color depth,
// 1px hairlines, Inter type, keycaps, and (because it floats over the desktop) a single soft
// shadow on the outer panel only. Fully keyboard-driven: ↑↓ navigate, ↩ (or click) opens the
// main window at the chosen moment, esc closes.
//
// SearchCore is shared across scenes, so this works with the main window CLOSED — we only spin
// the main window up at the moment the user commits to a result.
struct LauncherView: View {
    @EnvironmentObject var search: SearchCore
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var selectedID: SearchResult.ID?

    // The rows we actually render (and therefore the set keyboard nav walks over).
    private var visibleResults: [SearchResult] { Array(search.results.prefix(8)) }

    private var selectedResult: SearchResult? {
        search.results.first { $0.id == selectedID }
    }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                SearchField(placeholder: "Describe a moment…", large: true)
                    .padding(Space.m)

                if search.hasQuery && !search.results.isEmpty {
                    Divider().overlay(Color.borderSubtle)
                    resultsList(proxy: proxy)
                } else {
                    emptyState
                }

                ActionBar(appGlyph: "magnifyingglass",
                          contextTitle: selectedResult?.videoName,
                          primary: openPrimary,
                          actions: launcherActions)
            }
            .frame(width: 640)
            .background(Color.bgSurfaceElevated,
                        in: RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous)
                    .strokeBorder(Color.borderDefault, lineWidth: 1)
            )
            .floatingShadow()
            .tint(Color.brand)
            .onMoveCommand { direction in move(direction, proxy: proxy) }
            .onKeyPress(.return) {
                if let r = selectedResult { open(r) }
                return .handled
            }
            .onAppear { selectedID = search.results.first?.id }
            .onChange(of: search.results) { _, results in
                // Keep the cursor valid as live results stream in / change.
                if selectedID == nil || !results.contains(where: { $0.id == selectedID }) {
                    selectedID = results.first?.id
                }
            }
        }
    }

    // MARK: - Results

    private func resultsList(proxy: ScrollViewProxy) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(visibleResults) { r in
                    Button { open(r) } label: {
                        CommandRow(thumbnail: r.thumbnail,
                                   icon: nil,
                                   title: r.videoName,
                                   subtitle: r.timecode,
                                   accessories: ["\(Int(r.normalizedScore * 100))% match"],
                                   trailingKey: nil,
                                   selected: r.id == selectedID)
                    }
                    .buttonStyle(.plain)
                    .onHover { if $0 { selectedID = r.id } }
                    .id(r.id)
                }
            }
            .padding(Space.s)
        }
        .frame(maxHeight: 380)
    }

    // MARK: - Empty state (no query)

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("Search your footage by describing what you remember.")
                .font(Typo.caption)
                .foregroundStyle(Color.textTertiary)
                .padding(.horizontal, 10)
                .padding(.vertical, Space.s)

            ForEach(emptyQueries, id: \.self) { query in
                Button { search.runExample(query) } label: {
                    CommandRow(thumbnail: nil,
                               icon: "magnifyingglass",
                               title: query,
                               subtitle: nil,
                               accessories: [],
                               trailingKey: nil,
                               selected: false)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.s)
    }

    // Recent searches first (if any), then the curated examples.
    private var emptyQueries: [String] {
        search.recentSearches + search.examples
    }

    // MARK: - Actions

    private var openPrimary: ActionItem {
        ActionItem(title: "Open", systemImage: "arrow.up.forward.app", shortcut: ["↩"]) {
            if let r = selectedResult { open(r) }
        }
    }

    private var launcherActions: [ActionItem] {
        guard let r = selectedResult else { return [] }
        return [
            ActionItem(title: "Open", systemImage: "arrow.up.forward.app", shortcut: ["↩"]) {
                open(r)
            },
            ActionItem(title: "Reveal in Finder", systemImage: "folder") {
                search.reveal(r)
            },
            ActionItem(title: "Copy Link", systemImage: "link") {
                search.copyLink(r)
            },
            ActionItem(title: "Export Clip", systemImage: "scissors") {
                search.exportClip(r)
            },
        ]
    }

    private func open(_ result: SearchResult) {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
        search.select(result)
        dismissWindow(id: "launcher")
    }

    private func move(_ direction: MoveCommandDirection, proxy: ScrollViewProxy) {
        let order = visibleResults
        guard !order.isEmpty else { return }
        let current = order.firstIndex { $0.id == selectedID } ?? 0
        let next: Int
        switch direction {
        case .up:   next = max(current - 1, 0)
        case .down: next = min(current + 1, order.count - 1)
        default:    return
        }
        let id = order[next].id
        selectedID = id
        withAnimation(Motion.quick) { proxy.scrollTo(id, anchor: .center) }
    }
}
