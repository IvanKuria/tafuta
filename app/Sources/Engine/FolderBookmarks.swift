//
//  FolderBookmarks.swift
//  Engine
//
//  Persists the set of folders a user chose to index across app launches.
//
//  Strategy:
//  - We store *security-scoped* bookmark data (not raw paths) in UserDefaults.
//    A bookmark is a stable, relocation-tolerant reference to a file-system
//    object. Created with `.withSecurityScope`, it also carries the entitlement
//    needed to keep reading that folder after relaunch *if* the app is ever
//    sandboxed. The app is currently NOT sandboxed, so these calls succeed and
//    behave like plain bookmarks today; using `.withSecurityScope` now means we
//    won't have to migrate stored data later.
//  - Everything is `static` on an enum so there's no instantiable state — this
//    is a namespaced collection of helpers.
//
//  No external dependencies; AppKit/Foundation only. macOS 14+.
//

import Foundation

/// Namespace for reading/writing the user's chosen index folders as
/// security-scoped bookmarks persisted in `UserDefaults`.
public enum FolderBookmarks {

    // MARK: - Storage configuration

    /// UserDefaults key under which we store a `[Data]` of bookmark blobs.
    private static let defaultsKey = "tafuta.folderBookmarks"

    /// The store we read/write. `UserDefaults.standard` is fine for app prefs.
    private static var defaults: UserDefaults { .standard }

    // MARK: - Low-level array access

    /// Read the raw array of stored bookmark `Data` blobs.
    ///
    /// UserDefaults can hand back an `[Any]` (or `nil`), so we defensively
    /// filter to only the `Data` elements rather than force-casting.
    private static func storedBookmarks() -> [Data] {
        guard let raw = defaults.array(forKey: defaultsKey) else { return [] }
        return raw.compactMap { $0 as? Data }
    }

    /// Persist the array of bookmark `Data` blobs back to UserDefaults.
    private static func setStoredBookmarks(_ bookmarks: [Data]) {
        if bookmarks.isEmpty {
            // Keep defaults tidy: drop the key entirely when nothing is stored.
            defaults.removeObject(forKey: defaultsKey)
        } else {
            defaults.set(bookmarks, forKey: defaultsKey)
        }
    }

    // MARK: - Resolving helpers

    /// Resolve a single bookmark blob into a URL.
    ///
    /// Returns the resolved URL plus whether the bookmark is *stale* (i.e. the
    /// underlying file moved/changed enough that the bookmark should be
    /// recreated). Returns `nil` if resolution fails entirely.
    private static func resolve(_ data: Data) -> (url: URL, isStale: Bool)? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }
        return (url, isStale)
    }

    /// Create fresh security-scoped bookmark data for a folder URL.
    ///
    /// Returns `nil` if the system can't produce a bookmark (e.g. the folder no
    /// longer exists or we lack access). We never throw out of the public API.
    private static func makeBookmark(for url: URL) -> Data? {
        // Standardize so dedupe comparisons later are apples-to-apples.
        let target = url.standardizedFileURL
        return try? target.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    /// A normalized key used to compare two folder URLs for "same folder".
    private static func pathKey(for url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    // MARK: - Public API

    /// Persist `url` as a security-scoped bookmark so it survives relaunch.
    ///
    /// De-duplicates: if an already-stored bookmark resolves to the same
    /// standardized path, this is a no-op (we keep the existing bookmark).
    public static func save(_ url: URL) {
        guard let newBookmark = makeBookmark(for: url) else { return }

        let targetKey = pathKey(for: url)

        var bookmarks = storedBookmarks()

        // Dedupe by resolving existing bookmarks and comparing paths.
        for existing in bookmarks {
            if let resolved = resolve(existing),
               pathKey(for: resolved.url) == targetKey {
                // Already tracking this folder; nothing to do.
                return
            }
        }

        bookmarks.append(newBookmark)
        setStoredBookmarks(bookmarks)
    }

    /// Resolve and return all saved folder URLs.
    ///
    /// For each resolved URL we call `startAccessingSecurityScopedResource()`.
    /// In a sandboxed build this is required before touching the folder's
    /// contents; we intentionally leave access open for the app's lifetime
    /// (the process exit reclaims it), which is the common pattern for a small
    /// set of long-lived, user-chosen roots.
    ///
    /// Bookmarks that fail to resolve are silently skipped. Stale bookmarks are
    /// recreated and re-stored in place so the next launch resolves cleanly.
    public static func savedFolders() -> [URL] {
        let bookmarks = storedBookmarks()
        guard !bookmarks.isEmpty else { return [] }

        var resolvedURLs: [URL] = []
        var rewrittenBookmarks: [Data] = []
        var didRewrite = false

        for data in bookmarks {
            guard let resolved = resolve(data) else {
                // Couldn't resolve: drop this entry from the rewritten set.
                didRewrite = true
                continue
            }

            let url = resolved.url

            // Begin (and intentionally retain) access for the app lifetime.
            // Harmless on a non-sandboxed build; required once sandboxed.
            _ = url.startAccessingSecurityScopedResource()

            if resolved.isStale {
                // Refresh the bookmark blob so future launches stay healthy.
                if let refreshed = makeBookmark(for: url) {
                    rewrittenBookmarks.append(refreshed)
                    didRewrite = true
                } else {
                    // Couldn't refresh; keep the old blob rather than lose it.
                    rewrittenBookmarks.append(data)
                }
            } else {
                rewrittenBookmarks.append(data)
            }

            resolvedURLs.append(url)
        }

        // Only write back if something actually changed (stale refresh or a
        // dropped unresolvable entry), to avoid needless UserDefaults churn.
        if didRewrite {
            setStoredBookmarks(rewrittenBookmarks)
        }

        return resolvedURLs
    }

    /// Remove any stored bookmark(s) that resolve to `url`'s folder.
    ///
    /// Matching is by standardized path, so this works even though the stored
    /// representation is bookmark data rather than a path string. Entries that
    /// no longer resolve are also pruned as a side effect.
    public static func remove(_ url: URL) {
        let targetKey = pathKey(for: url)

        let bookmarks = storedBookmarks()
        guard !bookmarks.isEmpty else { return }

        let kept = bookmarks.filter { data in
            guard let resolved = resolve(data) else {
                // Unresolvable: drop it.
                return false
            }
            // Keep everything that is NOT the target folder.
            return pathKey(for: resolved.url) != targetKey
        }

        // Avoid an unnecessary write if nothing changed.
        if kept.count != bookmarks.count {
            setStoredBookmarks(kept)
        }
    }
}
