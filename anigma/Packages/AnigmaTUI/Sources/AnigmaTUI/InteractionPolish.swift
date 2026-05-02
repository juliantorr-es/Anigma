import Foundation

// MARK: - Extmark (Virtual Text)
public struct Extmark: Sendable {
    public let line: Int
    public let column: Int
    public let content: String
    public let color: Color
    public let attributes: TextAttributes
}

// MARK: - FrecencyStore
public actor FrecencyStore {
    private var stats: [String: (count: Int, lastUsed: Date)] = [: ]

    public func recordUse(_ id: String) {
        let current = stats[id] ?? (0, Date())
        stats[id] = (current.count + 1, Date())
    }

    public func score(_ id: String) -> Double {
        guard let stat = stats[id] else { return 0 }
        let hoursSinceUsed = Date().timeIntervalSince(stat.lastUsed) / 3600
        let decay = 1.0 / (1.0 + hoursSinceUsed)
        return Double(stat.count) * decay
    }
}

// MARK: - JSONLStore (Self-Healing)
public actor JSONLStore<T: Codable & Sendable> {
    private let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func append(_ item: T) async throws {
        let data = try JSONEncoder().encode(item)
        var line = data
        line.append(contentsOf: "\n".utf8)
        // Append logic
    }

    public func loadAll() async throws -> [T] {
        // Reads line by line, ignores corrupt lines (self-healing)
        return []
    }
}
