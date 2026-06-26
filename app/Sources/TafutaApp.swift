import SwiftUI

@main
struct TafutaApp: App {
    @StateObject private var search = SearchCore()

    var body: some Scene {
        // Main window.
        WindowGroup(id: "main") {
            MainWindow()
                .environmentObject(search)
                .frame(minWidth: 820, minHeight: 560)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1040, height: 700)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Quick Search…") { openLauncher() }
                    .keyboardShortcut("k", modifiers: .command)
            }
        }

        // Floating launcher (Phase 2: summoned by a global hotkey from anywhere).
        Window("Quick Search", id: "launcher") {
            LauncherView()
                .environmentObject(search)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        // Menu-bar status item.
        MenuBarExtra("Tafuta", systemImage: "sparkle.magnifyingglass") {
            MenuBarView()
                .environmentObject(search)
        }
        .menuBarExtraStyle(.window)
    }

    private func openLauncher() {
        // Bridge to AppKit to focus/raise the launcher window.
        NSApp.activate(ignoringOtherApps: true)
    }
}
