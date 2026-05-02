import Foundation
import AnigmaPrimitives

/// Unique identifier for a live audio buffer registered in AudioBufferAuthority.
public struct AudioBufferToken: Hashable, Sendable, Codable {
    public let rawValue: UUID
    
    public init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

/// A portable handle to a live audio buffer.
/// Contains format metadata but no raw sample data.
public struct AudioBufferReference: Sendable, Codable, Hashable {
    public let token: AudioBufferToken
    public let sampleRate: Double
    public let channels: Int
    public let frameCount: Int
    public let format: String // e.g. "pcm_f32", "aac"
    
    public init(
        token: AudioBufferToken,
        sampleRate: Double,
        channels: Int,
        frameCount: Int,
        format: String
    ) {
        self.token = token
        self.sampleRate = sampleRate
        self.channels = channels
        self.frameCount = frameCount
        self.format = format
    }
}

/// An audit record proving that an audio operation maintained zero-copy continuity.
public struct AudioZeroCopyProof: Sendable, Codable {
    public let token: AudioBufferToken
    public let copiedBytes: Int64
    public let timestamp: Date
    
    public init(
        token: AudioBufferToken,
        copiedBytes: Int64 = 0,
        timestamp: Date = Date()
    ) {
        self.token = token
        self.copiedBytes = copiedBytes
        self.timestamp = timestamp
    }
    
    public var isPerfect: Bool {
        return copiedBytes == 0
    }
}
