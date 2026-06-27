import SwiftUI
import AppKit

// The custom, content-first top bar for Tafuta. The window uses `.hiddenTitleBar`, so the
// macOS traffic lights overlay the top-left — we reserve space for them and keep empty areas
// window-draggable. Aesthetic: clean, monochrome, single blue accent, native vibrancy.
struct TopBar: View {
    @EnvironmentObject var search: SearchCore

    // Width reserved for the overlaid traffic lights at the leading edge.
    private let trafficLightInset: CGFloat = 72
    private let barHeight: CGFloat = 52

    var body: some View {
        HStack(spacing: Space.m) {
            // Reserve the traffic-light zone (window controls overlay here).
            Color.clear.frame(width: trafficLightInset, height: 1)

            SearchField()
                .frame(maxWidth: 520)

            statusPill

            Spacer(minLength: Space.s)

            trailingControls
        }
        .padding(.horizontal, Space.m)
        .frame(height: barHeight)
        .frame(maxWidth: .infinity)
        // Same canvas as the content — the top bar flows seamlessly into the grid (no header
        // band, no divider). Canvas paints the black; the drag backing (click-through canvas on
        // top) lets empty areas move the window.
        .background(WindowDragArea())   // drag backing; the window's frosted vibrancy shows through
    }

    // MARK: - Status pill

    @ViewBuilder
    private var statusPill: some View {
        if search.isIndexing {
            HStack(spacing: Space.xs) {
                ProgressView().controlSize(.mini)
                Pill(text: "Indexing…")
            }
        } else if search.hasIndex {
            Pill(text: "Ready", systemImage: "checkmark.circle")
        } else {
            Pill(text: "No videos yet")
        }
    }

    // MARK: - Trailing controls

    private var trailingControls: some View {
        HStack(spacing: Space.s) {
            groupingMenu
            strictnessMenu

            iconButton("folder.badge.plus", help: "Add a folder of videos to index") {
                search.addFolder()
            }

            iconButton("sidebar.right", help: "Toggle inspector") {
                search.toggleInspector()
            }
            .keyboardShortcut("i", modifiers: .command)

            SettingsLink {
                Image(systemName: "gearshape")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
    }

    private var groupingMenu: some View {
        Menu {
            Button { search.grouping = .grouped } label: {
                Label("Grouped", systemImage: search.grouping == .grouped ? "checkmark" : "square.grid.2x2")
            }
            Button { search.grouping = .flat } label: {
                Label("Flat", systemImage: search.grouping == .flat ? "checkmark" : "rectangle.grid.1x2")
            }
        } label: {
            Pill(text: search.grouping == .grouped ? "Grouped" : "Flat",
                 systemImage: "square.grid.2x2")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Group results by source video")
    }

    private var strictnessMenu: some View {
        Menu {
            Button { setStrictness(0.10) } label: {
                Label("Loose", systemImage: strictnessLabel == "Loose" ? "checkmark" : "circle")
            }
            Button { setStrictness(0.18) } label: {
                Label("Balanced", systemImage: strictnessLabel == "Balanced" ? "checkmark" : "circle")
            }
            Button { setStrictness(0.26) } label: {
                Label("Strict", systemImage: strictnessLabel == "Strict" ? "checkmark" : "circle")
            }
        } label: {
            Pill(text: "Match: \(strictnessLabel)", systemImage: "slider.horizontal.3")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("How closely results must match the query")
    }

    private var strictnessLabel: String {
        if search.strictness < 0.14 { return "Loose" }
        if search.strictness < 0.22 { return "Balanced" }
        return "Strict"
    }

    private func setStrictness(_ value: Double) {
        search.strictness = value
        search.runSearch()
    }

    // A hairline-free plain icon button (~28×28).
    private func iconButton(_ systemName: String,
                            help: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.textSecondary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

// Transparent backing whose mouse-downs drag the window. Placed behind the bar so empty
// regions (and the Spacer) move the window, while controls on top still receive clicks.
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        final class DragView: NSView { override var mouseDownCanMoveWindow: Bool { true } }
        return DragView()
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
