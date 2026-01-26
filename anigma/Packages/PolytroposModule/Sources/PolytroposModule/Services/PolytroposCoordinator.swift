//
//  PolytroposCoordinator.swift
//  PolytroposModule
//
//  Actor that orchestrates the video ingestion and processing pipeline.
//

import AnigmaCore
import Foundation
import MediaContainerCapsule

// MARK: - PolytroposCoordinator

/// Central coordinator actor for the Polytropos video processing pipeline.
///
/// Orchestrates:
/// - Video ingestion and metadata extraction
/// - Key frame harvesting
/// - Integration with ArtifactStoreModule for persistence
/// - Pipeline state management
public actor PolytroposCoordinator {
    // MARK: - Properties

    /// Video ingestion service.
    private let ingestionService: VideoIngestionService

    /// Configuration for the coordinator.
    private let configuration: PolytroposCoordinatorConfiguration

    /// In-memory cache of processed assets.
    private var assetCache: [UUID: VideoAsset] = [:]

    /// Active processing jobs.
    private var activeJobs: [UUID: ProcessingJob] = [:]

    /// Event subscribers.
    private var eventHandlers: [(PolytroposEvent) -> Void] = []

    /// Artifact store integration (optional).
    private let artifactStoreAdapter: ArtifactStoreAdapter?

    // MARK: - Initialization

    public init(
        configuration: PolytroposCoordinatorConfiguration = .default,
        ingestionService: VideoIngestionService? = nil,
        artifactStoreAdapter: ArtifactStoreAdapter? = nil
    ) {
        self.configuration = configuration
        self.ingestionService = ingestionService ?? VideoIngestionService(
            configuration: configuration.ingestionConfiguration,
            containerCapsule: nil,
            workDirectory: configuration.workDirectory
        )
        self.artifactStoreAdapter = artifactStoreAdapter
    }

    /// Create a coordinator with a pre-configured MediaContainerCapsule.
    public init(
        configuration: PolytroposCoordinatorConfiguration = .default,
        containerCapsule: MediaContainerCapsuleWrapper,
        artifactStoreAdapter: ArtifactStoreAdapter? = nil
    ) {
        self.configuration = configuration
        self.ingestionService = VideoIngestionService(
            configuration: configuration.ingestionConfiguration,
            containerCapsule: containerCapsule,
            workDirectory: configuration.workDirectory
        )
        self.artifactStoreAdapter = artifactStoreAdapter
    }

    // MARK: - Public API

    /// Ingest a video file and process it through the pipeline.
    ///
    /// - Parameters:
    ///   - url: URL to the video file.
    ///   - options: Processing options.
    /// - Returns: The processed VideoAsset.
    public func ingestVideo(
        at url: URL,
        options: ProcessingOptions = .default
    ) async throws -> VideoAsset {
        let jobId = UUID()
        let job = ProcessingJob(
            id: jobId,
            sourceURL: url,
            status: .pending,
            startedAt: Date()
        )
        activeJobs[jobId] = job

        emitEvent(.processingStarted(jobId: jobId, url: url))

        do {
            // Update job status
            var updatedJob = job
            updatedJob.status = .ingesting
            activeJobs[jobId] = updatedJob

            // Ingest the video
            var asset = try await ingestionService.ingest(
                url: url,
                extractFrames: options.extractFrames
            )

            // Persist to artifact store if adapter is available
            if let adapter = artifactStoreAdapter, options.persistToArtifactStore {
                updatedJob.status = .persisting
                activeJobs[jobId] = updatedJob

                let artifactID = try await adapter.persistVideoAsset(asset)
                asset.artifactID = artifactID
            }

            // Cache the asset
            assetCache[asset.id] = asset

            // Complete the job
            updatedJob.status = .completed
            updatedJob.completedAt = Date()
            updatedJob.resultAssetId = asset.id
            activeJobs[jobId] = updatedJob

            emitEvent(.processingCompleted(jobId: jobId, asset: asset))

            return asset
        } catch {
            var updatedJob = job
            updatedJob.status = .failed
            updatedJob.completedAt = Date()
            updatedJob.error = error.localizedDescription
            activeJobs[jobId] = updatedJob

            emitEvent(.processingFailed(jobId: jobId, error: error))
            throw error
        }
    }

    /// Ingest multiple videos in batch.
    ///
    /// - Parameters:
    ///   - urls: URLs to video files.
    ///   - options: Processing options.
    ///   - progressHandler: Optional progress callback.
    /// - Returns: Array of results.
    public func ingestVideos(
        at urls: [URL],
        options: ProcessingOptions = .default,
        progressHandler: ((Int, Int) -> Void)? = nil
    ) async -> [IngestionResult] {
        var results: [IngestionResult] = []

        for (index, url) in urls.enumerated() {
            progressHandler?(index, urls.count)

            do {
                let asset = try await ingestVideo(at: url, options: options)
                results.append(.success(asset))
            } catch {
                results.append(.failure(url: url, error: error))
            }
        }

        progressHandler?(urls.count, urls.count)
        return results
    }

    /// Get a cached asset by ID.
    public func getAsset(id: UUID) -> VideoAsset? {
        assetCache[id]
    }

    /// Get all cached assets.
    public func getAllAssets() -> [VideoAsset] {
        Array(assetCache.values)
    }

    /// Get the status of a processing job.
    public func getJobStatus(id: UUID) -> ProcessingJob? {
        activeJobs[id]
    }

    /// Get all active jobs.
    public func getActiveJobs() -> [ProcessingJob] {
        Array(activeJobs.values).filter { $0.status != .completed && $0.status != .failed }
    }

    /// Subscribe to coordinator events.
    public func subscribe(_ handler: @escaping (PolytroposEvent) -> Void) {
        eventHandlers.append(handler)
    }

    /// Clear the asset cache.
    public func clearCache() {
        assetCache.removeAll()
    }

    /// Remove completed jobs from history.
    public func pruneCompletedJobs() {
        activeJobs = activeJobs.filter { $0.value.status != .completed && $0.value.status != .failed }
    }

    // MARK: - Private Methods

    private func emitEvent(_ event: PolytroposEvent) {
        for handler in eventHandlers {
            handler(event)
        }
    }
}

// MARK: - PolytroposCoordinatorConfiguration

/// Configuration for the PolytroposCoordinator.
public struct PolytroposCoordinatorConfiguration: Sendable {
    /// Work directory for intermediate outputs.
    public var workDirectory: URL

    /// Ingestion service configuration.
    public var ingestionConfiguration: VideoIngestionConfiguration

    /// Maximum concurrent ingestion jobs.
    public var maxConcurrentJobs: Int

    /// Whether to cache assets in memory.
    public var enableCaching: Bool

    /// Default configuration.
    public static let `default` = PolytroposCoordinatorConfiguration(
        workDirectory: FileManager.default.temporaryDirectory
            .appendingPathComponent("polytropos", isDirectory: true),
        ingestionConfiguration: .default,
        maxConcurrentJobs: 4,
        enableCaching: true
    )

    public init(
        workDirectory: URL,
        ingestionConfiguration: VideoIngestionConfiguration = .default,
        maxConcurrentJobs: Int = 4,
        enableCaching: Bool = true
    ) {
        self.workDirectory = workDirectory
        self.ingestionConfiguration = ingestionConfiguration
        self.maxConcurrentJobs = maxConcurrentJobs
        self.enableCaching = enableCaching
    }
}

// MARK: - ProcessingOptions

/// Options for video processing.
public struct ProcessingOptions: Sendable {
    /// Whether to extract key frames.
    public var extractFrames: Bool

    /// Whether to compute fingerprints.
    public var computeFingerprints: Bool

    /// Whether to persist to artifact store.
    public var persistToArtifactStore: Bool

    /// Custom metadata to attach to the asset.
    public var customMetadata: [String: String]

    /// Default options.
    public static let `default` = ProcessingOptions(
        extractFrames: true,
        computeFingerprints: true,
        persistToArtifactStore: false,
        customMetadata: [:]
    )

    /// Quick preview options (minimal processing).
    public static let quickPreview = ProcessingOptions(
        extractFrames: true,
        computeFingerprints: false,
        persistToArtifactStore: false,
        customMetadata: [:]
    )

    /// Full processing with persistence.
    public static let fullWithPersistence = ProcessingOptions(
        extractFrames: true,
        computeFingerprints: true,
        persistToArtifactStore: true,
        customMetadata: [:]
    )

    public init(
        extractFrames: Bool = true,
        computeFingerprints: Bool = true,
        persistToArtifactStore: Bool = false,
        customMetadata: [String: String] = [:]
    ) {
        self.extractFrames = extractFrames
        self.computeFingerprints = computeFingerprints
        self.persistToArtifactStore = persistToArtifactStore
        self.customMetadata = customMetadata
    }
}

// MARK: - ProcessingJob

/// Represents a video processing job.
public struct ProcessingJob: Sendable, Identifiable {
    public let id: UUID
    public let sourceURL: URL
    public var status: ProcessingJobStatus
    public let startedAt: Date
    public var completedAt: Date?
    public var resultAssetId: UUID?
    public var error: String?
    public var progress: Double = 0.0

    public init(
        id: UUID,
        sourceURL: URL,
        status: ProcessingJobStatus,
        startedAt: Date,
        completedAt: Date? = nil,
        resultAssetId: UUID? = nil,
        error: String? = nil
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.status = status
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.resultAssetId = resultAssetId
        self.error = error
    }
}

/// Status of a processing job.
public enum ProcessingJobStatus: String, Sendable {
    case pending
    case ingesting
    case extractingFrames
    case computingFingerprints
    case persisting
    case completed
    case failed
}

// MARK: - IngestionResult

/// Result of a video ingestion operation.
public enum IngestionResult: Sendable {
    case success(VideoAsset)
    case failure(url: URL, error: Error)

    public var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    public var asset: VideoAsset? {
        if case .success(let asset) = self { return asset }
        return nil
    }
}

// MARK: - PolytroposEvent

/// Events emitted by the coordinator.
public enum PolytroposEvent: Sendable {
    case processingStarted(jobId: UUID, url: URL)
    case processingProgress(jobId: UUID, progress: Double)
    case processingCompleted(jobId: UUID, asset: VideoAsset)
    case processingFailed(jobId: UUID, error: Error)
    case assetPersisted(assetId: UUID, artifactID: String)
}

// MARK: - ArtifactStoreAdapter

/// Protocol for integrating with ArtifactStoreModule.
public protocol ArtifactStoreAdapter: Actor {
    /// Persist a VideoAsset and return the artifact ID.
    func persistVideoAsset(_ asset: VideoAsset) async throws -> String

    /// Retrieve a VideoAsset by artifact ID.
    func retrieveVideoAsset(artifactID: String) async throws -> VideoAsset?

    /// Check if an artifact exists.
    func artifactExists(artifactID: String) async throws -> Bool
}

// MARK: - Default ArtifactStoreAdapter Implementation

/// Default implementation of ArtifactStoreAdapter for standalone use.
public actor DefaultArtifactStoreAdapter: ArtifactStoreAdapter {
    private var storage: [String: VideoAsset] = [:]

    public init() {}

    public func persistVideoAsset(_ asset: VideoAsset) async throws -> String {
        let artifactID = "poly_\(asset.id.uuidString.lowercased())"
        storage[artifactID] = asset
        return artifactID
    }

    public func retrieveVideoAsset(artifactID: String) async throws -> VideoAsset? {
        storage[artifactID]
    }

    public func artifactExists(artifactID: String) async throws -> Bool {
        storage[artifactID] != nil
    }
}
