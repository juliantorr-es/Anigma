import Foundation

public struct ContextSourceComponent: Codable, Hashable, Sendable {
    public let sourceId: String
    public let sourceType: SourceType
    public let artifactHash: String
    public let receiptId: String
    public let timestamp: Date
    public let metadata: [String: String]

    public enum SourceType: String, Codable, Sendable {
        case document
        case conversation
        case toolOutput
        case codebase
        case userInput
    }

    public init(
        sourceId: String,
        sourceType: SourceType,
        artifactHash: String,
        receiptId: String,
        timestamp: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.sourceId = sourceId
        self.sourceType = sourceType
        self.artifactHash = artifactHash
        self.receiptId = receiptId
        self.timestamp = timestamp
        self.metadata = metadata
    }
}
