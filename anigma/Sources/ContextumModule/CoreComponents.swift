import Foundation

/// A report detailing a system or processing failure.
public struct FailureReport: Sendable, Codable {
    public let reportID: UUID
    public let receiptID: String
    public let runID: String
    public let error: String
    public let timestamp: Date
    
    public init(reportID: UUID = UUID(), receiptID: String, runID: String, error: String, timestamp: Date = Date()) {
        self.reportID = reportID
        self.receiptID = receiptID
        self.runID = runID
        self.error = error
        self.timestamp = timestamp
    }
}

/// Component tracking the status of indexing operations.
public struct ContextIndexStatusComponent: Sendable, Codable {
    public enum IndexType: String, Sendable, Codable {
        case fts
        case vector
        case spatial
    }
    
    public enum Status: String, Sendable, Codable {
        case pending
        case inProgress
        case completed
        case failed
    }
    
    public let sourceId: String
    public let indexType: IndexType
    public let status: Status
    public let lastUpdated: Date
    public let documentCount: Int32
    public let errorMessage: String?
    
    public init(sourceId: String, indexType: IndexType, status: Status, lastUpdated: Date = Date(), documentCount: Int32 = 0, errorMessage: String? = nil) {
        self.sourceId = sourceId
        self.indexType = indexType
        self.status = status
        self.lastUpdated = lastUpdated
        self.documentCount = documentCount
        self.errorMessage = errorMessage
    }
}
