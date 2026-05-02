import Foundation
import AnigmaNativeShims

/// Configuration for text chunking strategies.
public struct TextChunkingConfig: Sendable, Codable {
    public var targetChunkSize: Int
    public var minChunkSize: Int
    public var maxChunkSize: Int
    public var windowSize: Int
    public var polynomial: UInt64
    public var determinismTier: UInt32
    
    public init(
        targetChunkSize: Int = 1024,
        minChunkSize: Int = 512,
        maxChunkSize: Int = 4096,
        windowSize: Int = 48,
        polynomial: UInt64 = 0x3DA3358B4DC173,
        determinismTier: UInt32 = 1
    ) {
        self.targetChunkSize = targetChunkSize
        self.minChunkSize = minChunkSize
        self.maxChunkSize = maxChunkSize
        self.windowSize = windowSize
        self.polynomial = polynomial
        self.determinismTier = determinismTier
    }
}
