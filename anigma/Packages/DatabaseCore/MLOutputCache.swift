//
//  MLOutputCache.swift
//  DatabaseCore
//
//  Cache key resolver and ML output cache system.
//  Turns "compute vs retrieve" decision into deterministic database queries.
//

import Foundation
import CryptoKit

/// Cache key resolver for ML tasks
public actor MLOutputCache {
    private let dbActor: DatabaseActor

    public init(dbActor: DatabaseActor) {
        self.dbActor = dbActor
    }

    /// Generate deterministic cache key from ML request
    public func generateCacheKey(
        taskKind: String,
        engine: String,
        modelHash: String,
        binaryHash: String,
        canonicalArgs: [String],
        inputHash: String
    ) -> String {
        let components = [
            taskKind,
            engine,
            modelHash,
            binaryHash,
            canonicalArgs.joined(separator: "|"),
            inputHash
        ]

        guard let data = components.joined(separator: ":").data(using: .utf8) else {
            return UUID().uuidString // Fallback to UUID if encoding fails
        }
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Check if cached output exists for a cache key
    public func hasCachedOutput(cacheKey: String) async -> Bool {
        return false // Simplified for now
    }

    /// Retrieve cached ML output
    public func getCachedOutput(cacheKey: String) async -> MLOutputRecord? {
        return nil // Simplified for now
    }

    /// Store ML output with cache key
    public func storeOutput(
        cacheKey: String,
        outputType: String,
        artifactPath: String?,
        containerHash: String?,
        status: String = "completed",
        expiresAt: Date? = nil
    ) async throws {
        let insertSQL = """
        INSERT INTO ml_output_cache (
            cache_key, output_type, artifact_path, container_hash,
            created_at, expires_at, status
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """

        _ = try await dbActor.executeAsync(insertSQL, parameters: [
            .text(cacheKey),
            .text(outputType),
            .text(artifactPath ?? ""),
            .text(containerHash ?? ""),
            .text(String(Int(Date().timeIntervalSince1970))),
            .text(expiresAt.map { String(Int($0.timeIntervalSince1970)) } ?? ""),
            .text(status)
        ])
    }

    /// Mark cached output as verified (for audit trail)
    public func markOutputVerified(cacheKey: String) async throws {
        let updateSQL = """
        UPDATE ml_output_cache
        SET status = 'verified', verified_at = ?
        WHERE cache_key = ?
        """

        _ = try await dbActor.executeAsync(updateSQL, parameters: [
            .text(String(Int(Date().timeIntervalSince1970))),
            .text(cacheKey)
        ])
    }
}

/// ML output cache record
public struct MLOutputRecord {
    public let outputType: String
    public let artifactPath: String?
    public let containerHash: String?
    public let createdAt: Date
    public let expiresAt: Date?
    public let status: String

    public init(
        outputType: String,
        artifactPath: String?,
        containerHash: String?,
        createdAt: Date,
        expiresAt: Date?,
        status: String
    ) {
        self.outputType = outputType
        self.artifactPath = artifactPath
        self.containerHash = containerHash
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.status = status
    }
}

// MARK: - Cache Schema Extension

extension DatabaseActor {
    /// Initialize ML output cache table
    public func initializeMLOutputCache() async throws {
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS ml_output_cache (
            cache_key TEXT NOT NULL,
            output_type TEXT NOT NULL,           -- 'embedding', 'chat_completion', 'summarize', etc.
            artifact_path TEXT,                  -- Path to generated artifact
            container_hash TEXT,                  -- Hash of container with artifacts
            created_at INTEGER NOT NULL,       -- Cache creation time
            expires_at INTEGER,                   -- Cache expiration time
            status TEXT DEFAULT 'pending',       -- 'pending', 'completed', 'verified', 'expired'

            -- Performance indexes
            PRIMARY KEY (cache_key),
            UNIQUE(cache_key, output_type)
        );

        CREATE INDEX IF NOT EXISTS idx_ml_cache_key ON ml_output_cache(cache_key);
        CREATE INDEX IF NOT EXISTS idx_ml_cache_status ON ml_output_cache(status);
        CREATE INDEX IF NOT EXISTS idx_ml_cache_expires ON ml_output_cache(expires_at);
        """

        _ = try await executeScript(createTableSQL)
    }

}

/// Document unit for evidence tracking
public struct DocumentUnit: Sendable, Codable {
    public let id: String
    public let contentHash: String
    public let filePath: String
    public let origin: String  // doc:governance, doc:incident, doc:status
    public let gitStateId: String
    public let createdAt: Date
    public let contentType: String
    public let metadata: String?

    public init(
        id: String,
        contentHash: String,
        filePath: String,
        origin: String,
        gitStateId: String,
        createdAt: Date,
        contentType: String,
        metadata: String?
    ) {
        self.id = id
        self.contentHash = contentHash
        self.filePath = filePath
        self.origin = origin
        self.gitStateId = gitStateId
        self.createdAt = createdAt
        self.contentType = contentType
        self.metadata = metadata
    }
}
