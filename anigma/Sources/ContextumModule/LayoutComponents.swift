import Foundation

/// Metadata describing the layout properties of a chunk.
public struct ChunkLayoutMetadata: Sendable, Codable {
    public let pageIndex: Int
    public let segmentType: String
    public let boundingBox: [Double] // [left, top, right, bottom]
    public let confidence: Double
    
    public init(pageIndex: Int, segmentType: String, boundingBox: [Double], confidence: Double) {
        self.pageIndex = pageIndex
        self.segmentType = segmentType
        self.boundingBox = boundingBox
        self.confidence = confidence
    }
}
