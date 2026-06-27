import SwiftUI

// Floating ⌘⇧K command palette — a Spotlight-style "Liquid Glass" command palette (macOS Tahoe).
// A single floating glass panel: borderless search row up top, a results list (or recent/example
// queries) in the middle, and a footer action bar with keycaps. Fully keyboard-driven: ↑↓ navigate,
// ↩ (or click) opens the main window at the chosen moment, esc closes.
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

    private var hairline: Color { Color.white.opacity(0.06) }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                // TOP — borderless search row living directly inside the glass panel.
                SearchField(placeholder: "Describe a moment…", large: true, boxless: true)
                    .padding(.horizontal, Space.s)
                    .padding(.vertical, 3)
                    .frame(height: 62)

                // MIDDLE — results, or the recent/example queries when there's no query.
                // (No divider — the search row flows seamlessly into the list.)
                if search.hasQuery && !search.results.isEmpty {
                    resultsList(proxy: proxy)
                } else {
                    emptyState
                }

                // BOTTOM — footer action bar with brand mark + keycaps.
                footer
            }
            // Fixed width; the middle section fills, so the glass panel always fills the entire
            // window height (no transparent strip even if the window is title-bar-padded taller).
            .frame(width: 720)
            .frame(maxHeight: .infinity)
            .background(.ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
            )
            .floatingShadow()
            .tint(Color.brand)
            // Spotlight chrome: no traffic-light buttons, floats above, draggable by background.
            .background(LauncherWindowConfigurator())
            .onMoveCommand { direction in move(direction, proxy: proxy) }
            .onKeyPress(.return) {
                if let r = selectedResult { open(r) }
                return .handled
            }
            // esc dismisses the launcher, exactly like Spotlight.
            .onExitCommand { dismissWindow(id: "launcher") }
            // Fill the whole window — no leftover title-bar strip above the glass panel.
            .ignoresSafeArea()
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
            VStack(spacing: 2) {
                ForEach(visibleResults) { r in
                    Button { open(r) } label: {
                        resultRow(r)
                    }
                    .buttonStyle(.plain)
                    .onHover { if $0 { selectedID = r.id } }
                    .id(r.id)
                }
            }
            .padding(Space.s)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func resultRow(_ r: SearchResult) -> some View {
        HStack(spacing: Space.m) {
            // Leading thumbnail with a timecode badge.
            thumbnail(r)

            // Middle — filename + path · timecode.
            VStack(alignment: .leading, spacing: 2) {
                Text(r.videoName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Text("\(r.prettyPath) · \(r.timecode)")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: Space.s)

            // Trailing — relevance.
            Text("\(Int(r.normalizedScore * 100))%")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(r.id == selectedID ? Color.white.opacity(0.10) : Color.clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    @ViewBuilder private func thumbnail(_ r: SearchResult) -> some View {
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
        Image(nsImage: r.thumbnail)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 64, height: 40)
            .clipShape(shape)
        .overlay(alignment: .bottomTrailing) {
            Text(r.timecode)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.black.opacity(0.55),
                            in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                .padding(3)
        }
    }

    // MARK: - Empty state (no query)

    private var emptyState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                Text("TRY")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(Color.textTertiary)
                    .padding(.horizontal, 12)
                    .padding(.top, Space.s)
                    .padding(.bottom, Space.xs)

                ForEach(emptyQueries, id: \.self) { query in
                    Button { search.runExample(query) } label: {
                        queryRow(query)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Space.s)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func queryRow(_ query: String) -> some View {
        HoverRow { hovering in
            HStack(spacing: Space.m) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                Text(query)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(hovering ? Color.white.opacity(0.06) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
    }

    // Recent searches first (if any), then the curated examples. Dedupe while preserving order.
    private var emptyQueries: [String] {
        var seen = Set<String>()
        return (search.recentSearches + search.examples).filter { seen.insert($0).inserted }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: Space.m) {
            // Brand mark — a film glyph behind a magnifying glass.
            HStack(spacing: Space.s) {
                ZStack {
                    Image(systemName: "film")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.3))
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text("Tafuta")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            // Keycaps.
            Button { if let r = selectedResult { open(r) } } label: {
                keycapPair(label: "Open") { KBD(key: "↩") }
            }
            .buttonStyle(.plain)

            keycapPair(label: "Actions") {
                HStack(spacing: 2) { KBD(key: "⌘"); KBD(key: "K") }
            }

            keycapPair(label: nil) { KBD(key: "esc") }
        }
        .padding(.horizontal, Space.m)
        .frame(height: 46)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.03))
        .overlay(alignment: .top) { hairline.frame(height: 1) }
    }

    @ViewBuilder
    private func keycapPair<K: View>(label: String?, @ViewBuilder keys: () -> K) -> some View {
        HStack(spacing: Space.xs) {
            keys()
            if let label {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }

    // MARK: - Actions

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

// Lightweight hover wrapper so empty-state query rows can highlight without polluting selectedID.
private struct HoverRow<Content: View>: View {
    @ViewBuilder var content: (Bool) -> Content
    @State private var hovering = false
    var body: some View {
        content(hovering)
            .onHover { hovering = $0 }
    }
}
