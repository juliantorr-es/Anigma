import AnigmaPrimitives

import AnigmaPrimitives

//
//  MediaAssetComponents.swift
//  PolytroposModule
//
//  Components for individual media files (video, audio).
//

import AnigmaCore
import Foundation

// MARK: - Media Asset Component

/// Represents a single imported media file.
public struct MediaAssetComponent: Component, Codable {
    /// Unique asset identifier.
    public let id: UUID

    /// Original file path or URL.
    public var originalPath: String

    /// Proxy file path (if generated).
    public var proxyPath: String?

    /// Media type classification.
    public var mediaType: MediaType

    /// Source device identifier (derived from EXIF/metadata).
    public var deviceId: String?

    /// Human-readable camera/device label.
    public var deviceLabel: String?

    /// Import timestamp.
    public let importedAt: Date

    /// Processing status.
    public var status: MediaAssetStatus

    public init(
        id: UUID = UUID(),
        originalPath: String,
        proxyPath: String? = nil,
        mediaType: MediaType = .video,
        deviceId: String? = nil,
        deviceLabel: String? = nil,
        importedAt: Date = Date(),
        status: MediaAssetStatus = .pending
    ) {
        self.id = id
        self.originalPath = originalPath
        self.proxyPath = proxyPath
        self.mediaType = mediaType
        self.deviceId = deviceId
        self.deviceLabel = deviceLabel
        self.importedAt = importedAt
        self.status = status
    }
}

/// Media type classification.
public enum MediaType: String, Codable, Sendable {
    case video
    case audio
    case image
    case unknown
}

/// Media asset processing status.
public enum MediaAssetStatus: String, Codable, Sendable {
    case pending
    case analyzing
    case ready
    case error
    case excluded
}

// MARK: - Temporal Metadata Component

/// Time-related metadata for a media asset.
public struct TemporalMetadataComponent: Component, Codable {
    /// Duration in seconds.
    public var duration: TimeInterval

    /// Capture start timestamp (from file metadata).
    public var captureStartTime: Date?

    /// Timecode (if embedded in file).
    public var timecode: String?

    /// Frame rate (for video).
    public var frameRate: Double?

    /// Sample rate (for audio).
    public var sampleRate: Double?

    public init(
        duration: TimeInterval,
        captureStartTime: Date? = nil,
        timecode: String? = nil,
        frameRate: Double? = nil,
        sampleRate: Double? = nil
    ) {
        self.duration = duration
        self.captureStartTime = captureStartTime
        self.timecode = timecode
        self.frameRate = frameRate
        self.sampleRate = sampleRate
    }
}

// MARK: - Video Metadata Component

/// Video-specific technical metadata.
public struct VideoMetadataComponent: Component, Codable {
    /// Width in pixels.
    public var width: Int

    /// Height in pixels.
    public var height: Int

    /// Codec name (e.g., "H.264", "HEVC").
    public var codec: String?

    /// Bitrate in bits per second.
    public var bitrate: Int?

    /// Color space (e.g., "Rec.709", "P3").
    public var colorSpace: String?

    /// Whether HDR metadata is present.
    public var isHDR: Bool

    /// Aspect ratio as width/height.
    public var aspectRatio: Double {
        guard height > 0 else { return 1.0 }
        return Double(width) / Double(height)
    }

    /// Whether this is vertical (portrait) video.
    public var isVertical: Bool {
        height > width
    }

    public init(
        width: Int,
        height: Int,
        codec: String? = nil,
        bitrate: Int? = nil,
        colorSpace: String? = nil,
        isHDR: Bool = false
    ) {
        self.width = width
        self.height = height
        self.codec = codec
        self.bitrate = bitrate
        self.colorSpace = colorSpace
        self.isHDR = isHDR
    }
}

// MARK: - Audio Metadata Component

/// Audio-specific technical metadata.
public struct AudioMetadataComponent: Component, Codable {
    /// Number of audio channels.
    public var channelCount: Int

    /// Sample rate in Hz.
    public var sampleRate: Double

    /// Codec name (e.g., "AAC", "PCM").
    public var codec: String?

    /// Bitrate in bits per second.
    public var bitrate: Int?

    /// Peak level in dBFS.
    public var peakLevel: Double?

    /// Average loudness in LUFS.
    public var loudnessLUFS: Double?

    public init(
        channelCount: Int,
        sampleRate: Double,
        codec: String? = nil,
        bitrate: Int? = nil,
        peakLevel: Double? = nil,
        loudnessLUFS: Double? = nil
    ) {
        self.channelCount = channelCount
        self.sampleRate = sampleRate
        self.codec = codec
        self.bitrate = bitrate
        self.peakLevel = peakLevel
        self.loudnessLUFS = loudnessLUFS
    }
}

// MARK: - Device Metadata Component

/// Device/camera identification metadata.
public struct DeviceMetadataComponent: Component, Codable {
    /// Camera/device make (e.g., "Apple", "Canon").
    public var make: String?

    /// Camera/device model (e.g., "iPhone 15 Pro", "EOS R5").
    public var model: String?

    /// Device serial number if available.
    public var serialNumber: String?

    /// Lens information if available.
    public var lens: String?

    /// GPS coordinates if embedded.
    public var gpsLatitude: Double?
    public var gpsLongitude: Double?

    /// Derived device fingerprint for clustering.
    public var deviceFingerprint: String {
        [make, model, serialNumber]
            .compactMap { $0 }
            .joined(separator: "_")
    }

    public init(
        make: String? = nil,
        model: String? = nil,
        serialNumber: String? = nil,
        lens: String? = nil,
        gpsLatitude: Double? = nil,
        gpsLongitude: Double? = nil
    ) {
        self.make = make
        self.model = model
        self.serialNumber = serialNumber
        self.lens = lens
        self.gpsLatitude = gpsLatitude
        self.gpsLongitude = gpsLongitude
    }
}

// MARK: - Waveform Component

/// Pre-computed audio waveform for visualization and sync.
public struct WaveformComponent: Component, Codable {
    /// Waveform samples (normalized 0-1).
    public var samples: [Float]

    /// Samples per second (resolution).
    public var samplesPerSecond: Int

    /// Peak values per sample (for visualization).
    public var peaks: [Float]?

    /// RMS values per sample (for energy analysis).
    public var rmsValues: [Float]?

    public init(
        samples: [Float],
        samplesPerSecond: Int,
        peaks: [Float]? = nil,
        rmsValues: [Float]? = nil
    ) {
        self.samples = samples
        self.samplesPerSecond = samplesPerSecond
        self.peaks = peaks
        self.rmsValues = rmsValues
    }

    /// Duration represented by this waveform.
    public var duration: TimeInterval {
        guard samplesPerSecond > 0 else { return 0 }
        return TimeInterval(samples.count) / TimeInterval(samplesPerSecond)
    }
}

// MARK: - Thumbnail Component

/// Pre-generated thumbnails for a video asset.
public struct ThumbnailComponent: Component, Codable {
    /// Thumbnail image paths keyed by timestamp in seconds.
    public var thumbnails: [TimeInterval: String]

    /// Default/representative thumbnail path.
    public var defaultThumbnail: String?

    /// Thumbnail dimensions.
    public var width: Int
    public var height: Int

    public init(
        thumbnails: [TimeInterval: String] = [:],
        defaultThumbnail: String? = nil,
        width: Int = 320,
        height: Int = 180
    ) {
        self.thumbnails = thumbnails
        self.defaultThumbnail = defaultThumbnail
        self.width = width
        self.height = height
    }
}
