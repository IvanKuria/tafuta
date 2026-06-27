import SwiftUI

// The shared search input. Two personalities from one view:
//   • small — a quiet inset field in the top bar.
//   • large — a tall Raycast-style launcher input (⌘⇧K).
// PERF: the TextField is bound to LOCAL @State, not to the shared SearchCore. A keystroke
// therefore only re-renders this field — not the launcher rows, the result grid, or any other
// observer of SearchCore. The (debounced) query is pushed to the engine once typing settles.
struct SearchField: View {
    @EnvironmentObject var search: SearchCore
    var placeholder: String = "Describe a moment…"
    var large: Bool = false

    @FocusState private var focused: Bool
    @State private var text: String = ""
    @State private var debounce: Task<Void, Never>?

    private var glyphSize: CGFloat { large ? 19 : 13 }
    private var fontSize:  CGFloat { large ? 19 : 14 }
    private var radius:    CGFloat { large ? Radius.sheet : Radius.control }
    private var vPad:      CGFloat { large ? Space.m : Space.s }

    var body: some View {
        HStack(spacing: large ? Space.m : Space.s) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: glyphSize, weight: .medium))
                .foregroundStyle(focused ? Color.textSecondary : Color.textTertiary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: fontSize, weight: large ? .medium : .regular))
                .tracking(large ? -0.3 : 0)
                .foregroundStyle(Color.textPrimary)
                .focused($focused)
                .onSubmit { commit() }
                .onChange(of: text) { _, new in scheduleSearch(new) }

            trailing
        }
        .padding(.horizontal, Space.m)
        .padding(.vertical, vPad)
        .background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(large ? Color.bgSurface : Color.bgInset)
        )
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(focused ? Color.brand : Color.borderDefault, lineWidth: focused ? 1.5 : 1)
        )
        .animation(Motion.quick, value: focused)
        .onAppear { text = search.query; focused = true }
        // Reflect external query changes (example / recent chips) back into the field.
        .onChange(of: search.query) { _, q in if q != text { text = q } }
    }

    @ViewBuilder private var trailing: some View {
        HStack(spacing: Space.s) {
            if !text.isEmpty {
                Button { text = ""; commit() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: large ? 16 : 12))
                        .foregroundStyle(Color.textTertiary)
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.7)))
            }
            if large && text.isEmpty {
                KBD(key: "esc").opacity(0.8).transition(.opacity)
            }
        }
        .animation(Motion.quick, value: text.isEmpty)
    }

    // Debounce ~180ms; push to the engine and run search off the main thread.
    private func scheduleSearch(_ new: String) {
        debounce?.cancel()
        debounce = Task {
            try? await Task.sleep(nanoseconds: 180_000_000)
            if Task.isCancelled { return }
            search.query = new
            search.runSearch()
        }
    }

    private func commit() {
        debounce?.cancel()
        search.query = text
        search.runSearch(record: true)
    }
}
