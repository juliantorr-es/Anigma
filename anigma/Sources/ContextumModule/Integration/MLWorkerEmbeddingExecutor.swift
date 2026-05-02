import Foundation
import ContractsCore

/// Executes embedding jobs through governed MLWorker path using EmbeddingComputing protocol
public struct MLWorkerEmbeddingExecutor {
    private let embeddingComputing: EmbeddingComputing
    private let modelRegistry: ModelRegistryProtocol

    public init(
        embeddingComputing: EmbeddingComputing,
        modelRegistry: ModelRegistryProtocol
    ) {
        self.embeddingComputing = embeddingComputing
        self.modelRegistry = modelRegistry
    }

    /// Execute embedding job through governed ML path
    public func execute(
        job: EmbeddingJobPayload
    ) async throws -> EmbeddingExecutionResult {
        // 1. Resolve and validate model from registry
        guard let entry = try await modelRegistry.find(id: job.embeddingModelID) else {
            throw EmbeddingError.modelNotFound(job.embeddingModelID)
        }

        // 2. Validate it's an embedding model
        guard entry.spec.task == ModelTaskKind.embedding else {
            throw EmbeddingError.invalidTaskKind("Expected embedding, got \(entry.spec.task.rawValue)")
        }

        // 3. Record usage
        try await modelRegistry.recordUsage(entry.id)

        // 4. Compute embeddings
        let texts = job.chunks.map { $0.content }
        let result = try await embeddingComputing.computeEmbeddings(
            modelID: entry.id,
            modelVersion: entry.spec.metadata["version"],
            inputs: texts,
            normalize: true
        )

        // 5. Convert to execution result with receipts
        var embeddings: [EmbeddingRow] = []
        for (index, vector) in result.vectors.enumerated() {
            guard index < job.chunks.count else { break }

            embeddings.append(EmbeddingRow(
                chunkHash: job.chunks[index].chunkHash,
                embeddingModelID: entry.id,
                modelHash: entry.spec.canonicalHash,
                vector: vector.map { Float($0) },
                dim: result.dimension,
                receiptID: "embed_\(job.jobID)_\(index)",
                evidenceHeadHash: result.inputHashes[index],
                createdAt: Date()
            ))
        }

        return EmbeddingExecutionResult(
            jobID: job.jobID,
            embeddingModelID: entry.id,
            modelHash: entry.spec.canonicalHash,
            tokenizerHash: entry.spec.tokenizerHash,
            embeddings: embeddings,
            receiptID: "job_\(job.jobID)",
            evidenceHeadHash: result.inputHashes.joined(separator: "|"),
            executionTimeMs: 0  // Computed by caller if needed
        )
    }
}

// MARK: - Supporting Types

public struct EmbeddingJobPayload: Codable, Sendable {
    public let jobID: String
    public let embeddingModelID: String
    public let chunks: [ChunkData]

    public init(jobID: String, embeddingModelID: String, chunks: [ChunkData]) {
        self.jobID = jobID
        self.embeddingModelID = embeddingModelID
        self.chunks = chunks
    }
}

public struct ChunkData: Codable, Sendable {
    public let chunkHash: String
    public let content: String
    public let embeddingModelID: String?

    public init(chunkHash: String, content: String, embeddingModelID: String?) {
        self.chunkHash = chunkHash
        self.content = content
        self.embeddingModelID = embeddingModelID
    }
}

public struct EmbeddingRow: Codable, Sendable {
    public let chunkHash: String
    public let embeddingModelID: String
    public let modelHash: String
    public let vector: [Float]
    public let dim: Int
    public let receiptID: String
    public let evidenceHeadHash: String
    public let createdAt: Date

    public init(
        chunkHash: String,
        embeddingModelID: String,
        modelHash: String,
        vector: [Float],
        dim: Int,
        receiptID: String,
        evidenceHeadHash: String,
        createdAt: Date
    ) {
        self.chunkHash = chunkHash
        self.embeddingModelID = embeddingModelID
        self.modelHash = modelHash
        self.vector = vector
        self.dim = dim
        self.receiptID = receiptID
        self.evidenceHeadHash = evidenceHeadHash
        self.createdAt = createdAt
    }
}

public struct EmbeddingExecutionResult: Codable, Sendable {
    public let jobID: String
    public let embeddingModelID: String
    public let modelHash: String
    public let tokenizerHash: String?
    public let embeddings: [EmbeddingRow]
    public let receiptID: String
    public let evidenceHeadHash: String
    public let executionTimeMs: Int

    public init(
        jobID: String,
        embeddingModelID: String,
        modelHash: String,
        tokenizerHash: String?,
        embeddings: [EmbeddingRow],
        receiptID: String,
        evidenceHeadHash: String,
        executionTimeMs: Int
    ) {
        self.jobID = jobID
        self.embeddingModelID = embeddingModelID
        self.modelHash = modelHash
        self.tokenizerHash = tokenizerHash
        self.embeddings = embeddings
        self.receiptID = receiptID
        self.evidenceHeadHash = evidenceHeadHash
        self.executionTimeMs = executionTimeMs
    }
}

public enum EmbeddingError: Error, LocalizedError {
    case modelNotFound(String)
    case invalidTaskKind(String)
    case mlWorkerUnavailable
    case outputMismatch
    case vectorParsingFailed

    public var errorDescription: String? {
        switch self {
        case .modelNotFound(let id):
            return "Embedding model not found: \(id)"
        case .invalidTaskKind(let kind):
            return "Model task kind \(kind) is not embedding"
        case .mlWorkerUnavailable:
            return "MLWorker execution unavailable"
        case .outputMismatch:
            return "MLWorker output count does not match chunk count"
        case .vectorParsingFailed:
            return "Failed to parse embedding vector from MLWorker output"
        }
    }
}
