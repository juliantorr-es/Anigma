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
    private let database: LegacyDatabaseActor

    public init(database: LegacyDatabaseActor) {
        self.database = database
    }

    // MARK: - Evidence Chain Persistence

    /// Persist evidence to database evidence_chain table
    public func persistEvidence(_ evidence: Evidence) async throws {
        try await database.execute(
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
                .integer(Int64(evidence.timestamp.timeIntervalSince1970)),
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
            "SELECT COUNT(*) as count FROM evidence_chain"
        )

        guard let row = rows.first,
              let count = row.int(at: 0) else {
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
            """
        )

        return rows.first?.string(at: 0)
    }

    // MARK: - Violation Persistence

    /// Persist evidence violation
    public func persistViolation(_ violation: EvidenceViolation) async throws {
        try await database.execute(
            """
            INSERT INTO policy_violations (
                violation_type, severity, actor, session_id,
                description, context_json, timestamp
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                .text(violation.violationType.rawValue),
                .text(violation.severity.rawValue),
                .text("system"),
                .text(violation.evidenceId), // Using evidenceId as session_id
                .text(violation.description),
                .text(try encodeContext(violation.context)),
                .integer(Int64(violation.detectedAt.timeIntervalSince1970))
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
        try await database.execute(
            """
            INSERT OR REPLACE INTO document_metadata (
                document_id, file_path, acquisition_time,
                source_metadata, current_state
            ) VALUES (?, ?, ?, ?, ?)
            """,
            parameters: [
                .text(metadata.documentId),
                .text(metadata.filePath),
                .integer(Int64(metadata.acquisitionTime.timeIntervalSince1970)),
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
        try await database.execute(
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
                .integer(Int64(transformation.timestamp.timeIntervalSince1970)),
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
        try await database.execute(
            """
            INSERT INTO retrieval_evidence (
                query_id, query_text, query_timestamp,
                embedding_recipe, similarity_threshold,
                max_results, total_candidates, results_json,
                execution_time_ms, engine_metadata, record_hash,
                created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                .text(record.id),
                .text(record.query.text),
                .integer(Int64(record.timestamp.timeIntervalSince1970)),
                .blob(Data()), // Placeholder for embedding recipe
                .real(record.query.parameters.threshold),
                .integer(Int64(record.query.parameters.topK)),
                .integer(Int64(record.results.count)),
                .blob(try encodeResults(record.results)),
                .integer(0), // Placeholder for execution time
                .blob(Data()), // Placeholder for engine metadata
                .text(record.id.sha256Hash),
                .integer(Int64(Date().timeIntervalSince1970))
            ]
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
        guard let id = row.string(at: 0),
              let typeString = row.string(at: 1),
              let type = EvidenceType(rawValue: typeString),
              let timestampInt = row.int64(at: 2),
              let contentHash = row.string(at: 3),
              let previousHash = row.string(at: 4),
              let payloadString = row.string(at: 5),
              let agentId = row.string(at: 6),
              let sessionId = row.string(at: 7) else {
            throw DatabaseError.decodingError("Failed to decode evidence")
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
        guard let id = row.int64(at: 0),
              let evidenceId = row.string(at: 1),
              let typeString = row.string(at: 2),
              let type = EvidenceViolationType(rawValue: typeString),
              let severityString = row.string(at: 3),
              let severity = EvidenceViolationSeverity(rawValue: severityString),
              let description = row.string(at: 4),
              let timestampInt = row.int64(at: 5) else {
            throw DatabaseError.decodingError("Failed to decode violation")
        }

        let timestamp = Date(timeIntervalSince1970: TimeInterval(timestampInt))
        let contextString = row.string(at: 6)

        var context: [String: String]?
        if let contextString = contextString,
           let contextData = contextString.data(using: .utf8) {
            context = try? JSONDecoder().decode([String: String].self, from: contextData)
        }

        return EvidenceViolation(
            id: String(id),
            evidenceId: evidenceId,
            violationType: type,
            severity: severity,
            description: description,
            detectedAt: timestamp,
            context: context
        )
    }

    private func decodeDocumentMetadata(
        from row: DatabaseRow,
        transformations: [DocumentTransformation]
    ) throws -> DocumentMetadata {
        guard let documentId = row.string(at: 0),
              let filePath = row.string(at: 1),
              let acquisitionTimeInt = row.int64(at: 2),
              let sourceMetadataString = row.string(at: 3),
              let stateString = row.string(at: 4),
              let state = DocumentState(rawValue: stateString) else {
            throw DatabaseError.decodingError("Failed to decode document metadata")
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
        guard let id = row.string(at: 0),
              let type = row.string(at: 1),
              let toolName = row.string(at: 2),
              let toolVersion = row.string(at: 3),
              let timestampInt = row.int64(at: 4),
              let inputHash = row.string(at: 5),
              let outputHash = row.string(at: 6) else {
            throw DatabaseError.decodingError("Failed to decode transformation")
        }

        let timestamp = Date(timeIntervalSince1970: TimeInterval(timestampInt))

        var parameters: [String: String] = [:]
        if let parametersString = row.string(at: 7),
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
        guard let id = row.string(at: 0),
              let queryText = row.string(at: 1),
              let timestampInt = row.int64(at: 2),
              let threshold = row.real(at: 3),
              let topK = row.int(at: 4),
              let resultsBlob = row.blob(at: 5) else {
            throw DatabaseError.decodingError("Failed to decode query record")
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

public enum DatabaseError: Error {
    case connectionError(String)
    case executionError(String)
    case decodingError(String)
}
