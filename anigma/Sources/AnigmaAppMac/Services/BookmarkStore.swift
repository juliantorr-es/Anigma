import Foundation

@MainActor
final class BookmarkStore {
    static let shared = BookmarkStore()
    private let defaults = UserDefaults.standard

    func saveBookmark(for url: URL, key: String) throws {
        let data = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        defaults.set(data, forKey: key)
    }

    func resolveBookmark(key: String) throws -> URL {
        guard let data = defaults.data(forKey: key) else {
            throw NSError(domain: "BookmarkStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing bookmark \(key)"])
        }
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        if isStale {
            // You can re-save, but don’t do it silently unless you confirm access still works.
            try? saveBookmark(for: url, key: key)
        }
        return url
    }
}

struct ScopedAccess {
    let urls: [URL]
    private var started: [URL] = []

    init(urls: [URL]) {
        self.urls = urls
    }

    mutating func start() {
        for u in urls {
            if u.startAccessingSecurityScopedResource() {
                started.append(u)
            }
        }
    }

    mutating func stop() {
        for u in started {
            u.stopAccessingSecurityScopedResource()
        }
        started.removeAll()
    }
}
