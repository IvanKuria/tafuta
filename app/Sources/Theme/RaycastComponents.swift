import SwiftUI
import AppKit

// Raycast-style presentational components. Surface-color depth, 1px hairlines, NO drop shadows,
// Inter type, keycaps, monochrome chrome (accent reserved). Pure data + closures in — no app state.
// All tokens/components (Color.*, Space, Radius, Typo, Motion, KBD) are defined elsewhere.

// MARK: - ActionItem

/// A single command/action: title, glyph, optional keycap shortcut, and what to do when invoked.
struct ActionItem: Identifiable {
    let id = UUID()
    var title: String
    var systemImage: String
    var shortcut: [String] = []
    var isDestructive = false
    var perform: () -> Void
}

// MARK: - CommandRow

/// A command-palette row: optional thumbnail or glyph, title/subtitle, trailing accessories + keycap.
struct CommandRow: View {
    var thumbnail: NSImage? = nil
    var icon: String? = nil
    var title: String
    var subtitle: String? = nil
    var accessories: [String] = []
    var trailingKey: String? = nil
    var selected: Bool = false

    var body: some View {
        HStack(spacing: Space.m) {
            leading

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(Typo.callout)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(Typo.caption)
                        .foregroundStyle(Color.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: Space.s)

            ForEach(accessories, id: \.self) { accessory in
                Text(accessory)
                    .font(Typo.caption)
                    .foregroundStyle(Color.textTertiary)
            }
            if let trailingKey {
                KBD(key: trailingKey)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            selected ? Color.bgInset : .clear,
            in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder private var leading: some View {
        if let thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 44, height: 26)
                .clipShape(RoundedRectangle(cornerRadius: Radius.tag, style: .continuous))
        } else if let icon {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.textSecondary)
                .frame(width: 20)
        }
    }
}

// MARK: - ActionPanel

/// A ~280pt vertical list of actions (the ⌘K menu). Each row hover-highlights; tapping performs
/// the action then dismisses.
struct ActionPanel: View {
    var items: [ActionItem]
    var dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Actions")
                .font(Typo.caption)
                .foregroundStyle(Color.textTertiary)
                .padding(.horizontal, 8)
                .padding(.bottom, Space.xxs)

            ForEach(items) { item in
                ActionPanelRow(item: item, dismiss: dismiss)
            }
        }
        .padding(Space.s)
        .frame(width: 280)
        .background(Color.bgSurfaceElevated)
    }
}

/// One ActionPanel row, isolated so hover state is per-row.
private struct ActionPanelRow: View {
    let item: ActionItem
    let dismiss: () -> Void
    @State private var hovering = false

    var body: some View {
        Button {
            item.perform()
            dismiss()
        } label: {
            HStack {
                Image(systemName: item.systemImage)
                    .foregroundStyle(item.isDestructive ? .red : Color.textSecondary)
                    .frame(width: 18)
                Text(item.title)
                    .font(Typo.body)
                    .foregroundStyle(item.isDestructive ? .red : Color.textPrimary)
                Spacer()
                ForEach(item.shortcut, id: \.self) { KBD(key: $0) }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                hovering ? Color.bgInset : .clear,
                in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// MARK: - ActionBar

/// Bottom action bar: app glyph + context on the left; primary action, divider, and the ⌘K
/// Actions popover on the right. A hairline tops the bar.
struct ActionBar: View {
    var appGlyph: String = "magnifyingglass"
    var contextTitle: String? = nil
    var primary: ActionItem? = nil
    var actions: [ActionItem] = []

    @State private var showActions = false

    var body: some View {
        HStack(spacing: Space.m) {
            Image(systemName: appGlyph)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.textTertiary)
            if let contextTitle {
                Text(contextTitle)
                    .font(Typo.caption)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            if let primary {
                Button {
                    primary.perform()
                } label: {
                    HStack(spacing: Space.xs) {
                        Text(primary.title)
                            .font(Typo.caption)
                            .foregroundStyle(Color.textPrimary)
                        KBD(key: "↩")
                    }
                }
                .buttonStyle(.plain)
            }

            if !actions.isEmpty {
                Rectangle()
                    .fill(Color.borderDefault)
                    .frame(width: 1, height: 16)

                Button {
                    showActions.toggle()
                } label: {
                    HStack(spacing: Space.xs) {
                        Text("Actions")
                            .font(Typo.caption)
                            .foregroundStyle(Color.textSecondary)
                        KBD(key: "⌘")
                        KBD(key: "K")
                    }
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showActions, arrowEdge: .bottom) {
                    ActionPanel(items: actions) { showActions = false }
                }
            }

            // Hidden hotkey: ⌘K opens the Actions popover.
            Button("") {
                if !actions.isEmpty { showActions = true }
            }
            .keyboardShortcut("k", modifiers: .command)
            .opacity(0)
            .frame(width: 0, height: 0)
        }
        .frame(height: 40)
        .padding(.horizontal, Space.m)
        .background(Color.bgSurfaceElevated)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.borderDefault).frame(height: 1)
        }
    }
}

// MARK: - DetailMetadata

/// A label/value metadata list with hairline dividers between (not after) rows.
struct DetailMetadata: View {
    var pairs: [(label: String, value: String)]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(pairs.enumerated()), id: \.offset) { index, pair in
                HStack {
                    Text(pair.label)
                        .font(Typo.caption)
                        .foregroundStyle(Color.textTertiary)
                    Spacer()
                    Text(pair.value)
                        .font(Typo.caption)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.vertical, Space.s)

                if index < pairs.count - 1 {
                    Divider().overlay(Color.borderSubtle)
                }
            }
        }
    }
}
