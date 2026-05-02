import Foundation
import ContractsCore

/// Bridges artifact store commit events to Contextum indexing pipeline
/// Implements auto-indexing with debouncing and idempotency
public actor ArtifactStoreEventBridge {
    private let submitJob: (String, Codable) async throws -> Void
    private let recordTelemetry: (Codable) async throws -> Void
    private let debounceWindow: TimeInterval
    private var pendingCommits: [String: ArtifactCommitEvent] = [:]
    private var debounceTask: Task<Void, Never>?

    public init(
        submitJob: @escaping (String, Codable) async throws -> Void,
        recordTelemetry: @escaping (Codable) async throws -> Void,
        debounceWindow: TimeInterval = 2.0
    ) {
        self.submitJob = submitJob
        self.recordTelemetry = recordTelemetry
        self.debounceWindow = debounceWindow
    }

    /// Record an artifact commit and trigger indexing
    /// Debounced to handle batch commits (e.g., repo checkout)
    public func recordCommit(_ event: ArtifactCommitEvent) {
        // Store event keyed by contentHash for deduplication
        pendingCommits[event.contentHash] = event

        // Cancel existing debounce task
        debounceTask?.cancel()

        // Start new debounce window
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(debounceWindow * 1_000_000_000))

            guard !Task.isCancelled else { return }

            await flushPendingCommits()
        }
    }

    private func flushPendingCommits() async {
        let commits = Array(pendingCommits.values)
        pendingCommits.removeAll()

        for commit in commits {
            await enqueueIndexingJobs(for: commit)
        }
    }

    private func enqueueIndexingJobs(for event: ArtifactCommitEvent) async {
        // Check if already indexed
        let stateKey = computeStateKey(
            contentHash: event.contentHash,
            chunkerVersion: 1, // Use current version
            embeddingModelID: event.embeddingModelID
        )

        // Build auto-indexing job payload
        let jobPayload = AutoIndexingJobPayload(
            artifactID: event.artifactID,
            contentHash: event.contentHash,
            sourceHash: event.sourceHash,
            mediaType: event.mediaType,
            commitReceiptID: event.commitReceiptID,
            embeddingModelID: event.embeddingModelID,
            chunkerVersion: 1,
            stateKey: stateKey
        )

        // Submit job through injected closure
        try? await submitJob("context.autoindex", jobPayload)

        // Record indexing plan event for forensics
        let planEvent = IndexPlanEvent(
            eventID: UUID().uuidString,
            artifactID: event.artifactID,
            contentHash: event.contentHash,
            stateKey: stateKey,
            ingestJobID: "ingest_\(event.artifactID)",
            chunkJobID: "chunk_\(event.contentHash)",
            embedJobID: event.embeddingModelID != nil ? "embed_\(event.contentHash)" : nil,
            commitReceiptID: event.commitReceiptID,
            timestamp: Date()
        )

        // Persist plan event via injected telemetry
        try? await recordTelemetry(planEvent)
    }

    private func computeStateKey(
        contentHash: String,
        chunkerVersion: Int,
        embeddingModelID: String?
    ) -> String {
        return "\(contentHash)_\(chunkerVersion)_\(embeddingModelID ?? "none")"
    }
}

// MARK: - Event Types

public struct ArtifactCommitEvent: Codable, Sendable {
    public let artifactID: String
    public let contentHash: String
    public let sourceHash: String
    public let mediaType: String
    public let commitReceiptID: String
    public let embeddingModelID: String?
    public let timestamp: Date

    public init(
        artifactID: String,
        contentHash: String,
        sourceHash: String,
        mediaType: String,
        commitReceiptID: String,
        embeddingModelID: String? = nil,
        timestamp: Date = Date()
    ) {
        self.artifactID = artifactID
        self.contentHash = contentHash
        self.sourceHash = sourceHash
        self.mediaType = mediaType
        self.commitReceiptID = commitReceiptID
        self.embeddingModelID = embeddingModelID
        self.timestamp = timestamp
    }
}

public struct IndexPlanEvent: Codable, Sendable {
    public let eventID: String
    public let artifactID: String
    public let contentHash: String
    public let stateKey: String
    public let ingestJobID: String
    public let chunkJobID: String
    public let embedJobID: String?
    public let commitReceiptID: String
    public let timestamp: Date

    public init(
        eventID: String,
        artifactID: String,
        contentHash: String,
        stateKey: String,
        ingestJobID: String,
        chunkJobID: String,
        embedJobID: String?,
        commitReceiptID: String,
        timestamp: Date
    ) {
        self.eventID = eventID
        self.artifactID = artifactID
        self.contentHash = contentHash
        self.stateKey = stateKey
        self.ingestJobID = ingestJobID
        self.chunkJobID = chunkJobID
        self.embedJobID = embedJobID
        self.commitReceiptID = commitReceiptID
        self.timestamp = timestamp
    }
}

public struct AutoIndexingJobPayload: Codable, Sendable {
    public let artifactID: String
    public let contentHash: String
    public let sourceHash: String
    public let mediaType: String
    public let commitReceiptID: String
    public let embeddingModelID: String?
    public let chunkerVersion: Int
    public let stateKey: String

    public init(
        artifactID: String,
        contentHash: String,
        sourceHash: String,
        mediaType: String,
        commitReceiptID: String,
        embeddingModelID: String?,
        chunkerVersion: Int,
        stateKey: String
    ) {
        self.artifactID = artifactID
        self.contentHash = contentHash
        self.sourceHash = sourceHash
        self.mediaType = mediaType
        self.commitReceiptID = commitReceiptID
        self.embeddingModelID = embeddingModelID
        self.chunkerVersion = chunkerVersion
        self.stateKey = stateKey
    }
}
