import SwiftUI
import KeyboardShortcuts

// First-run onboarding overlay for Tafuta. Rendered as an overlay on the main
// window (NOT a sheet) so it floats above the app chrome with a dimmed backdrop.
// It teaches the global launcher shortcut (default ⌘⇧K) and nudges the user to
// index their first folder. Self-dismissing once an index exists or the shortcut
// fires, and persists its "seen" state via @AppStorage.
struct OnboardingModal: View {
    @AppStorage("tafuta.hasOnboarded") private var hasOnboarded = false
    @EnvironmentObject var search: SearchCore

    // Drives the entrance transition + the gentle hero pulse.
    @State private var appeared = false
    @State private var pulse = false

    var body: some View {
        if hasOnboarded {
            EmptyView()
        } else {
            overlay
        }
    }

    private var overlay: some View {
        ZStack {
            // Dimmed full-bleed backdrop. Tapping outside is intentionally inert —
            // onboarding is dismissed only via "Got it" or an explicit action.
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            card
                .frame(maxWidth: 420)
                .padding(Space.xl)
                .scaleEffect(appeared ? 1 : 0.94)
                .opacity(appeared ? 1 : 0)
        }
        .transition(.opacity)
        .onAppear {
            withAnimation(Motion.spring) { appeared = true }
            // Gentle 1.0 ↔ 1.06 breathing on the hero chip.
            withAnimation(Motion.gentle.repeatForever(autoreverses: true)) { pulse = true }
            // Triggering the launcher shortcut also dismisses onboarding.
            // (v1: acceptable that this swaps the handler; MainWindow re-registers on its own appear.)
            KeyboardShortcuts.onKeyUp(for: .summon) { hasOnboarded = true }
        }
        // Auto-dismiss once content exists — either signal is sufficient.
        .onChange(of: search.hasIndex) { _, has in
            if has { hasOnboarded = true }
        }
        .onChange(of: search.indexedCount) { _, count in
            if count > 0 { hasOnboarded = true }
        }
    }

    private var card: some View {
        VStack(spacing: Space.l) {
            IconChip(systemName: "sparkle.magnifyingglass", tint: .brand, size: 64)
                .scaleEffect(pulse ? 1.06 : 1.0)

            VStack(spacing: Space.s) {
                Text("Welcome to Tafuta")
                    .font(Typo.title)
                    .foregroundStyle(Color.textPrimary)
                    .tracking(-0.4)

                Text("Search inside your videos by describing a moment. "
                     + "Everything stays on your Mac — no uploads, no account.")
                    .font(Typo.body)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            shortcutRow

            VStack(spacing: Space.s) {
                Button("Choose Folder…") { search.addFolder() }
                    .buttonStyle(PrimaryButtonStyle())

                Button("Got it") { hasOnboarded = true }
                    .buttonStyle(.plain)
                    .font(Typo.callout)
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.top, Space.xs)
        }
        .padding(Space.xl)
        .frame(maxWidth: 420)
        .cardStyle(fill: .bgSurfaceElevated)
        .floatingShadow()
    }

    // "Press [⌘][⇧][K] to search from anywhere" — keys read from the live shortcut.
    private var shortcutRow: some View {
        HStack(spacing: Space.xs) {
            Text("Press")
                .font(Typo.callout)
                .foregroundStyle(Color.textSecondary)

            ForEach(Array(shortcutKeys.enumerated()), id: \.offset) { _, key in
                KBD(key: key)
            }

            Text("to search from anywhere")
                .font(Typo.callout)
                .foregroundStyle(Color.textSecondary)
        }
    }

    // Split the resolved shortcut description into individual KBD chips. Falls back
    // to the default ⌘⇧K when the shortcut is unset. The description is a compact
    // glyph string (e.g. "⌘⇧K"), so we map each non-space character to a chip.
    private var shortcutKeys: [String] {
        let description = KeyboardShortcuts.getShortcut(for: .summon)?.description ?? "⌘⇧K"
        let glyphs = description.filter { !$0.isWhitespace }.map(String.init)
        return glyphs.isEmpty ? ["⌘", "⇧", "K"] : glyphs
    }
}
