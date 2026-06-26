import SwiftUI

// The shared search input — a clean inset field with a leading glyph. Submits on change.
struct SearchField: View {
    @EnvironmentObject var search: SearchCore
    var placeholder: String = "Describe a moment…"
    var large: Bool = false
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: Space.s) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: large ? 16 : 13, weight: .medium))
                .foregroundStyle(Color.textTertiary)

            TextField(placeholder, text: $search.query)
                .textFieldStyle(.plain)
                .font(.system(size: large ? 18 : 14, weight: .regular))
                .foregroundStyle(Color.textPrimary)
                .focused($focused)
                .onSubmit { search.runSearch() }
                .onChange(of: search.query) { _, _ in search.runSearch() }

            if search.hasQuery {
                Button { search.query = ""; search.runSearch() } label: {
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
                   border: focused ? .borderStrong : .borderDefault)
        .animation(Motion.quick, value: focused)
        .onAppear { focused = true }
    }
}
