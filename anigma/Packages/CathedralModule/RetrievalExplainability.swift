//
//  RetrievalExplainability.swift
//  CathedralModule
//
//  Explainable search and retrieval with reproducibility tracking
//

import Foundation
import ContractsCore

// MARK: - Retrieval Explainability System

/// Provides explainable search with complete provenance and reproducibility
public actor RetrievalExplainability {
    private var queryHistory: [String: QueryRecord] = [:]
    private let evidenceSubstrate: EvidenceSubstrate
    private let persistence: CathedralDatabasePersistence?

    public init(evidenceSubstrate: EvidenceSubstrate, persistence: CathedralDatabasePersistence? = nil) {
        self.evidenceSubstrate = evidenceSubstrate
        self.persistence = persistence
    }

    // MARK: - Query Recording

    /// Record search query with parameters and results
    public func recordQuery(
        query: SearchQuery,
        results: [SearchResult],
        sessionId: String,
        agentId: String
    ) async throws -> QueryRecord {
        let record = QueryRecord(
            id: UUID().uuidString,
            query: query,
            results: results,
            timestamp: Date(),
            sessionId: sessionId,
            agentId: agentId
        )

        queryHistory[record.id] = record

        // Persist to database
        if let persistence = persistence {
            try await persistence.persistQueryRecord(record)
        }

        // Record as evidence
        let evidence = Evidence(
            type: .queryExecution,
            sessionId: sessionId,
            agentId: agentId,
            contentHash: record.id.sha256Hash,
            metadata: EvidenceMetadata(
                source: "RetrievalExplainability",
                operation: "recordQuery",
                parameters: [
                    "queryId": record.id,
                    "queryType": query.type.rawValue,
                    "resultCount": String(results.count)
                ],
                quality: .verified
            )
        )

        try await evidenceSubstrate.recordEvidence(evidence)

        return record
    }

    // MARK: - Result Provenance

    /// Record retrieval result with complete provenance
    public func recordRetrievalResult(
        queryId: String,
        result: SearchResult,
        sessionId: String,
        agentId: String
    ) async throws {
        let evidence = Evidence(
            type: .retrievalResult,
            sessionId: sessionId,
            agentId: agentId,
            contentHash: result.documentId.sha256Hash,
            metadata: EvidenceMetadata(
                source: "RetrievalExplainability",
                operation: "recordRetrievalResult",
                parameters: [
                    "queryId": queryId,
                    "documentId": result.documentId,
                    "score": String(result.score),
                    "rank": String(result.rank)
                ],
                quality: .verified
            )
        )

        try await evidenceSubstrate.recordEvidence(evidence)
    }

    // MARK: - Reproducibility Testing

    /// Verify that query produces same results
    public func verifyReproducibility(
        originalQueryId: String,
        newResults: [SearchResult]
    ) async throws -> ReproducibilityReport {
        guard let originalRecord = queryHistory[originalQueryId] else {
            throw CathedralError.invalidEvidenceFormat("Query \(originalQueryId) not found")
        }

        let originalResultIds = Set(originalRecord.results.map { $0.documentId })
        let newResultIds = Set(newResults.map { $0.documentId })

        let matchingResults = originalResultIds.intersection(newResultIds)
        let missingResults = originalResultIds.subtracting(newResultIds)
        let extraResults = newResultIds.subtracting(originalResultIds)

        let matchRate = Double(matchingResults.count) / Double(originalResultIds.count)

        return ReproducibilityReport(
            originalQueryId: originalQueryId,
            matchingResults: matchingResults.count,
            missingResults: missingResults.count,
            extraResults: extraResults.count,
            matchRate: matchRate,
            isReproducible: matchRate >= 0.95,
            timestamp: Date()
        )
    }

    // MARK: - Query Retrieval

    /// Get query record by ID
    public func getQueryRecord(queryId: String) async -> QueryRecord? {
        // Check in-memory first
        if let record = queryHistory[queryId] {
            return record
        }

        // Fall back to database
        if let persistence = persistence {
            return try? await persistence.getQueryRecord(queryId: queryId)
        }

        return nil
    }

    /// Get all queries for session
    public func getSessionQueries(sessionId: String) async -> [QueryRecord] {
        return queryHistory.values.filter { $0.sessionId == sessionId }
    }
}

// MARK: - Search Query

public struct SearchQuery: Sendable, Codable {
    public let text: String
    public let type: QueryType
    public let parameters: QueryParameters

    public enum QueryType: String, Sendable, Codable {
        case semantic = "semantic"
        case keyword = "keyword"
        case hybrid = "hybrid"
    }

    public init(text: String, type: QueryType, parameters: QueryParameters = QueryParameters()) {
        self.text = text
        self.type = type
        self.parameters = parameters
    }
}

public struct QueryParameters: Sendable, Codable {
    public let topK: Int
    public let threshold: Double
    public let filters: [String: String]

    public init(topK: Int = 10, threshold: Double = 0.7, filters: [String: String] = [:]) {
        self.topK = topK
        self.threshold = threshold
        self.filters = filters
    }
}

// MARK: - Search Result

public struct SearchResult: Sendable, Codable, Hashable {
    public let documentId: String
    public let score: Double
    public let rank: Int
    public let snippet: String?
    public let metadata: [String: String]

    public init(
        documentId: String,
        score: Double,
        rank: Int,
        snippet: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.documentId = documentId
        self.score = score
        self.rank = rank
        self.snippet = snippet
        self.metadata = metadata
    }
}

// MARK: - Query Record

public struct QueryRecord: Sendable, Codable {
    public let id: String
    public let query: SearchQuery
    public let results: [SearchResult]
    public let timestamp: Date
    public let sessionId: String
    public let agentId: String

    public init(
        id: String,
        query: SearchQuery,
        results: [SearchResult],
        timestamp: Date,
        sessionId: String,
        agentId: String
    ) {
        self.id = id
        self.query = query
        self.results = results
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.agentId = agentId
    }
}

// MARK: - Reproducibility Report

public struct ReproducibilityReport: Sendable, Codable {
    public let originalQueryId: String
    public let matchingResults: Int
    public let missingResults: Int
    public let extraResults: Int
    public let matchRate: Double
    public let isReproducible: Bool
    public let timestamp: Date

    public init(
        originalQueryId: String,
        matchingResults: Int,
        missingResults: Int,
        extraResults: Int,
        matchRate: Double,
        isReproducible: Bool,
        timestamp: Date
    ) {
        self.originalQueryId = originalQueryId
        self.matchingResults = matchingResults
        self.missingResults = missingResults
        self.extraResults = extraResults
        self.matchRate = matchRate
        self.isReproducible = isReproducible
        self.timestamp = timestamp
    }
}
