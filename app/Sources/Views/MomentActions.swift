import SwiftUI

// Canonical action set for a moment, shared by the ActionBar (⌘K panel) on every surface so the
// actions + shortcuts are identical everywhere (Raycast consistency).
enum MomentActions {
    @MainActor static func primary(_ r: SearchResult, _ search: SearchCore) -> ActionItem {
        ActionItem(title: "Play", systemImage: "play.fill", shortcut: ["↩"]) {
            search.select(r); search.playInline()
        }
    }

    @MainActor static func all(_ r: SearchResult, _ search: SearchCore) -> [ActionItem] {
        [
            ActionItem(title: "Play at \(r.timecode)", systemImage: "play.fill", shortcut: ["↩"]) {
                search.select(r); search.playInline()
            },
            ActionItem(title: "Find Similar Moments", systemImage: "square.on.square") {
                search.findSimilar(to: r)
            },
            ActionItem(title: "Export Clip…", systemImage: "scissors") { search.exportClip(r) },
            ActionItem(title: "Save Frame…", systemImage: "photo") { search.saveFrame(r) },
            ActionItem(title: "Copy Timestamp Link", systemImage: "link") { search.copyLink(r) },
            ActionItem(title: "Reveal in Finder", systemImage: "folder") { search.reveal(r) },
            ActionItem(title: "Remove", systemImage: "trash", isDestructive: true) {
                search.removeFromIndex(r)
            },
        ]
    }
}
