import Foundation

public struct ChunkComponent: Codable, Hashable, Sendable {
    public let chunkId: String
    public let sourceId: String
    public let contentHash: String
    public let chunkIndex: Int
    public let totalChunks: Int
    public let byteRange: Range<Int>
    public let tokenCount: Int?
    public let timestamp: Date

    public init(
        chunkId: String,
        sourceId: String,
        contentHash: String,
        chunkIndex: Int,
        totalChunks: Int,
        byteRange: Range<Int>,
        tokenCount: Int? = nil,
        timestamp: Date = Date()
    ) {
        self.chunkId = chunkId
        self.sourceId = sourceId
        self.contentHash = contentHash
        self.chunkIndex = chunkIndex
        self.totalChunks = totalChunks
        self.byteRange = byteRange
        self.tokenCount = tokenCount
        self.timestamp = timestamp
    }
}
