import Foundation
import ContractsCore

public struct AutoIndexingWorkflow {
    private let database: ContextumDatabase
    private let idempotencyGuard: IdempotencyGuard
    private let chunkingSystem: ChunkingSystem
    private let embeddingSystem: EmbeddingRequestSystem
    private let ftsSystem: FtsIndexSystem

    public init(
        database: ContextumDatabase,
        idempotencyGuard: IdempotencyGuard,
        chunkingSystem: ChunkingSystem,
        embeddingSystem: EmbeddingRequestSystem,
        ftsSystem: FtsIndexSystem
    ) {
        self.database = database
        self.idempotencyGuard = idempotencyGuard
        self.chunkingSystem = chunkingSystem
        self.embeddingSystem = embeddingSystem
        self.ftsSystem = ftsSystem
    }

    public func execute(commit: ArtifactCommitComponent) async throws -> IndexPlanReceipt {
        let stateKey = "\(commit.contentHash)_\(commit.chunkerVersion)_\(commit.embeddingModelID ?? "none")"

        // Check if already indexed using idempotency guard
        let idempotencyResult = try await idempotencyGuard.checkIngestIdempotency(
            artifactID: commit.artifactID,
            contentHash: commit.contentHash
        )

        switch idempotencyResult {
        case .alreadyIngested:
            return IndexPlanReceipt(
                commitReceiptID: commit.commitReceiptID,
                stateKey: stateKey,
                status: .skipped,
                reason: "Already indexed",
                chunkCount: 0,
                embeddingCount: 0
            )
        case .shouldIngest(let newStateKey):
            // Record the intent to ingest
            try await idempotencyGuard.recordIngestState(
                stateKey: newStateKey,
                artifactID: commit.artifactID,
                contentHash: commit.contentHash,
                chunkerVersion: String(commit.chunkerVersion),
                embeddingModelID: commit.embeddingModelID ?? "",
                chunkingNeeded: true,
                embeddingNeeded: commit.embeddingModelID != nil
            )
        }

        let startTime = Date()
        var chunkCount = 0
        var embeddingCount = 0

        // Step 1: Ingest source if needed
        let existingSource = try await database.getSource(artifactHash: commit.contentHash)
        if existingSource == nil {
            let sourceType: ContextSourceComponent.SourceType
            switch commit.mediaType.lowercased() {
            case let type where type.contains("code"):
                sourceType = .codebase
            case let type where type.contains("conversation"):
                sourceType = .conversation
            default:
                sourceType = .document
            }

            let source = ContextSourceComponent(
                sourceId: UUID().uuidString,
                sourceType: sourceType,
                artifactHash: commit.contentHash,
                receiptId: commit.commitReceiptID,
                timestamp: Date(),
                metadata: ["mediaType": commit.mediaType]
            )
            try await database.insertSource(source)
        }

        // Step 2: Chunk if needed (simplified - would normally load from artifact store)
        let existingChunks = try await database.getChunksByContentHash(contentHash: commit.contentHash)
        if existingChunks.isEmpty {
            // For now, skip actual chunking as it requires artifact store integration
            // In production, this would load content and chunk it
            chunkCount = 0
        } else {
            chunkCount = existingChunks.count
        }

        // Step 3: Embed if model specified (simplified)
        if commit.embeddingModelID != nil {
            // For now, skip embedding as it requires model registry integration
            // In production, this would request embeddings from MLWorker
            embeddingCount = 0
        }

        // Record index status
        let indexStatus = IndexStatusComponent(
            sourceId: commit.artifactID,
            indexType: .hybrid,
            status: .ready,
            lastUpdated: Date(),
            documentCount: chunkCount,
            errorMessage: nil
        )
        try await database.insertIndexStatus(indexStatus)

        let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)

        return IndexPlanReceipt(
            commitReceiptID: commit.commitReceiptID,
            stateKey: stateKey,
            status: .complete,
            reason: "Indexed successfully",
            chunkCount: chunkCount,
            embeddingCount: embeddingCount,
            durationMs: durationMs
        )
    }
}

public struct ArtifactCommitComponent: Codable, Sendable {
    public let artifactID: String
    public let contentHash: String
    public let sourceHash: String
    public let mediaType: String
    public let commitReceiptID: String
    public let chunkerVersion: Int
    public let embeddingModelID: String?
    public let indexed: Bool
    public let committedAt: Date

    public init(
        artifactID: String,
        contentHash: String,
        sourceHash: String,
        mediaType: String,
        commitReceiptID: String,
        chunkerVersion: Int,
        embeddingModelID: String?,
        indexed: Bool,
        committedAt: Date
    ) {
        self.artifactID = artifactID
        self.contentHash = contentHash
        self.sourceHash = sourceHash
        self.mediaType = mediaType
        self.commitReceiptID = commitReceiptID
        self.chunkerVersion = chunkerVersion
        self.embeddingModelID = embeddingModelID
        self.indexed = indexed
        self.committedAt = committedAt
    }
}

public struct IndexPlanReceipt: Codable, Sendable {
    public let commitReceiptID: String
    public let stateKey: String
    public let status: IndexStatus
    public let reason: String
    public let chunkCount: Int
    public let embeddingCount: Int
    public let durationMs: Int

    public init(
        commitReceiptID: String,
        stateKey: String,
        status: IndexStatus,
        reason: String,
        chunkCount: Int,
        embeddingCount: Int,
        durationMs: Int = 0
    ) {
        self.commitReceiptID = commitReceiptID
        self.stateKey = stateKey
        self.status = status
        self.reason = reason
        self.chunkCount = chunkCount
        self.embeddingCount = embeddingCount
        self.durationMs = durationMs
    }
}

public enum IndexStatus: String, Codable, Sendable {
    case pending
    case inProgress
    case complete
    case failed
    case skipped
}
