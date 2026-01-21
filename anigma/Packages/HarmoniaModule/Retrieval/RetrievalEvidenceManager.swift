//
//  RetrievalEvidenceManager.swift
//  HarmoniaModule
//
//  [Brief description of file purpose]
//

import AnigmaCore
import DatabaseCore
import Foundation
import CryptoKit
import MLWorkerCommon
import ContractsCore

// Use canonical security contract types
public typealias RetrievalResult = ContractsCore.RetrievalHit
public typealias RetrievalEvidenceRecord = ContractsCore.RetrievalEvidenceRecord

/// Manager for retrieval evidence with database persistence
public actor RetrievalEvidenceManager {
    private let dbActor: any DatabaseExecutor
    private let tamperEvidence: TamperEvidenceSystem

    public init(dbActor: any DatabaseExecutor, tamperEvidence: TamperEvidenceSystem) {
struct StoreRetrievalEvidenceConfiguration: Sendable {
    let queryId: String
    let queryText: String
    let embeddingRecipe: String
    let similarityThreshold: Double
    let maxResults: Int
    let results: [RetrievalResult]
    let executionTimeMs: Int
    let engineMetadata: EngineMetadata
    
    init(
        queryId: String,
        queryText: String,
        embeddingRecipe: String,
        similarityThreshold: Double,
        maxResults: Int,
        results: [RetrievalResult],
        executionTimeMs: Int,
        engineMetadata: EngineMetadata
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

// Updated function signature:
// func storeRetrievalEvidence(config: StoreRetrievalEvidenceConfiguration)
        queryId: String,
        queryText: String,
        embeddingRecipe: String,
        similarityThreshold: Double,
        maxResults: Int,
        results: [RetrievalResult],
        executionTimeMs: Int,
        engineMetadata: EngineMetadata
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

// Updated function signature:
func storeRetrievalEvidence(config: StoreRetrievalEvidenceConfiguration) async throws {
    let timestamp = Int(Date().timeIntervalSince1970)
    
    // Create evidence record
    let record = RetrievalEvidenceRecord(
        queryId: config.queryId,
        queryText: config.queryText,
        // ... continue with other parameters
    )
    // ... rest of implementation
}
            queryTimestamp: timestamp,
            embeddingRecipe: embeddingRecipe,
            similarityThreshold: similarityThreshold,
            maxResults: maxResults,
            results: results,
            executionTimeMs: executionTimeMs,
            totalCandidates: results.count
        )

        let recordData = try JSONEncoder().encode(record)
        let recordHash = Hashing.sha256Hex(recordData)

        _ = try await dbActor.execute("""
            INSERT INTO retrieval_evidence (
                query_id, query_text, query_timestamp, embedding_recipe,
                similarity_threshold, max_results, total_candidates, results,
                execution_time_ms, engine_metadata, record_hash
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, parameters: [
            dbp(queryId),
            dbp(queryText),
            dbp(timestamp),
            dbpJSON(embeddingRecipe),
            dbp(Double(similarityThreshold)),
            dbp(maxResults),
            dbp(results.count),
            dbpJSON(results),
            dbp(executionTimeMs),
            dbpJSON(engineMetadata),
            dbp(recordHash)
        ])

        // Append to evidence chain
        _ = try await tamperEvidence.appendEvent(
            eventType: "retrieval_operation",
            payload: [
                "query_id": queryId,
                "query_text": queryText,
                "timestamp": timestamp,
                "results_count": results.count,
                "execution_time_ms": executionTimeMs,
                "record_hash": recordHash
            ],
            actor: "RetrievalEvidenceManager",
            actorIP: "local",
            sessionId: queryId
        )
    }

    /// Get retrieval evidence by query ID
    public func getRetrievalEvidence(queryId: String) async throws -> RetrievalEvidenceRecord? {
        let rows = try await dbActor.query("""
            SELECT * FROM retrieval_evidence
            WHERE query_id = ?
        """, parameters: [dbp(queryId)])

        guard let row = rows.first else { return nil }

        let recipeData = row["embedding_recipe"]?.asData ?? Data()
        let resultsData = row["results"]?.asData ?? Data()
        return RetrievalEvidenceRecord(
            queryId: row["query_id"]?.asString ?? "",
            queryText: row["query_text"]?.asString ?? "",
            queryTimestamp: row["query_timestamp"]?.asInt ?? 0,
            embeddingRecipe: try JSONDecoder().decode(EmbeddingRecipe.self, from: recipeData),
            similarityThreshold: Float(row["similarity_threshold"]?.asDouble ?? 0.0),
            maxResults: row["max_results"]?.asInt ?? 0,
            results: try JSONDecoder().decode([RetrievalResult].self, from: resultsData),
            executionTimeMs: row["execution_time_ms"]?.asInt ?? 0,
            totalCandidates: row["total_candidates"]?.asInt ?? 0
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
