//
//  IndexEmbeddingsContract.swift
//  AnigmaCore
//
//  Contract definition for IndexEmbeddingsContract in AnigmaCore.
//

import AnigmaFoundation
import AnigmaGovernance
import AnigmaJobs
import AnigmaPrimitives
import InferenceCore
import FoundationContracts
import EvidenceContracts
import Foundation
import DatabaseCore // Assuming DocumentUnitDatabase is in DatabaseCore or accessible

/// Input for the IndexEmbeddingsContract, which is the output of EmbedTextContract.
public struct IndexEmbeddingsInput: Codable, Sendable {
    public let modelID: String
    public let modelVersion: String?
    public let dimension: Int
    public let vectors: [EmbeddingVector] // From EmbedTextContract
}

/// Output of the IndexEmbeddingsContract, confirming which embeddings were indexed.
public struct IndexEmbeddingsOutput: Codable, Sendable {
    public let indexedEmbeddingIDs: [String]
    public let indexedCount: Int

    public init(indexedEmbeddingIDs: [String], indexedCount: Int) {
        self.indexedEmbeddingIDs = indexedEmbeddingIDs
        self.indexedCount = indexedCount
    }
}

/// Contract for indexing generated embeddings into a searchable database.
public enum IndexEmbeddingsContract: ContractSpec {
    public static let id = ContractID(name: "pipeline.embedding.index", major: 1, minor: 0, schemaHash: "v1.0")
    public typealias Input = IndexEmbeddingsInput
    public typealias Output = IndexEmbeddingsOutput
    public static let inputSchemaVersion = 1
    public static let outputSchemaVersion = 1

    public static func validate(output: IndexEmbeddingsOutput) throws {
        guard output.indexedCount == output.indexedEmbeddingIDs.count else {
            throw ContractValidationError.invalidSchema(code: "indexing.mismatch", message: "Indexed count does not match number of IDs.")
        }
    }

    public static func execute(input: ArtifactEnvelope<IndexEmbeddingsInput>, ctx: ContractContext) async throws -> ArtifactEnvelope<IndexEmbeddingsOutput> {
        // Assume DocumentUnitDatabase is accessible via the context or a global setup.
        // For simplicity, we'll create a mock DocumentUnitDatabase for now.
        // In a real scenario, ctx would provide access to necessary services like the database.

        // Mock DocumentUnitDatabase for demonstration
        class MockDocumentUnitDatabase {
            var embeddingRecipes: [String: String] = [:] // recipeHash -> recipeId
            var embeddings: [String: String] = [:] // embeddingId -> vectorData

            func getOrCreateEmbeddingRecipe(modelID: String, modelVersion: String?, dimension: Int) async throws -> String {
                let recipeHash = "\(modelID)-\(modelVersion ?? "")-\(dimension)"
                if let id = embeddingRecipes[recipeHash] { return id }
                let newId = UUID().uuidString
                embeddingRecipes[recipeHash] = newId
                return newId
            }

            func storeEmbedding(embeddingRecipeId: String, documentUnitId: String, vectorData: Data, vectorHash: String) async throws -> String {
                let id = UUID().uuidString
                embeddings[id] = vectorData.base64EncodedString()
                return id
            }
        }

        let mockDB = MockDocumentUnitDatabase() // Replace with actual context.databaseService.documentUnitDatabase

        var indexedEmbeddingIDs: [String] = []
        let modelID = input.payload.modelID
        let modelVersion = input.payload.modelVersion
        let dimension = input.payload.dimension

        let embeddingRecipeId = try await mockDB.getOrCreateEmbeddingRecipe(
            modelID: modelID,
            modelVersion: modelVersion,
            dimension: dimension
        )

        for vector in input.payload.vectors {
            // Need a documentUnitId for each embedding. This implies embeddings are linked to source documents.
            // For now, let's use a placeholder or derive from context.
            let documentUnitId = ctx.sessionID // Placeholder: link to session for now
            let vectorData = vector.vector.withUnsafeBytes { bufferPointer in
                Data(bytes: bufferPointer.baseAddress!, count: bufferPointer.count)
            }
            let vectorHash = ContractKeyDerivation.blake3Hex(vectorData)

            let embeddingId = try await mockDB.storeEmbedding(
                embeddingRecipeId: embeddingRecipeId,
                documentUnitId: documentUnitId,
                vectorData: vectorData,
                vectorHash: vectorHash
            )
            indexedEmbeddingIDs.append(embeddingId)
        }

        let payload = IndexEmbeddingsOutput(indexedEmbeddingIDs: indexedEmbeddingIDs, indexedCount: indexedEmbeddingIDs.count)
        let metrics = ExecutionMetrics(
            wallTimeMs: 50, // Simulated execution time
            toolCallCount: 0,
            executor: ctx.executorIdentity
        )
        let receipt = ContractReceipt.placeholder(
            contractID: id,
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
            evidenceRefs: [],
            metrics: metrics,
            receipt: receipt
        )
    }
}
