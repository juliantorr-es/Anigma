import Foundation

/// Core error types for the Anigma ecosystem.
public enum AnigmaError: Error, Codable, Sendable {
    case internalError(String)
    case notFound(String)
    case unauthorized(String)
    case invalidArgument(String)
    case budgetExceeded(String)
}

/// Fundamental protocols for authorities.
public protocol BaseAuthority: Sendable {
    var id: String { get }
}

/// Minimal context for execution.
public struct ExecutionContext: Codable, Sendable {
    public let traceId: UUID
    public let timestamp: Date
    
    public init(traceId: UUID = UUID(), timestamp: Date = Date()) {
        self.traceId = traceId
        self.timestamp = timestamp
    }
}
