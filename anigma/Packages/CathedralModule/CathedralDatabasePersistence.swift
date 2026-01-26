//
//  CathedralDatabasePersistence.swift
//  CathedralModule
//
//  Database persistence layer for Cathedral evidence chains
//

import Foundation
import DatabaseCore
import ContractsCore
import AnigmaCore

// MARK: - Cathedral Database Persistence

/// Handles persistence of Cathedral evidence to database
public actor CathedralDatabasePersistence {
    private let database: any DatabaseCore.DatabaseExecutor

    public init(database: any DatabaseCore.DatabaseExecutor) {
        self.database = database
    }

    // MARK: - Evidence Chain Persistence

    /// Persist evidence to database evidence_chain table
    public func persistEvidence(_ evidence: Evidence) async throws {
        try await database.executeAsync(
            """
            INSERT INTO evidence_chain (
                event_id, event_type, timestamp, timezone,
                payload_hash, previous_hash, head_hash,
                payload, actor, session_id, bundle_ids
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                .text(evidence.id),
                .text(evidence.type.rawValue),
                .int(Int(evidence.timestamp.timeIntervalSince1970)),
                .text("UTC"),
                .text(evidence.contentHash),
                .text(evidence.previousHash ?? ""),
                .text(evidence.computeHash()),
                .text(try encodeEvidencePayload(evidence)),
                .text(evidence.agentId),
                .text(evidence.sessionId),
                .text("[]")
            ]
        )
    }

    /// Retrieve evidence by ID
    public func getEvidence(id: String) async throws -> Evidence? {
        let rows = try await database.query(
            """
            SELECT event_id, event_type, timestamp, payload_hash,
                   previous_hash, payload, actor, session_id
            FROM evidence_chain
            WHERE event_id = ?
            """,
            parameters: [.text(id)]
        )

        guard let row = rows.first else { return nil }
        return try decodeEvidence(from: row)
    }

    /// Get all evidence for a session
    public func getSessionEvidence(sessionId: String) async throws -> [Evidence] {
        let rows = try await database.query(
            """
            SELECT event_id, event_type, timestamp, payload_hash,
                   previous_hash, payload, actor, session_id
            FROM evidence_chain
            WHERE session_id = ?
            ORDER BY sequence_number ASC
            """,
            parameters: [.text(sessionId)]
        )

        return try rows.map { try decodeEvidence(from: $0) }
    }

    /// Get evidence chain length
    public func getChainLength() async throws -> Int {
        let rows = try await database.query(
            "SELECT COUNT(*) as count FROM evidence_chain",
            parameters: []
        )

        guard let row = rows.first,
              let count = row.int(for: "count") else {
            return 0
        }

        return count
    }

    /// Get last hash in chain
    public func getLastHash() async throws -> String? {
        let rows = try await database.query(
            """
            SELECT head_hash FROM evidence_chain
            ORDER BY sequence_number DESC
            LIMIT 1
            """,
            parameters: []
        )

        return rows.first?.string(for: "head_hash")
    }

    // MARK: - Violation Persistence

    /// Persist evidence violation
    public func persistViolation(_ violation: EvidenceViolation, sessionId: String?) async throws {
        var context: [String: String] = [:]
        if let evidenceId = violation.evidenceId {
            context["evidenceId"] = evidenceId
        }

        try await database.executeAsync(
            """
            INSERT INTO policy_violations (
                violation_type, severity, actor, session_id,
                description, context_json, timestamp
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                .text(violation.type.rawValue),
                .text(violation.severity.rawValue),
                .text("system"),
                sessionId.map(DatabaseParameter.text) ?? .null,
                .text(violation.description),
                .text(try encodeContext(context.isEmpty ? nil : context)),
                .int(Int(violation.timestamp.timeIntervalSince1970))
            ]
        )
    }

    /// Get violations for session
    public func getSessionViolations(sessionId: String) async throws -> [EvidenceViolation] {
        let rows = try await database.query(
            """
            SELECT id, session_id, violation_type, severity,
                   description, timestamp, context_json
            FROM policy_violations
            WHERE session_id = ?
            ORDER BY timestamp DESC
            """,
            parameters: [.text(sessionId)]
        )

        return try rows.map { try decodeViolation(from: $0) }
    }

    // MARK: - Document Metadata Persistence

    /// Persist document metadata
    public func persistDocumentMetadata(_ metadata: DocumentMetadata) async throws {
        // First, ensure document_metadata table exists (it's in Schema_DocumentUnits.sql)
        try await database.executeAsync(
            """
            INSERT OR REPLACE INTO document_metadata (
                document_id, file_path, acquisition_time,
                source_metadata, current_state
            ) VALUES (?, ?, ?, ?, ?)
            """,
            parameters: [
                .text(metadata.documentId),
                .text(metadata.filePath),
                .int(Int(metadata.acquisitionTime.timeIntervalSince1970)),
                .text(try encodeSourceMetadata(metadata.sourceMetadata)),
                .text(metadata.currentState.rawValue)
            ]
        )
    }

    /// Persist document transformation
    public func persistTransformation(
        documentId: String,
        transformation: DocumentTransformation
    ) async throws {
        try await database.executeAsync(
            """
            INSERT INTO document_transformations (
                id, document_id, type, tool_name, tool_version,
                timestamp, input_hash, output_hash, parameters
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                .text(transformation.id),
                .text(documentId),
                .text(transformation.type),
                .text(transformation.toolName),
                .text(transformation.toolVersion),
                .int(Int(transformation.timestamp.timeIntervalSince1970)),
                .text(transformation.inputHash),
                .text(transformation.outputHash),
                .text(try encodeParameters(transformation.parameters))
            ]
        )
    }

    /// Get document metadata
    public func getDocumentMetadata(documentId: String) async throws -> DocumentMetadata? {
        let rows = try await database.query(
            """
            SELECT document_id, file_path, acquisition_time,
                   source_metadata, current_state
            FROM document_metadata
            WHERE document_id = ?
            """,
            parameters: [.text(documentId)]
        )

        guard let row = rows.first else { return nil }

        // Get transformations
        let transformations = try await getTransformations(documentId: documentId)

        return try decodeDocumentMetadata(from: row, transformations: transformations)
    }

    /// Get document transformations
    private func getTransformations(documentId: String) async throws -> [DocumentTransformation] {
        let rows = try await database.query(
            """
            SELECT id, type, tool_name, tool_version, timestamp,
                   input_hash, output_hash, parameters
            FROM document_transformations
            WHERE document_id = ?
            ORDER BY timestamp ASC
            """,
            parameters: [.text(documentId)]
        )

        return try rows.map { try decodeTransformation(from: $0) }
    }

    // MARK: - Query Record Persistence

    /// Persist query record
    public func persistQueryRecord(_ record: QueryRecord) async throws {
        let resultsData = try encodeResults(record.results)
        let embeddingRecipe = Data()
        let engineMetadata = Data()
        let recordHash = record.id.sha256Hash
        let createdAt = Int(Date().timeIntervalSince1970)
        let parameters: [DatabaseCore.DatabaseParameter] = [
            .text(record.id),
            .text(record.query.text),
            .int(Int(record.timestamp.timeIntervalSince1970)),
            .blob(embeddingRecipe),
            .double(record.query.parameters.threshold),
            .int(Int(record.query.parameters.topK)),
            .int(Int(record.results.count)),
            .blob(resultsData),
            .int(0),
            .blob(engineMetadata),
            .text(recordHash),
            .int(createdAt)
        ]

        try await database.executeAsync(
            """
            INSERT INTO retrieval_evidence (
                query_id, query_text, query_timestamp,
                embedding_recipe, similarity_threshold,
                max_results, total_candidates, results_json,
                execution_time_ms, engine_metadata, record_hash,
                created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            parameters: parameters
        )
    }

    /// Get query record
    public func getQueryRecord(queryId: String) async throws -> QueryRecord? {
        let rows = try await database.query(
            """
            SELECT query_id, query_text, query_timestamp,
                   similarity_threshold, max_results, results_json
            FROM retrieval_evidence
            WHERE query_id = ?
            """,
            parameters: [.text(queryId)]
        )

        guard let row = rows.first else { return nil }
        return try decodeQueryRecord(from: row)
    }

    // MARK: - Helper Methods - Encoding

    private func encodeEvidencePayload(_ evidence: Evidence) throws -> String {
        let encoder = JSONEncoder()
        let data = try encoder.encode(evidence.metadata)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private func encodeContext(_ context: [String: String]?) throws -> String {
        guard let context = context else { return "{}" }
        let encoder = JSONEncoder()
        let data = try encoder.encode(context)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private func encodeSourceMetadata(_ metadata: [String: String]) throws -> String {
        let encoder = JSONEncoder()
        let data = try encoder.encode(metadata)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private func encodeParameters(_ parameters: [String: String]) throws -> String {
        let encoder = JSONEncoder()
        let data = try encoder.encode(parameters)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private func encodeResults(_ results: [SearchResult]) throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(results)
    }

    // MARK: - Helper Methods - Decoding

    private func decodeEvidence(from row: DatabaseRow) throws -> Evidence {
        guard let id = row.string(for: "event_id"),
              let typeString = row.string(for: "event_type"),
              let type = EvidenceType(rawValue: typeString),
              let timestampInt = row.int64(for: "timestamp"),
              let contentHash = row.string(for: "payload_hash"),
              let previousHash = row.string(for: "previous_hash"),
              let payloadString = row.string(for: "payload"),
              let agentId = row.string(for: "actor"),
              let sessionId = row.string(for: "session_id") else {
            throw CathedralDatabaseError.decodingError("Failed to decode evidence")
        }

        let timestamp = Date(timeIntervalSince1970: TimeInterval(timestampInt))

        // Decode metadata from payload
        let decoder = JSONDecoder()
        let payloadData = payloadString.data(using: .utf8) ?? Data()
        let metadata = try? decoder.decode(EvidenceMetadata.self, from: payloadData)

        return Evidence(
            id: id,
            type: type,
            sessionId: sessionId,
            agentId: agentId,
            timestamp: timestamp,
            contentHash: contentHash,
            metadata: metadata ?? EvidenceMetadata(
                source: "unknown",
                operation: "unknown",
                quality: .none
            ),
            previousHash: previousHash.isEmpty ? nil : previousHash
        )
    }

    private func decodeViolation(from row: DatabaseRow) throws -> EvidenceViolation {
        guard let typeString = row.string(for: "violation_type"),
              let type = EvidenceViolationType(rawValue: typeString),
              let severityString = row.string(for: "severity"),
              let severity = EvidenceViolationSeverity(rawValue: severityString),
              let description = row.string(for: "description"),
              let timestampInt = row.int64(for: "timestamp") else {
            throw CathedralDatabaseError.decodingError("Failed to decode violation")
        }

        let timestamp = Date(timeIntervalSince1970: TimeInterval(timestampInt))
        let contextString = row.string(for: "context_json")

        var evidenceId: String?
        if let contextString = contextString,
           let contextData = contextString.data(using: .utf8),
           let context = try? JSONDecoder().decode([String: String].self, from: contextData) {
            evidenceId = context["evidenceId"]
        }

        return EvidenceViolation(
            type: type,
            severity: severity,
            description: description,
            evidenceId: evidenceId,
            timestamp: timestamp
        )
    }

    private func decodeDocumentMetadata(
        from row: DatabaseRow,
        transformations: [DocumentTransformation]
    ) throws -> DocumentMetadata {
        guard let documentId = row.string(for: "document_id"),
              let filePath = row.string(for: "file_path"),
              let acquisitionTimeInt = row.int64(for: "acquisition_time"),
              let sourceMetadataString = row.string(for: "source_metadata"),
              let stateString = row.string(for: "current_state"),
              let state = DocumentState(rawValue: stateString) else {
            throw CathedralDatabaseError.decodingError("Failed to decode document metadata")
        }

        let acquisitionTime = Date(timeIntervalSince1970: TimeInterval(acquisitionTimeInt))

        var sourceMetadata: [String: String] = [:]
        if let data = sourceMetadataString.data(using: .utf8) {
            sourceMetadata = (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
        }

        return DocumentMetadata(
            documentId: documentId,
            filePath: filePath,
            acquisitionTime: acquisitionTime,
            sourceMetadata: sourceMetadata,
            transformations: transformations,
            currentState: state
        )
    }

    private func decodeTransformation(from row: DatabaseRow) throws -> DocumentTransformation {
        guard let id = row.string(for: "id"),
              let type = row.string(for: "type"),
              let toolName = row.string(for: "tool_name"),
              let toolVersion = row.string(for: "tool_version"),
              let timestampInt = row.int64(for: "timestamp"),
              let inputHash = row.string(for: "input_hash"),
              let outputHash = row.string(for: "output_hash") else {
            throw CathedralDatabaseError.decodingError("Failed to decode transformation")
        }

        let timestamp = Date(timeIntervalSince1970: TimeInterval(timestampInt))

        var parameters: [String: String] = [:]
        if let parametersString = row.string(for: "parameters"),
           let data = parametersString.data(using: .utf8) {
            parameters = (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
        }

        return DocumentTransformation(
            id: id,
            type: type,
            toolName: toolName,
            toolVersion: toolVersion,
            timestamp: timestamp,
            inputHash: inputHash,
            outputHash: outputHash,
            parameters: parameters
        )
    }

    private func decodeQueryRecord(from row: DatabaseRow) throws -> QueryRecord {
        guard let id = row.string(for: "query_id"),
              let queryText = row.string(for: "query_text"),
              let timestampInt = row.int64(for: "query_timestamp"),
              let threshold = row.double(for: "similarity_threshold"),
              let topK = row.int(for: "max_results"),
              let resultsBlob = row.data(for: "results_json") else {
            throw CathedralDatabaseError.decodingError("Failed to decode query record")
        }

        let timestamp = Date(timeIntervalSince1970: TimeInterval(timestampInt))

        let results = try JSONDecoder().decode([SearchResult].self, from: resultsBlob)

        let query = SearchQuery(
            text: queryText,
            type: .semantic,
            parameters: QueryParameters(topK: topK, threshold: threshold)
        )

        return QueryRecord(
            id: id,
            query: query,
            results: results,
            timestamp: timestamp,
            sessionId: "unknown", // Would need to add session_id column
            agentId: "unknown" // Would need to add agent_id column
        )
    }
}

// MARK: - Database Error Extension

public enum CathedralDatabaseError: Error {
    case connectionError(String)
    case executionError(String)
    case decodingError(String)
}
