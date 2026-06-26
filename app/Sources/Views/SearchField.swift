import SwiftUI

// The shared search input. Two personalities from one view:
//   • small  — a quiet inset field that lives in the top bar.
//   • large  — a tall, roomy Raycast-style launcher input (⌘⇧K).
// Live search is debounced (~180ms); ⏎ runs immediately; the trailing clear
// button resets the query. Autofocuses on appear.
struct SearchField: View {
    @EnvironmentObject var search: SearchCore
    var placeholder: String = "Describe a moment…"
    var large: Bool = false
    @FocusState private var focused: Bool
    @State private var debounce: Task<Void, Never>?

    // Tuned per-variant so the small field stays compact and the large one
    // feels generous, like a dedicated command bar.
    private var glyphSize: CGFloat { large ? 19 : 13 }
    private var fontSize:  CGFloat { large ? 19 : 14 }
    private var radius:    CGFloat { large ? Radius.sheet : Radius.control }
    private var vPad:      CGFloat { large ? Space.m : Space.s }

    var body: some View {
        HStack(spacing: large ? Space.m : Space.s) {
            // Leading affordance. Lifts toward the brand graphite when focused
            // so the whole field reads as "active".
            Image(systemName: "magnifyingglass")
                .font(.system(size: glyphSize, weight: .medium))
                .foregroundStyle(focused ? Color.textSecondary : Color.textTertiary)

            TextField(placeholder, text: $search.query)
                .textFieldStyle(.plain)
                .font(.system(size: fontSize, weight: large ? .medium : .regular))
                .tracking(large ? -0.3 : 0)
                .foregroundStyle(Color.textPrimary)
                .focused($focused)
                .onSubmit { runNow() }
                .onChange(of: search.query) { _, _ in scheduleSearch() }

            trailing
        }
        .padding(.horizontal, Space.m)
        .padding(.vertical, vPad)
        .background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(large ? Color.bgSurface : Color.bgInset)
        )
        .overlay(
            // Single continuous border that warms to the brand accent on focus.
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(focused ? Color.brand : Color.borderDefault,
                              lineWidth: focused ? 1.5 : 1)
        )
        // Subtle elevation so the field floats above its surface; deepen on focus.
        .softShadow(focused && large ? 2 : 1)
        .animation(Motion.quick, value: focused)
        .onAppear { focused = true }
    }

    // Trailing cluster. The clear button appears whenever there's a query; the
    // large launcher also shows a quiet `esc` hint as a dismiss affordance.
    @ViewBuilder private var trailing: some View {
        HStack(spacing: Space.s) {
            if search.hasQuery {
                Button { search.query = ""; runNow() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: large ? 16 : 12))
                        .foregroundStyle(Color.textTertiary)
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.7)))
            }

            if large && !search.hasQuery {
                KBD(key: "esc")
                    .opacity(0.8)
                    .transition(.opacity)
            }
        }
        .animation(Motion.quick, value: search.hasQuery)
    }

    // Debounce ~180ms so we don't embed+rank on every keystroke (smooth on large libraries).
    private func scheduleSearch() {
        debounce?.cancel()
        debounce = Task {
            try? await Task.sleep(nanoseconds: 180_000_000)
            if !Task.isCancelled { search.runSearch() }
        }
    }

    private func runNow() {
        debounce?.cancel()
        search.runSearch()
    }
}
