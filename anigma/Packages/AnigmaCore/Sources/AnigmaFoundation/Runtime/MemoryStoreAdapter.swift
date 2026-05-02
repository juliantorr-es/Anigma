//
//  MemoryStoreAdapter.swift
//  AnigmaCore
//
//  Adapter that implements MemoryStore protocol using governed DatabaseAuthority.
//  This is the seam between pure HarmoniaV2Memory and side-effectful runtime.
//

import AnigmaPrimitives
import Foundation
import GovernanceCore
import DatabaseCore
import FoundationContracts
import GovernanceContracts
import EvidenceContracts
import IntelligenceContracts

/// Adapter that implements MemoryStore using governed database operations.
/// Memory writes go through DatabaseAuthority → governance enforcement.
public actor MemoryStoreAdapter: MemoryStore {
    private let database: any DatabaseAuthority
    private let tableName: String
    
    public init(database: any DatabaseAuthority, tableName: String = "harmonia_memories") {
        self.database = database
        self.tableName = tableName
    }
    
    /// Initialize the memory table schema (call once at startup)
    public func initializeSchema() async throws {
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS \(tableName) (
            id TEXT PRIMARY KEY,
            content TEXT NOT NULL,
            metadata TEXT NOT NULL,
            embedding BLOB,
            created_at INTEGER NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_\(tableName)_created_at ON \(tableName)(created_at);
        """
        
        // Schema creation is a mutation, but a special one for initialization
        // For MVP, we'll execute it directly. In production, use a migration system.
        // Note: This bypasses governance intentionally for schema setup only.
        // TODO: Add proper schema migration authority
        
        // For now, we'll create a context for system operations
        let systemContext = ExecutionContext(
            principal: Principal(id: "system", displayName: "System", roles: ["system"]),
            projectId: nil,
            sessionId: "schema-init"
        )
        
        let mutation = DatabaseMutation(
            sql: createTableSQL,
            parameters: [],
            componentType: "schema",
            entityId: EntityId(stringLiteral: tableName)
        )
        
        _ = try await database.mutate(mutation, context: systemContext)
    }
    
    // MARK: - MemoryStore Protocol
    
    public func store(
        content: String,
        metadata: [String: String],
        embedding: [Float]?
    ) async throws -> String {
        let id = UUID().uuidString
        let now = Date()
        
        // Serialize metadata as JSON
        let metadataJSON = try JSONEncoder().encode(metadata)
        let metadataString = String(data: metadataJSON, encoding: .utf8) ?? "{}"
        
        // Serialize embedding as binary if present
        let embeddingData: Data? = if let embedding = embedding {
            Data(bytes: embedding, count: embedding.count * MemoryLayout<Float>.size)
        } else {
            nil
        }
        
        let sql = """
        INSERT INTO \(tableName) (id, content, metadata, embedding, created_at)
        VALUES (?, ?, ?, ?, ?)
        """
        
        var parameters: [DatabaseParameter] = [
            .text(id),
            .text(content),
            .text(metadataString),
            .int(Int(now.timeIntervalSince1970))
        ]
        
        // Add embedding as blob parameter if present
        if let embeddingData = embeddingData {
            parameters.insert(.blob(embeddingData), at: 3)
        } else {
            parameters.insert(.null, at: 3)
        }
        
        // Create execution context from metadata
        let userId = metadata["userId"] ?? "unknown"
        let projectId = metadata["projectId"]
        let sessionId = metadata["sessionId"] ?? UUID().uuidString
        
        let context = ExecutionContext(
            principal: Principal(id: userId, displayName: userId),
            projectId: projectId,
            sessionId: sessionId
        )
        
        let mutation = DatabaseMutation(
            sql: sql,
            parameters: parameters,
            componentType: "memory",
            entityId: EntityId(stringLiteral: id)
        )
        
        // This goes through governance!
        _ = try await database.mutate(mutation, context: context)
        
        return id
    }
    
    public func retrieve(
        sessionId: String?,
        tenantId: String?,
        limit: Int
    ) async throws -> [StoredMemoryRecord] {
        var sql = "SELECT id, content, metadata, embedding, created_at FROM \(tableName)"
        var conditions: [String] = []
        var parameters: [String: String] = [:]
        
        if let sessionId = sessionId {
            conditions.append("json_extract(metadata, '$.sessionId') = :sessionId")
            parameters["sessionId"] = sessionId
        }
        
        if let tenantId = tenantId {
            conditions.append("json_extract(metadata, '$.tenantId') = :tenantId")
            parameters["tenantId"] = tenantId
        }
        
        if !conditions.isEmpty {
            sql += " WHERE " + conditions.joined(separator: " AND ")
        }
        
        sql += " ORDER BY created_at DESC LIMIT \(limit)"
        
        let rows = try await database.query(sql, parameters: parameters)
        
        return try rows.map { row in
            guard let id = row.string(for: "id"),
                  let content = row.string(for: "content"),
                  let createdAtInt = row.int(for: "created_at") else {
                throw MemoryStoreError.storageFailure("Invalid row data")
            }
            
            let metadataString = row.string(for: "metadata") ?? "{}"
            let metadataData = metadataString.data(using: .utf8) ?? Data()
            let metadata = (try? JSONDecoder().decode([String: String].self, from: metadataData)) ?? [:]
            
            // TODO: Deserialize embedding from blob
            let embedding: [Float]? = nil
            
            let createdAt = Date(timeIntervalSince1970: TimeInterval(createdAtInt))
            
            return StoredMemoryRecord(
                id: id,
                content: content,
                metadata: metadata,
                embedding: embedding,
                createdAt: createdAt
            )
        }
    }
    
    public func searchSimilar(
        embedding: [Float],
        embeddingModel: String?,
        projectId: String,
        limit: Int,
        threshold: Float?,
        scanLimit: Int?
    ) async throws -> [SimilarMemoryResult] {
        var sql = """
        SELECT id, content, metadata, embedding, created_at
        FROM \(tableName)
        WHERE embedding IS NOT NULL
          AND (json_extract(metadata, '$.projectId') = :projectId
               OR json_extract(metadata, '$.tenantId') = :projectId)
        """

        if let scanLimit {
            sql += " LIMIT \(scanLimit)"
        }

        let rows = try await database.query(sql, parameters: ["projectId": projectId])

        struct ScoredResult {
            let record: StoredMemoryRecord
            let similarity: Float
        }

        var scored: [ScoredResult] = []
        let queryMagnitude = sqrt(embedding.map { $0 * $0 }.reduce(0, +))
        guard queryMagnitude > 0 else { return [] }

        for row in rows {
            guard let id = row.string(for: "id"),
                  let content = row.string(for: "content"),
                  let createdAtInt = row.int(for: "created_at"),
                  let metadataString = row.string(for: "metadata"),
                  let embeddingData = row.data(for: "embedding") else {
                continue
            }

            let metadataData = metadataString.data(using: .utf8) ?? Data()
            let metadata = (try? JSONDecoder().decode([String: String].self, from: metadataData)) ?? [:]

            if let expectedModel = embeddingModel,
               let storedModel = metadata["embeddingModel"],
               storedModel != expectedModel {
                throw HarmoniaError.embeddingModelMismatch("Expected \(expectedModel), got \(storedModel)")
            }

            let storedEmbedding: [Float] = embeddingData.withUnsafeBytes { buffer in
                Array(buffer.bindMemory(to: Float.self))
            }

            guard storedEmbedding.count == embedding.count else { continue }

            let storedMagnitude = sqrt(storedEmbedding.map { $0 * $0 }.reduce(0, +))
            guard storedMagnitude > 0 else { continue }

            let dotProduct = zip(embedding, storedEmbedding).map(*).reduce(0, +)
            let similarity = dotProduct / (queryMagnitude * storedMagnitude)
            if let threshold, similarity < threshold { continue }

            scored.append(
                ScoredResult(
                    record: StoredMemoryRecord(
                        id: id,
                        content: content,
                        metadata: metadata,
                        embedding: storedEmbedding,
                        createdAt: Date(timeIntervalSince1970: TimeInterval(createdAtInt))
                    ),
                    similarity: similarity
                )
            )
        }

        scored.sort {
            if abs($0.similarity - $1.similarity) < 0.0001 {
                return $0.record.id < $1.record.id
            }
            return $0.similarity > $1.similarity
        }

        return scored.prefix(limit).enumerated().map { index, result in
            SimilarMemoryResult(
                record: result.record,
                similarity: result.similarity,
                rank: index + 1,
                vectorRank: index + 1,
                ftsRank: nil,
                rrfScore: result.similarity,
                tags: []
            )
        }
    }
}
