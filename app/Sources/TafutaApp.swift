import SwiftUI
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    // Global hotkey to summon the launcher from anywhere (user-customizable).
    static let summon = Self("summonLauncher", default: .init(.k, modifiers: [.command, .shift]))
}

@main
struct TafutaApp: App {
    @StateObject private var search = SearchCore()

    var body: some Scene {
        WindowGroup(id: "main") {
            MainWindow()
                .environmentObject(search)
                .frame(minWidth: 820, minHeight: 560)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1040, height: 700)
        .defaultPosition(.center)
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
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        MenuBarExtra("Tafuta", systemImage: "sparkle.magnifyingglass") {
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
