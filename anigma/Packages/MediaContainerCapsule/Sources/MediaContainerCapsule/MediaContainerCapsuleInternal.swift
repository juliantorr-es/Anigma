/// MediaContainerCapsuleInternal.swift
/// Internal implementation for the MediaContainerCapsule
/// Container format support with stream extraction and subtitle handling

import Foundation
import AVFoundation
import CoreMedia

/// Supported container formats
public enum ContainerFormat: String, CaseIterable, Sendable {
    case mp4 = "mp4"
    case mov = "mov"
    case mkv = "mkv"
    case webm = "webm"
    case avi = "avi"
    case m4v = "m4v"
    case flv = "flv"
}

/// Stream types within containers
enum StreamType: String, CaseIterable, Sendable {
    case video = "video"
    case audio = "audio"
    case subtitle = "subtitle"
    case data = "data"
}

/// Stream information
struct InternalStreamInfo: Sendable {
    public let index: Int
    public let type: StreamType
    public let codec: String
    public let language: String?
    public let bitrate: Int?
    public let duration: TimeInterval?
    public let metadata: [String: String]
    
    public init(index: Int, type: StreamType, codec: String, language: String?, 
                bitrate: Int?, duration: TimeInterval?, metadata: [String: String]) {
        self.index = index
        self.type = type
        self.codec = codec
        self.language = language
        self.bitrate = bitrate
        self.duration = duration
        self.metadata = metadata
    }
}

/// Subtitle information
public struct SubtitleInfo: Sendable {
    public let index: Int
    public let language: String?
    public let format: String
    public let encoding: String?
    public let isForced: Bool
    public let isDefault: Bool
    
    public init(index: Int, language: String?, format: String, encoding: String?, 
                isForced: Bool, isDefault: Bool) {
        self.index = index
        self.language = language
        self.format = format
        self.encoding = encoding
        self.isForced = isForced
        self.isDefault = isDefault
    }
}

/// Container analysis result
struct ContainerAnalysis: Sendable {
    public let format: ContainerFormat
    public let duration: TimeInterval
    public let streams: [InternalStreamInfo]
    public let subtitles: [SubtitleInfo]
    public let metadata: [String: String]
    public let fileSize: Int64
    
    public init(format: ContainerFormat, duration: TimeInterval, streams: [InternalStreamInfo], 
                subtitles: [SubtitleInfo], metadata: [String: String], fileSize: Int64) {
        self.format = format
        self.duration = duration
        self.streams = streams
        self.subtitles = subtitles
        self.metadata = metadata
        self.fileSize = fileSize
    }
}

/// Stream extraction result
struct StreamExtractionResult: Sendable {
    public let streamInfo: InternalStreamInfo
    public let outputPath: String
    public let fileSize: Int64
    public let processingTime: TimeInterval
    
    public init(streamInfo: InternalStreamInfo, outputPath: String, fileSize: Int64, processingTime: TimeInterval) {
        self.streamInfo = streamInfo
        self.outputPath = outputPath
        self.fileSize = fileSize
        self.processingTime = processingTime
    }
}

/// Internal implementation of the MediaContainerCapsule processing logic.
/// Marked as Sendable to comply with Swift 6 concurrency requirements.
internal final class MediaContainerCapsuleInternal: Sendable {
    
    private let processingQueue = DispatchQueue(label: "mediacontainer.processing", qos: .userInitiated)
    
    /// Initialize the internal implementation.
    internal init() {}
    
    /// Analyze a media container and extract stream information
    /// - Parameter url: URL of the container file
    /// - Returns: ContainerAnalysis with detailed stream information
    /// - Throws: Analysis errors
    internal func analyzeContainer(from url: URL) async throws -> ContainerAnalysis {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        
        guard let uti = UTType(filenameExtension: url.pathExtension),
              let format = ContainerFormat(rawValue: uti.preferredFilenameExtension ?? "") else {
            throw MediaContainerError.unsupportedFormat("Unsupported container format: \(url.pathExtension)")
        }
        
        let asset = AVURLAsset(url: url)
        
        // Get duration
        let duration: TimeInterval
        if asset.duration.isIndefinite {
            duration = 0.0
        } else {
            duration = asset.duration.seconds
        }
        
        // Extract streams
        var streams: [InternalStreamInfo] = []
        var subtitles: [SubtitleInfo] = []
        
        // Load tracks
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        
        // Process video tracks
        for (index, track) in tracks.enumerated() {
            let codec = try await track.load(.naturalSize).description
            let bitrate = try await track.load(.estimatedBitrate)
            
            let streamInfo = InternalStreamInfo(
                index: index,
                type: .video,
                codec: codec,
                language: nil,
                bitrate: Int(bitrate),
                duration: duration,
                metadata: [:]
            )
            streams.append(streamInfo)
        }
        
        // Process audio tracks
        let audioIndexOffset = tracks.count
        for (index, track) in audioTracks.enumerated() {
            let language = try await track.load(.language)
            let bitrate = try await track.load(.estimatedBitrate)
            
            let streamInfo = InternalStreamInfo(
                index: audioIndexOffset + index,
                type: .audio,
                codec: "aac", // Simplified
                language: language,
                bitrate: Int(bitrate),
                duration: duration,
                metadata: [:]
            )
            streams.append(streamInfo)
        }
        
        // Extract metadata
        var metadata: [String: String] = [:]
        if let commonMetadata = try? await asset.load(.commonMetadata) {
            for item in commonMetadata {
                if let key = item.commonKey?.rawValue, let value = item.stringValue {
                    metadata[key] = value
                }
            }
        }
        
        return ContainerAnalysis(
            format: format,
            duration: duration,
            streams: streams,
            subtitles: subtitles,
            metadata: metadata,
            fileSize: fileSize
        )
    }
    
    /// Extract a specific stream from a container
    /// - Parameters:
    ///   - containerURL: URL of the source container
    ///   - streamIndex: Index of the stream to extract
    ///   - outputPath: Output path for the extracted stream
    ///   - progress: Progress callback
    /// - Returns: StreamExtractionResult
    /// - Throws: Extraction errors
    internal func extractStream(
        from containerURL: URL,
        streamIndex: Int,
        outputPath: String,
        progress: ((Double) -> Void)? = nil
    ) async throws -> StreamExtractionResult {
        let startTime = Date()
        
        let asset = AVURLAsset(url: containerURL)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        let allTracks = tracks + audioTracks
        
        guard streamIndex < allTracks.count else {
            throw MediaContainerError.invalidStream("Stream index \(streamIndex) out of range")
        }
        
        let track = allTracks[streamIndex]
        
        // Create export session for stream extraction
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw MediaContainerError.extractionFailed("Failed to create export session")
        }
        
        let outputURL = URL(fileURLWithPath: outputPath)
        exportSession.outputURL = outputURL
        
        // Determine output format based on stream type
        if tracks.contains(track) {
            exportSession.outputFileType = .mp4
        } else {
            exportSession.outputFileType = .wav
        }
        
        // Set up progress monitoring
        let progressSource = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            progress?(exportSession.progress)
        }
        
        defer { progressSource.invalidate() }
        
        await exportSession.export()
        
        guard exportSession.status == .completed else {
            if let error = exportSession.error {
                throw MediaContainerError.extractionFailed("Export failed: \(error.localizedDescription)")
            } else {
                throw MediaContainerError.extractionFailed("Export failed with unknown error")
            }
        }
        
        let processingTime = Date().timeIntervalSince(startTime)
        let outputAttributes = try FileManager.default.attributesOfItem(atPath: outputPath)
        let fileSize = outputAttributes[.size] as? Int64 ?? 0
        
        // Create stream info
        let streamType: StreamType = tracks.contains(track) ? .video : .audio
        let streamInfo = InternalStreamInfo(
            index: streamIndex,
            type: streamType,
            codec: streamType == .video ? "h264" : "aac",
            language: nil,
            bitrate: nil,
            duration: asset.duration.seconds,
            metadata: [:]
        )
        
        return StreamExtractionResult(
            streamInfo: streamInfo,
            outputPath: outputPath,
            fileSize: fileSize,
            processingTime: processingTime
        )
    }
    
    /// Extract subtitles from a container
    /// - Parameters:
    ///   - containerURL: URL of the source container
    ///   - outputPath: Output directory for subtitle files
    ///   - progress: Progress callback
    /// - Returns: Array of subtitle file paths
    /// - Throws: Extraction errors
    internal func extractSubtitles(
        from containerURL: URL,
        outputPath: String,
        progress: ((Double) -> Void)? = nil
    ) async throws -> [String] {
        // In a real implementation, this would use FFmpeg or similar to extract subtitles
        // For now, we'll simulate subtitle extraction
        
        await MainActor.run {
            progress?(0.5)
        }
        
        // Simulate processing time
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Create a dummy subtitle file for demonstration
        let subtitlePath = (outputPath as NSString).appendingPathComponent("subtitle.srt")
        let dummySubtitle = "1\n00:00:00,000 --> 00:00:01,000\nSample subtitle text\n"
        
        try dummySubtitle.write(toFile: subtitlePath, atomically: true, encoding: .utf8)
        
        await MainActor.run {
            progress?(1.0)
        }
        
        return [subtitlePath]
    }
    
    /// Get available subtitle tracks
    /// - Parameter containerURL: URL of the container
    /// - Returns: Array of SubtitleInfo
    /// - Throws: Analysis errors
    internal func getSubtitleTracks(from containerURL: URL) async throws -> [SubtitleInfo] {
        // In a real implementation, this would analyze the container for subtitle tracks
        // For now, return empty array
        return []
    }
}

/// MediaContainer specific errors
public enum MediaContainerError: LocalizedError, Sendable {
    case unsupportedFormat(String)
    case invalidStream(String)
    case extractionFailed(String)
    case analysisFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let message):
            return "Unsupported format: \(message)"
        case .invalidStream(let message):
            return "Invalid stream: \(message)"
        case .extractionFailed(let message):
            return "Extraction failed: \(message)"
        case .analysisFailed(let message):
            return "Analysis failed: \(message)"
        }
    }
}
