//
//  HarmoniaPolytroposIntegration.swift
//  PolytroposModule
//
//  Integration with Harmonia for distributed job processing
//  and workflow orchestration.
//

import AnigmaCore
import Foundation

// MARK: - Harmonia Job Definitions

/// Job definitions for Harmonia-based distributed processing.
public enum PolytroposHarmoniaJobs {

    /// Media ingestion job specification.
    public struct IngestJob: Codable, Sendable {
        public let projectId: String
        public let mediaPaths: [String]
        public let generateProxies: Bool
        public let proxyQuality: ProxyQuality

        public init(
            projectId: String,
            mediaPaths: [String],
            generateProxies: Bool = true,
            proxyQuality: ProxyQuality = .standard
        ) {
            self.projectId = projectId
            self.mediaPaths = mediaPaths
            self.generateProxies = generateProxies
            self.proxyQuality = proxyQuality
        }
    }

    /// Audio sync job specification.
    public struct SyncJob: Codable, Sendable {
        public let clusterId: String
        public let referenceAssetId: String?
        public let maxSearchOffset: TimeInterval
        public let minimumConfidence: Double

        public init(
            clusterId: String,
            referenceAssetId: String? = nil,
            maxSearchOffset: TimeInterval = 60.0,
            minimumConfidence: Double = 0.7
        ) {
            self.clusterId = clusterId
            self.referenceAssetId = referenceAssetId
            self.maxSearchOffset = maxSearchOffset
            self.minimumConfidence = minimumConfidence
        }
    }

    /// Audio analysis job specification.
    public struct AudioAnalysisJob: Codable, Sendable {
        public let assetId: String
        public let detectBeats: Bool
        public let detectStructure: Bool
        public let detectApplause: Bool
        public let detectSpeech: Bool

        public init(
            assetId: String,
            detectBeats: Bool = true,
            detectStructure: Bool = true,
            detectApplause: Bool = true,
            detectSpeech: Bool = true
        ) {
            self.assetId = assetId
            self.detectBeats = detectBeats
            self.detectStructure = detectStructure
            self.detectApplause = detectApplause
            self.detectSpeech = detectSpeech
        }
    }

    /// Video analysis job specification.
    public struct VideoAnalysisJob: Codable, Sendable {
        public let assetId: String
        public let windowSize: TimeInterval
        public let detectSubjects: Bool
        public let classifyScenes: Bool
        public let computeQuality: Bool

        public init(
            assetId: String,
            windowSize: TimeInterval = 0.5,
            detectSubjects: Bool = true,
            classifyScenes: Bool = true,
            computeQuality: Bool = true
        ) {
            self.assetId = assetId
            self.windowSize = windowSize
            self.detectSubjects = detectSubjects
            self.classifyScenes = classifyScenes
            self.computeQuality = computeQuality
        }
    }

    /// Auto-edit job specification.
    public struct AutoEditJob: Codable, Sendable {
        public let clusterId: String
        public let profileId: String?
        public let eventType: String
        public let overrides: EditProfileOverridesDTO?

        public init(
            clusterId: String,
            profileId: String? = nil,
            eventType: String = "concert",
            overrides: EditProfileOverridesDTO? = nil
        ) {
            self.clusterId = clusterId
            self.profileId = profileId
            self.eventType = eventType
            self.overrides = overrides
        }
    }

    /// Caption generation job specification.
    public struct CaptionJob: Codable, Sendable {
        public let timelineId: String
        public let languageCode: String
        public let model: String
        public let speakerDiarization: Bool

        public init(
            timelineId: String,
            languageCode: String = "en",
            model: String = "whisper-large-v3",
            speakerDiarization: Bool = false
        ) {
            self.timelineId = timelineId
            self.languageCode = languageCode
            self.model = model
            self.speakerDiarization = speakerDiarization
        }
    }

    /// Export job specification.
    public struct ExportJob: Codable, Sendable {
        public let timelineId: String
        public let sceneId: String?
        public let presetName: String
        public let outputPath: String
        public let burnCaptions: Bool
        public let reframeForAspect: String?

        public init(
            timelineId: String,
            sceneId: String? = nil,
            presetName: String,
            outputPath: String,
            burnCaptions: Bool = true,
            reframeForAspect: String? = nil
        ) {
            self.timelineId = timelineId
            self.sceneId = sceneId
            self.presetName = presetName
            self.outputPath = outputPath
            self.burnCaptions = burnCaptions
            self.reframeForAspect = reframeForAspect
        }
    }
}

// MARK: - DTOs

/// Data transfer object for edit profile overrides.
public struct EditProfileOverridesDTO: Codable, Sendable {
    public var targetShotLength: TimeInterval?
    public var preferredAngleType: String?
    public var crowdEnabled: Bool?
    public var beatAlignmentStrength: Double?

    public init(
        targetShotLength: TimeInterval? = nil,
        preferredAngleType: String? = nil,
        crowdEnabled: Bool? = nil,
        beatAlignmentStrength: Double? = nil
    ) {
        self.targetShotLength = targetShotLength
        self.preferredAngleType = preferredAngleType
        self.crowdEnabled = crowdEnabled
        self.beatAlignmentStrength = beatAlignmentStrength
    }

    public func toOverrides() -> EditProfileOverrides {
        EditProfileOverrides(
            targetShotLength: targetShotLength,
            preferredAngleType: preferredAngleType.flatMap { CameraAngleType(rawValue: $0) },
            crowdEnabled: crowdEnabled,
            beatAlignmentStrength: beatAlignmentStrength
        )
    }
}

/// Proxy quality levels.
public enum ProxyQuality: String, Codable, Sendable {
    case low      // 540p, high compression
    case standard // 720p, balanced
    case high     // 1080p, lower compression
    case original // No proxy, use original
}

// MARK: - Job Results

/// Results from a completed Polytropos job.
public enum PolytroposJobResult: Codable, Sendable {
    case ingest(IngestResult)
    case sync(SyncResultDTO)
    case audioAnalysis(AudioAnalysisResultDTO)
    case videoAnalysis(VideoAnalysisResultDTO)
    case autoEdit(AutoEditResultDTO)
    case caption(CaptionResultDTO)
    case export(ExportResultDTO)

    public struct IngestResult: Codable, Sendable {
        public let assetIds: [String]
        public let proxyPaths: [String: String]
        public let errors: [String: String]
    }

    public struct SyncResultDTO: Codable, Sendable {
        public let referenceAssetId: String
        public let offsets: [String: TimeInterval]
        public let confidences: [String: Double]
        public let needsManualReview: Bool
    }

    public struct AudioAnalysisResultDTO: Codable, Sendable {
        public let tempo: Double?
        public let beatCount: Int
        public let segmentCount: Int
        public let applauseCount: Int
    }

    public struct VideoAnalysisResultDTO: Codable, Sendable {
        public let frameCount: Int
        public let qualityScore: Double
        public let usablePercentage: Double
    }

    public struct AutoEditResultDTO: Codable, Sendable {
        public let timelineId: String
        public let segmentCount: Int
        public let sceneCount: Int
        public let duration: TimeInterval
    }

    public struct CaptionResultDTO: Codable, Sendable {
        public let transcriptId: String
        public let wordCount: Int
        public let confidence: Double
        public let speakerCount: Int?
    }

    public struct ExportResultDTO: Codable, Sendable {
        public let outputPath: String
        public let fileSize: Int64
        public let renderDuration: TimeInterval
    }
}

// MARK: - Harmonia Integration Service

/// Service for integrating Polytropos with Harmonia's job orchestration.
public actor PolytroposHarmoniaService {

    private let world: World
    private let syncService: SyncService
    private let autoEditEngine: AutoEditEngine
    private let exportService: ExportService

    public init(
        world: World,
        syncService: SyncService,
        autoEditEngine: AutoEditEngine,
        exportService: ExportService
    ) {
        self.world = world
        self.syncService = syncService
        self.autoEditEngine = autoEditEngine
        self.exportService = exportService
    }

    /// Submits a job to Harmonia for processing.
    public func submitJob<T: Codable & Sendable>(
        type: String,
        payload: T,
        priority: JobPriority = .normal
    ) async throws -> String {
        // In real implementation, this would submit to Harmonia's job queue
        let jobId = UUID().uuidString

        await Logger.shared.info(
            "Submitted Polytropos job: \(type) [\(jobId)]",
            category: "Polytropos"
        )

        return jobId
    }

    /// Gets the status of a submitted job.
    public func getJobStatus(_ jobId: String) async -> HarmoniaJobStatus {
        // In real implementation, this would query Harmonia
        return .completed
    }

    /// Waits for a job to complete.
    public func awaitJob(_ jobId: String, timeout: TimeInterval = 300) async throws -> PolytroposJobResult {
        // In real implementation, this would poll/subscribe to Harmonia
        throw PolytroposHarmoniaError.notImplemented
    }

    /// Cancels a running job.
    public func cancelJob(_ jobId: String) async throws {
        // In real implementation, this would send cancel to Harmonia
        await Logger.shared.info(
            "Cancelled Polytropos job: \(jobId)",
            category: "Polytropos"
        )
    }

    // MARK: - Convenience Methods

    /// Submits a full event processing pipeline.
    public func processFullEvent(
        projectId: String,
        eventType: EventType,
        exportPresets: [String]
    ) async throws -> String {
        let pipelineId = UUID().uuidString

        // This would create a multi-stage pipeline in Harmonia
        await Logger.shared.info(
            "Started full event pipeline: \(pipelineId)",
            category: "Polytropos"
        )

        return pipelineId
    }

    /// Submits a quick clip generation pipeline.
    public func processQuickClip(
        projectId: String,
        presetName: String
    ) async throws -> String {
        let pipelineId = UUID().uuidString

        await Logger.shared.info(
            "Started quick clip pipeline: \(pipelineId)",
            category: "Polytropos"
        )

        return pipelineId
    }
}

// MARK: - Supporting Types

/// Job priority levels.
public enum JobPriority: String, Codable, Sendable {
    case low
    case normal
    case high
    case urgent
}

/// Harmonia job status.
public enum HarmoniaJobStatus: String, Codable, Sendable {
    case pending
    case queued
    case running
    case completed
    case failed
    case cancelled
}

/// Errors from Harmonia integration.
public enum PolytroposHarmoniaError: Error, LocalizedError {
    case notImplemented
    case jobNotFound(String)
    case timeout(String)
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .notImplemented:
            return "Harmonia integration not implemented"
        case .jobNotFound(let id):
            return "Job not found: \(id)"
        case .timeout(let id):
            return "Job timed out: \(id)"
        case .failed(let reason):
            return "Job failed: \(reason)"
        }
    }
}

// MARK: - Worker Node Registration

/// Information about a Polytropos worker node for Harmonia.
public struct PolytroposWorkerInfo: Codable, Sendable {
    public let nodeId: String
    public let hostname: String
    public let capabilities: WorkerCapabilities
    public let load: WorkerLoad

    public init(
        nodeId: String,
        hostname: String,
        capabilities: WorkerCapabilities,
        load: WorkerLoad
    ) {
        self.nodeId = nodeId
        self.hostname = hostname
        self.capabilities = capabilities
        self.load = load
    }
}

/// Capabilities of a worker node.
public struct WorkerCapabilities: Codable, Sendable {
    public let canIngest: Bool
    public let canSync: Bool
    public let canAnalyzeAudio: Bool
    public let canAnalyzeVideo: Bool
    public let canAutoEdit: Bool
    public let canCaption: Bool
    public let canExport: Bool
    public let hasGPU: Bool
    public let hasMLX: Bool

    public static let full = WorkerCapabilities(
        canIngest: true,
        canSync: true,
        canAnalyzeAudio: true,
        canAnalyzeVideo: true,
        canAutoEdit: true,
        canCaption: true,
        canExport: true,
        hasGPU: true,
        hasMLX: true
    )

    public static let minimal = WorkerCapabilities(
        canIngest: true,
        canSync: true,
        canAnalyzeAudio: false,
        canAnalyzeVideo: false,
        canAutoEdit: false,
        canCaption: false,
        canExport: true,
        hasGPU: false,
        hasMLX: false
    )

    public init(
        canIngest: Bool,
        canSync: Bool,
        canAnalyzeAudio: Bool,
        canAnalyzeVideo: Bool,
        canAutoEdit: Bool,
        canCaption: Bool,
        canExport: Bool,
        hasGPU: Bool,
        hasMLX: Bool
    ) {
        self.canIngest = canIngest
        self.canSync = canSync
        self.canAnalyzeAudio = canAnalyzeAudio
        self.canAnalyzeVideo = canAnalyzeVideo
        self.canAutoEdit = canAutoEdit
        self.canCaption = canCaption
        self.canExport = canExport
        self.hasGPU = hasGPU
        self.hasMLX = hasMLX
    }
}

/// Current load of a worker node.
public struct WorkerLoad: Codable, Sendable {
    public let cpuUsage: Double        // 0-1
    public let memoryUsage: Double     // 0-1
    public let gpuUsage: Double?       // 0-1, nil if no GPU
    public let activeJobs: Int
    public let queuedJobs: Int

    public init(
        cpuUsage: Double,
        memoryUsage: Double,
        gpuUsage: Double?,
        activeJobs: Int,
        queuedJobs: Int
    ) {
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
        self.gpuUsage = gpuUsage
        self.activeJobs = activeJobs
        self.queuedJobs = queuedJobs
    }
}
