import Foundation
import CapsuleCore
import AnigmaNativeShims

public final class MediaContainerCapsuleWrapper: @unchecked Sendable {
    public enum VideoCodec: UInt32, Sendable {
        case h264 = 0
        case h265 = 1
        case vp9 = 2
        case av1 = 3
        case mpeg2 = 4
        case mpeg4 = 5
        case vc1 = 6
        case theora = 7
        case unknown = 0xFFFFFFFF
    }

    public enum AudioCodec: UInt32, Sendable {
        case aac = 0
        case mp3 = 1
        case opus = 2
        case vorbis = 3
        case flac = 4
        case pcmS16LE = 5
        case pcmF32LE = 6
        case unknown = 0xFFFFFFFF
    }

    private let handle: CapsuleHandle<AnyObject>
    
    public init(config: MediaContainerConfig) throws {
        var rawHandle: anigma_media_container_capsule_t?
        var error = anigma_capsule_error_t()
        var cConfig = config.toCStruct()
        
        let status = anigma_media_container_capsule_create(&cConfig, &rawHandle, &error)
        guard status == ANIGMA_OK, let finalHandle = rawHandle else {
            throw capsuleError(status: status, error: error)
        }
        
        self.handle = CapsuleHandle<AnyObject>(
            rawHandle: finalHandle,
            destroyFunction: { ptr in
                var mutablePtr: anigma_media_container_capsule_t? = ptr
                var err = anigma_capsule_error_t()
                _ = anigma_media_container_capsule_destroy(&mutablePtr, &err)
            }
        )
    }

    private var rawHandle: anigma_media_container_capsule_t {
        // Safe because the closure is synchronous and only used internally
        unsafeBitCast(handle, to: UnsafeMutableRawPointer.self) 
        // Wait, handle.rawHandle is private in CapsuleHandle. 
        // I should use handle.withHandle { ... }
        fatalError("Use withHandle instead")
    }

    public func analyzeFile(at url: URL) throws -> MediaContainerReport {
        try handle.withHandle { h in
            var report = anigma_media_container_report_t()
            var error = anigma_capsule_error_t()
            
            let status = anigma_media_container_capsule_analyze_file(h, url.path, &report, &error)
            guard status == ANIGMA_OK else {
                throw capsuleError(status: status, error: error)
            }
            
            defer {
                var mutableReport = report
                _ = anigma_media_container_capsule_free_report(h, &mutableReport, &error)
            }
            
            return MediaContainerReport(from: report)
        }
    }

    public func getVideoStreamInfo(at index: UInt32) throws -> VideoStreamInfo {
        try handle.withHandle { h in
            var info = anigma_video_stream_info_t()
            var error = anigma_capsule_error_t()
            
            let status = anigma_media_container_capsule_get_video_stream_info(h, index, &info, &error)
            guard status == ANIGMA_OK else {
                throw capsuleError(status: status, error: error)
            }
            
            return VideoStreamInfo(from: info)
        }
    }

    public func getAudioStreamInfo(at index: UInt32) throws -> AudioStreamInfo {
        try handle.withHandle { h in
            var info = anigma_audio_stream_info_t()
            var error = anigma_capsule_error_t()
            
            let status = anigma_media_container_capsule_get_audio_stream_info(h, index, &info, &error)
            guard status == ANIGMA_OK else {
                throw capsuleError(status: status, error: error)
            }
            
            return AudioStreamInfo(from: info)
        }
    }
}

public struct MediaContainerConfig: Sendable, Codable {
    public var determinismTier: UInt32 = 1
    public var maxStreamCount: UInt32 = 32
    public var analysisFlags: UInt32 = 0
    public var maxFileSizeBytes: UInt64 = 0
    public var maxDurationSeconds: Double = 0

    public init() {}

    internal func toCStruct() -> anigma_media_container_config_t {
        anigma_media_container_config_t(
            determinism_tier: determinismTier,
            max_stream_count: maxStreamCount,
            analysis_flags: analysisFlags,
            max_file_size_bytes: maxFileSizeBytes,
            max_duration_seconds: maxDurationSeconds
        )
    }
}

public struct MediaContainerReport: Sendable {
    public let containerType: ContainerType
    public let streamCount: UInt32
    public let streams: [CStreamInfo]
    public let totalDurationUs: UInt64
    public let fileSizeData: UInt64
    public let title: String
    
    internal init(from cReport: anigma_media_container_report_t) {
        self.containerType = ContainerType(rawValue: cReport.container_type.rawValue) ?? .unknown
        self.streamCount = cReport.stream_count
        self.totalDurationUs = cReport.total_duration_us
        self.fileSizeData = cReport.file_size_bytes
        // Correct way to handle fixed-size C char arrays in Swift
        self.title = withUnsafePointer(to: cReport.title) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: 256) { String(cString: $0) }
        }
        
        var streams: [CStreamInfo] = []
        if let cStreams = cReport.streams {
            for i in 0..<Int(cReport.stream_count) {
                streams.append(CStreamInfo(from: cStreams[i]))
            }
        }
        self.streams = streams
    }
}

public enum ContainerType: UInt32, Sendable {
    case unknown = 0
    case mp4 = 1
    case matroska = 2
}

public struct CStreamInfo: Sendable {
    public let type: MediaStreamType
    public let index: UInt32
    
    internal init(from cInfo: anigma_stream_info_t) {
        self.type = MediaStreamType(rawValue: cInfo.type.rawValue) ?? .unknown
        self.index = cInfo.index
    }
}

public enum MediaStreamType: UInt32, Sendable {
    case unknown = 0
    case video = 1
    case audio = 2
}

public struct VideoStreamInfo: Sendable {
    public let codec: VideoCodec
    public let width: UInt32
    public let height: UInt32
    public let frameRate: Rational
    public let sampleRate: UInt32 = 48000 // Placeholder
    public let bitRate: UInt64

    internal init(from cInfo: anigma_video_stream_info_t) {
        self.codec = VideoCodec(rawValue: cInfo.codec.rawValue) ?? .unknown
        self.width = cInfo.width
        self.height = cInfo.height
        self.frameRate = Rational(num: cInfo.frame_rate.num, den: cInfo.frame_rate.den)
        self.bitRate = UInt64(cInfo.bit_rate)
    }
}

public struct AudioStreamInfo: Sendable {
    public let codec: AudioCodec
    public let sampleRate: Double
    public let channels: UInt32
    public let bitRate: UInt64

    internal init(from cInfo: anigma_audio_stream_info_t) {
        self.codec = AudioCodec(rawValue: cInfo.codec.rawValue) ?? .unknown
        self.sampleRate = Double(cInfo.sample_rate)
        self.channels = cInfo.channels
        self.bitRate = UInt64(cInfo.bit_rate)
    }
}

public struct Rational: Sendable {
    public let num: UInt32
    public let den: UInt32
}

public enum VideoCodec: UInt32, Sendable {
    case unknown = 0
    case h264 = 1
    case h265 = 2
    case vp9 = 3
    case av1 = 4
    case mpeg2 = 5
    case mpeg4 = 6
    case vc1 = 7
    case theora = 8
}

public enum AudioCodec: UInt32, Sendable {
    case unknown = 0
    case aac = 1
    case mp3 = 2
    case opus = 3
    case vorbis = 4
    case flac = 5
    case pcmS16LE = 6
    case pcmF32LE = 7
}

private func capsuleError(status: anigma_status_t, error: anigma_capsule_error_t) -> CapsuleNativeError {
    let message = error.message.map { String(cString: $0) } ?? "Capsule error"
    return CapsuleNativeError(status: status, code: error.code, message: message)
}
