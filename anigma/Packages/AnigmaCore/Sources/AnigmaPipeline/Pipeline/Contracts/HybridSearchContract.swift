//
//  HybridSearchContract.swift
//  AnigmaCore
//
//  Contract definition for HybridSearchContract in AnigmaCore.
//

import AnigmaFoundation
import AnigmaGovernance
import AnigmaJobs
import AnigmaPrimitives
import InferenceCore
import FoundationContracts
import EvidenceContracts
import Foundation
import DatabaseCore // For DocumentUnitDatabase, RetrievalModels, etc.

public struct EmbeddingSearchResult: Codable, Sendable {
    public let embeddingId: String
    public let documentUnitId: String
    public let vector: Data
    public let distance: Double

    public init(embeddingId: String, documentUnitId: String, vector: Data, distance: Double) {
        self.embeddingId = embeddingId
        self.documentUnitId = documentUnitId
        self.vector = vector
        self.distance = distance
    }
}

public struct LexicalSearchResult: Codable, Sendable {
    public let documentUnitId: String
    public let textSnippet: String
    public let score: Double

    public init(documentUnitId: String, textSnippet: String, score: Double) {
        self.documentUnitId = documentUnitId
        self.textSnippet = textSnippet
        self.score = score
    }
}

/// Input for the HybridSearchContract.
public struct HybridSearchInput: Codable, Sendable {
    public let query: String
    public let topK: Int // Number of top results to retrieve
    public let embeddingModelID: String? // Model to use for query embedding
    // Add other search parameters like filters, lexical query, etc.
}

/// A single search hit with content, score, and evidence references.
public struct HybridSearchHit: Codable, Sendable {
    public let documentUnitID: String
    public let textSnippet: String // The relevant text snippet
    public var score: Double // Combined lexical + vector score
    public var lexicalScore: Double
    public let vectorScore: Double
    public let artifactID: String // Reference to the original artifact (e.g., PDFBlobArtifact)
    public let evidenceRefs: [EvidenceRef] // References to specific spans, pages, etc.
}

/// Output of the HybridSearchContract.
public struct HybridSearchResult: Codable, Sendable {
    public let hits: [HybridSearchHit]
    public let totalHits: Int
}

/// Contract for performing a hybrid search (lexical + vector) over indexed content.
public enum HybridSearchContract: ContractSpec {
    public static let id = ContractID(name: "retrieval.hybrid.search", major: 1, minor: 0, schemaHash: "v1.0")
    public typealias Input = HybridSearchInput
    public typealias Output = HybridSearchResult
    public static let inputSchemaVersion = 1
    public static let outputSchemaVersion = 1

    public static func validate(output: ArtifactEnvelope<HybridSearchResult>) throws {
        // No specific validation for now
    }

    public static func execute(input: ArtifactEnvelope<HybridSearchInput>, ctx: ContractContext) async throws -> ArtifactEnvelope<HybridSearchResult> {
        guard let embeddingComputer = ctx.embeddingComputer else {
            throw ContractExecutionError.deniedToolAccess(code: "hybrid_search.embedding_computer_missing", message: "EmbeddingComputing is required for HybridSearchContract.")
        }

        let query = input.payload.query
        let topK = input.payload.topK
        let embeddingModelID = input.payload.embeddingModelID ?? "nomic-embed-text" // Default model

        // --- Step 1: Generate Query Embedding ---
        let queryEmbeddingResult = try await embeddingComputer.computeEmbeddings(
            modelID: embeddingModelID,
            modelVersion: nil, // Assuming no specific version for now
            inputs: [query],
            normalize: true
        )
        guard let queryVector = queryEmbeddingResult.vectors.first else {
            throw ContractExecutionError.underlying(code: "search.embedding_failed", message: "Failed to generate query embedding.")
        }

        // --- Step 2: Perform Hybrid Search ---
        // For demonstration, we'll use a mock DocumentUnitDatabase interaction.
        // In a real scenario, ctx would provide access to DocumentUnitDatabase or a RetrievalService.

        // Mock DocumentUnitDatabase interaction for search
        struct MockDocumentUnitDatabaseForSearch {
            func searchEmbeddings(queryVector: Data, embeddingRecipeId: String? = nil, limit: Int) async throws -> [EmbeddingSearchResult] {
                // Simulate some search results
                let mockResults: [EmbeddingSearchResult] = [
                    .init(embeddingId: "emb-1", documentUnitId: "doc-1", vector: Data(), distance: 0.1),
                    .init(embeddingId: "emb-2", documentUnitId: "doc-2", vector: Data(), distance: 0.2)
                ]
                return Array(mockResults.prefix(limit))
            }

            func performLexicalSearch(query: String, limit: Int) async throws -> [LexicalSearchResult] {
                // Simulate some lexical search results
                let mockResults: [LexicalSearchResult] = [
                    .init(documentUnitId: "doc-1", textSnippet: "Lexical snippet for \(query)", score: 0.9),
                    .init(documentUnitId: "doc-3", textSnippet: "Another snippet", score: 0.8)
                ]
                return Array(mockResults.prefix(limit))
            }
        }

        let mockDB = MockDocumentUnitDatabaseForSearch() // Replace with actual database service

        let queryVectorData = queryVector.withUnsafeBytes { bufferPointer in
            Data(bytes: bufferPointer.baseAddress!, count: bufferPointer.count)
        }

        let vectorSearchResults = try await mockDB.searchEmbeddings(
            queryVector: queryVectorData,
            embeddingRecipeId: nil as String?, // Search across all recipes for now
            limit: topK
        )

        let lexicalSearchResults = try await mockDB.performLexicalSearch(
            query: query,
            limit: topK
        )

        // --- Step 3: Combine and Rank Results ---
        var combinedHits: [String: HybridSearchHit] = [:]

        // Process vector results
        for vsr in vectorSearchResults {
            let snippet = "Vector-based snippet for \(vsr.documentUnitId)" // Placeholder
            combinedHits[vsr.documentUnitId] = HybridSearchHit(
                documentUnitID: vsr.documentUnitId,
                textSnippet: snippet,
                score: 1.0 - vsr.distance, // Convert distance to score
                lexicalScore: 0.0, // Will be updated if a lexical hit
                vectorScore: 1.0 - vsr.distance,
                artifactID: vsr.documentUnitId, // Assuming docUnitID is also artifactID for simplicity
                evidenceRefs: []
            )
        }

        // Process lexical results and combine
        for lsr in lexicalSearchResults {
            if var existingHit = combinedHits[lsr.documentUnitId] {
                // Combine scores, update snippet if better, etc.
                existingHit.lexicalScore = lsr.score
                existingHit.score = (existingHit.vectorScore * 0.5) + (lsr.score * 0.5) // Simple average
                combinedHits[lsr.documentUnitId] = existingHit
            } else {
                combinedHits[lsr.documentUnitId] = HybridSearchHit(
                    documentUnitID: lsr.documentUnitId,
                    textSnippet: lsr.textSnippet,
                    score: lsr.score * 0.5, // Only lexical score
                    lexicalScore: lsr.score,
                    vectorScore: 0.0,
                    artifactID: lsr.documentUnitId,
                    evidenceRefs: []
                )
            }
        }

        // Sort by combined score
        let sortedHits = combinedHits.values.sorted { $0.score > $1.score }

        let payload = HybridSearchResult(hits: sortedHits, totalHits: sortedHits.count)
        let metrics = ExecutionMetrics(
            wallTimeMs: 100, // Simulated execution time
            toolCallCount: 1, // For embedding generation
            executor: ctx.executorIdentity
        )
        let receipt = ContractReceipt.placeholder(
            contractID: Self.id,
            runID: ctx.runID,
            sessionID: ctx.sessionID,
            status: .satisfied,
            startedAt: Date(),
            endedAt: Date(),
            metrics: metrics
        )

        return ArtifactEnvelope(
            schemaVersion: outputSchemaVersion,
            payload: payload,
            evidenceRefs: [], // Evidence will be built from hits
            metrics: metrics,
            receipt: receipt
        )
    }
}
