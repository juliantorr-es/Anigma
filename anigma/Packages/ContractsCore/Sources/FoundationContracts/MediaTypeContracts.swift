import Foundation
import AnigmaPrimitives

/// Broad category of media content.
public enum MediaTypeDescriptor: String, Sendable, Codable {
    case video
    case audio
    case image
    case document
    case unknown
}

/// Standardized identifier for a media container format (e.g., "mp4", "mov").
public struct ContainerDescriptor: Hashable, Sendable, Codable {
    public let rawValue: String
    
    public init(_ rawValue: String) {
        self.rawValue = rawValue.lowercased()
    }
    
    public static let mp4 = ContainerDescriptor("mp4")
    public static let mov = ContainerDescriptor("mov")
    public static let m4a = ContainerDescriptor("m4a")
    public static let webm = ContainerDescriptor("webm")
    public static let mkv = ContainerDescriptor("mkv")
    public static let wav = ContainerDescriptor("wav")
    public static let png = ContainerDescriptor("png")
    public static let jpg = ContainerDescriptor("jpg")
    public static let pdf = ContainerDescriptor("pdf")
}

/// Standardized identifier for a media codec (e.g., "h264", "hevc").
public struct CodecDescriptor: Hashable, Sendable, Codable {
    public let rawValue: String
    
    public init(_ rawValue: String) {
        self.rawValue = rawValue.lowercased()
    }
    
    public static let h264 = CodecDescriptor("h264")
    public static let hevc = CodecDescriptor("hevc")
    public static let vp9 = CodecDescriptor("vp9")
    public static let prores = CodecDescriptor("prores")
    public static let aac = CodecDescriptor("aac")
    public static let pcm = CodecDescriptor("pcm")
}

/// Durable file/blob artifact (long-lived, versioned, auditable)
public struct ArtifactReference: Codable, Sendable, Hashable {
    public let id: UUID
    public let mediaType: MediaTypeDescriptor
    public let size: UInt64
    public let hash: String
    public let createdAt: Date
    
    public init(id: UUID, mediaType: MediaTypeDescriptor, size: UInt64, hash: String, createdAt: Date = Date()) {
        self.id = id
        self.mediaType = mediaType
        self.size = size
        self.hash = hash
        self.createdAt = createdAt
    }
}

/// Live still-image surface reference
public struct ImageSurfaceReference: Codable, Sendable, Hashable {
    public let token: SurfaceToken
    public let width: Int
    public let height: Int
    public let format: String
    
    public init(token: SurfaceToken, width: Int, height: Int, format: String) {
        self.token = token
        self.width = width
        self.height = height
        self.format = format
    }
}

/// Unified media reference that wraps all substrate-managed handles.
public enum MediaReference: Codable, Sendable, Hashable {
    case videoFrame(FrameReference)
    case audioBuffer(AudioBufferReference)
    case imageSurface(ImageSurfaceReference)
    case packetStream(PacketStreamReference)
    case artifact(ArtifactReference)
}

/// A bundle combining media type, container, and codec information for routing decisions.
public struct MediaDescriptorBundle: Sendable, Codable {
    public let type: MediaTypeDescriptor
    public let container: ContainerDescriptor
    public let codec: CodecDescriptor?
    public let hardwareDecodingSupported: Bool
    
    public init(
        type: MediaTypeDescriptor,
        container: ContainerDescriptor,
        codec: CodecDescriptor? = nil,
        hardwareDecodingSupported: Bool = false
    ) {
        self.type = type
        self.container = container
        self.codec = codec
        self.hardwareDecodingSupported = hardwareDecodingSupported
    }
}
