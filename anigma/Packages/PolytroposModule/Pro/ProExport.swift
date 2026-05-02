import AnigmaPrimitives

import AnigmaPrimitives

//
//  ProExport.swift
//  PolytroposModule
//
//  Professional export pipeline with platform-specific presets.
//  Phase 6 of Polytropos Pro roadmap.
//

import AnigmaCore
import Foundation
import AnigmaPrimitives

// MARK: - Export Configuration

/// Complete export configuration for professional output.
public struct ProExportConfiguration: Codable, Sendable {
    /// Export preset to use.
    public var preset: ProExportPreset

    /// Output destination.
    public var destination: ExportDestination

    /// Range to export (nil = full timeline).
    public var range: ExportRange?

    /// Whether to include audio.
    public var includeAudio: Bool

    /// Whether to burn in captions.
    public var burnInCaptions: Bool

    /// Whether to burn in timecode.
    public var burnInTimecode: Bool

    /// Whether to apply color grades.
    public var applyColorGrades: Bool

    /// Hardware acceleration preference.
    public var hardwareAcceleration: HardwareAcceleration

    /// Background rendering preference.
    public var backgroundRendering: Bool

    public init(
        preset: ProExportPreset = .youtube1080p,
        destination: ExportDestination = .file(url: nil),
        range: ExportRange? = nil,
        includeAudio: Bool = true,
        burnInCaptions: Bool = false,
        burnInTimecode: Bool = false,
        applyColorGrades: Bool = true,
        hardwareAcceleration: HardwareAcceleration = .auto,
        backgroundRendering: Bool = true
    ) {
        self.preset = preset
        self.destination = destination
        self.range = range
        self.includeAudio = includeAudio
        self.burnInCaptions = burnInCaptions
        self.burnInTimecode = burnInTimecode
        self.applyColorGrades = applyColorGrades
        self.hardwareAcceleration = hardwareAcceleration
        self.backgroundRendering = backgroundRendering
    }
}

/// Export range.
public struct ExportRange: Codable, Sendable {
    public var start: TimeInterval
    public var end: TimeInterval

    public var duration: TimeInterval { end - start }

    public init(start: TimeInterval, end: TimeInterval) {
        self.start = start
        self.end = end
    }
}

/// Export destination.
public enum ExportDestination: Codable, Sendable {
    case file(url: URL?)
    case shareSheet
    case directUpload(platform: UploadPlatform)

    enum CodingKeys: String, CodingKey {
        case type, url, platform
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "file":
            let urlString = try container.decodeIfPresent(String.self, forKey: .url)
            let url = urlString.flatMap { URL(string: $0) }
            self = .file(url: url)
        case "shareSheet":
            self = .shareSheet
        case "directUpload":
            let platform = try container.decode(UploadPlatform.self, forKey: .platform)
            self = .directUpload(platform: platform)
        default:
            self = .file(url: nil)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .file(let url):
            try container.encode("file", forKey: .type)
            try container.encodeIfPresent(url?.absoluteString, forKey: .url)
        case .shareSheet:
            try container.encode("shareSheet", forKey: .type)
        case .directUpload(let platform):
            try container.encode("directUpload", forKey: .type)
            try container.encode(platform, forKey: .platform)
        }
    }
}

/// Upload platforms for direct upload.
public enum UploadPlatform: String, Codable, Sendable {
    case youtube
    case vimeo
    case tiktok
    case instagram
    case twitter
    case custom
}

/// Hardware acceleration options.
public enum HardwareAcceleration: String, Codable, Sendable {
    case auto           // Use best available
    case videoToolbox   // Apple VideoToolbox
    case software       // CPU only
    case disabled       // Force software
}

// MARK: - Export Presets

/// Professional export presets.
public enum ProExportPreset: String, Codable, Sendable, CaseIterable {
    // Social Media - Vertical
    case tiktokVertical
    case instagramReels
    case youtubeShorts

    // Social Media - Square
    case instagramSquare

    // Social Media - Horizontal
    case youtube1080p
    case youtube4k
    case twitter1080p
    case facebook1080p

    // Professional
    case proresProxy
    case prores422
    case prores4444
    case dnxHD

    // Generic
    case mp4High
    case mp4Medium
    case mp4Low
    case gifAnimated

    public var displayName: String {
        switch self {
        case .tiktokVertical: return "TikTok (Vertical)"
        case .instagramReels: return "Instagram Reels (Vertical)"
        case .youtubeShorts: return "YouTube Shorts (Vertical)"
        case .instagramSquare: return "Instagram (Square)"
        case .youtube1080p: return "YouTube HD (1080p)"
        case .youtube4k: return "YouTube 4K"
        case .twitter1080p: return "Twitter/X (1080p)"
        case .facebook1080p: return "Facebook (1080p)"
        case .proresProxy: return "ProRes Proxy (Mac)"
        case .prores422: return "ProRes 422 (Mac)"
        case .prores4444: return "ProRes 4444 (Mac)"
        case .dnxHD: return "DNxHD"
        case .mp4High: return "MP4 High Quality"
        case .mp4Medium: return "MP4 Medium Quality"
        case .mp4Low: return "MP4 Low Quality"
        case .gifAnimated: return "Animated GIF"
        }
    }

    public var settings: ExportSettings {
        switch self {
        case .tiktokVertical:
            return ExportSettings(
                resolution: .init(width: 1080, height: 1920),
                aspectRatio: .vertical9x16,
                codec: .hevc,
                videoBitrate: 8_000_000,
                frameRate: 30,
                audioCodec: .aac,
                audioBitrate: 192_000,
                audioSampleRate: 48000,
                loudnessTarget: .streaming,
                colorSpace: .rec709
            )

        case .instagramReels:
            return ExportSettings(
                resolution: .init(width: 1080, height: 1920),
                aspectRatio: .vertical9x16,
                codec: .h264,
                videoBitrate: 10_000_000,
                frameRate: 30,
                audioCodec: .aac,
                audioBitrate: 256_000,
                audioSampleRate: 48000,
                loudnessTarget: .streaming,
                colorSpace: .rec709
            )

        case .youtubeShorts:
            return ExportSettings(
                resolution: .init(width: 1080, height: 1920),
                aspectRatio: .vertical9x16,
                codec: .h264,
                videoBitrate: 12_000_000,
                frameRate: 30,
                audioCodec: .aac,
                audioBitrate: 256_000,
                audioSampleRate: 48000,
                loudnessTarget: .streaming,
                colorSpace: .rec709
            )

        case .instagramSquare:
            return ExportSettings(
                resolution: .init(width: 1080, height: 1080),
                aspectRatio: .square1x1,
                codec: .h264,
                videoBitrate: 8_000_000,
                frameRate: 30,
                audioCodec: .aac,
                audioBitrate: 192_000,
                audioSampleRate: 48000,
                loudnessTarget: .streaming,
                colorSpace: .rec709
            )

        case .youtube1080p:
            return ExportSettings(
                resolution: .init(width: 1920, height: 1080),
                aspectRatio: .horizontal16x9,
                codec: .h264,
                videoBitrate: 15_000_000,
                frameRate: 30,
                audioCodec: .aac,
                audioBitrate: 320_000,
                audioSampleRate: 48000,
                loudnessTarget: .streaming,
                colorSpace: .rec709
            )

        case .youtube4k:
            return ExportSettings(
                resolution: .init(width: 3840, height: 2160),
                aspectRatio: .horizontal16x9,
                codec: .hevc,
                videoBitrate: 45_000_000,
                frameRate: 30,
                audioCodec: .aac,
                audioBitrate: 384_000,
                audioSampleRate: 48000,
                loudnessTarget: .streaming,
                colorSpace: .rec709
            )

        case .twitter1080p:
            return ExportSettings(
                resolution: .init(width: 1920, height: 1080),
                aspectRatio: .horizontal16x9,
                codec: .h264,
                videoBitrate: 6_000_000, // Twitter has lower limits
                frameRate: 30,
                audioCodec: .aac,
                audioBitrate: 192_000,
                audioSampleRate: 48000,
                loudnessTarget: .streaming,
                colorSpace: .rec709
            )

        case .facebook1080p:
            return ExportSettings(
                resolution: .init(width: 1920, height: 1080),
                aspectRatio: .horizontal16x9,
                codec: .h264,
                videoBitrate: 12_000_000,
                frameRate: 30,
                audioCodec: .aac,
                audioBitrate: 256_000,
                audioSampleRate: 48000,
                loudnessTarget: .streaming,
                colorSpace: .rec709
            )

        case .proresProxy:
            return ExportSettings(
                resolution: .init(width: 1920, height: 1080),
                aspectRatio: .horizontal16x9,
                codec: .proresProxy,
                videoBitrate: 0, // ProRes uses fixed quality
                frameRate: 30,
                audioCodec: .pcm,
                audioBitrate: 0,
                audioSampleRate: 48000,
                loudnessTarget: .none,
                colorSpace: .rec709
            )

        case .prores422:
            return ExportSettings(
                resolution: .init(width: 1920, height: 1080),
                aspectRatio: .horizontal16x9,
                codec: .prores422,
                videoBitrate: 0,
                frameRate: 30,
                audioCodec: .pcm,
                audioBitrate: 0,
                audioSampleRate: 48000,
                loudnessTarget: .none,
                colorSpace: .rec709
            )

        case .prores4444:
            return ExportSettings(
                resolution: .init(width: 1920, height: 1080),
                aspectRatio: .horizontal16x9,
                codec: .prores4444,
                videoBitrate: 0,
                frameRate: 30,
                audioCodec: .pcm,
                audioBitrate: 0,
                audioSampleRate: 48000,
                loudnessTarget: .none,
                colorSpace: .rec709
            )

        case .dnxHD:
            return ExportSettings(
                resolution: .init(width: 1920, height: 1080),
                aspectRatio: .horizontal16x9,
                codec: .dnxHD,
                videoBitrate: 145_000_000,
                frameRate: 30,
                audioCodec: .pcm,
                audioBitrate: 0,
                audioSampleRate: 48000,
                loudnessTarget: .none,
                colorSpace: .rec709
            )

        case .mp4High:
            return ExportSettings(
                resolution: .init(width: 1920, height: 1080),
                aspectRatio: .horizontal16x9,
                codec: .h264,
                videoBitrate: 20_000_000,
                frameRate: 30,
                audioCodec: .aac,
                audioBitrate: 320_000,
                audioSampleRate: 48000,
                loudnessTarget: .streaming,
                colorSpace: .rec709
            )

        case .mp4Medium:
            return ExportSettings(
                resolution: .init(width: 1280, height: 720),
                aspectRatio: .horizontal16x9,
                codec: .h264,
                videoBitrate: 8_000_000,
                frameRate: 30,
                audioCodec: .aac,
                audioBitrate: 192_000,
                audioSampleRate: 48000,
                loudnessTarget: .streaming,
                colorSpace: .rec709
            )

        case .mp4Low:
            return ExportSettings(
                resolution: .init(width: 854, height: 480),
                aspectRatio: .horizontal16x9,
                codec: .h264,
                videoBitrate: 2_500_000,
                frameRate: 30,
                audioCodec: .aac,
                audioBitrate: 128_000,
                audioSampleRate: 44100,
                loudnessTarget: .streaming,
                colorSpace: .rec709
            )

        case .gifAnimated:
            return ExportSettings(
                resolution: .init(width: 480, height: 270),
                aspectRatio: .horizontal16x9,
                codec: .gif,
                videoBitrate: 0,
                frameRate: 15,
                audioCodec: .none,
                audioBitrate: 0,
                audioSampleRate: 0,
                loudnessTarget: .none,
                colorSpace: .srgb
            )
        }
    }

    public var fileExtension: String {
        switch self {
        case .proresProxy, .prores422, .prores4444:
            return "mov"
        case .dnxHD:
            return "mxf"
        case .gifAnimated:
            return "gif"
        default:
            return "mp4"
        }
    }

    public var isProResFormat: Bool {
        switch self {
        case .proresProxy, .prores422, .prores4444:
            return true
        default:
            return false
        }
    }
}

// MARK: - Export Settings

/// Detailed export settings.
public struct ExportSettings: Codable, Sendable {
    public var resolution: ProResolution
    public var aspectRatio: AspectRatio
    public var codec: ProVideoCodec
    public var videoBitrate: Int
    public var frameRate: Double
    public var audioCodec: ProAudioCodec
    public var audioBitrate: Int
    public var audioSampleRate: Int
    public var loudnessTarget: LoudnessTarget
    public var colorSpace: ProColorSpace

    public init(
        resolution: ProResolution,
        aspectRatio: AspectRatio,
        codec: ProVideoCodec,
        videoBitrate: Int,
        frameRate: Double,
        audioCodec: ProAudioCodec,
        audioBitrate: Int,
        audioSampleRate: Int,
        loudnessTarget: LoudnessTarget,
        colorSpace: ProColorSpace
    ) {
        self.resolution = resolution
        self.aspectRatio = aspectRatio
        self.codec = codec
        self.videoBitrate = videoBitrate
        self.frameRate = frameRate
        self.audioCodec = audioCodec
        self.audioBitrate = audioBitrate
        self.audioSampleRate = audioSampleRate
        self.loudnessTarget = loudnessTarget
        self.colorSpace = colorSpace
    }
}

/// Video resolution.
public struct ProResolution: Codable, Sendable, Equatable {
    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    public static let hd720 = ProResolution(width: 1280, height: 720)
    public static let hd1080 = ProResolution(width: 1920, height: 1080)
    public static let uhd4k = ProResolution(width: 3840, height: 2160)
}

/// Video codecs.
public enum ProVideoCodec: String, Codable, Sendable {
    case h264
    case hevc
    case proresProxy
    case prores422
    case prores4444
    case dnxHD
    case gif
    case av1
}

/// Audio codecs.
public enum ProAudioCodec: String, Codable, Sendable {
    case aac
    case pcm
    case mp3
    case opus
    case none
}

/// Color spaces.
public enum ProColorSpace: String, Codable, Sendable {
    case rec709       // Standard HD
    case rec2020      // HDR/Wide gamut
    case srgb         // Web
    case displayP3    // Apple displays
}

// MARK: - Export Job Component

/// Extended export job with professional features.
public struct ProExportJobComponent: Component, Codable {
    public let id: UUID

    /// Timeline entity reference.
    public var timelineId: EntityId

    /// Scene entity reference (if exporting single scene).
    public var sceneId: EntityId?

    /// Export configuration.
    public var configuration: ProExportConfiguration

    /// Job status.
    public var status: ProExportStatus

    /// Progress (0-1).
    public var progress: Double

    /// Current phase.
    public var currentPhase: ExportPhase

    /// Output file URL.
    public var outputUrl: URL?

    /// File size in bytes.
    public var fileSize: Int64?

    /// Render duration.
    public var renderDuration: TimeInterval?

    /// Error information.
    public var error: ProExportError?

    /// Timestamps.
    public var createdAt: Date
    public var startedAt: Date?
    public var completedAt: Date?

    public init(
        id: UUID = UUID(),
        timelineId: EntityId,
        sceneId: EntityId? = nil,
        configuration: ProExportConfiguration,
        status: ProExportStatus = .queued,
        progress: Double = 0,
        currentPhase: ExportPhase = .preparing,
        outputUrl: URL? = nil,
        fileSize: Int64? = nil,
        renderDuration: TimeInterval? = nil,
        error: ProExportError? = nil,
        createdAt: Date = Date(),
        startedAt: Date? = nil,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.timelineId = timelineId
        self.sceneId = sceneId
        self.configuration = configuration
        self.status = status
        self.progress = progress
        self.currentPhase = currentPhase
        self.outputUrl = outputUrl
        self.fileSize = fileSize
        self.renderDuration = renderDuration
        self.error = error
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.completedAt = completedAt
    }
}

/// Export job status.
public enum ProExportStatus: String, Codable, Sendable {
    case queued
    case preparing
    case rendering
    case encoding
    case finalizing
    case completed
    case failed
    case cancelled
}

/// Export phases.
public enum ExportPhase: String, Codable, Sendable {
    case preparing          // Setting up export
    case renderingVideo     // Compositing video
    case renderingAudio     // Mixing audio
    case applyingEffects    // Color/audio processing
    case encoding           // Final encode
    case writingFile        // Writing to disk
    case finalizing         // Cleanup
}

/// Export error.
public struct ProExportError: Codable, Sendable {
    public var code: String
    public var message: String
    public var details: String?

    public init(code: String, message: String, details: String? = nil) {
        self.code = code
        self.message = message
        self.details = details
    }
}

// MARK: - Batch Export

/// Batch export configuration for multiple scenes/presets.
public struct BatchExportConfiguration: Codable, Sendable {
    /// Scenes to export.
    public var sceneIds: [EntityId]

    /// Presets to export each scene in.
    public var presets: [ProExportPreset]

    /// Base output directory.
    public var outputDirectory: URL

    /// Naming pattern.
    public var namingPattern: NamingPattern

    /// Whether to create subdirectories per preset.
    public var createSubdirectories: Bool

    /// Common configuration overrides.
    public var commonConfig: ProExportConfiguration?

    public init(
        sceneIds: [EntityId],
        presets: [ProExportPreset],
        outputDirectory: URL,
        namingPattern: NamingPattern = .sceneNameWithPreset,
        createSubdirectories: Bool = true,
        commonConfig: ProExportConfiguration? = nil
    ) {
        self.sceneIds = sceneIds
        self.presets = presets
        self.outputDirectory = outputDirectory
        self.namingPattern = namingPattern
        self.createSubdirectories = createSubdirectories
        self.commonConfig = commonConfig
    }

    /// Total number of exports.
    public var totalExports: Int {
        sceneIds.count * presets.count
    }
}

/// Naming patterns for batch export.
public enum NamingPattern: String, Codable, Sendable {
    case sceneNameOnly          // "Scene 1.mp4"
    case sceneNameWithPreset    // "Scene 1 - YouTube 1080p.mp4"
    case presetWithSceneName    // "YouTube 1080p - Scene 1.mp4"
    case numbered               // "001.mp4", "002.mp4"
    case custom                 // Uses custom pattern
}

// MARK: - Export Service

/// Professional export service.
public actor ProExportService {

    private let world: World
    private var activeJobs: [UUID: Task<Void, Error>] = [:]

    public init(world: World) {
        self.world = world
    }

    /// Queues an export job.
    public func queueExport(
        timelineId: EntityId,
        sceneId: EntityId? = nil,
        configuration: ProExportConfiguration
    ) async throws -> EntityId {
        let entity = await world.createEntity()

        let job = ProExportJobComponent(
            timelineId: timelineId,
            sceneId: sceneId,
            configuration: configuration
        )

        await world.addComponent(entity, job)

        await PlatformLogger.shared.info(
            "Queued export job \(job.id) for timeline \(timelineId)",
            category: "Export"
        )

        return entity
    }

    /// Queues a batch export.
    public func queueBatchExport(
        _ config: BatchExportConfiguration
    ) async throws -> [EntityId] {
        var jobIds: [EntityId] = []

        for sceneId in config.sceneIds {
            for preset in config.presets {
                var exportConfig = config.commonConfig ?? ProExportConfiguration()
                exportConfig.preset = preset

                let jobId = try await queueExport(
                    timelineId: sceneId, // Assuming scene has timeline
                    sceneId: sceneId,
                    configuration: exportConfig
                )
                jobIds.append(jobId)
            }
        }

        await PlatformLogger.shared.info(
            "Queued batch export with \(jobIds.count) jobs",
            category: "Export"
        )

        return jobIds
    }

    /// Starts processing queued export jobs.
    public func startExport(jobId: EntityId) async throws {
        guard var job = await world.getComponent(jobId, ProExportJobComponent.self) else {
            throw ExportServiceError.jobNotFound
        }

        job.status = .preparing
        job.startedAt = Date()
        await world.addComponent(jobId, job)

        // Create background task
        let task = Task {
            try await processExport(jobId: jobId)
        }

        activeJobs[job.id] = task
    }

    /// Cancels an export job.
    public func cancelExport(jobId: EntityId) async throws {
        guard var job = await world.getComponent(jobId, ProExportJobComponent.self) else {
            throw ExportServiceError.jobNotFound
        }

        if let task = activeJobs[job.id] {
            task.cancel()
            activeJobs.removeValue(forKey: job.id)
        }

        job.status = .cancelled
        await world.addComponent(jobId, job)
    }

    /// Processes an export job.
    private func processExport(jobId: EntityId) async throws {
        // This would contain the actual export logic
        // For now, simulate progress

        let phases: [ExportPhase] = [
            .preparing,
            .renderingVideo,
            .renderingAudio,
            .applyingEffects,
            .encoding,
            .writingFile,
            .finalizing
        ]

        for (index, phase) in phases.enumerated() {
            try Task.checkCancellation()

            guard var job = await world.getComponent(jobId, ProExportJobComponent.self) else {
                return
            }

            job.currentPhase = phase
            job.progress = Double(index) / Double(phases.count)

            if phase == .renderingVideo || phase == .encoding {
                job.status = .rendering
            } else if phase == .encoding {
                job.status = .encoding
            }

        await world.addComponent(jobId, job)

            // Simulate work
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }

        // Complete
        guard var job = await world.getComponent(jobId, ProExportJobComponent.self) else {
            return
        }

        job.status = .completed
        job.progress = 1.0
        job.completedAt = Date()
        job.renderDuration = job.completedAt!.timeIntervalSince(job.startedAt ?? job.createdAt)

        await world.addComponent(jobId, job)

        await PlatformLogger.shared.info(
            "Export job \(job.id) completed in \(job.renderDuration ?? 0) seconds",
            category: "Export"
        )
    }

    /// Gets the status of an export job.
    public func getJobStatus(jobId: EntityId) async throws -> ProExportJobComponent? {
        await world.getComponent(jobId, ProExportJobComponent.self)
    }
}

/// Export service errors.
public enum ExportServiceError: Error, LocalizedError {
    case jobNotFound
    case invalidConfiguration
    case encoderNotAvailable
    case diskFull
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .jobNotFound:
            return "Export job not found"
        case .invalidConfiguration:
            return "Invalid export configuration"
        case .encoderNotAvailable:
            return "Required encoder is not available"
        case .diskFull:
            return "Not enough disk space for export"
        case .cancelled:
            return "Export was cancelled"
        }
    }
}
