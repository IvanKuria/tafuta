import SwiftUI

// The shared search input — a clean inset field with a leading glyph. Debounced live search.
struct SearchField: View {
    @EnvironmentObject var search: SearchCore
    var placeholder: String = "Describe a moment…"
    var large: Bool = false
    @FocusState private var focused: Bool
    @State private var debounce: Task<Void, Never>?

    var body: some View {
        HStack(spacing: Space.s) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: large ? 16 : 13, weight: .medium))
                .foregroundStyle(Color.textTertiary)

            TextField(placeholder, text: $search.query)
                .textFieldStyle(.plain)
                .font(.system(size: large ? 18 : 13, weight: .regular))
                .tracking(large ? -0.2 : 0)
                .foregroundStyle(Color.textPrimary)
                .focused($focused)
                .onSubmit { runNow() }
                .onChange(of: search.query) { _, _ in scheduleSearch() }

            if search.hasQuery {
                Button { search.query = ""; runNow() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: large ? 15 : 12))
                        .foregroundStyle(Color.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Space.m)
        .padding(.vertical, large ? Space.m : Space.s)
        .cardStyle(radius: large ? Radius.sheet : Radius.control,
                   fill: .bgInset,
                   border: focused ? .brand : .borderDefault)
        .animation(Motion.quick, value: focused)
        .onAppear { focused = true }
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
