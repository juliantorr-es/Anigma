import Foundation
import ContractsCore
import DatabaseCore

/// System for applying retention policies with governed deletion
public actor RetentionSystem {
    private let database: ContextumDatabase

    public init(database: ContextumDatabase) {
        self.database = database
    }

    /// Apply retention sweep for a given policy
    public func applyRetentionSweep(
        policyID: String,
        cutoffDate: Date,
        targetTypes: Set<String>
    ) async throws -> DeletionManifest {
        let manifestID = UUID().uuidString
        var deletedItems: [DeletionManifestEntry] = []

        // Query items older than cutoff
        let candidates = try await database.queryExpiredItems(
            cutoffDate: cutoffDate,
            targetTypes: targetTypes
        )

        // Build deletion manifest before applying changes
        for candidate in candidates {
            deletedItems.append(DeletionManifestEntry(
                targetHash: candidate.hash,
                targetType: candidate.type,
                deletedAt: Date()
            ))
        }

        // Apply deletions/tombstones
        try await database.applyDeletions(hashes: candidates.map(\.hash))

        return DeletionManifest(
            manifestID: manifestID,
            policyID: policyID,
            cutoffDate: cutoffDate,
            deletedItems: deletedItems,
            totalDeleted: deletedItems.count
        )
    }
}

/// Deletion manifest artifact
public struct DeletionManifest: Codable, Sendable {
    public let manifestID: String
    public let policyID: String
    public let cutoffDate: Date
    public let deletedItems: [DeletionManifestEntry]
    public let totalDeleted: Int
}

public struct DeletionManifestEntry: Codable, Sendable {
    public let targetHash: String
    public let targetType: String
    public let deletedAt: Date
}

extension ContextumDatabase {
    func queryExpiredItems(cutoffDate: Date, targetTypes: Set<String>) async throws -> [(hash: String, type: String)] {
        var results: [(hash: String, type: String)] = []
        let cutoffTimestamp = Int(cutoffDate.timeIntervalSince1970)

        if targetTypes.contains("event") {
            let sql = "SELECT id FROM events WHERE timestamp < ?"
            let rows = try await dbActor.query(sql, parameters: [DatabaseParameter.int(cutoffTimestamp)])
            results.append(contentsOf: rows.compactMap { row in
                guard let id = row.string(for: "id") else { return nil }
                return (hash: id, type: "event")
            })
        }

        if targetTypes.contains("chunk") {
            let sql = "SELECT chunkHash FROM chunks WHERE createdAt < ?"
            let rows = try await dbActor.query(sql, parameters: [DatabaseParameter.int(cutoffTimestamp)])
            results.append(contentsOf: rows.compactMap { row in
                guard let hash = row.string(for: "chunkHash") else { return nil }
                return (hash: hash, type: "chunk")
            })
        }

        if targetTypes.contains("embedding") {
            let sql = "SELECT chunkHash FROM embeddings WHERE timestamp < ?"
            let rows = try await dbActor.query(sql, parameters: [DatabaseParameter.int(cutoffTimestamp)])
            results.append(contentsOf: rows.compactMap { row in
                guard let hash = row.string(for: "chunkHash") else { return nil }
                return (hash: hash, type: "embedding")
            })
        }

        return results
    }

    func applyDeletions(hashes: [String]) async throws {
        guard !hashes.isEmpty else { return }

        let placeholders = hashes.map { _ in "?" }.joined(separator: ",")
        let hashParams = hashes.map { DatabaseParameter.text($0) }

        // Delete events
        _ = try await dbActor.executeAsync("DELETE FROM events WHERE id IN (\(placeholders))", parameters: hashParams)

        // Delete chunks
        _ = try await dbActor.executeAsync("DELETE FROM chunks WHERE chunkHash IN (\(placeholders))", parameters: hashParams)
        _ = try await dbActor.executeAsync("DELETE FROM fts_chunks WHERE chunkHash IN (\(placeholders))", parameters: hashParams)

        // Delete embeddings
        _ = try await dbActor.executeAsync("DELETE FROM embeddings WHERE chunkHash IN (\(placeholders))", parameters: hashParams)

        // Delete orphaned search telemetry
        _ = try await dbActor.executeAsync("DELETE FROM search_telemetry WHERE returnedChunkHashes LIKE '%' || ? || '%'", parameters: hashParams)
    }
}
