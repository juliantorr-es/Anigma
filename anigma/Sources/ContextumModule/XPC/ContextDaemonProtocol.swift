import Foundation

public protocol ContextDaemonProtocol: Sendable {
    func submit(jobEnvelope: JobEnvelope) async throws -> String
    func query(jobId: String) async throws -> JobStatus
}

public struct JobEnvelope: Codable, Sendable {
    public let jobId: String
    public let jobType: String
    public let payload: Data
    public let priority: Int
    public let metadata: [String: String]

    public init(
        jobId: String,
        jobType: String,
        payload: Data,
        priority: Int = 0,
        metadata: [String: String] = [:]
    ) {
        self.jobId = jobId
        self.jobType = jobType
        self.payload = payload
        self.priority = priority
        self.metadata = metadata
    }
}

public struct JobStatus: Codable, Sendable {
    public let jobId: String
    public let state: State
    public let progress: Double
    public let result: Data?
    public let error: String?

    public enum State: String, Codable, Sendable {
        case queued
        case running
        case completed
        case failed
        case cancelled
    }

    public init(
        jobId: String,
        state: State,
        progress: Double = 0,
        result: Data? = nil,
        error: String? = nil
    ) {
        self.jobId = jobId
        self.state = state
        self.progress = progress
        self.result = result
        self.error = error
    }
}
