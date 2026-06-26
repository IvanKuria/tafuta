import SwiftUI

// Floating Raycast/Spotlight-style launcher. Phase 1: a window scene; the global hotkey to
// summon it from anywhere is wired in Phase 2 (KeyboardShortcuts).
struct LauncherView: View {
    @EnvironmentObject var search: SearchCore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            SearchField(placeholder: "Find a moment…", large: true)
                .padding(Space.m)

            if search.hasQuery && !search.results.isEmpty {
                Divider().overlay(Color.borderSubtle)
                ScrollView {
                    VStack(spacing: Space.xs) {
                        ForEach(search.results.prefix(6)) { LauncherRow(result: $0) }
                    }
                    .padding(Space.s)
                }
                .frame(maxHeight: 320)
            }
        }
        .frame(width: 560)
        .background(.ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous)
                .strokeBorder(Color.borderDefault, lineWidth: 1)
        )
        .tint(Color.brand)
    }
}

struct LauncherRow: View {
    let result: SearchResult
    @State private var hovering = false
    var body: some View {
        HStack(spacing: Space.m) {
            RoundedRectangle(cornerRadius: Radius.tag, style: .continuous)
                .fill(Color.bgInset)
                .frame(width: 52, height: 30)
                .overlay(Image(systemName: "film").font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary))
            VStack(alignment: .leading, spacing: 1) {
                Text(result.videoName).font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.textPrimary).lineLimit(1).truncationMode(.middle)
                Text(result.timecode).font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(Color.textTertiary)
            }
            Spacer()
            Pill(text: String(format: "%.0f%%", min(result.score / 0.4, 1) * 100))
        }
        .padding(.horizontal, Space.s).padding(.vertical, Space.s)
        .background(hovering ? Color.bgSurface : .clear,
                    in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        .onHover { hovering = $0 }
    }
}
