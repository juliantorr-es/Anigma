import Foundation
import AnigmaPrimitives
import ExecutionCore

// Shared daemon-side types that were previously in a separate DaemonTypes module.

public typealias DaemonRequestContext = AnigmaRequestContext
public typealias ErrorStatus = AnigmaErrorStatus
public typealias EntityId = AnigmaPrimitives.EntityId
public typealias JobSpec = AnigmaJobSpec
public typealias Job = AnigmaJob
typealias SubmitJobResponse = AnigmaSubmitJobResponse
typealias GetJobStatusResponse = AnigmaGetJobStatusResponse
typealias CancelJobResponse = AnigmaCancelJobResponse
typealias OpenSessionResponse = AnigmaOpenSessionResponse
typealias StatusResponse = AnigmaStatusResponse
typealias HealthCheckResponse = AnigmaHealthResponse
typealias DaemonJobEvent = AnigmaJobEvent

enum JobEventType: String, Codable, Sendable {
    case state
    case progress
    case log
    case output
}

/// Lightweight reference to an artifact in the governed vault.
public typealias ArtifactRef = AnigmaArtifactRef

/// Output payload produced by a job worker before ingest into the vault.
public struct JobOutputPayload: Codable, Sendable {
    public let data: Data
    public let mediaType: String
    public let kind: String

    public init(data: Data, mediaType: String, kind: String) {
        self.data = data
        self.mediaType = mediaType
        self.kind = kind
    }
}

/// Wire payload sent from the daemon to a subprocess worker.
public struct WorkerJobPayload: Codable, Sendable {
    public let jobId: String
    public let spec: JobSpec
    public let vaultPayloads: [String: Data]

    public init(jobId: String, spec: JobSpec, vaultPayloads: [String: Data]) {
        self.jobId = jobId
        self.spec = spec
        self.vaultPayloads = vaultPayloads
    }
}

/// Canonical job state used by the daemon job queue and events.
public enum JobState: String, Codable, Sendable, CaseIterable {
    case queued
    case running
    case succeeded
    case failed
    case canceled
}
