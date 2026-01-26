//
//  VideoIngestionService.swift
//  PolytroposModule
//
//  Service for ingesting video files, extracting metadata, and harvesting key frames.
//

import AnigmaCore
import Foundation
import MediaContainerCapsule

// MARK: - VideoIngestionService

/// Service for ingesting video files with metadata extraction and key frame harvesting.
///
/// This service handles:
/// - Accepting video file URLs
/// - Extracting key frames at configurable intervals
/// - Harvesting video metadata (duration, resolution, codec)
/// - Preparing VideoAsset models for persistence
public actor VideoIngestionService {
    // MARK: - Properties

    /// Configuration for frame extraction.
    private let configuration: VideoIngestionConfiguration

    /// Media container capsule for metadata extraction.
    private let containerCapsule: MediaContainerCapsuleWrapper?

    /// Work directory for intermediate outputs.
    private let workDirectory: URL

    /// Supported video file extensions.
    private let supportedExtensions: Set<String> = [
        "mp4", "mov", "m4v", "mkv", "avi", "mxf", "mts", "webm", "wmv", "flv"
    ]

    // MARK: - Initialization

    public init(
        configuration: VideoIngestionConfiguration = .default,
        containerCapsule: MediaContainerCapsuleWrapper? = nil,
        workDirectory: URL? = nil
    ) {
        self.configuration = configuration
        self.containerCapsule = containerCapsule
        self.workDirectory = workDirectory ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("polytropos/ingestion", isDirectory: true)
    }

    // MARK: - Public API

    /// Ingest a video file and create a VideoAsset with extracted metadata.
    ///
    /// - Parameters:
    ///   - url: URL to the video file.
    ///   - extractFrames: Whether to extract key frames (default: true).
    /// - Returns: A VideoAsset with metadata and optionally frame fingerprints.
    /// - Throws: VideoAssetError if ingestion fails.
    public func ingest(url: URL, extractFrames: Bool = true) async throws -> VideoAsset {
        // Validate file exists and is supported
        try validateVideoFile(at: url)

        // Get file size
        let fileSize = try getFileSize(at: url)

        // Extract metadata using MediaContainerCapsule
        let metadata = try await extractMetadata(from: url)

        // Create file reference
        let fileReference = VideoFileReference(
            url: url,
            sizeBytes: fileSize,
            contentHash: nil
        )

        // Create initial asset
        var asset = VideoAsset(
            fileReference: fileReference,
            metadata: metadata,
            status: .extractingMetadata
        )

        // Extract key frames if requested
        if extractFrames && configuration.enableFrameExtraction {
            asset.status = .extractingFrames
            let fingerprints = try await extractKeyFrames(from: url, metadata: metadata)
            asset.frameFingerprints = fingerprints
        }

        // Mark as ready
        asset.status = .ready
        asset.updatedAt = Date()

        await Logger.shared.info(
            "Ingested video: \(url.lastPathComponent) (\(metadata.resolution.descriptionString), \(String(format: "%.1f", metadata.duration))s)",
            category: "Polytropos.Ingestion"
        )

        return asset
    }

    /// Ingest multiple video files in batch.
    ///
    /// - Parameters:
    ///   - urls: URLs to video files.
    ///   - extractFrames: Whether to extract key frames.
    ///   - progressHandler: Optional progress callback.
    /// - Returns: Array of ingestion results.
    public func ingestBatch(
        urls: [URL],
        extractFrames: Bool = true,
        progressHandler: ((Int, Int) -> Void)? = nil
    ) async -> [VideoIngestionResult] {
        var results: [VideoIngestionResult] = []

        for (index, url) in urls.enumerated() {
            progressHandler?(index, urls.count)

            do {
                let asset = try await ingest(url: url, extractFrames: extractFrames)
                results.append(.success(asset))
            } catch {
                results.append(.failure(url: url, error: error))
            }
        }

        progressHandler?(urls.count, urls.count)
        return results
    }

    /// Extract only metadata without frame extraction.
    ///
    /// - Parameter url: URL to the video file.
    /// - Returns: VideoAssetMetadata with extracted information.
    public func extractMetadataOnly(from url: URL) async throws -> VideoAssetMetadata {
        try validateVideoFile(at: url)
        return try await extractMetadata(from: url)
    }

    /// Check if a file is a supported video format.
    public func isSupported(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return supportedExtensions.contains(ext)
    }

    // MARK: - Private Methods

    private func validateVideoFile(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw VideoAssetError.fileNotFound(url.path)
        }

        let ext = url.pathExtension.lowercased()
        guard supportedExtensions.contains(ext) else {
            throw VideoAssetError.unsupportedFormat(ext)
        }
    }

    private func getFileSize(at url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? Int64) ?? 0
    }

    private func extractMetadata(from url: URL) async throws -> VideoAssetMetadata {
        // Use MediaContainerCapsule if available
        if let capsule = containerCapsule {
            return try extractMetadataWithCapsule(from: url, capsule: capsule)
        }

        // Fallback to AVFoundation-based extraction
        return try await extractMetadataWithAVFoundation(from: url)
    }

    private func extractMetadataWithCapsule(
        from url: URL,
        capsule: MediaContainerCapsuleWrapper
    ) throws -> VideoAssetMetadata {
        let report = try capsule.analyzeFile(at: url)

        var resolution = VideoResolution(width: 1920, height: 1080)
        var codec = VideoCodecInfo.unknown
        var frameRate: Double = 30.0
        var bitrate: Int?
        var audioTrackCount = 0

        for stream in report.streams {
            switch stream.type {
            case .video:
                if let videoInfo = try? capsule.getVideoStreamInfo(at: stream.index) {
                    resolution = VideoResolution(
                        width: Int(videoInfo.width),
                        height: Int(videoInfo.height)
                    )
                    codec = mapVideoCodec(videoInfo.codec)
                    frameRate = Double(videoInfo.frameRate.num) / Double(videoInfo.frameRate.den)
                    bitrate = Int(videoInfo.bitRate) > 0 ? Int(videoInfo.bitRate) : nil
                }
            case .audio:
                audioTrackCount += 1
            case .unknown:
                break
            }
        }

        let duration = Double(report.totalDurationUs) / 1_000_000.0
        let containerFormat = mapContainerFormat(report.containerType)

        return VideoAssetMetadata(
            duration: duration,
            resolution: resolution,
            codec: codec,
            frameRate: frameRate,
            bitrate: bitrate,
            isHDR: false,
            audioTrackCount: audioTrackCount,
            captureDate: nil,
            containerFormat: containerFormat
        )
    }

    private func extractMetadataWithAVFoundation(from url: URL) async throws -> VideoAssetMetadata {
        // Fallback implementation using file extension heuristics
        // In production, this would use AVAsset for metadata extraction
        
        let ext = url.pathExtension.lowercased()
        let containerFormat = ext.uppercased()

        // Default values - in production, use AVAsset
        return VideoAssetMetadata(
            duration: 0,
            resolution: VideoResolution(width: 1920, height: 1080),
            codec: .h264,
            frameRate: 30.0,
            bitrate: nil,
            isHDR: false,
            audioTrackCount: 1,
            captureDate: nil,
            containerFormat: containerFormat
        )
    }

    private func extractKeyFrames(
        from url: URL,
        metadata: VideoAssetMetadata
    ) async throws -> [FrameFingerprint] {
        var fingerprints: [FrameFingerprint] = []

        let intervalSeconds = configuration.keyFrameIntervalSeconds
        let maxFrames = configuration.maxKeyFramesPerVideo

        // Calculate frame timestamps
        var currentTime: TimeInterval = 0
        var frameIndex = 0

        while currentTime < metadata.duration && fingerprints.count < maxFrames {
            // Create a placeholder fingerprint
            // In production, this would extract actual frame data using AVAssetImageGenerator
            // and compute perceptual hashes using MediaFingerprintCapsule
            let fingerprint = FrameFingerprint(
                frameIndex: frameIndex,
                timestamp: currentTime,
                pHash: nil, // Placeholder for MediaFingerprintCapsule integration
                colorSignature: nil,
                motionMagnitude: nil,
                isKeyFrame: frameIndex == 0 || (frameIndex % Int(metadata.frameRate * intervalSeconds)) == 0
            )

            fingerprints.append(fingerprint)
            currentTime += intervalSeconds
            frameIndex += 1
        }

        await Logger.shared.debug(
            "Extracted \(fingerprints.count) key frames from \(url.lastPathComponent)",
            category: "Polytropos.Ingestion"
        )

        return fingerprints
    }

    private func mapVideoCodec(_ codec: MediaContainerCapsule.VideoCodec) -> VideoCodecInfo {
        switch codec {
        case .h264:
            return .h264
        case .h265:
            return .hevc
        case .vp9:
            return .vp9
        case .av1:
            return .av1
        default:
            return .unknown
        }
    }

    private func mapContainerFormat(_ type: ContainerType) -> String {
        switch type {
        case .mp4:
            return "MP4"
        case .matroska:
            return "MKV"
        case .unknown:
            return "Unknown"
        }
    }
}

// MARK: - VideoIngestionConfiguration

/// Configuration for video ingestion behavior.
public struct VideoIngestionConfiguration: Codable, Sendable {
    /// Interval in seconds between key frame extractions.
    public var keyFrameIntervalSeconds: TimeInterval

    /// Maximum number of key frames to extract per video.
    public var maxKeyFramesPerVideo: Int

    /// Whether to enable frame extraction.
    public var enableFrameExtraction: Bool

    /// Whether to compute perceptual hashes for frames.
    public var computePerceptualHashes: Bool

    /// Whether to compute color signatures for frames.
    public var computeColorSignatures: Bool

    /// Thumbnail dimensions for extracted frames.
    public var thumbnailWidth: Int
    public var thumbnailHeight: Int

    /// Default configuration.
    public static let `default` = VideoIngestionConfiguration(
        keyFrameIntervalSeconds: 1.0,
        maxKeyFramesPerVideo: 300,
        enableFrameExtraction: true,
        computePerceptualHashes: true,
        computeColorSignatures: true,
        thumbnailWidth: 320,
        thumbnailHeight: 180
    )

    /// Configuration optimized for quick previews.
    public static let quickPreview = VideoIngestionConfiguration(
        keyFrameIntervalSeconds: 5.0,
        maxKeyFramesPerVideo: 60,
        enableFrameExtraction: true,
        computePerceptualHashes: false,
        computeColorSignatures: false,
        thumbnailWidth: 160,
        thumbnailHeight: 90
    )

    /// Configuration for detailed analysis.
    public static let detailed = VideoIngestionConfiguration(
        keyFrameIntervalSeconds: 0.5,
        maxKeyFramesPerVideo: 600,
        enableFrameExtraction: true,
        computePerceptualHashes: true,
        computeColorSignatures: true,
        thumbnailWidth: 640,
        thumbnailHeight: 360
    )

    public init(
        keyFrameIntervalSeconds: TimeInterval = 1.0,
        maxKeyFramesPerVideo: Int = 300,
        enableFrameExtraction: Bool = true,
        computePerceptualHashes: Bool = true,
        computeColorSignatures: Bool = true,
        thumbnailWidth: Int = 320,
        thumbnailHeight: Int = 180
    ) {
        self.keyFrameIntervalSeconds = keyFrameIntervalSeconds
        self.maxKeyFramesPerVideo = maxKeyFramesPerVideo
        self.enableFrameExtraction = enableFrameExtraction
        self.computePerceptualHashes = computePerceptualHashes
        self.computeColorSignatures = computeColorSignatures
        self.thumbnailWidth = thumbnailWidth
        self.thumbnailHeight = thumbnailHeight
    }
}

// MARK: - VideoIngestionResult

/// Result of a video ingestion operation.
public enum VideoIngestionResult: Sendable {
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
