import Foundation

/// Represents the status of a client session
public struct ClientSessionStatus: Sendable {
    public let clientId: String
    public let activeRequests: Int
    public let requestsInLastMinute: Int
    public let quotaAvailable: Bool
    public let lastActivityAt: Date
}

/// Per-client session tracking and quota enforcement
public actor MCPClientSession {
    public let clientId: String

    // Configuration
    private let maxConcurrentRequests: Int
    private let maxRequestsPerMinute: Int

    // State
    private var activeRequests: Set<MCPRequestId> = []
    private var requestTimestamps: [Date] = []  // Timestamp of each request in the last minute
    private var lastActivityAt = Date()

    public init(
        clientId: String,
        maxConcurrentRequests: Int = 5,
        maxRequestsPerMinute: Int = 120
    ) {
        self.clientId = clientId
        self.maxConcurrentRequests = maxConcurrentRequests
        self.maxRequestsPerMinute = maxRequestsPerMinute
    }

    /// Attempts to accept a new request for this client
    public func canAcceptRequest() -> Bool {
        // Check concurrent request limit
        guard activeRequests.count < maxConcurrentRequests else {
            return false
        }

        // Check requests-per-minute limit
        let now = Date()
        let oneMinuteAgo = now.addingTimeInterval(-60)

        // Remove old timestamps outside the 1-minute window
        requestTimestamps.removeAll { $0 < oneMinuteAgo }

        // Check if we exceed the rate limit
        guard requestTimestamps.count < maxRequestsPerMinute else {
            return false
        }

        return true
    }

    /// Records a request start
    public func recordRequestStart(_ requestId: MCPRequestId) throws {
        guard canAcceptRequest() else {
            throw MCPClientError.quotaExceeded(clientId: clientId)
        }

        activeRequests.insert(requestId)
        requestTimestamps.append(Date())
        lastActivityAt = Date()
    }

    /// Records a request completion
    public func recordRequestCompletion(_ requestId: MCPRequestId) {
        activeRequests.remove(requestId)
        lastActivityAt = Date()
    }

    /// Gets current session status
    public func getStatus() -> ClientSessionStatus {
        // Remove timestamps older than 1 minute
        let oneMinuteAgo = Date().addingTimeInterval(-60)
        requestTimestamps.removeAll { $0 < oneMinuteAgo }

        return ClientSessionStatus(
            clientId: clientId,
            activeRequests: activeRequests.count,
            requestsInLastMinute: requestTimestamps.count,
            quotaAvailable: canAcceptRequest(),
            lastActivityAt: lastActivityAt
        )
    }

    /// Cleans up stale timestamps
    public func cleanup() {
        let oneMinuteAgo = Date().addingTimeInterval(-60)
        requestTimestamps.removeAll { $0 < oneMinuteAgo }
    }
}

/// Error types for client operations
public enum MCPClientError: Error, Sendable {
    case quotaExceeded(clientId: String)
    case sessionNotFound(clientId: String)
    case requestNotFound(requestId: MCPRequestId)
}
