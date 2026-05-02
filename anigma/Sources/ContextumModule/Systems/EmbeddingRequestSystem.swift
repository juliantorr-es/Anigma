import Foundation
import ContractsCore

public actor EmbeddingRequestSystem {
    private let database: ContextumDatabase
    private let budgetSystem: EmbeddingBudgetSystem
    private let modelRegistry: ModelRegistryProtocol
    private let embeddingComputing: EmbeddingComputing

    public init(
        database: ContextumDatabase,
        budgetSystem: EmbeddingBudgetSystem,
        modelRegistry: ModelRegistryProtocol,
        embeddingComputing: EmbeddingComputing
    ) {
        self.database = database
        self.budgetSystem = budgetSystem
        self.modelRegistry = modelRegistry
        self.embeddingComputing = embeddingComputing
    }

    public struct EmbeddingRequest: Codable, Sendable {
        public let jobID: String
        public let runID: String
        public let chunkHashes: [String]
        public let embeddingModelID: String
        public let embeddingModelHash: String
        public let batchSize: Int
        public let workflowID: String

        public init(
            jobID: String,
            runID: String,
            chunkHashes: [String],
            embeddingModelID: String,
            embeddingModelHash: String,
            batchSize: Int = 32,
            workflowID: String
        ) {
            self.jobID = jobID
            self.runID = runID
            self.chunkHashes = chunkHashes
            self.embeddingModelID = embeddingModelID
            self.embeddingModelHash = embeddingModelHash
            self.batchSize = batchSize
            self.workflowID = workflowID
        }
    }

    public struct EmbeddingResult: Codable, Sendable {
        public let chunkHash: String
        public let embedding: [Float]
        public let receiptID: String
        public let evidenceHeadHash: String
        public let modelHash: String
        public let modelID: String
        public let dimensions: Int
    }

    public func requestEmbeddings(request: EmbeddingRequest) async throws -> [EmbeddingResult] {
        guard await budgetSystem.canStartJob(runId: request.runID, jobId: request.jobID) else {
            throw EmbeddingBudgetError.budgetExhausted(runId: request.runID)
        }

        try await budgetSystem.startJob(runId: request.runID, jobId: request.jobID)
        defer {
            Task {
                await budgetSystem.completeJob(jobId: request.jobID)
            }
        }

        guard let entry = try await modelRegistry.find(id: request.embeddingModelID) else {
            throw ContextumError.invalidModelIdentity(
                modelID: request.embeddingModelID,
                modelHash: request.embeddingModelHash,
                reason: "Model not found in registry"
            )
        }

        guard entry.spec.task == ModelTaskKind.embedding else {
            throw ContextumError.invalidModelIdentity(
                modelID: request.embeddingModelID,
                modelHash: request.embeddingModelHash,
                reason: "Model is not an embedding model"
            )
        }

        // Extract embedding dimensions from metadata or use default
        let dimensions = Int(entry.spec.metadata["embedding_dimensions"] ?? "768") ?? 768

        var results: [EmbeddingResult] = []
        let batches = request.chunkHashes.chunked(into: request.batchSize)

        for batch in batches {
            let batchResults = try await executeBatch(
                chunkHashes: batch,
                modelID: request.embeddingModelID,
                modelHash: entry.spec.canonicalHash,
                dimensions: dimensions,
                workflowID: request.workflowID,
                runID: request.runID
            )
            results.append(contentsOf: batchResults)
        }

        return results
    }

    private func executeBatch(
        chunkHashes: [String],
        modelID: String,
        modelHash: String,
        dimensions: Int,
        workflowID: String,
        runID: String
    ) async throws -> [EmbeddingResult] {
        let chunkEntries = try await database.getChunkContentByHash(chunkHashes: chunkHashes)
        let chunkByHash = Dictionary(uniqueKeysWithValues: chunkEntries.map { ($0.chunkHash, $0) })
        let orderedChunks = chunkHashes.compactMap { chunkByHash[$0] }
        guard orderedChunks.count == chunkHashes.count else {
            throw ContextumDatabaseError.invalidChunkData
        }

        // Batch all chunk contents for efficient computation
        let texts = orderedChunks.map { $0.content }

        // Use the EmbeddingComputing protocol to compute embeddings
        let embeddingResult = try await embeddingComputing.computeEmbeddings(
            modelID: modelID,
            modelVersion: nil,
            inputs: texts,
            normalize: true
        )

        // Verify result dimensions match
        guard embeddingResult.dimension == dimensions else {
            throw ContextumError.invalidEmbeddingDimensions(
                expected: dimensions,
                actual: embeddingResult.dimension,
                modelID: modelID
            )
        }

        var results: [EmbeddingResult] = []

        // Store each embedding and create result
        for (index, chunk) in orderedChunks.enumerated() {
            guard index < embeddingResult.vectors.count else {
                throw ContextumError.embeddingFailed(
                    chunkHash: chunk.chunkHash,
                    modelID: modelID,
                    reason: "Missing embedding vector for chunk"
                )
            }

            let vector = embeddingResult.vectors[index]
            let floatVector = vector.map { Float($0) }

            let receiptID = "embed_\(workflowID)_\(UUID().uuidString)"

            let config = InsertEmbeddingConfiguration(
                embeddingId: UUID().uuidString,
                chunkHash: chunk.chunkHash,
                modelHash: modelHash,
                modelId: modelID,
                vectorDimensions: dimensions,
                vector: floatVector,
                receiptId: receiptID,
                evidenceHeadHash: embeddingResult.inputHashes[index]
            )
            
            try await database.insertEmbedding(config: config)

            results.append(EmbeddingResult(
                chunkHash: chunk.chunkHash,
                embedding: floatVector,
                receiptID: receiptID,
                evidenceHeadHash: embeddingResult.inputHashes[index],
                modelHash: modelHash,
                modelID: modelID,
                dimensions: dimensions
            ))
        }

        return results
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
