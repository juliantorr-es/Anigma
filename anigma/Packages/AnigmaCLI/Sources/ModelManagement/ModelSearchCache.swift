//
//  ModelSearchCache.swift
//  AnigmaCLI
//
//  PostgreSQL-backed cache for HuggingFace search results.
//  Limits: 10 entries, 1 week TTL.
//

import Foundation
import DatabaseCore

public actor ModelSearchCache {
    private let db: DatabaseActor
    private let maxEntries: Int
    private let maxAge: TimeInterval

    public struct CachedSearch: Codable, Sendable {
        public let id: String
        public let query: String
        public let filters: String
        public let results: [HFSearchResult]
        public let cachedAt: Date
        public let expiresAt: Date
    }

    public init(
        database: DatabaseActor,
        maxEntries: Int = 10,
        maxAge: TimeInterval = 7 * 24 * 60 * 60
    ) async throws {
        self.db = database
        self.maxEntries = maxEntries
        self.maxAge = maxAge

        try await createSchema()
    }

    private func createSchema() async throws {
        _ = try await db.executeAsync("""
            CREATE TABLE IF NOT EXISTS model_search_cache (
                id TEXT PRIMARY KEY,
                query TEXT NOT NULL,
                filters TEXT NOT NULL,
                results BLOB NOT NULL,
                cached_at REAL NOT NULL,
                expires_at REAL NOT NULL
            )
            """, parameters: [])
    }

    public func get(query: String, filters: String) async -> [HFSearchResult]? {
        let id = cacheId(query: query, filters: filters)

        do {
            let rows = try await db.query("""
                SELECT results, expires_at FROM model_search_cache WHERE id = ?
                """, parameters: [.text(id)])

            guard let row = rows.first,
                  let resultsData = row.data(for: "results"),
                  let expiresAt = row.double(for: "expires_at") else {
                return nil
            }

            if Date().timeIntervalSince1970 > expiresAt {
                await delete(id: id)
                return nil
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([HFSearchResult].self, from: resultsData)
        } catch {
            return nil
        }
    }

    public func store(query: String, filters: String, results: [HFSearchResult]) async {
        let id = cacheId(query: query, filters: filters)
        let now = Date()
        let expiresAt = now.addingTimeInterval(maxAge)

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let resultsData = try encoder.encode(results)

            _ = try await db.executeAsync("""
                INSERT OR REPLACE INTO model_search_cache
                (id, query, filters, results, cached_at, expires_at)
                VALUES (?, ?, ?, ?, ?, ?)
                """, parameters: [
                    .text(id),
                    .text(query),
                    .text(filters),
                    .blob(resultsData),
                    .double(now.timeIntervalSince1970),
                    .double(expiresAt.timeIntervalSince1970)
                ])

            await enforceLimit()
        } catch {
        }
    }

    public func invalidateAll() async {
        do {
            _ = try await db.executeAsync("DELETE FROM model_search_cache", parameters: [])
        } catch {
        }
    }

    public func invalidateOnTokenChange() async {
        await invalidateAll()
    }

    public func cleanupExpired() async {
        let now = Date().timeIntervalSince1970
        do {
            _ = try await db.executeAsync("""
                DELETE FROM model_search_cache WHERE expires_at < ?
                """, parameters: [.double(now)])
        } catch {
        }
    }

    public func isStale(query: String, filters: String) async -> Bool {
        let id = cacheId(query: query, filters: filters)

        do {
            let rows = try await db.query("""
                SELECT expires_at FROM model_search_cache WHERE id = ?
                """, parameters: [.text(id)])

            guard let row = rows.first,
                  let expiresAt = row.double(for: "expires_at") else {
                return true
            }

            return Date().timeIntervalSince1970 > expiresAt
        } catch {
            return true
        }
    }

    private func delete(id: String) async {
        do {
            _ = try await db.executeAsync("""
                DELETE FROM model_search_cache WHERE id = ?
                """, parameters: [.text(id)])
        } catch {
        }
    }

    private func enforceLimit() async {
        do {
            _ = try await db.executeAsync("""
                DELETE FROM model_search_cache
                WHERE id NOT IN (
                    SELECT id FROM model_search_cache
                    ORDER BY cached_at DESC
                    LIMIT ?
                )
                """, parameters: [.int(maxEntries)])
        } catch {
        }
    }

    private func cacheId(query: String, filters: String) -> String {
        let input = "\(query)|\(filters)"
        let data = Data(input.utf8)
        var hash = [UInt8](repeating: 0, count: 32)
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    public func getStats() async -> CacheStats {
        do {
            let rows = try await db.query("""
                SELECT COUNT(*) as count FROM model_search_cache
                """)

            let count = rows.first?.int(for: "count") ?? 0

            return CacheStats(
                entryCount: count,
                maxEntries: maxEntries,
                maxAgeSeconds: maxAge
            )
        } catch {
            return CacheStats(entryCount: 0, maxEntries: maxEntries, maxAgeSeconds: maxAge)
        }
    }
}

public struct CacheStats: Sendable {
    public let entryCount: Int
    public let maxEntries: Int
    public let maxAgeSeconds: TimeInterval

    public var utilizationPercent: Double {
        guard maxEntries > 0 else { return 0 }
        return Double(entryCount) / Double(maxEntries) * 100
    }

    public var formattedAgeLimit: String {
        let hours = Int(maxAgeSeconds / 3600)
        if hours < 24 {
            return "\(hours) hours"
        }
        let days = hours / 24
        return "\(days) days"
    }
}

import CommonCrypto
