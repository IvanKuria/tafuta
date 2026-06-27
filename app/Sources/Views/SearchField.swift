import SwiftUI

// Shared search input. The compact version is tuned for a macOS toolbar; the large version
// powers the floating quick-search window.
// PERF: the TextField is bound to LOCAL @State, not to the shared SearchCore. A keystroke
// therefore only re-renders this field — not the launcher rows, the result grid, or any other
// observer of SearchCore. The (debounced) query is pushed to the engine once typing settles.
struct SearchField: View {
    @EnvironmentObject var search: SearchCore
    var placeholder: String = "Describe a moment…"
    var large: Bool = false
    var autoFocus: Bool = true
    var autoIndexMacWhenNeeded: Bool = false
    // When true the field paints NO chrome (no material, border, or glow). Used inside the
    // floating launcher panel, which already supplies its own glass backdrop.
    var boxless: Bool = false

    @FocusState private var focused: Bool
    @State private var text: String = ""
    @State private var debounce: Task<Void, Never>?
    @State private var syncingExternalText = false

    // Tahoe-style metrics: a soft glass field, not a hard dark box.
    private var glyphSize: CGFloat { large ? 21 : 17 }
    private var fontSize:  CGFloat { large ? 18 : 15 }
    private var fieldHeight: CGFloat { large ? 56 : 44 }
    private var radius:    CGFloat { large ? 15 : 12 }

    var body: some View {
        HStack(spacing: large ? Space.m : Space.s) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: glyphSize, weight: .medium))
                .foregroundStyle(focused ? Color.textSecondary : Color.textTertiary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: fontSize, weight: .regular))
                .foregroundStyle(Color.textPrimary)
                .focused($focused)
                .onSubmit { commit() }
                .onChange(of: text) { _, new in scheduleSearch(new) }

            trailing
        }
        .padding(.horizontal, Space.l)
        .frame(height: fieldHeight)
        .background(fieldBackground)
        .overlay(fieldBorder)
        .animation(Motion.quick, value: focused)
        .onAppear {
            text = search.query
            focused = autoFocus
        }
        // Reflect external query changes (example / recent chips) back into the field.
        .onChange(of: search.query) { _, q in
            if q != text {
                syncingExternalText = true
                text = q
            }
        }
    }

    // A translucent glass fill that reads slightly brighter than the canvas; brighter on focus.
    @ViewBuilder private var fieldBackground: some View {
        if boxless {
            Color.clear
        } else {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(Color.white.opacity(focused ? 0.05 : 0.0))
                )
        }
    }

    // Hairline border; a slightly brighter (still monochrome) hairline when focused. No glow.
    @ViewBuilder private var fieldBorder: some View {
        if !boxless {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(Color.white.opacity(focused ? 0.20 : 0.08), lineWidth: 1)
        }
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
                Text("esc")
                    .font(.system(size: 11, weight: .medium).monospaced())
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.white.opacity(0.07),
                                in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1))
                    .transition(.opacity)
            }
        }
        .animation(Motion.quick, value: text.isEmpty)
    }

    // Debounce ~180ms; push to the engine and run search off the main thread.
    private func scheduleSearch(_ new: String) {
        if syncingExternalText {
            syncingExternalText = false
            return
        }
        debounce?.cancel()
        debounce = Task {
            try? await Task.sleep(nanoseconds: 180_000_000)
            if Task.isCancelled { return }
            search.query = new
            if autoIndexMacWhenNeeded,
               !search.hasIndex,
               !search.isIndexing,
               !new.trimmingCharacters(in: .whitespaces).isEmpty {
                search.indexMacVideos()
            }
            search.runSearch()
        }
    }

    private func commit() {
        debounce?.cancel()
        search.query = text
        if autoIndexMacWhenNeeded,
           !search.hasIndex,
           !search.isIndexing,
           !text.trimmingCharacters(in: .whitespaces).isEmpty {
            search.indexMacVideos()
        }
        search.runSearch(record: true)
    }
}
