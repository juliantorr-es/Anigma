//
//  ExportComponents.swift
//  PolytroposModule
//
//  Components for export presets and render jobs.
//

import AnigmaCore
import Foundation
import AnigmaPrimitives

// MARK: - Export Preset Component

/// Platform-specific export configuration.
public struct ExportPresetComponent: Component, Codable {
    /// Unique preset identifier.
    public let id: UUID

    /// Preset name.
    public var name: String

    /// Target platform.
    public var platform: ExportPlatform

    /// Resolution configuration.
    public var resolution: ExportResolution

    /// Video codec.
    public var videoCodec: VideoCodec

    /// Video bitrate in bits per second (nil = auto).
    public var videoBitrate: Int?

    /// Video quality (0-100, used if bitrate is nil).
    public var videoQuality: Int

    /// Audio codec.
    public var audioCodec: AudioCodec

    /// Audio bitrate in bits per second.
    public var audioBitrate: Int

    /// Target loudness in LUFS.
    public var loudnessTarget: Double

    /// Frame rate.
    public var frameRate: Double

    /// Whether to embed captions.
    public var embedCaptions: Bool

    /// Caption format if embedding.
    public var captionFormat: CaptionFormat?

    /// Color space.
    public var colorSpace: ColorSpace

    /// Whether this is a system preset (non-editable).
    public var isSystemPreset: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        platform: ExportPlatform,
        resolution: ExportResolution,
        videoCodec: VideoCodec = .h264,
        videoBitrate: Int? = nil,
        videoQuality: Int = 80,
        audioCodec: AudioCodec = .aac,
        audioBitrate: Int = 256_000,
        loudnessTarget: Double = -14.0,
        frameRate: Double = 30,
        embedCaptions: Bool = false,
        captionFormat: CaptionFormat? = nil,
        colorSpace: ColorSpace = .rec709,
        isSystemPreset: Bool = false
    ) {
        self.id = id
        self.name = name
        self.platform = platform
        self.resolution = resolution
        self.videoCodec = videoCodec
        self.videoBitrate = videoBitrate
        self.videoQuality = videoQuality
        self.audioCodec = audioCodec
        self.audioBitrate = audioBitrate
        self.loudnessTarget = loudnessTarget
        self.frameRate = frameRate
        self.embedCaptions = embedCaptions
        self.captionFormat = captionFormat
        self.colorSpace = colorSpace
        self.isSystemPreset = isSystemPreset
    }
}

/// Target export platform.
public enum ExportPlatform: String, Codable, Sendable, CaseIterable {
    case youtube
    case youtubeShorts
    case instagram
    case instagramReels
    case tiktok
    case twitter
    case facebook
    case vimeo
    case generic
    case archive

    /// Default aspect ratio for this platform.
    public var defaultAspectRatio: AspectRatio {
        switch self {
        case .youtube, .vimeo, .generic:
            return .horizontal16x9
        case .youtubeShorts, .instagramReels, .tiktok:
            return .vertical9x16
        case .instagram:
            return .square1x1
        case .twitter, .facebook:
            return .horizontal16x9
        case .archive:
            return .horizontal16x9
        }
    }

    /// Maximum recommended duration for this platform.
    public var maxDuration: TimeInterval? {
        switch self {
        case .youtubeShorts:
            return 60
        case .tiktok:
            return 180
        case .instagramReels:
            return 90
        default:
            return nil
        }
    }
}

/// Export resolution configuration.
public struct ExportResolution: Codable, Sendable, Equatable {
    /// Width in pixels.
    public var width: Int

    /// Height in pixels.
    public var height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    // Common presets
    public static let hd720 = ExportResolution(width: 1280, height: 720)
    public static let hd1080 = ExportResolution(width: 1920, height: 1080)
    public static let uhd4k = ExportResolution(width: 3840, height: 2160)

    public static let vertical720 = ExportResolution(width: 720, height: 1280)
    public static let vertical1080 = ExportResolution(width: 1080, height: 1920)

    public static let square720 = ExportResolution(width: 720, height: 720)
    public static let square1080 = ExportResolution(width: 1080, height: 1080)
}

/// Video codec options.
public enum VideoCodec: String, Codable, Sendable, CaseIterable, Equatable {
    case h264
    case hevc
    case prores422
    case prores4444
    case av1
}

/// Audio codec options.
public enum AudioCodec: String, Codable, Sendable, CaseIterable, Equatable {
    case aac
    case mp3
    case pcm
    case flac
    case opus
}

/// Caption format options.
public enum CaptionFormat: String, Codable, Sendable {
    case srt
    case vtt
    case burnedIn
    case cea608
}

/// Color space options.
public enum ColorSpace: String, Codable, Sendable {
    case rec709
    case rec2020
    case p3
    case srgb
}

// MARK: - Export Job Component

/// A concrete render request.
public struct ExportJobComponent: Component, Codable {
    /// Unique job identifier.
    public let id: UUID

    /// Source timeline entity ID.
    public var timelineId: EntityId

    /// Scene entity ID (if exporting single scene).
    public var sceneId: EntityId?

    /// Export preset entity ID.
    public var presetId: EntityId

    /// Output file path.
    public var outputPath: String?

    /// Job status.
    public var status: ExportJobStatus

    /// Progress (0-1).
    public var progress: Double

    /// Estimated time remaining in seconds.
    public var estimatedTimeRemaining: TimeInterval?

    /// Job creation timestamp.
    public let createdAt: Date

    /// Job start timestamp.
    public var startedAt: Date?

    /// Job completion timestamp.
    public var completedAt: Date?

    /// Error message if failed.
    public var errorMessage: String?

    /// Output file size in bytes.
    public var outputSize: Int64?

    /// Render duration in seconds.
    public var renderDuration: TimeInterval?

    public init(
        id: UUID = UUID(),
        timelineId: EntityId,
        sceneId: EntityId? = nil,
        presetId: EntityId,
        outputPath: String? = nil,
        status: ExportJobStatus = .pending,
        progress: Double = 0,
        estimatedTimeRemaining: TimeInterval? = nil,
        createdAt: Date = Date(),
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        errorMessage: String? = nil,
        outputSize: Int64? = nil,
        renderDuration: TimeInterval? = nil
    ) {
        self.id = id
        self.timelineId = timelineId
        self.sceneId = sceneId
        self.presetId = presetId
        self.outputPath = outputPath
        self.status = status
        self.progress = progress
        self.estimatedTimeRemaining = estimatedTimeRemaining
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.errorMessage = errorMessage
        self.outputSize = outputSize
        self.renderDuration = renderDuration
    }
}

/// Export job status.
public enum ExportJobStatus: String, Codable, Sendable {
    case pending
    case queued
    case preparing
    case rendering
    case encoding
    case finalizing
    case completed
    case failed
    case cancelled

    public var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled:
            return true
        default:
            return false
        }
    }
}

// MARK: - Reframe Instructions Component

/// Per-clip reframing data for multi-aspect export.
public struct ReframeInstructionsComponent: Component, Codable {
    /// Reframe instructions keyed by aspect ratio.
    public var instructions: [AspectRatio: [ReframeKeyframe]]

    /// Auto-reframe mode.
    public var autoReframeMode: AutoReframeMode

    public init(
        instructions: [AspectRatio: [ReframeKeyframe]] = [:],
        autoReframeMode: AutoReframeMode = .subjectTracking
    ) {
        self.instructions = instructions
        self.autoReframeMode = autoReframeMode
    }
}

/// A single reframe keyframe.
public struct ReframeKeyframe: Codable, Sendable {
    /// Time in the clip.
    public var time: TimeInterval

    /// Center point (normalized 0-1).
    public var centerX: Float
    public var centerY: Float

    /// Scale (1.0 = no zoom).
    public var scale: Float

    /// Easing to next keyframe.
    public var easing: ReframeEasing

    public init(
        time: TimeInterval,
        centerX: Float = 0.5,
        centerY: Float = 0.5,
        scale: Float = 1.0,
        easing: ReframeEasing = .smooth
    ) {
        self.time = time
        self.centerX = centerX
        self.centerY = centerY
        self.scale = scale
        self.easing = easing
    }
}

/// Easing function for reframe transitions.
public enum ReframeEasing: String, Codable, Sendable {
    case linear
    case smooth
    case easeIn
    case easeOut
    case easeInOut
    case instant
}

/// Auto-reframe behavior.
public enum AutoReframeMode: String, Codable, Sendable {
    case subjectTracking   // Follow detected subjects
    case centerCrop        // Always center crop
    case smartCrop         // Use composition rules
    case manual            // No auto-reframe
}

// MARK: - System Presets

/// Built-in export presets.
public enum SystemExportPresets {

    public static let tiktokVertical = ExportPresetComponent(
        name: "TikTok Vertical",
        platform: .tiktok,
        resolution: .vertical1080,
        videoCodec: .h264,
        videoQuality: 85,
        audioBitrate: 192_000,
        loudnessTarget: -14.0,
        frameRate: 30,
        embedCaptions: true,
        captionFormat: .burnedIn,
        isSystemPreset: true
    )

    public static let instagramReels = ExportPresetComponent(
        name: "Instagram Reels",
        platform: .instagramReels,
        resolution: .vertical1080,
        videoCodec: .h264,
        videoQuality: 85,
        audioBitrate: 192_000,
        loudnessTarget: -14.0,
        frameRate: 30,
        embedCaptions: true,
        captionFormat: .burnedIn,
        isSystemPreset: true
    )

    public static let youtubeHorizontal = ExportPresetComponent(
        name: "YouTube 1080p",
        platform: .youtube,
        resolution: .hd1080,
        videoCodec: .h264,
        videoQuality: 90,
        audioBitrate: 320_000,
        loudnessTarget: -14.0,
        frameRate: 30,
        embedCaptions: false,
        isSystemPreset: true
    )

    public static let youtubeShorts = ExportPresetComponent(
        name: "YouTube Shorts",
        platform: .youtubeShorts,
        resolution: .vertical1080,
        videoCodec: .h264,
        videoQuality: 85,
        audioBitrate: 192_000,
        loudnessTarget: -14.0,
        frameRate: 30,
        embedCaptions: true,
        captionFormat: .burnedIn,
        isSystemPreset: true
    )

    public static let proresArchive = ExportPresetComponent(
        name: "ProRes Archive",
        platform: .archive,
        resolution: .hd1080,
        videoCodec: .prores422,
        videoQuality: 100,
        audioBitrate: 1_536_000, // PCM equivalent
        loudnessTarget: -14.0,
        frameRate: 30,
        embedCaptions: false,
        isSystemPreset: true
    )

    public static var allPresets: [ExportPresetComponent] {
        [
            tiktokVertical,
            instagramReels,
            youtubeHorizontal,
            youtubeShorts,
            proresArchive
        ]
    }
}
