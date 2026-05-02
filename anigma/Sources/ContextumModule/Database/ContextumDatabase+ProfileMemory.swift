//
//  ContextumDatabase+ProfileMemory.swift
//  ContextumModule
//
//  Profile memory database extensions
//

import Foundation
import DatabaseCore
import ContractsCore

// MARK: - Profile Memory Schema

extension ContextumDatabase {
    
    /// Initialize profile memory tables
    public func initializeProfileMemorySchema() async throws {
        _ = try await database.executeAsync(
            """
            CREATE TABLE IF NOT EXISTS contextum_profile_memories (
                id TEXT PRIMARY KEY,
                entity_id TEXT NOT NULL,
                entity_type TEXT NOT NULL,
                fact_type TEXT NOT NULL,
                fact_value TEXT NOT NULL,
                fact_data_json JSONB,
                confidence DOUBLE PRECISION NOT NULL,
                source_count BIGINT NOT NULL,
                first_observed_at DOUBLE PRECISION NOT NULL,
                last_observed_at DOUBLE PRECISION NOT NULL,
                last_updated_at DOUBLE PRECISION NOT NULL,
                is_active BIGINT NOT NULL DEFAULT 1,
                conflict_status TEXT NOT NULL,
                metadata_json JSONB
            )
            """
        )

        _ = try await database.executeAsync(
            """
            CREATE TABLE IF NOT EXISTS contextum_profile_memory_evidence (
                id TEXT PRIMARY KEY,
                profile_memory_id TEXT NOT NULL,
                source_id TEXT NOT NULL,
                chunk_id TEXT,
                evidence_type TEXT NOT NULL,
                confidence_contribution DOUBLE PRECISION NOT NULL,
                created_at DOUBLE PRECISION NOT NULL,
                metadata_json JSONB,
                FOREIGN KEY (profile_memory_id) REFERENCES contextum_profile_memories(id) ON DELETE CASCADE,
                FOREIGN KEY (source_id) REFERENCES contextum_sources(source_id) ON DELETE CASCADE,
                FOREIGN KEY (chunk_id) REFERENCES contextum_chunks(chunk_id) ON DELETE SET NULL
            )
            """
        )

        // Indexes for performance
        _ = try await database.executeAsync("CREATE INDEX IF NOT EXISTS idx_profile_memory_entity ON contextum_profile_memories(entity_id, entity_type)")
        _ = try await database.executeAsync("CREATE INDEX IF NOT EXISTS idx_profile_memory_fact ON contextum_profile_memories(entity_id, fact_type)")
        _ = try await database.executeAsync("CREATE INDEX IF NOT EXISTS idx_profile_memory_active ON contextum_profile_memories(is_active)")
        _ = try await database.executeAsync("CREATE INDEX IF NOT EXISTS idx_profile_memory_evidence_profile ON contextum_profile_memory_evidence(profile_memory_id)")
        _ = try await database.executeAsync("CREATE INDEX IF NOT EXISTS idx_profile_memory_evidence_source ON contextum_profile_memory_evidence(source_id)")
    }

    // MARK: - Create Operations

    /// Create profile memory
    public func createProfileMemory(_ memory: ProfileMemoryComponent) async throws {
        let factDataJSON = try JSONEncoder().encode(memory.factData)
        let metadataJSON = try JSONEncoder().encode(memory.metadata)

        _ = try await database.executeAsync(
            """
            INSERT INTO contextum_profile_memories (
                id, entity_id, entity_type, fact_type, fact_value, 
                fact_data_json, confidence, source_count, 
                first_observed_at, last_observed_at, last_updated_at, 
                is_active, conflict_status, metadata_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                .text(memory.id),
                .text(memory.entityId),
                .text(memory.entityType.rawValue),
                .text(memory.factType.rawValue),
                .text(memory.factValue),
                .blob(factDataJSON),
                .double(memory.confidence),
                .int(memory.sourceCount),
                .double(memory.firstObservedAt.timeIntervalSince1970),
                .double(memory.lastObservedAt.timeIntervalSince1970),
                .double(memory.lastUpdatedAt.timeIntervalSince1970),
                .int(memory.isActive ? 1 : 0),
                .text(memory.conflictStatus.rawValue),
                .blob(metadataJSON)
            ]
        )
    }

    /// Create profile memory evidence link
    public func createProfileMemoryEvidenceLink(_ link: ProfileMemoryEvidenceLink) async throws {
        let metadataJSON = try JSONEncoder().encode(link.metadata)

        _ = try await database.executeAsync(
            """
            INSERT INTO contextum_profile_memory_evidence (
                id, profile_memory_id, source_id, chunk_id, 
                evidence_type, confidence_contribution, created_at, metadata_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                .text(link.id),
                .text(link.profileMemoryId),
                .text(link.sourceId),
                link.chunkId.map { .text($0) } ?? .null,
                .text(link.evidenceType.rawValue),
                .double(link.confidenceContribution),
                .double(link.createdAt.timeIntervalSince1970),
                .blob(metadataJSON)
            ]
        )
    }

    // MARK: - Read Operations

    /// Get profile memory by ID
    public func getProfileMemory(id: String) async throws -> ProfileMemoryComponent? {
        let rows = try await database.query(
            """
            SELECT id, entity_id, entity_type, fact_type, fact_value,
                   fact_data_json, confidence, source_count,
                   first_observed_at, last_observed_at, last_updated_at,
                   is_active, conflict_status, metadata_json
            FROM contextum_profile_memories
            WHERE id = ?
            """,
            parameters: [.text(id)]
        )

        guard let row = rows.first else { return nil }

        return try decodeProfileMemoryRow(row)
    }

    /// Get profile memory evidence links
    public func getProfileMemoryEvidenceLinks(profileMemoryId: String) async throws -> [ProfileMemoryEvidenceLink] {
        let rows = try await database.query(
            """
            SELECT id, profile_memory_id, source_id, chunk_id,
                   evidence_type, confidence_contribution, created_at, metadata_json
            FROM contextum_profile_memory_evidence
            WHERE profile_memory_id = ?
            ORDER BY created_at ASC
            """,
            parameters: [.text(profileMemoryId)]
        )

        return try rows.map { try decodeProfileMemoryEvidenceRow($0) }
    }

    /// Query profile memories
    public func queryProfileMemories(query: ProfileMemoryQuery) async throws -> [ProfileMemoryComponent] {
        var sql = """
            SELECT id, entity_id, entity_type, fact_type, fact_value,
                   fact_data_json, confidence, source_count,
                   first_observed_at, last_observed_at, last_updated_at,
                   is_active, conflict_status, metadata_json
            FROM contextum_profile_memories
            WHERE 1 = 1
        """

        var parameters: [DatabaseParameter] = []

        if let entityId = query.entityId {
            sql += " AND entity_id = ?"
            parameters.append(.text(entityId))
        }

        if let entityType = query.entityType {
            sql += " AND entity_type = ?"
            parameters.append(.text(entityType.rawValue))
        }

        if let factType = query.factType {
            sql += " AND fact_type = ?"
            parameters.append(.text(factType.rawValue))
        }

        if let searchText = query.searchText, !searchText.isEmpty {
            sql += " AND (fact_value LIKE ? OR fact_data_json LIKE ?)"
            let searchParam = "%" + searchText + "%"
            parameters.append(.text(searchParam))
            parameters.append(.text(searchParam))
        }

        if let minConfidence = query.minConfidence {
            sql += " AND confidence >= ?"
            parameters.append(.double(minConfidence))
        }

        if !query.includeInactive {
            sql += " AND is_active = 1"
        }

        sql += " ORDER BY last_observed_at DESC, confidence DESC"
        sql += " LIMIT ? OFFSET ?"
        parameters.append(.int(query.limit))
        parameters.append(.int(query.offset))

        let rows = try await database.query(sql, parameters: parameters)
        return try rows.map { try decodeProfileMemoryRow($0) }
    }

    // MARK: - Update Operations

    /// Update profile memory
    public func updateProfileMemory(_ memory: ProfileMemoryComponent) async throws {
        let factDataJSON = try JSONEncoder().encode(memory.factData)
        let metadataJSON = try JSONEncoder().encode(memory.metadata)

        _ = try await database.executeAsync(
            """
            UPDATE contextum_profile_memories SET
                entity_id = ?,
                entity_type = ?,
                fact_type = ?,
                fact_value = ?,
                fact_data_json = ?,
                confidence = ?,
                source_count = ?,
                first_observed_at = ?,
                last_observed_at = ?,
                last_updated_at = ?,
                is_active = ?,
                conflict_status = ?,
                metadata_json = ?
            WHERE id = ?
            """,
            parameters: [
                .text(memory.entityId),
                .text(memory.entityType.rawValue),
                .text(memory.factType.rawValue),
                .text(memory.factValue),
                .blob(factDataJSON),
                .double(memory.confidence),
                .int(memory.sourceCount),
                .double(memory.firstObservedAt.timeIntervalSince1970),
                .double(memory.lastObservedAt.timeIntervalSince1970),
                .double(memory.lastUpdatedAt.timeIntervalSince1970),
                .int(memory.isActive ? 1 : 0),
                .text(memory.conflictStatus.rawValue),
                .blob(metadataJSON),
                .text(memory.id)
            ]
        )
    }

    // MARK: - Delete Operations

    /// Delete profile memory by ID (cascades to evidence links)
    public func deleteProfileMemory(id: String) async throws {
        _ = try await database.executeAsync(
            "DELETE FROM contextum_profile_memories WHERE id = ?",
            parameters: [.text(id)]
        )
    }

    /// Delete profile memory evidence link by ID
    public func deleteProfileMemoryEvidenceLink(id: String) async throws {
        _ = try await database.executeAsync(
            "DELETE FROM contextum_profile_memory_evidence WHERE id = ?",
            parameters: [.text(id)]
        )
    }

    // MARK: - Private Decoding Methods

    private func decodeProfileMemoryRow(_ row: DatabaseRow) throws -> ProfileMemoryComponent {
        guard
            let id = row["id"].string,
            let entityId = row["entity_id"].string,
            let entityTypeRaw = row["entity_type"].string, let entityType = ProfileMemoryEntityType(rawValue: entityTypeRaw),
            let factTypeRaw = row["fact_type"].string, let factType = ProfileMemoryFactType(rawValue: factTypeRaw),
            let factValue = row["fact_value"].string,
            let confidence = row["confidence"].double,
            let sourceCount = row["source_count"].int,
            let firstObservedAt = row["first_observed_at"].double,
            let lastObservedAt = row["last_observed_at"].double,
            let lastUpdatedAt = row["last_updated_at"].double,
            let isActive = row["is_active"].int,
            let conflictStatusRaw = row["conflict_status"].string, let conflictStatus = ProfileMemoryConflictStatus(rawValue: conflictStatusRaw)
        else {
            throw ContextumError.databaseError("Failed to decode ProfileMemoryComponent from database")
        }

        let factData: [String: String]
        if let factDataJSON = row["fact_data_json"].data {
            factData = try JSONDecoder().decode([String: String].self, from: factDataJSON)
        } else {
            factData = [:]
        }

        let metadata: [String: String]
        if let metadataJSON = row["metadata_json"].data {
            metadata = try JSONDecoder().decode([String: String].self, from: metadataJSON)
        } else {
            metadata = [:]
        }

        return ProfileMemoryComponent(
            id: id,
            entityId: entityId,
            entityType: entityType,
            factType: factType,
            factValue: factValue,
            factData: factData,
            confidence: confidence,
            sourceCount: sourceCount,
            firstObservedAt: Date(timeIntervalSince1970: firstObservedAt),
            lastObservedAt: Date(timeIntervalSince1970: lastObservedAt),
            lastUpdatedAt: Date(timeIntervalSince1970: lastUpdatedAt),
            isActive: isActive == 1,
            conflictStatus: conflictStatus,
            metadata: metadata
        )
    }

    private func decodeProfileMemoryEvidenceRow(_ row: DatabaseRow) throws -> ProfileMemoryEvidenceLink {
        guard
            let id = row["id"].string,
            let profileMemoryId = row["profile_memory_id"].string,
            let sourceId = row["source_id"].string,
            let evidenceTypeRaw = row["evidence_type"].string, let evidenceType = ProfileMemoryEvidenceType(rawValue: evidenceTypeRaw),
            let confidenceContribution = row["confidence_contribution"].double,
            let createdAt = row["created_at"].double
        else {
            throw ContextumError.databaseError("Failed to decode ProfileMemoryEvidenceLink from database")
        }

        let chunkId = row["chunk_id"].string

        let metadata: [String: String]
        if let metadataJSON = row["metadata_json"].data {
            metadata = try JSONDecoder().decode([String: String].self, from: metadataJSON)
        } else {
            metadata = [:]
        }

        return ProfileMemoryEvidenceLink(
            id: id,
            profileMemoryId: profileMemoryId,
            sourceId: sourceId,
            chunkId: chunkId,
            evidenceType: evidenceType,
            confidenceContribution: confidenceContribution,
            createdAt: Date(timeIntervalSince1970: createdAt),
            metadata: metadata
        )
    }
}
