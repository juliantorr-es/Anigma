import Foundation
import ContractsCore
import TelemetryCore

/// Adapter for ingesting artifacts into Contextum with debounced auto-flush
public actor ArtifactIngestionAdapter {
    private let database: ContextumDatabase
    private let chunkerVersion: Int
    private let debounceWindow: TimeInterval
    private let telemetry: TelemetryClient

    private var pendingCommits: [String: ArtifactCommitComponent] = [:]
    private var flushTask: Task<Void, Never>?
    private var lastCommitTime: Date?

    public init(
        database: ContextumDatabase,
        chunkerVersion: Int = 1,
        debounceWindow: TimeInterval = 2.0,
        telemetry: TelemetryClient? = nil
    ) {
        self.database = database
        self.chunkerVersion = chunkerVersion
        self.debounceWindow = debounceWindow
        self.telemetry = telemetry ?? TelemetryClient.forDevelopment()
    }

    public func recordArtifactCommit(
        artifactID: String,
        contentHash: String,
        sourceHash: String,
        mediaType: String,
        commitReceiptID: String,
        embeddingModelID: String?
    ) {
        let commit = ArtifactCommitComponent(
            artifactID: artifactID,
            contentHash: contentHash,
            sourceHash: sourceHash,
            mediaType: mediaType,
            commitReceiptID: commitReceiptID,
            chunkerVersion: chunkerVersion,
            embeddingModelID: embeddingModelID,
            indexed: false,
            committedAt: Date()
        )

        pendingCommits[contentHash] = commit
        lastCommitTime = Date()

        // Cancel existing flush task and schedule new one
        flushTask?.cancel()
        scheduleDebouncedFlush()
    }

    public func getPendingCommits() -> [ArtifactCommitComponent] {
        return Array(pendingCommits.values)
    }

    public func clearPendingCommits() {
        pendingCommits.removeAll()
    }

    /// Manually flush pending commits immediately
    public func flush() async throws {
        flushTask?.cancel()
        try await flushInternal()
    }

    // MARK: - Private

    private func scheduleDebouncedFlush() {
        let debounceWindow = self.debounceWindow
        flushTask = Task { [weak self] in
            guard let self = self else { return }

            // Wait for debounce window
            try? await Task.sleep(for: .seconds(debounceWindow))

            // If not cancelled, flush
            guard !Task.isCancelled else { return }

            try? await self.flushInternal()
        }
    }

    private func flushInternal() async throws {
        guard !pendingCommits.isEmpty else { return }

        let commits = Array(pendingCommits.values)
        let startTime = Date()
        
        // Log flush operation start
        _ = await telemetry.emit(
            category: .workflow,
            name: "contextum.artifact.flush_start",
            privacyClassification: .internal,
            values: [
                "pending_count": .integer(commits.count)
            ]
        )

        // Persist commits to database
        for commit in commits {
            try await database.insertArtifactCommit(commit)
        }
        
        let duration = Date().timeIntervalSince(startTime) * 1000

        // Log successful flush with metrics
        _ = await telemetry.emitTrace(
            module: "ContextumModule.ArtifactIngestionAdapter",
            action: "flush",
            durationMs: duration,
            privacyClassification: .internal,
            additionalValues: [
                "commits_flushed": .integer(commits.count)
            ]
        )
        
        pendingCommits.removeAll()
    }
}
