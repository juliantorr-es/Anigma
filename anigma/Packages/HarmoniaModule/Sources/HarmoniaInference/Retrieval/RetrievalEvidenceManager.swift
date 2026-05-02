//
//  RetrievalEvidenceManager.swift
//  HarmoniaModule
//
//  [Brief description of file purpose]
//

import Foundation
import HarmoniaCore
import AnigmaPrimitives
import InferenceCore
import AnigmaCore
import DatabaseCore
@preconcurrency import Foundation
@preconcurrency import CryptoKit
import MLWorkerCommon
import ContractsCore

// Use canonical security contract types
public typealias RetrievalResult = ContractsCore.RetrievalHit
public typealias RetrievalEvidenceRecord = ContractsCore.RetrievalEvidenceRecord

public struct HarmoniaRetrievalEvidenceConfiguration: Sendable {
    let queryId: String
    let queryText: String
    let embeddingRecipe: String
    let similarityThreshold: Double
    let maxResults: Int
    let results: [RetrievalResult]
    let executionTimeMs: Int
    let engineMetadata: ContractsCore.EmbeddingRecipe
    
    init(
        queryId: String,
        queryText: String,
        embeddingRecipe: String,
        similarityThreshold: Double,
        maxResults: Int,
        results: [RetrievalResult],
        executionTimeMs: Int,
        engineMetadata: ContractsCore.EmbeddingRecipe
    ) {
        self.queryId = queryId
        self.queryText = queryText
        self.embeddingRecipe = embeddingRecipe
        self.similarityThreshold = similarityThreshold
        self.maxResults = maxResults
        self.results = results
        self.executionTimeMs = executionTimeMs
        self.engineMetadata = engineMetadata
    }
}

// MARK: - Evidence Manager

/// Manager for retrieval evidence with database persistence
public actor RetrievalEvidenceManager {
    private let dbActor: any DatabaseCore.DatabaseExecutor
    private let tamperEvidence: TamperEvidenceSystem

    public init(dbActor: any DatabaseCore.DatabaseExecutor, tamperEvidence: TamperEvidenceSystem) {
        self.dbActor = dbActor
        self.tamperEvidence = tamperEvidence
    }

    public func storeRetrievalEvidence(config: HarmoniaRetrievalEvidenceConfiguration) async throws {
        let timestamp = Int(Date().timeIntervalSince1970)
        
        // Create evidence record
        let record = RetrievalEvidenceRecord(
            queryId: config.queryId,
            queryText: config.queryText,
            queryTimestamp: timestamp,
            embeddingRecipe: config.engineMetadata,
            similarityThreshold: Float(config.similarityThreshold),
            maxResults: config.maxResults,
            results: config.results,
            executionTimeMs: config.executionTimeMs,
            totalCandidates: config.results.count
        )

        let recordData = try JSONEncoder().encode(record)
        let recordHash = SHA256.hash(data: recordData).map { String(format: "%02x", $0) }.joined()

        _ = try await dbActor.executeAsync("""
            INSERT INTO retrieval_evidence (
                query_id, query_text, query_timestamp, embedding_recipe,
                similarity_threshold, max_results, total_candidates, results,
                execution_time_ms, engine_metadata, record_hash
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, parameters: [
            DatabaseCore.DatabaseParameter.text(config.queryId),
            DatabaseCore.DatabaseParameter.text(config.queryText),
            DatabaseCore.DatabaseParameter.int(timestamp),
            DatabaseCore.DatabaseParameter.text(try encodeJSON(config.embeddingRecipe)),
            DatabaseCore.DatabaseParameter.double(config.similarityThreshold),
            DatabaseCore.DatabaseParameter.int(config.maxResults),
            DatabaseCore.DatabaseParameter.int(config.results.count),
            DatabaseCore.DatabaseParameter.text(try encodeJSON(config.results)),
            DatabaseCore.DatabaseParameter.int(config.executionTimeMs),
            DatabaseCore.DatabaseParameter.text(try encodeJSON(config.engineMetadata)),
            DatabaseCore.DatabaseParameter.text(recordHash)
        ])

        // Append to evidence chain
        _ = try await tamperEvidence.appendEvent(
            eventType: "retrieval_operation",
            payload: [
                "query_id": config.queryId,
                "query_text": config.queryText,
                "timestamp": timestamp,
                "results_count": config.results.count,
                "execution_time_ms": config.executionTimeMs,
                "record_hash": recordHash
            ],
            actor: "RetrievalEvidenceManager",
            actorIP: "local",
            sessionId: config.queryId
        )
    }



    private func encodeJSON<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    /// Get retrieval evidence by query ID
    public func getRetrievalEvidence(queryId: String) async throws -> RetrievalEvidenceRecord? {
        let rows = try await dbActor.query("""
            SELECT * FROM retrieval_evidence
            WHERE query_id = ?
        """, parameters: [DatabaseCore.DatabaseParameter.text(queryId)])

        guard let row = rows.first else { return nil }

        let recipeData: Data = row.data(for: "embedding_recipe") ?? Data()
        let resultsData: Data = row.data(for: "results") ?? Data()
        return RetrievalEvidenceRecord(
            queryId: row.string(for: "query_id") ?? "",
            queryText: row.string(for: "query_text") ?? "",
            queryTimestamp: row.int(for: "query_timestamp") ?? 0,
            embeddingRecipe: try JSONDecoder().decode(EmbeddingRecipe.self, from: recipeData),
            similarityThreshold: Float(row.double(for: "similarity_threshold") ?? 0.0),
            maxResults: row.int(for: "max_results") ?? 0,
            results: try JSONDecoder().decode([RetrievalResult].self, from: resultsData),
            executionTimeMs: row.int(for: "execution_time_ms") ?? 0,
            totalCandidates: row.int(for: "total_candidates") ?? 0
        )
    }

    /// Replay a retrieval operation for verification
    public func replayRetrieval(queryId: String) async throws -> RetrievalEvidenceRecord? {
        guard let originalRecord = try await getRetrievalEvidence(queryId: queryId) else {
            return nil
        }

        // This would involve re-running same query with same embedding recipe
        // and comparing results to verify reproducibility
        return originalRecord
    }
}
