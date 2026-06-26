import SwiftUI

// Floating ⌘⇧K command palette — a Raycast-style launcher with LARGE inline previews so a
// match is recognisable at a glance, without ever opening the main window. Fully keyboard-driven:
// ↑↓ navigate, ↩ (or click) opens the main window at the chosen moment, esc closes.
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

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                SearchField(placeholder: "Describe a moment…", large: true)
                    .padding(Space.m)

                if search.hasQuery && !search.results.isEmpty {
                    Divider().overlay(Color.borderSubtle)

                    ScrollView {
                        VStack(spacing: Space.xs) {
                            ForEach(visibleResults) { result in
                                LauncherRow(result: result,
                                            selected: result.id == selectedID,
                                            onHover: { selectedID = result.id },
                                            onOpen: { open(result) })
                                    .id(result.id)
                            }
                        }
                        .padding(Space.s)
                    }
                    .frame(maxHeight: 360)
                } else {
                    emptyState
                }

                footer
            }
            .frame(width: 640)
            .background(.ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous)
                    .strokeBorder(Color.borderDefault, lineWidth: 1)
            )
            .floatingShadow()
            .tint(Color.brand)
            .onMoveCommand { direction in move(direction, proxy: proxy) }
            .onKeyPress(.return) { openSelected(); return .handled }
            .onAppear { selectedID = search.results.first?.id }
            .onChange(of: search.results) { _, results in
                // Keep the cursor valid as live results stream in / change.
                if selectedID == nil || !results.contains(where: { $0.id == selectedID }) {
                    selectedID = results.first?.id
                }
            }
        }
    }

    // MARK: - Empty state (no query)

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("Search your footage by describing what you remember.")
                .font(Typo.callout)
                .foregroundStyle(Color.textTertiary)

            if !search.recentSearches.isEmpty {
                exampleSection("Recent", search.recentSearches, icon: "clock")
            }
            exampleSection("Try", search.examples, icon: "sparkles")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.m)
        .padding(.bottom, Space.m)
    }

    private func exampleSection(_ title: String, _ items: [String], icon: String) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(title.uppercased())
                .font(Typo.caption)
                .foregroundStyle(Color.textTertiary)
            FlowChips(items: items, icon: icon) { search.runExample($0) }
        }
    }

    // MARK: - Actions

    private func open(_ result: SearchResult) {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
        search.select(result)
        dismissWindow(id: "launcher")
    }

    private func openSelected() {
        guard let id = selectedID,
              let result = search.results.first(where: { $0.id == id }) else { return }
        open(result)
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

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: Space.s) {
            hint("↩", "Open")
            dot
            hint("↑↓", "Navigate")
            dot
            hint("esc", "Close")
            Spacer()
        }
        .padding(.horizontal, Space.m)
        .padding(.vertical, Space.s)
        .overlay(alignment: .top) { Divider().overlay(Color.borderSubtle) }
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: Space.xs) {
            KBD(key: key)
            Text(label).font(Typo.caption).foregroundStyle(Color.textTertiary)
        }
    }

    private var dot: some View {
        Text("·").font(Typo.caption).foregroundStyle(Color.textTertiary)
    }
}

// MARK: - Row

struct LauncherRow: View {
    let result: SearchResult
    var selected: Bool = false
    var onHover: () -> Void = {}
    var onOpen: () -> Void = {}

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: Space.m) {
                Image(nsImage: result.thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 128, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                        .strokeBorder(Color.borderSubtle, lineWidth: 1))

                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(result.videoName)
                        .font(Typo.callout)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(result.timecode)
                        .font(Typo.mono)
                        .foregroundStyle(Color.textTertiary)
                }

                Spacer(minLength: Space.s)

                Pill(text: "\(Int(result.normalizedScore * 100))% match", tint: .brand, filled: true)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(Space.s)
            .background(selected ? Color.bgSurface : .clear,
                        in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { if $0 { onHover() } }
    }
}

// MARK: - Wrapping chip layout for example / recent queries

private struct FlowChips: View {
    let items: [String]
    var icon: String
    var action: (String) -> Void

    var body: some View {
        // A simple wrapping layout via FlowLayout (macOS 14 `Layout`).
        FlowLayout(spacing: Space.s) {
            ForEach(items, id: \.self) { item in
                Button { action(item) } label: {
                    Pill(text: item, systemImage: icon)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// Minimal flow (wrapping) layout — keeps example chips tidy without hard-coding rows.
private struct FlowLayout: Layout {
    var spacing: CGFloat = Space.s

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading,
                          proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
