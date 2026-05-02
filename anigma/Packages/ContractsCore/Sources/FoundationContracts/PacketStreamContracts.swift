import Foundation
import AnigmaPrimitives

/// Unique identifier for a live packet stream registered in PacketStreamAuthority.
public struct PacketStreamToken: Hashable, Sendable, Codable {
    public let rawValue: UUID
    
    public init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

/// A portable reference to a compressed media packet stream.
/// Used to bridge raw bitstreams to hardware decoders.
public struct PacketStreamReference: Sendable, Codable, Hashable {
    public let token: PacketStreamToken
    public let codec: String // e.g., "h264", "aac"
    public let mediaType: String // e.g., "video", "audio"
    public let bitRate: Int?
    public let timestamp: Date
    
    public init(
        token: PacketStreamToken,
        codec: String,
        mediaType: String,
        bitRate: Int? = nil,
        timestamp: Date = Date()
    ) {
        self.token = token
        self.codec = codec
        self.mediaType = mediaType
        self.bitRate = bitRate
        self.timestamp = timestamp
    }
}
