import Foundation
import AnigmaPrimitives

/// Base protocol for all governed media transformation contracts.
/// All media contracts MUST return a result containing a proof of zero-copy or accounted-copy continuity.
public protocol MediaContract: WorkflowContract {
    /// The specific media kind this contract operates on.
    var mediaKind: String { get }
}

/// A contract for decoding a compressed video bitstream into a zero-copy frame handle.
public struct VideoDecodeContract: MediaContract {
    public static let id = ContractID(name: "media.video.decode", major: 0, minor: 1, schemaHash: "h264-zero-copy")
    
    public let packetToken: PacketStreamToken
    public let codec: String
    
    public var mediaKind: String { "video" }
    
    public init(packetToken: PacketStreamToken, codec: String) {
        self.packetToken = packetToken
        self.codec = codec
    }
}

/// A contract for scaling a video frame surface.
public struct VideoScaleContract: MediaContract {
    public static let id = ContractID(name: "media.video.scale", major: 0, minor: 1, schemaHash: "metal-gpu-scale")
    
    public let sourceFrame: FrameReference
    public let targetWidth: Int
    public let targetHeight: Int
    
    public var mediaKind: String { "video" }
    
    public init(sourceFrame: FrameReference, targetWidth: Int, targetHeight: Int) {
        self.sourceFrame = sourceFrame
        self.targetWidth = targetWidth
        self.targetHeight = targetHeight
    }
}

/// A contract for encoding a video frame surface into a compressed bitstream packet.
public struct VideoEncodeContract: MediaContract {
    public static let id = ContractID(name: "media.video.encode", major: 0, minor: 1, schemaHash: "videotoolbox-encode")
    
    public let sourceFrame: FrameReference
    public let targetCodec: String
    public let bitRate: Int?
    
    public var mediaKind: String { "video" }
    
    public init(sourceFrame: FrameReference, targetCodec: String, bitRate: Int? = nil) {
        self.sourceFrame = sourceFrame
        self.targetCodec = targetCodec
        self.bitRate = bitRate
    }
}

/// A contract for mixing multiple audio buffers.
public struct AudioMixContract: MediaContract {
    public static let id = ContractID(name: "media.audio.mix", major: 0, minor: 1, schemaHash: "dsp-audio-mix")
    
    public let sourceBuffers: [AudioBufferReference]
    public let outputFormat: String
    
    public var mediaKind: String { "audio" }
    
    public init(sourceBuffers: [AudioBufferReference], outputFormat: String) {
        self.sourceBuffers = sourceBuffers
        self.outputFormat = outputFormat
    }
}

/// A contract for decoding a compressed audio file into a substrate-managed buffer.
public struct AudioDecodeContract: MediaContract {
    public static let id = ContractID(name: "media.audio.decode", major: 0, minor: 1, schemaHash: "audiotoolbox-decode")
    
    public let artifactId: UUID
    public let targetFormat: String
    
    public var mediaKind: String { "audio" }
    
    public init(artifactId: UUID, targetFormat: String) {
        self.artifactId = artifactId
        self.targetFormat = targetFormat
    }
}

/// A contract for decoding a still image.
public struct ImageDecodeContract: MediaContract {
    public static let id = ContractID(name: "media.image.decode", major: 0, minor: 1, schemaHash: "imageio-decode")
    
    public let artifactId: UUID
    public let format: String
    
    public var mediaKind: String { "image" }
    
    public init(artifactId: UUID, format: String) {
        self.artifactId = artifactId
        self.format = format
    }
}
