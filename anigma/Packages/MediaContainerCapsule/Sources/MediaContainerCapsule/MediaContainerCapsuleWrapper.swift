import Foundation
import AnigmaNativeShims
import AnigmaPrimitives
import CapsuleCore

// Static error message constants to ensure proper lifetime management
private let invalidHandleMsg = "Invalid capsule handle"
private let analysisFailedMsg = "Media analysis failed"
private let invalidFileMsg = "Invalid file path or data"
private let extractionFailedMsg = "Stream extraction failed"

// Helper to create error messages with static string pointers
private func createError(code: anigma_status_t, message: UnsafePointer<CChar>?, detail: UnsafePointer<CChar>? = nil, aux: UInt64 = 0) -> anigma_capsule_error_t {
    return anigma_capsule_error_t(
        code: code,
        message: message,
        detail: detail,
        aux: aux
    )
}

// Helper with string parameter that converts to static pointer
private func createError(code: anigma_status_t, message: String, detail: String? = nil, aux: UInt64 = 0) -> anigma_capsule_error_t {
    switch message {
    case "Invalid capsule handle":
        return createError(code: code, message: invalidHandleMsg, detail: detail, aux: aux)
    case "Media analysis failed":
        return createError(code: code, message: analysisFailedMsg, detail: detail, aux: aux)
    case "Invalid file path or data":
        return createError(code: code, message: invalidFileMsg, detail: detail, aux: aux)
    case "Stream extraction failed":
        return createError(code: code, message: extractionFailedMsg, detail: detail, aux: aux)
    default:
        return message.withCString { messagePtr in
            let staticPtr = UnsafePointer<CChar>(messagePtr)
            if let detail = detail {
                return detail.withCString { detailPtr in
                    let staticDetail = UnsafePointer<CChar>(detailPtr)
                    return createError(code: code, message: staticPtr, detail: staticDetail, aux: aux)
                }
            } else {
                return createError(code: code, message: staticPtr, detail: nil, aux: aux)
            }
        }
    }
}

/// Media stream types
public enum MediaStreamType: UInt32, CaseIterable, Sendable {
    case unknown = 0
    case video = 1
    case audio = 2
    case subtitle = 3
    case data = 4
    case attachment = 5
    
    var cValue: anigma_media_stream_type_t {
        switch self {
        case .unknown: return ANIGMA_MEDIA_STREAM_UNKNOWN
        case .video: return ANIGMA_MEDIA_STREAM_VIDEO
        case .audio: return ANIGMA_MEDIA_STREAM_AUDIO
        case .subtitle: return ANIGMA_MEDIA_STREAM_SUBTITLE
        case .data: return ANIGMA_MEDIA_STREAM_DATA
        case .attachment: return ANIGMA_MEDIA_STREAM_ATTACHMENT
        }
    }
}

/// Video codec types
public enum VideoCodec: UInt32, CaseIterable, Sendable {
    case unknown = 0
    case h264 = 1
    case h265 = 2
    case vp9 = 3
    case av1 = 4
    case mpeg2 = 5
    case mpeg4 = 6
    case vc1 = 7
    case theora = 8
    
    var cValue: anigma_video_codec_t {
        switch self {
        case .unknown: return ANIGMA_VIDEO_CODEC_UNKNOWN
        case .h264: return ANIGMA_VIDEO_CODEC_H264
        case .h265: return ANIGMA_VIDEO_CODEC_H265
        case .vp9: return ANIGMA_VIDEO_CODEC_VP9
        case .av1: return ANIGMA_VIDEO_CODEC_AV1
        case .mpeg2: return ANIGMA_VIDEO_CODEC_MPEG2
        case .mpeg4: return ANIGMA_VIDEO_CODEC_MPEG4
        case .vc1: return ANIGMA_VIDEO_CODEC_VC1
        case .theora: return ANIGMA_VIDEO_CODEC_THEORA
        }
    }
}

/// Audio codec types
public enum AudioCodec: UInt32, CaseIterable, Sendable {
    case unknown = 0
    case aac = 1
    case mp3 = 2
    case opus = 3
    case vorbis = 4
    case flac = 5
    case pcmS16LE = 6
    case pcmF32LE = 7
    
    var cValue: anigma_audio_codec_t {
        switch self {
        case .unknown: return ANIGMA_AUDIO_CODEC_UNKNOWN
        case .aac: return ANIGMA_AUDIO_CODEC_AAC
        case .mp3: return ANIGMA_AUDIO_CODEC_MP3
        case .opus: return ANIGMA_AUDIO_CODEC_OPUS
        case .vorbis: return ANIGMA_AUDIO_CODEC_VORBIS
        case .flac: return ANIGMA_AUDIO_CODEC_FLAC
        case .pcmS16LE: return ANIGMA_AUDIO_CODEC_PCM_S16LE
        case .pcmF32LE: return ANIGMA_AUDIO_CODEC_PCM_F32LE
        }
    }
}

/// Container format types
public enum ContainerType: UInt32, CaseIterable, Sendable {
    case unknown = 0
    case mp4 = 1
    case matroska = 2
    case avi = 3
    case mov = 4
    case webm = 5
    case mpegTS = 6
    case flv = 7
    case ogg = 8
    
    var cValue: anigma_container_type_t {
        switch self {
        case .unknown: return ANIGMA_CONTAINER_UNKNOWN
        case .mp4: return ANIGMA_CONTAINER_MP4
        case .matroska: return ANIGMA_CONTAINER_MATROSKA
        case .avi: return ANIGMA_CONTAINER_AVI
        case .mov: return ANIGMA_CONTAINER_MOV
        case .webm: return ANIGMA_CONTAINER_WEBM
        case .mpegTS: return ANIGMA_CONTAINER_MPEG_TS
        case .flv: return ANIGMA_CONTAINER_FLV
        case .ogg: return ANIGMA_CONTAINER_OGG
        }
    }
}

/// Video stream information
public struct VideoStreamInfo: Sendable {
    public var codec: VideoCodec
    public var width: UInt32
    public var height: UInt32
    public var frameRate: (num: UInt32, den: UInt32)
    public var timeBase: (num: UInt32, den: UInt32)
    public var durationUs: UInt64       // Duration in microseconds
    public var bitRate: UInt32
    public var frameCount: UInt32
    public var codecProfile: String
    public var codecLevel: String
    
    public init(
        codec: VideoCodec,
        width: UInt32,
        height: UInt32,
        frameRate: (num: UInt32, den: UInt32),
        timeBase: (num: UInt32, den: UInt32),
        durationUs: UInt64,
        bitRate: UInt32,
        frameCount: UInt32,
        codecProfile: String,
        codecLevel: String
    ) {
        self.codec = codec
        self.width = width
        self.height = height
        self.frameRate = frameRate
        self.timeBase = timeBase
        self.durationUs = durationUs
        self.bitRate = bitRate
        self.frameCount = frameCount
        self.codecProfile = codecProfile
        self.codecLevel = codecLevel
    }
}

/// Audio stream information
public struct AudioStreamInfo: Sendable {
    public var codec: AudioCodec
    public var sampleRate: UInt32
    public var channels: UInt32
    public var bitsPerSample: UInt32
    public var durationUs: UInt64       // Duration in microseconds
    public var bitRate: UInt32
    public var language: String
    public var blockAlign: UInt32
    
    public init(
        codec: AudioCodec,
        sampleRate: UInt32,
        channels: UInt32,
        bitsPerSample: UInt32,
        durationUs: UInt64,
        bitRate: UInt32,
        language: String,
        blockAlign: UInt32
    ) {
        self.codec = codec
        self.sampleRate = sampleRate
        self.channels = channels
        self.bitsPerSample = bitsPerSample
        self.durationUs = durationUs
        self.bitRate = bitRate
        self.language = language
        self.blockAlign = blockAlign
    }
}

/// General stream information
public struct StreamInfo: Sendable {
    public var type: MediaStreamType
    public var index: UInt32
    public var language: String            // For audio/subtitle streams
    public var title: String             // Stream title
    public var durationUs: UInt64        // Duration in microseconds
    public var bitRate: UInt32
    
    public init(
        type: MediaStreamType,
        index: UInt32,
        language: String,
        title: String,
        durationUs: UInt64,
        bitRate: UInt32
    ) {
        self.type = type
        self.index = index
        self.language = language
        self.title = title
        self.durationUs = durationUs
        self.bitRate = bitRate
    }
}

/// Complete media container analysis report
public struct MediaContainerReport: Sendable {
    public var containerType: ContainerType
    public var streams: [StreamInfo]
    public var totalDurationUs: UInt64   // Total duration in microseconds
    public var fileSizeBytes: UInt64
    public var title: String
    public var artist: String
    public var album: String
    public var date: String
    public var encoder: String
    public var metadataHash: UInt64      // BLAKE3 hash of metadata for determinism
    
    public init(
        containerType: ContainerType,
        streams: [StreamInfo],
        totalDurationUs: UInt64,
        fileSizeBytes: UInt64,
        title: String,
        artist: String,
        album: String,
        date: String,
        encoder: String,
        metadataHash: UInt64
    ) {
        self.containerType = containerType
        self.streams = streams
        self.totalDurationUs = totalDurationUs
        self.fileSizeBytes = fileSizeBytes
        self.title = title
        self.artist = artist
        self.album = album
        self.date = date
        self.encoder = encoder
        self.metadataHash = metadataHash
    }
}

/// Analysis flags for media container processing
public struct MediaAnalysisFlags: OptionSet, Sendable {
    public let rawValue: UInt32
    
    public static let extractVideoInfo = MediaAnalysisFlags(rawValue: 1 << 0)
    public static let extractAudioInfo = MediaAnalysisFlags(rawValue: 1 << 1)
    public static let extractMetadata = MediaAnalysisFlags(rawValue: 1 << 2)
    public static let validateContainers = MediaAnalysisFlags(rawValue: 1 << 3)
    public static let enableProfiling = MediaAnalysisFlags(rawValue: 1 << 4)
    public static let extractSubtitles = MediaAnalysisFlags(rawValue: 1 << 5)
    public static let extractAttachments = MediaAnalysisFlags(rawValue: 1 << 6)
    public static let deepScan = MediaAnalysisFlags(rawValue: 1 << 7)
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
}

/// Configuration for media container analysis
public struct MediaContainerConfig: Sendable {
    public var determinismTier: UInt32         // 1 = bitwise, 2 = epsilon-stable
    public var maxStreamCount: UInt32         // Maximum number of streams to analyze
    public var analysisFlags: MediaAnalysisFlags // Flags for analysis options
    public var maxFileSizeBytes: UInt64        // Maximum file size to process
    public var maxDurationSeconds: Double      // Maximum duration to process
    
    public static var `default`: MediaContainerConfig {
        return MediaContainerConfig(
            determinismTier: 1,
            maxStreamCount: 16,
            analysisFlags: [.extractVideoInfo, .extractAudioInfo, .extractMetadata],
            maxFileSizeBytes: 2_147_483_648,  // 2GB
            maxDurationSeconds: 3600.0            // 1 hour
        )
    }
    
    public init(
        determinismTier: UInt32 = 1,
        maxStreamCount: UInt32 = 16,
        analysisFlags: MediaAnalysisFlags = [.extractVideoInfo, .extractAudioInfo, .extractMetadata],
        maxFileSizeBytes: UInt64 = 2_147_483_648,
        maxDurationSeconds: Double = 3600.0
    ) {
        self.determinismTier = determinismTier
        self.maxStreamCount = maxStreamCount
        self.analysisFlags = analysisFlags
        self.maxFileSizeBytes = maxFileSizeBytes
        self.maxDurationSeconds = maxDurationSeconds
    }
    
    internal func toCStruct() -> anigma_media_container_config_t {
        return anigma_media_container_config_t(
            determinism_tier: determinismTier,
            max_stream_count: maxStreamCount,
            analysis_flags: analysisFlags.rawValue,
            max_file_size_bytes: maxFileSizeBytes,
            max_duration_seconds: maxDurationSeconds
        )
    }
}

/// Swift wrapper for media container analysis capsule.
/// Provides media inspection without UI dependencies, supporting FFmpeg-based analysis.
public final class MediaContainerCapsuleWrapper {
    /// Capsule identity information.
    public static var identity: anigma_capsule_identity_t {
        anigma_media_container_capsule_get_identity()
    }
    
    private var handle: CapsuleHandle<AnyObject>?
    private let config: MediaContainerConfig
    private let lock = NSLock()
    
    /// Configuration used by this capsule.
    public var configuration: MediaContainerConfig { config }
    
    /// Create a media container capsule with the given configuration.
    /// - Parameter config: Configuration for media analysis
    public init(config: MediaContainerConfig = .default) throws {
        var rawHandle: anigma_media_container_capsule_t?
        var error = anigma_capsule_error_t()
        
        let cConfig = config.toCStruct()
        let status = anigma_media_container_capsule_create(&cConfig, &rawHandle, &error)
        guard status == ANIGMA_OK, let rawHandle = rawHandle else {
            throw CapsuleError(status: status, error: error)
        }
        
        self.handle = CapsuleHandle<AnyObject>(
            rawHandle: rawHandle,
            destroyFunction: anigma_media_container_capsule_destroy
        )
        self.config = config
    }
    
    deinit {
        lock.withLock {
            handle?.invalidate()
        }
    }
    
    /// Analyze media container from file path.
    /// - Parameter filePath: Path to media file
    /// - Returns: Complete media container report
    public func analyzeFile(at filePath: URL) throws -> MediaContainerReport {
        var report = anigma_media_container_report_t()
        var error = anigma_capsule_error_t()
        
        return try handle?.withHandle { rawHandle in
            let status = filePath.path.withCString { pathPtr in
                anigma_media_container_capsule_analyze_file(rawHandle, pathPtr, &report, &error)
            }
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: error)
            }
            
            return convertFromCReport(report)
        } ?? MediaContainerReport(containerType: .unknown, streams: [], totalDurationUs: 0, fileSizeBytes: 0, title: "", artist: "", album: "", date: "", encoder: "", metadataHash: 0)
    }
    
    /// Analyze media container from memory buffer.
    /// - Parameter data: Media file data in memory
    /// - Returns: Complete media container report
    public func analyzeBuffer(_ data: Data) throws -> MediaContainerReport {
        var report = anigma_media_container_report_t()
        var error = anigma_capsule_error_t()
        
        return try handle?.withHandle { rawHandle in
            let status = data.withUnsafeBytes { bytes in
                anigma_media_container_capsule_analyze_buffer(
                    rawHandle,
                    bytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    data.count,
                    &report,
                    &error
                )
            }
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: error)
            }
            
            return convertFromCReport(report)
        } ?? MediaContainerReport(containerType: .unknown, streams: [], totalDurationUs: 0, fileSizeBytes: 0, title: "", artist: "", album: "", date: "", encoder: "", metadataHash: 0)
    }
    
    /// Get detailed information for a specific video stream.
    /// - Parameters:
    ///   - streamIndex: Index of the video stream
    /// - Returns: Detailed video stream information
    public func getVideoStreamInfo(at streamIndex: UInt32) throws -> VideoStreamInfo? {
        var videoInfo = anigma_video_stream_info_t()
        var error = anigma_capsule_error_t()
        
        return try handle?.withHandle { rawHandle in
            let status = anigma_media_container_capsule_get_video_stream_info(
                rawHandle, streamIndex, &videoInfo, &error
            )
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: error)
            }
            
            return convertFromCVideoInfo(videoInfo)
        } ?? nil
    }
    
    /// Get detailed information for a specific audio stream.
    /// - Parameters:
    ///   - streamIndex: Index of the audio stream
    /// - Returns: Detailed audio stream information
    public func getAudioStreamInfo(at streamIndex: UInt32) throws -> AudioStreamInfo? {
        var audioInfo = anigma_audio_stream_info_t()
        var error = anigma_capsule_error_t()
        
        return try handle?.withHandle { rawHandle in
            let status = anigma_media_container_capsule_get_audio_stream_info(
                rawHandle, streamIndex, &audioInfo, &error
            )
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: error)
            }
            
            return convertFromCAudioInfo(audioInfo)
        } ?? nil
    }
    
    /// Extract thumbnail from a video stream.
    /// - Parameters:
    ///   - streamIndex: Index of the video stream
    ///   - maxWidth: Maximum width of thumbnail
    ///   - maxHeight: Maximum height of thumbnail
    /// - Returns: JPEG image data for thumbnail
    public func extractThumbnail(
        from streamIndex: UInt32,
        maxWidth: UInt32 = 320,
        maxHeight: UInt32 = 240
    ) throws -> Data {
        var buffer = anigma_capsule_buffer_t()
        var error = anigma_capsule_error_t()
        
        return try handle?.withHandle { rawHandle in
            // Query required size
            let queryStatus = anigma_media_container_capsule_extract_thumbnail(
                rawHandle, streamIndex, maxWidth, maxHeight, &buffer, &error
            )
            
            guard queryStatus == ANIGMA_ERR_BUFFER_TOO_SMALL else {
                throw CapsuleError(status: queryStatus, error: error)
            }
            
            let requiredSize = Int(error.aux)
            let outputData = Data(count: requiredSize)
            buffer.ptr = outputData.withUnsafeMutableBytes { $0.baseAddress?.assumingMemoryBound(to: UInt8.self) }
            buffer.cap = requiredSize
            
            // Fill buffer
            let fillStatus = anigma_media_container_capsule_extract_thumbnail(
                rawHandle, streamIndex, maxWidth, maxHeight, &buffer, &error
            )
            
            guard fillStatus == ANIGMA_OK else {
                throw CapsuleError(status: fillStatus, error: error)
            }
            
            return outputData
        } ?? Data()
    }
    
    /// Validate media container format.
    /// - Parameter filePath: Path to media file
    /// - Returns: True if container is valid and supported
    public func validateContainer(at filePath: URL) throws -> Bool {
        var isValid: UInt8 = 0
        var error = anigma_capsule_error_t()
        
        return try handle?.withHandle { rawHandle in
            let status = filePath.path.withCString { pathPtr in
                anigma_media_container_capsule_validate_container(rawHandle, pathPtr, &isValid, &error)
            }
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: error)
            }
            
            return isValid != 0
        } ?? false
    }
    
    // MARK: - Private Helper Methods
    
    private func convertFromCReport(_ cReport: anigma_media_container_report_t) -> MediaContainerReport {
        var streams: [StreamInfo] = []
        
        if let streamsPtr = cReport.streams {
            for i in 0..<cReport.stream_count {
                let cStream = streamsPtr.advanced(by: Int(i)).pointee
                let stream = StreamInfo(
                    type: MediaStreamType(rawValue: cStream.type) ?? .unknown,
                    index: cStream.index,
                    language: String(cString: cStream.language),
                    title: String(cString: cStream.title),
                    durationUs: cStream.duration_us,
                    bitRate: cStream.bit_rate
                )
                streams.append(stream)
            }
        }
        
        return MediaContainerReport(
            containerType: ContainerType(rawValue: cReport.container_type) ?? .unknown,
            streams: streams,
            totalDurationUs: cReport.total_duration_us,
            fileSizeBytes: cReport.file_size_bytes,
            title: String(cString: cReport.title),
            artist: String(cString: cReport.artist),
            album: String(cString: cReport.album),
            date: String(cString: cReport.date),
            encoder: String(cString: cReport.encoder),
            metadataHash: cReport.metadata_hash
        )
    }
    
    private func convertFromCVideoInfo(_ cInfo: anigma_video_stream_info_t) -> VideoStreamInfo {
        return VideoStreamInfo(
            codec: VideoCodec(rawValue: cInfo.codec) ?? .unknown,
            width: cInfo.width,
            height: cInfo.height,
            frameRate: (num: cInfo.frame_rate.num, den: cInfo.frame_rate.den),
            timeBase: (num: cInfo.time_base.num, den: cInfo.time_base.den),
            durationUs: cInfo.duration_us,
            bitRate: cInfo.bit_rate,
            frameCount: cInfo.frame_count,
            codecProfile: String(cString: cInfo.codec_profile),
            codecLevel: String(cString: cInfo.codec_level)
        )
    }
    
    private func convertFromCAudioInfo(_ cInfo: anigma_audio_stream_info_t) -> AudioStreamInfo {
        return AudioStreamInfo(
            codec: AudioCodec(rawValue: cInfo.codec) ?? .unknown,
            sampleRate: cInfo.sample_rate,
            channels: cInfo.channels,
            bitsPerSample: cInfo.bits_per_sample,
            durationUs: cInfo.duration_us,
            bitRate: cInfo.bit_rate,
            language: String(cString: cInfo.language),
            blockAlign: cInfo.block_align
        )
    }
}