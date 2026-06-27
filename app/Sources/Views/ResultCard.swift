import SwiftUI

// Raycast Grid-view tile: a frame thumbnail with filename + match. Depth/selection come from the
// surface ladder (bgInset fill), not a colored ring or shadow. Actions live in the ActionBar/⌘K
// and the right-click menu. Equatable on (id, selected) so selection re-renders only the two
// affected tiles.
struct ResultCard: View, Equatable {
    let result: SearchResult
    var selected: Bool = false
    var onSelect: () -> Void = {}
    var onPlay: () -> Void = {}
    var actions: [ActionItem] = []
    @State private var hovering = false

    static func == (l: ResultCard, r: ResultCard) -> Bool {
        l.result.id == r.result.id && l.selected == r.selected
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Image(nsImage: result.thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: 128)
                .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    HStack(spacing: Space.xs) {
                        if !result.durationLabel.isEmpty { badge(result.durationLabel) }
                        badge(result.timecode)
                    }
                    .padding(Space.xs)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                        .strokeBorder(Color.borderSubtle, lineWidth: 1)
                )

            HStack(spacing: Space.xs) {
                Text(result.videoName)
                    .font(Typo.caption).foregroundStyle(Color.textPrimary)
                    .lineLimit(1).truncationMode(.middle)
                Spacer(minLength: Space.xs)
                Text("\(Int(result.normalizedScore * 100))%")
                    .font(Typo.mono).foregroundStyle(Color.textTertiary)
            }
        }
        .padding(Space.s)
        .background((selected || hovering) ? Color.bgInset : .clear,
                    in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay {
            if selected {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(Color.borderStrong, lineWidth: 1)
            }
        }
        .animation(Motion.quick, value: hovering)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(perform: onSelect)
        .simultaneousGesture(TapGesture(count: 2).onEnded { onPlay() })
        .onDrag { NSItemProvider(object: result.thumbnail) }
        .contextMenu {
            ForEach(actions) { a in
                Button(role: a.isDestructive ? .destructive : nil, action: a.perform) {
                    Label(a.title, systemImage: a.systemImage)
                }
            }
        }
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(Typo.mono)
            .foregroundStyle(.white)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(.black.opacity(0.6), in: Capsule())
    }
}
