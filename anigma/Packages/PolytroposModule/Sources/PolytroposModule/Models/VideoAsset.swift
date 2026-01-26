//
//  VideoAsset.swift
//  PolytroposModule
//
//  Video asset model with metadata and frame fingerprint support.
//

import AnigmaCore
import Foundation

// MARK: - VideoAsset Model

/// Represents a video asset with extracted metadata and frame fingerprints.
/// Designed for persistence and integration with ArtifactStoreModule.
public struct VideoAsset: Codable, Sendable, Identifiable {
    /// Unique identifier for the video asset.
    public let id: UUID

    /// Reference to the original video file.
    public let fileReference: VideoFileReference

    /// Extracted video metadata.
    public let metadata: VideoAssetMetadata

    /// Frame fingerprints for content identification (placeholder for MediaFingerprintCapsule integration).
    public var frameFingerprints: [FrameFingerprint]

    /// Processing status.
    public var status: VideoAssetStatus

    /// Creation timestamp.
    public let createdAt: Date

    /// Last update timestamp.
    public var updatedAt: Date

    /// Associated artifact ID in ArtifactStoreModule (if persisted).
    public var artifactID: String?

    public init(
        id: UUID = UUID(),
        fileReference: VideoFileReference,
        metadata: VideoAssetMetadata,
        frameFingerprints: [FrameFingerprint] = [],
        status: VideoAssetStatus = .pending,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        artifactID: String? = nil
    ) {
        self.id = id
        self.fileReference = fileReference
        self.metadata = metadata
        self.frameFingerprints = frameFingerprints
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.artifactID = artifactID
    }
}

// MARK: - VideoFileReference

/// Reference to a video file location.
public struct VideoFileReference: Codable, Sendable {
    /// File URL path (as string for Codable compatibility).
    public let path: String

    /// Optional bookmark data for sandboxed access.
    public var bookmarkData: Data?

    /// Original filename.
    public let filename: String

    /// File size in bytes.
    public let sizeBytes: Int64

    /// Content hash for integrity verification.
    public var contentHash: String?

    /// URL representation.
    public var url: URL {
        URL(fileURLWithPath: path)
    }

    public init(
        path: String,
        filename: String,
        sizeBytes: Int64,
        bookmarkData: Data? = nil,
        contentHash: String? = nil
    ) {
        self.path = path
        self.filename = filename
        self.sizeBytes = sizeBytes
        self.bookmarkData = bookmarkData
        self.contentHash = contentHash
    }

    public init(url: URL, sizeBytes: Int64, contentHash: String? = nil) {
        self.path = url.path
        self.filename = url.lastPathComponent
        self.sizeBytes = sizeBytes
        self.bookmarkData = nil
        self.contentHash = contentHash
    }
}

// MARK: - VideoAssetMetadata

/// Comprehensive video metadata extracted during ingestion.
public struct VideoAssetMetadata: Codable, Sendable {
    /// Duration in seconds.
    public let duration: TimeInterval

    /// Video resolution.
    public let resolution: VideoResolution

    /// Video codec information.
    public let codec: VideoCodecInfo

    /// Frame rate (frames per second).
    public let frameRate: Double

    /// Bitrate in bits per second (if known).
    public let bitrate: Int?

    /// Whether the video contains HDR content.
    public let isHDR: Bool

    /// Audio track count.
    public let audioTrackCount: Int

    /// Creation date from metadata (if available).
    public let captureDate: Date?

    /// Container format.
    public let containerFormat: String

    /// Aspect ratio as width/height.
    public var aspectRatio: Double {
        guard resolution.height > 0 else { return 1.0 }
        return Double(resolution.width) / Double(resolution.height)
    }

    /// Whether video is vertical (portrait).
    public var isVertical: Bool {
        resolution.height > resolution.width
    }

    /// Total frame count (estimated from duration and frame rate).
    public var estimatedFrameCount: Int {
        Int(duration * frameRate)
    }

    public init(
        duration: TimeInterval,
        resolution: VideoResolution,
        codec: VideoCodecInfo,
        frameRate: Double,
        bitrate: Int? = nil,
        isHDR: Bool = false,
        audioTrackCount: Int = 0,
        captureDate: Date? = nil,
        containerFormat: String = "unknown"
    ) {
        self.duration = duration
        self.resolution = resolution
        self.codec = codec
        self.frameRate = frameRate
        self.bitrate = bitrate
        self.isHDR = isHDR
        self.audioTrackCount = audioTrackCount
        self.captureDate = captureDate
        self.containerFormat = containerFormat
    }
}

// MARK: - VideoResolution

/// Video resolution dimensions.
public struct VideoResolution: Codable, Sendable, Equatable {
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    /// Standard resolution presets.
    public static let sd480p = VideoResolution(width: 854, height: 480)
    public static let hd720p = VideoResolution(width: 1280, height: 720)
    public static let hd1080p = VideoResolution(width: 1920, height: 1080)
    public static let uhd4k = VideoResolution(width: 3840, height: 2160)

    /// Human-readable description.
    public var descriptionString: String {
        "\(width)x\(height)"
    }

    /// Resolution category.
    public var category: ResolutionCategory {
        let pixels = width * height
        if pixels >= 3840 * 2160 { return .uhd4k }
        if pixels >= 1920 * 1080 { return .hd1080p }
        if pixels >= 1280 * 720 { return .hd720p }
        return .sd
    }
}

/// Resolution category classification.
public enum ResolutionCategory: String, Codable, Sendable {
    case sd
    case hd720p
    case hd1080p
    case uhd4k
}

// MARK: - VideoCodecInfo

/// Video codec information.
public struct VideoCodecInfo: Codable, Sendable {
    /// Codec identifier (e.g., "h264", "hevc", "vp9").
    public let identifier: String

    /// Human-readable codec name.
    public let displayName: String

    /// Profile (if known, e.g., "High", "Main").
    public let profile: String?

    /// Level (if known, e.g., "4.1", "5.0").
    public let level: String?

    public init(
        identifier: String,
        displayName: String,
        profile: String? = nil,
        level: String? = nil
    ) {
        self.identifier = identifier
        self.displayName = displayName
        self.profile = profile
        self.level = level
    }

    /// Common codec presets.
    public static let h264 = VideoCodecInfo(identifier: "h264", displayName: "H.264/AVC")
    public static let hevc = VideoCodecInfo(identifier: "hevc", displayName: "H.265/HEVC")
    public static let vp9 = VideoCodecInfo(identifier: "vp9", displayName: "VP9")
    public static let av1 = VideoCodecInfo(identifier: "av1", displayName: "AV1")
    public static let prores = VideoCodecInfo(identifier: "prores", displayName: "Apple ProRes")
    public static let unknown = VideoCodecInfo(identifier: "unknown", displayName: "Unknown")
}

// MARK: - FrameFingerprint

/// Fingerprint data for a single video frame.
/// Placeholder for MediaFingerprintCapsule integration.
public struct FrameFingerprint: Codable, Sendable, Identifiable {
    public let id: UUID

    /// Frame index (0-based).
    public let frameIndex: Int

    /// Timestamp in seconds.
    public let timestamp: TimeInterval

    /// Perceptual hash (pHash) of the frame.
    public var pHash: String?

    /// Average color signature.
    public var colorSignature: ColorSignature?

    /// Motion vector magnitude (relative to previous frame).
    public var motionMagnitude: Float?

    /// Whether this is a key frame (I-frame).
    public let isKeyFrame: Bool

    public init(
        id: UUID = UUID(),
        frameIndex: Int,
        timestamp: TimeInterval,
        pHash: String? = nil,
        colorSignature: ColorSignature? = nil,
        motionMagnitude: Float? = nil,
        isKeyFrame: Bool = false
    ) {
        self.id = id
        self.frameIndex = frameIndex
        self.timestamp = timestamp
        self.pHash = pHash
        self.colorSignature = colorSignature
        self.motionMagnitude = motionMagnitude
        self.isKeyFrame = isKeyFrame
    }
}

/// Color signature for a frame (average color in RGB space).
public struct ColorSignature: Codable, Sendable {
    public let r: Float
    public let g: Float
    public let b: Float

    public init(r: Float, g: Float, b: Float) {
        self.r = r
        self.g = g
        self.b = b
    }
}

// MARK: - VideoAssetStatus

/// Processing status for a video asset.
public enum VideoAssetStatus: String, Codable, Sendable {
    /// Asset created but not yet processed.
    case pending

    /// Metadata extraction in progress.
    case extractingMetadata

    /// Frame extraction in progress.
    case extractingFrames

    /// Fingerprint generation in progress.
    case generatingFingerprints

    /// All processing complete.
    case ready

    /// Asset processing failed.
    case failed

    /// Asset excluded from processing.
    case excluded
}

// MARK: - VideoAssetError

/// Errors that can occur during video asset processing.
public enum VideoAssetError: Error, Sendable {
    case fileNotFound(String)
    case unsupportedFormat(String)
    case metadataExtractionFailed(String)
    case frameExtractionFailed(String)
    case fingerprintGenerationFailed(String)
    case persistenceFailed(String)
    case invalidConfiguration(String)
}

extension VideoAssetError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .fileNotFound(let path):
            return "Video file not found: \(path)"
        case .unsupportedFormat(let format):
            return "Unsupported video format: \(format)"
        case .metadataExtractionFailed(let reason):
            return "Metadata extraction failed: \(reason)"
        case .frameExtractionFailed(let reason):
            return "Frame extraction failed: \(reason)"
        case .fingerprintGenerationFailed(let reason):
            return "Fingerprint generation failed: \(reason)"
        case .persistenceFailed(let reason):
            return "Persistence failed: \(reason)"
        case .invalidConfiguration(let reason):
            return "Invalid configuration: \(reason)"
        }
    }
}
