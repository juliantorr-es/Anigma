import Foundation

public struct IndexStatusComponent: Codable, Hashable, Sendable {
    public let sourceId: String
    public let indexType: IndexType
    public let status: Status
    public let lastUpdated: Date
    public let documentCount: Int
    public let errorMessage: String?

    public enum IndexType: String, Codable, Sendable {
        case fullText
        case semantic
        case hybrid
    }

    public enum Status: String, Codable, Sendable {
        case pending
        case indexing
        case ready
        case failed
        case stale
    }

    public init(
        sourceId: String,
        indexType: IndexType,
        status: Status,
        lastUpdated: Date = Date(),
        documentCount: Int = 0,
        errorMessage: String? = nil
    ) {
        self.sourceId = sourceId
        self.indexType = indexType
        self.status = status
        self.lastUpdated = lastUpdated
        self.documentCount = documentCount
        self.errorMessage = errorMessage
    }
}
