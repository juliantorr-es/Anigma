//
//  ArtifactStore.swift
//  DatabaseCore
//
//  [Brief description of file purpose]
//

import ContractsCore
import Foundation

/// Persisted artifact record.
public struct PersistedArtifact: Sendable {
    public let artifactID: String
    public let sessionID: String
    public let contractID: ContractID
    public let schemaVersion: Int
    public let artifactKey: String
    public let payloadJSON: Data
    public let evidenceJSON: Data
    public let metricsJSON: Data
    public let envelopeJSON: Data
    public let receiptJSON: Data
    public let createdAt: Date

    public init(artifactID: String, sessionID: String, contractID: ContractID, schemaVersion: Int, artifactKey: String, payloadJSON: Data, evidenceJSON: Data, metricsJSON: Data, envelopeJSON: Data, receiptJSON: Data, createdAt: Date) {
        self.artifactID = artifactID
        self.sessionID = sessionID
        self.contractID = contractID
        self.schemaVersion = schemaVersion
        self.artifactKey = artifactKey
        self.payloadJSON = payloadJSON
        self.evidenceJSON = evidenceJSON
        self.metricsJSON = metricsJSON
        self.envelopeJSON = envelopeJSON
        self.receiptJSON = receiptJSON
        self.createdAt = createdAt
    }
}

/// SQLite-backed artifact store with idempotent writes.
public actor DatabaseArtifactStore {
    private let db: any DatabaseExecutor

    public init(database: any DatabaseExecutor) async throws {
        self.db = database
        try await MigrationRegistry.applyMigrations(using: db)
    }

    /// Stores an artifact if not already present for the artifact_key. Idempotent via UNIQUE constraint.
    /// Returns the canonical stored row (either the newly inserted artifact or the existing one).
    @discardableResult
    public func putArtifactIdempotent(_ artifact: PersistedArtifact) async throws -> PersistedArtifact {
        let inserted = try await db.executeAsync(
            """
            INSERT OR IGNORE INTO artifacts
            (artifact_id, session_id, contract_id, schema_version, artifact_key, payload_json, evidence_json, metrics_json, envelope_json, receipt_json, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                .text(artifact.artifactID),
                .text(artifact.sessionID),
                .text(artifact.contractID.name),
                .int(artifact.schemaVersion),
                .text(artifact.artifactKey),
                .blob(artifact.payloadJSON),
                .blob(artifact.evidenceJSON),
                .blob(artifact.metricsJSON),
                .blob(artifact.envelopeJSON),
                .blob(artifact.receiptJSON),
                .double(artifact.createdAt.timeIntervalSince1970)
            ]
        )

        if inserted > 0 {
            return artifact
        }

        if let existing = try await fetchArtifact(byKey: artifact.artifactKey) {
            return existing
        }

        return artifact
    }

    public func fetchArtifact(byKey key: String) async throws -> PersistedArtifact? {
        let rows = try await db.query(
            """
            SELECT artifact_id, session_id, contract_id, schema_version, artifact_key, payload_json, evidence_json, metrics_json, envelope_json, receipt_json, created_at
            FROM artifacts
            WHERE artifact_key = ?
            LIMIT 1
            """,
            parameters: [.text(key)]
        )

        guard let row = rows.first else { return nil }
        return decode(row: row)
    }

    public func fetchArtifacts(sessionID: String, contractID: ContractID) async throws -> [PersistedArtifact] {
        let rows = try await db.query(
            """
            SELECT artifact_id, session_id, contract_id, schema_version, artifact_key, payload_json, evidence_json, metrics_json, envelope_json, receipt_json, created_at
            FROM artifacts
            WHERE session_id = ? AND contract_id = ?
            """,
            parameters: [.text(sessionID), .text(contractID.name)]
        )
        return rows.compactMap { decode(row: $0) }
    }

    private func decode(row: DatabaseRow) -> PersistedArtifact? {
        guard
            let artifactID = row.string(for: "artifact_id"),
            let sessionID = row.string(for: "session_id"),
            let schemaVersion = row.int(for: "schema_version"),
            let artifactKey = row.string(for: "artifact_key"),
            let payloadJSON = row.data(for: "payload_json"),
            let evidenceJSON = row.data(for: "evidence_json"),
            let metricsJSON = row.data(for: "metrics_json"),
            let envelopeJSON = row.data(for: "envelope_json"),
            let receiptJSON = row.data(for: "receipt_json"),
            let createdAtDouble = row.double(for: "created_at")
        else {
            return nil
        }

        let contractIDString = row.string(for: "contract_id") ?? "unknown" // Provide a default if nil
        let contractID = ContractID(name: contractIDString, major: 1, minor: 0, schemaHash: "v1.0")

        return PersistedArtifact(
            artifactID: artifactID,
            sessionID: sessionID,
            contractID: contractID,
            schemaVersion: schemaVersion,
            artifactKey: artifactKey,
            payloadJSON: payloadJSON,
            evidenceJSON: evidenceJSON,
            metricsJSON: metricsJSON,
            envelopeJSON: envelopeJSON,
            receiptJSON: receiptJSON,
            createdAt: Date(timeIntervalSince1970: createdAtDouble)
        )
    }
}
