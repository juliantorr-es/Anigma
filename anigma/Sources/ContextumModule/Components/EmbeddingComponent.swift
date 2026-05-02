import Foundation

public struct EmbeddingComponent: Codable, Hashable, Sendable {
    public let embeddingId: String
    public let chunkHash: String
    public let modelHash: String
    public let modelId: String
    public let vectorDimensions: Int
    public let receiptId: String
    public let timestamp: Date

    public init(
        embeddingId: String,
        chunkHash: String,
        modelHash: String,
        modelId: String,
        vectorDimensions: Int,
        receiptId: String,
        timestamp: Date = Date()
    ) {
        self.embeddingId = embeddingId
        self.chunkHash = chunkHash
        self.modelHash = modelHash
        self.modelId = modelId
        self.vectorDimensions = vectorDimensions
        self.receiptId = receiptId
        self.timestamp = timestamp
    }
}
