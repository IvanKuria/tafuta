import SwiftUI
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    // Global hotkey to summon the launcher from anywhere (user-customizable).
    static let summon = Self("summonLauncher", default: .init(.k, modifiers: [.command, .shift]))
}

@main
struct TafutaApp: App {
    @StateObject private var search = SearchCore()

    init() { AppFonts.register() }

    var body: some Scene {
        // Single-instance Window (NOT WindowGroup) — otherwise openWindow(id:"main") from the
        // launcher spawns a brand-new window each time instead of focusing the existing one.
        Window("Tafuta", id: "main") {
            MainWindow()
                .environmentObject(search)
                .frame(minWidth: 920, minHeight: 620)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 820)
        .defaultPosition(.center)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Quick Search…") { NSApp.activate(ignoringOtherApps: true) }
                    .keyboardShortcut("k", modifiers: .command)
            }
        }

        // Floating launcher — summoned in-app (⌘K) or via the global hotkey.
        Window("Quick Search", id: "launcher") {
            LauncherView()
                .environmentObject(search)
        }
        .windowStyle(.hiddenTitleBar)
        // NOT .contentSize — that re-adds the hidden title-bar height to the window frame, leaving
        // a transparent strip. We size the window ourselves in LauncherWindowConfigurator.
        .windowResizability(.contentMinSize)
        .defaultPosition(.center)

        MenuBarExtra("Tafuta", systemImage: "magnifyingglass") {
            MenuBarView()
                .environmentObject(search)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}

// Settings: let users rebind the global hotkey.
struct SettingsView: View {
    var body: some View {
        Form {
            LabeledContent("Summon search") {
                KeyboardShortcuts.Recorder(for: .summon)
            }
        }
        .padding(Space.xl)
        .frame(width: 380)
        .tint(Color.brand)
    }
}
