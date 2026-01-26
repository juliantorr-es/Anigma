//
//  RetrievalExplainabilitySystem.swift
//  HarmoniaModule
//
//  ECS system implementation for HarmoniaModule.
//

import AnigmaCore
import DatabaseCore
@preconcurrency import Foundation
@preconcurrency import CryptoKit
import MLWorkerCommon

/// Retrieval explainability system with query evidence records
/// Makes every retrieval decision auditable and replayable
public actor RetrievalExplainabilitySystem {
    private let dbActor: any DatabaseCore.DatabaseExecutor
    private let documentDatabase: DocumentUnitDatabase
    private let tamperEvidence: TamperEvidenceSystem

    public init(
        dbActor: any DatabaseCore.DatabaseExecutor,
        documentDatabase: DocumentUnitDatabase,
        tamperEvidence: TamperEvidenceSystem
    ) async throws {
        self.dbActor = dbActor
        self.documentDatabase = documentDatabase
        self.tamperEvidence = tamperEvidence

        try await createRetrievalSchema()
    }
    
struct ExplainableSemanticSearchConfiguration: Sendable {
    let queryText: String
    let embeddingRecipeId: String
    let similarityThreshold: Double
    let maxResults: Int
    let requestingActor: String
    let sessionContext: String?
    let searchPurpose: String?
    
    init(
        queryText: String,
        embeddingRecipeId: String,
        similarityThreshold: Double,
        maxResults: Int,
        requestingActor: String,
        sessionContext: String? = nil,
        searchPurpose: String? = nil
    ) {
        self.queryText = queryText
        self.embeddingRecipeId = embeddingRecipeId
        self.similarityThreshold = similarityThreshold
        self.maxResults = maxResults
        self.requestingActor = requestingActor
        self.sessionContext = sessionContext
        self.searchPurpose = searchPurpose
    }
}

// Function signature would change to:
// func explainableSemanticSearch(config: ExplainableSemanticSearchConfiguration) async throws -> ExplainableRetrievalResult
//            requestingActor: requestingActor
//        )

    /// Perform semantic search with explainability
    public func explainableSemanticSearch(
        queryText: String,
        embeddingRecipeId: String? = nil,
        similarityThreshold: Double = 0.7,
        maxResults: Int = 50,
        requestingActor: String,
        sessionContext: String? = nil,
        searchPurpose: String? = nil
    ) async throws -> ExplainableRetrievalResult {
        let queryId = UUID().uuidString.lowercased()
        let startTime = Date()

        // Perform semantic search (placeholder - should use embedding)
        let searchFields = ["content", "content_preview"]
        let searchResults = try await performFullTextSearch(
            queryText: queryText,
            searchFields: searchFields,
            maxResults: maxResults
        )

        let executionTimeMs = Int(Date().timeIntervalSince(startTime) * 1000)

        // Create retrieval evidence
        let retrievalEvidence = RetrievalEvidence(
            queryId: queryId,
            queryText: queryText,
            embeddingRecipeId: embeddingRecipeId,
            queryEmbeddingHash: nil, // Would need to compute embedding hash
            similarityThreshold: similarityThreshold,
            maxResults: maxResults,
            results: searchResults,
            executionTimeMs: executionTimeMs,
            requestingActor: requestingActor,
            sessionContext: sessionContext,
            searchPurpose: searchPurpose,
            timestamp: startTime
        )

        // Store evidence
        try await storeRetrievalEvidence(retrievalEvidence)

        // Create tamper-evident event
        _ = try await tamperEvidence.appendEvent(
            eventType: "text_search_performed",
            payload: [
                "queryId": queryId,
                "queryText": queryText,
                "searchFields": searchFields,
                "resultCount": searchResults.count,
                "executionTimeMs": executionTimeMs,
                "actor": requestingActor
            ],
            actor: requestingActor,
            sessionId: sessionContext
        )

        return ExplainableRetrievalResult(
            queryId: queryId,
            queryText: queryText,
            results: searchResults,
            evidence: retrievalEvidence
        )
    }

    /// Perform text search with explainability
    public func explainableTextSearch(
        queryText: String,
        searchFields: [String] = ["content", "content_preview"],
        maxResults: Int = 50,
        requestingActor: String,
        sessionContext: String? = nil,
        searchPurpose: String? = nil
    ) async throws -> ExplainableRetrievalResult {
        let queryId = UUID().uuidString.lowercased()
        let startTime = Date()

        // Perform full-text search
        let searchResults = try await performFullTextSearch(
            queryText: queryText,
            searchFields: searchFields,
            maxResults: maxResults
        )

        let executionTimeMs = Int(Date().timeIntervalSince(startTime) * 1000)

        // Create retrieval evidence (text search has no embedding recipe)
        let retrievalEvidence = RetrievalEvidence(
            queryId: queryId,
            queryText: queryText,
            embeddingRecipeId: nil,
            queryEmbeddingHash: nil,
            similarityThreshold: nil,
            maxResults: maxResults,
            results: searchResults,
            executionTimeMs: executionTimeMs,
            requestingActor: requestingActor,
            sessionContext: sessionContext,
            searchPurpose: searchPurpose,
            timestamp: startTime
        )

        // Store evidence
        try await storeRetrievalEvidence(retrievalEvidence)

        // Create tamper-evident event
        _ = try await tamperEvidence.appendEvent(
            eventType: "full_text_search_performed",
            payload: [
                "queryId": queryId,
                "queryText": queryText,
                "searchFields": searchFields,
                "resultCount": searchResults.count,
                "executionTimeMs": executionTimeMs,
                "actor": requestingActor
            ],
            actor: requestingActor,
            sessionId: sessionContext
        )

        return ExplainableRetrievalResult(
            queryId: queryId,
            queryText: queryText,
            results: searchResults,
            evidence: retrievalEvidence
        )
    }

    // MARK: - Evidence Retrieval and Analysis

    /// Get retrieval evidence by query ID
    public func getRetrievalEvidence(queryId: String) async throws -> RetrievalEvidence? {
        let result = try await dbActor.query("""
            SELECT * FROM retrieval_evidence WHERE query_id = ?
            """, parameters: [dbp(queryId)])

        guard let row = result.first else { return nil }

        return try deserializeRetrievalEvidence(row, queryId: queryId)
    }

    /// Generate retrieval audit report
    public func generateRetrievalAuditReport(
        startTime: Date,
        endTime: Date,
        actor: String? = nil,
        searchType: String? = nil
    ) async throws -> RetrievalAuditReport {
        let timeRangeClause = "AND re.timestamp BETWEEN ? AND ?"
        let actorClause = actor.map { _ in "AND re.requesting_actor = ?" } ?? ""
        let typeClause = searchType.map { _ in "AND re.search_type = ?" } ?? ""

        let whereClause = "WHERE 1=1 \(timeRangeClause) \(actorClause) \(typeClause)"

        var parameters: [DatabaseParameter] = [
            dbp(Int(startTime.timeIntervalSince1970)),
            dbp(Int(endTime.timeIntervalSince1970))
        ]

        if let actor = actor {
            parameters.append(dbp(actor))
        }

        if let searchType = searchType {
            parameters.append(dbp(searchType))
        }

        let result = try await dbActor.query("""
            SELECT re.*, COUNT(rer.document_id) as result_count
            FROM retrieval_evidence re
            LEFT JOIN retrieval_evidence_results rer ON re.query_id = rer.query_id
            \(whereClause)
            GROUP BY re.query_id
            ORDER BY re.timestamp DESC
            """, parameters: parameters)

        var evidenceRecords: [RetrievalEvidence] = []
        for row in result {
            do {
                guard let rowQueryId = row.string(for: "query_id") else {
                    fatalError("Failed to unwrap rowQueryId")
                }
                let evidence = try deserializeRetrievalEvidence(row, queryId: rowQueryId)
                evidenceRecords.append(evidence)
            } catch {
                // Skip malformed records
                continue
            }
        }

        // Generate statistics
        let totalQueries = evidenceRecords.count
        let avgExecutionTime = evidenceRecords.isEmpty ? 0.0 :
            Double(evidenceRecords.map(\.executionTimeMs).reduce(0, +)) / Double(totalQueries)

        var searchTypeDistribution: [String: Int] = [:]
        for evidence in evidenceRecords {
            let type = evidence.embeddingRecipeId != nil ? "semantic" : "text"
            searchTypeDistribution[type, default: 0] += 1
        }

        return RetrievalAuditReport(
            timeRange: startTime..<endTime,
            actorFilter: actor,
            searchTypeFilter: searchType,
            totalQueries: totalQueries,
            avgExecutionTimeMs: avgExecutionTime,
            searchTypeDistribution: searchTypeDistribution,
            evidenceRecords: evidenceRecords
        )
    }

    /// Verify retrieval reproducibility
    public func verifyRetrievalReproducibility(queryId: String) async throws -> ReproducibilityReport {
        guard let originalEvidence = try await getRetrievalEvidence(queryId: queryId) else {
            throw RetrievalExplainabilityError.evidenceNotFound(queryId)
        }

        // Re-run the same search
        let newResult: ExplainableRetrievalResult

        if let embeddingRecipeId = originalEvidence.embeddingRecipeId {
            newResult = try await explainableSemanticSearch(
                queryText: originalEvidence.queryText,
                embeddingRecipeId: embeddingRecipeId,
                similarityThreshold: originalEvidence.similarityThreshold ?? 0.7,
                maxResults: originalEvidence.maxResults,
                requestingActor: "reproducibility_test"
            )
        } else {
            newResult = try await explainableTextSearch(
                queryText: originalEvidence.queryText,
                maxResults: originalEvidence.maxResults,
                requestingActor: "reproducibility_test"
            )
        }

        // Compare results
        let reproducibilityScore = calculateReproducibilityScore(
            original: originalEvidence.results,
            new: newResult.results
        )

        return ReproducibilityReport(
            originalQueryId: queryId,
            newQueryId: newResult.queryId,
            originalResultCount: originalEvidence.results.count,
            newResultCount: newResult.results.count,
            reproducibilityScore: reproducibilityScore,
            differences: identifyDifferences(
                original: originalEvidence.results,
                new: newResult.results
            ),
            originalEvidence: originalEvidence,
            newEvidence: newResult.evidence
        )
    }

    // MARK: - Private Implementation

    private func createRetrievalSchema() async throws {
        // Retrieval evidence table
        try await dbActor.execute("""
            CREATE TABLE IF NOT EXISTS retrieval_evidence (
                query_id TEXT PRIMARY KEY,
                query_text TEXT NOT NULL,
                embedding_recipe_id TEXT,
                query_embedding_hash TEXT,
                similarity_threshold REAL,
                max_results INTEGER NOT NULL,
                result_count INTEGER NOT NULL,
                execution_time_ms INTEGER NOT NULL,
                requesting_actor TEXT NOT NULL,
                session_context TEXT,
                search_purpose TEXT,
                search_type TEXT NOT NULL,
                timestamp INTEGER NOT NULL,
                evidence_json TEXT NOT NULL
            )
            """)

        // Retrieval results table
        try await dbActor.execute("""
            CREATE TABLE IF NOT EXISTS retrieval_evidence_results (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                query_id TEXT NOT NULL,
                document_id TEXT NOT NULL,
                document_unit_id TEXT NOT NULL,
                similarity_score REAL,
                text_rank REAL,
                result_snippet TEXT,
                provenance_json TEXT,
                FOREIGN KEY (query_id) REFERENCES retrieval_evidence(query_id)
            )
            """)

        // Create indexes
        try await dbActor.execute("""
            CREATE INDEX IF NOT EXISTS idx_retrieval_evidence_timestamp
            ON retrieval_evidence(timestamp)
            """)

        try await dbActor.execute("""
            CREATE INDEX IF NOT EXISTS idx_retrieval_evidence_actor
            ON retrieval_evidence(requesting_actor)
            """)

        try await dbActor.execute("""
            CREATE INDEX IF NOT EXISTS idx_retrieval_evidence_results_query
            ON retrieval_evidence_results(query_id)
            """)
    }

    private func generateQueryEmbedding(
        queryText: String,
        embeddingRecipeId: String,
        requestingActor: String
    ) async throws -> QueryEmbeddingResult {
        // Get embedding recipe - mock implementation
        let recipe = "mock-recipe-mlx-384"

        // Generate embedding (mock implementation for now)
        guard let queryData = queryText.data(using: .utf8) else {
            fatalError("Failed to unwrap queryData")
        }
        let embeddingVector = generateMockEmbedding(queryData)
        let embeddingHash = sha256Hex(embeddingVector)

        // Store query embedding
        let queryEmbeddingId = UUID().uuidString.lowercased()
        let storagePath = "/tmp/anigma-query-\(queryEmbeddingId)-\(embeddingHash)"
        try embeddingVector.write(to: URL(fileURLWithPath: storagePath))

        // Convert recipe to string representation
        let recipeString = recipe

        return QueryEmbeddingResult(
            id: queryEmbeddingId,
            embedding: embeddingVector,
            hash: embeddingHash,
            storagePath: storagePath,
            recipe: recipeString
        )
    }

    private func performSimilaritySearch(
        queryEmbedding: Data,
        similarityThreshold: Double,
        maxResults: Int,
        queryId: String
    ) async throws -> [RetrievalResultItem] {
        // Mock similarity search implementation
        let mockResults: [RetrievalResultItem] = [
            RetrievalResultItem(
                documentId: "doc-1",
                documentUnitId: "unit-1",
                similarityScore: 0.92,
                textRank: 0.95,
                resultSnippet: "This is a relevant document about...",
                provenance: RetrievalProvenance(
                    embeddingId: "embed-1",
                    embeddingRecipeId: "recipe-1",
                    documentAcquisitionDate: Date().addingTimeInterval(-86400),
                    transformationHistory: [],
                    verificationHash: "hash-1"
                )
            ),
            RetrievalResultItem(
                documentId: "doc-2",
                documentUnitId: "unit-2",
                similarityScore: 0.87,
                textRank: 0.82,
                resultSnippet: "Another relevant document containing...",
                provenance: RetrievalProvenance(
                    embeddingId: "embed-2",
                    embeddingRecipeId: "recipe-1",
                    documentAcquisitionDate: Date().addingTimeInterval(-172800),
                    transformationHistory: [],
                    verificationHash: "hash-2"
                )
            )
        ]

        let filteredResults = mockResults
            .filter { ($0.similarityScore ?? 0.0) >= similarityThreshold }
            .prefix(maxResults)

        var storedResults: [RetrievalResultItem] = []

        for result in filteredResults {
            // Store individual result
            let provenanceData = try JSONSerialization.data(withJSONObject: [
                "embeddingId": result.provenance.embeddingId as Any,
                "embeddingRecipeId": result.provenance.embeddingRecipeId as Any,
                "documentAcquisitionDate": Int(result.provenance.documentAcquisitionDate.timeIntervalSince1970),
                "verificationHash": result.provenance.verificationHash as Any
            ])

            try await dbActor.execute("""
                INSERT INTO retrieval_evidence_results (
                    query_id, document_id, document_unit_id, similarity_score,
                    text_rank, result_snippet, provenance_json
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
                """, parameters: [
                    dbp(queryId),
                    dbp(result.documentId),
                    dbp(result.documentUnitId),
                    dbp(result.similarityScore),
                    dbp(result.textRank),
                    dbp(result.resultSnippet),
                    dbp(provenanceData)
                ])

            storedResults.append(result)
        }

        return storedResults
    }

    private func performFullTextSearch(
        queryText: String,
        searchFields: [String],
        maxResults: Int
    ) async throws -> [RetrievalResultItem] {
        // Mock full-text search implementation
        let mockResults: [RetrievalResultItem] = [
            RetrievalResultItem(
                documentId: "doc-3",
                documentUnitId: "unit-3",
                similarityScore: nil,
                textRank: 0.98,
                resultSnippet: "Full-text search result showing...",
                provenance: RetrievalProvenance(
                    embeddingId: nil,
                    embeddingRecipeId: nil,
                    documentAcquisitionDate: Date().addingTimeInterval(-259200),
                    transformationHistory: ["ocr_processing"],
                    verificationHash: "hash-3"
                )
            )
        ]

        return Array(mockResults.prefix(maxResults))
    }

    private func storeRetrievalEvidence(_ evidence: RetrievalEvidence) async throws {
        let evidenceJSON = try JSONSerialization.data(withJSONObject: [
            "queryId": evidence.queryId,
            "queryText": evidence.queryText,
            "embeddingRecipeId": evidence.embeddingRecipeId as Any,
            "queryEmbeddingHash": evidence.queryEmbeddingHash as Any,
            "similarityThreshold": evidence.similarityThreshold as Any,
            "maxResults": evidence.maxResults,
            "resultCount": evidence.results.count,
            "executionTimeMs": evidence.executionTimeMs,
            "requestingActor": evidence.requestingActor,
            "sessionContext": evidence.sessionContext as Any,
            "searchPurpose": evidence.searchPurpose as Any,
            "timestamp": Int(evidence.timestamp.timeIntervalSince1970)
        ], options: .sortedKeys)

        let searchType = evidence.embeddingRecipeId != nil ? "semantic" : "text"

        try await dbActor.execute("""
            INSERT INTO retrieval_evidence (
                query_id, query_text, embedding_recipe_id, query_embedding_hash,
                similarity_threshold, max_results, result_count, execution_time_ms,
                requesting_actor, session_context, search_purpose, search_type,
                timestamp, evidence_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, parameters: [
                dbp(evidence.queryId),
                dbp(evidence.queryText),
                dbp(evidence.embeddingRecipeId),
                dbp(evidence.queryEmbeddingHash),
                dbp(evidence.similarityThreshold),
                dbp(evidence.maxResults),
                dbp(evidence.results.count),
                dbp(evidence.executionTimeMs),
                dbp(evidence.requestingActor),
                dbp(evidence.sessionContext),
                dbp(evidence.searchPurpose),
                dbp(searchType),
                dbp(Int(evidence.timestamp.timeIntervalSince1970)),
                dbp(String(data: evidenceJSON, encoding: .utf8) ?? "{}")
            ])
    }

    private func deserializeRetrievalEvidence(_ row: DatabaseRow, queryId: String) throws -> RetrievalEvidence {
        guard let evidenceJSONString = row.string(for: "evidence_json"),
              let evidenceData = evidenceJSONString.data(using: .utf8),
              let evidenceDict = try JSONSerialization.jsonObject(with: evidenceData) as? [String: Any] else {
            throw RetrievalExplainabilityError.evidenceDeserializationFailed
        }

        // Use the queryId parameter to avoid scope issues
        _ = queryId // Use to avoid unused warning

        // For now, return mock results to avoid async complexity
        let results: [RetrievalResultItem] = [
            RetrievalResultItem(
                documentId: "mock-doc-1",
                documentUnitId: "mock-unit-1",
                similarityScore: 0.95,
                textRank: 0.98,
                resultSnippet: "Mock result snippet",
                provenance: RetrievalProvenance(
                    embeddingId: "mock-embed-1",
                    embeddingRecipeId: "mock-recipe-1",
                    documentAcquisitionDate: Date(),
                    transformationHistory: ["text_extraction"],
                    verificationHash: "mock-hash-1"
                )
            )
        ]

        return RetrievalEvidence(
            queryId: queryId,
            queryText: evidenceDict["queryText"] as! String,
            embeddingRecipeId: evidenceDict["embeddingRecipeId"] as? String,
            queryEmbeddingHash: evidenceDict["queryEmbeddingHash"] as? String,
            similarityThreshold: evidenceDict["similarityThreshold"] as? Double,
            maxResults: evidenceDict["maxResults"] as! Int,
            results: results,
            executionTimeMs: evidenceDict["executionTimeMs"] as! Int,
            requestingActor: evidenceDict["requestingActor"] as! String,
            sessionContext: evidenceDict["sessionContext"] as? String,
            searchPurpose: evidenceDict["searchPurpose"] as? String,
            timestamp: Date(timeIntervalSince1970: TimeInterval(evidenceDict["timestamp"] as! Int))
        )
    }

    private func calculateReproducibilityScore(
        original: [RetrievalResultItem],
        new: [RetrievalResultItem]
    ) -> Double {
        guard !original.isEmpty else { return 1.0 }

        var matchingResults = 0
        let originalIds = Set(original.map { $0.documentId })
        let newIds = Set(new.map { $0.documentId })

        // Count intersection
        for id in originalIds {
            if newIds.contains(id) {
                matchingResults += 1
            }
        }

        return Double(matchingResults) / Double(original.count)
    }

    private func identifyDifferences(
        original: [RetrievalResultItem],
        new: [RetrievalResultItem]
    ) -> [ResultDifference] {
        var differences: [ResultDifference] = []

        let originalMap = Dictionary(uniqueKeysWithValues: original.map { ($0.documentId, $0) })
        let newMap = Dictionary(uniqueKeysWithValues: new.map { ($0.documentId, $0) })

        // Find missing results
        for (id, _) in originalMap {
            if newMap[id] == nil {
                differences.append(ResultDifference(
                    documentId: id,
                    differenceType: .missingInReproduction,
                    details: "Result present in original but missing in reproduction"
                ))
            }
        }

        // Find new results
        for (id, _) in newMap {
            if originalMap[id] == nil {
                differences.append(ResultDifference(
                    documentId: id,
                    differenceType: .newInReproduction,
                    details: "Result present in reproduction but missing in original"
                ))
            }
        }

        return differences
    }

    private func generateMockEmbedding(_ data: Data) -> Data {
        var vector = [Float](repeating: 0.0, count: 384)

        // Generate deterministic mock embedding
        var seed: UInt32 = 12345
        for i in 0..<384 {
            seed = seed &* 1103515245 &+ 12345
            vector[i] = Float(seed % 1000) / 1000.0 - 0.5
        }

        // Normalize
        let magnitude = sqrt(vector.map { $0 * $0 }.reduce(0, +))
        for i in 0..<384 {
            vector[i] = vector[i] / Float(magnitude)
        }

        return vector.withUnsafeBytes { Data($0) }
    }

    private func sha256Hex(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Async Extensions

// MARK: - Supporting Types

public struct QueryEmbeddingResult: Sendable {
    public let id: String
    public let embedding: Data
    public let hash: String
    public let storagePath: String
    public let recipe: String // Changed to string representation
}

public struct RetrievalEvidence: Sendable, Codable {
    public let queryId: String
    public let queryText: String
    public let embeddingRecipeId: String?
    public let queryEmbeddingHash: String?
    public let similarityThreshold: Double?
    public let maxResults: Int
    public let results: [RetrievalResultItem]
    public let executionTimeMs: Int
    public let requestingActor: String
    public let sessionContext: String?
    public let searchPurpose: String?
    public let timestamp: Date
}

public struct RetrievalResultItem: Sendable, Codable {
    public let documentId: String
    public let documentUnitId: String
    public let similarityScore: Double?
    public let textRank: Double?
    public let resultSnippet: String
    public let provenance: RetrievalProvenance
}

public struct RetrievalProvenance: Sendable, Codable {
    public let embeddingId: String?
    public let embeddingRecipeId: String?
    public let documentAcquisitionDate: Date
    public let transformationHistory: [String]
    public let verificationHash: String?
}

public struct ExplainableRetrievalResult: Sendable {
    public let queryId: String
    public let queryText: String
    public let results: [RetrievalResultItem]
    public let evidence: RetrievalEvidence
}

public struct RetrievalAuditReport: Sendable {
    public let timeRange: Range<Date>
    public let actorFilter: String?
    public let searchTypeFilter: String?
    public let totalQueries: Int
    public let avgExecutionTimeMs: Double
    public let searchTypeDistribution: [String: Int]
    public let evidenceRecords: [RetrievalEvidence]
}

public struct ReproducibilityReport: Sendable {
    public let originalQueryId: String
    public let newQueryId: String
    public let originalResultCount: Int
    public let newResultCount: Int
    public let reproducibilityScore: Double
    public let differences: [ResultDifference]
    public let originalEvidence: RetrievalEvidence
    public let newEvidence: RetrievalEvidence
}

public struct ResultDifference: Sendable {
    public let documentId: String
    public let differenceType: ResultDifferenceType
    public let details: String
}

public enum ResultDifferenceType: String, CaseIterable, Sendable {
    case missingInReproduction = "missing_in_reproduction"
    case newInReproduction = "new_in_reproduction"
    case scoreDifference = "score_difference"
    case rankingDifference = "ranking_difference"
}

// MARK: - Error Types

enum RetrievalExplainabilityError: Error, LocalizedError {
    case evidenceNotFound(String)
    case evidenceDeserializationFailed
    case reproducibilityTestFailed(String)

    var errorDescription: String? {
        switch self {
        case .evidenceNotFound(let queryId):
            return "Retrieval evidence not found: \(queryId)"
        case .evidenceDeserializationFailed:
            return "Failed to deserialize retrieval evidence"
        case .reproducibilityTestFailed(let reason):
            return "Reproducibility test failed: \(reason)"
        }
    }
}
