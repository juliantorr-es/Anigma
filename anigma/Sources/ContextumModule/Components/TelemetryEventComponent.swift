import Foundation

public struct TelemetryEventComponent: Codable, Hashable, Sendable {
    public let eventId: String
    public let eventType: EventType
    public let agentId: String?
    public let jobId: String?
    public let runId: String?
    public let receiptId: String?
    public let timestamp: Date
    public let durationMs: Int?
    public let outcome: Outcome
    public let errorCode: String?
    public let diagnosticPayload: [String: String]

    public enum EventType: String, Codable, Sendable {
        case system
        case ingest
        case chunk
        case embed
        case search
        case toolCall
        case agentExecution
        case capsule
    }

    public enum Outcome: String, Codable, Sendable {
        case success
        case failure
        case timeout
        case cancelled
    }

    public init(
        eventId: String,
        eventType: EventType,
        agentId: String? = nil,
        jobId: String? = nil,
        runId: String? = nil,
        receiptId: String? = nil,
        timestamp: Date = Date(),
        durationMs: Int? = nil,
        outcome: Outcome,
        errorCode: String? = nil,
        diagnosticPayload: [String: String] = [:]
    ) {
        self.eventId = eventId
        self.eventType = eventType
        self.agentId = agentId
        self.jobId = jobId
        self.runId = runId
        self.receiptId = receiptId
        self.timestamp = timestamp
        self.durationMs = durationMs
        self.outcome = outcome
        self.errorCode = errorCode
        self.diagnosticPayload = diagnosticPayload
    }
}
