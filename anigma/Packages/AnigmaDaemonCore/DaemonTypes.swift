//
//  DaemonTypes.swift
//  AnigmaDaemonCore
//
//  Shared types for daemon and workers.
//

import DatabaseCore
import Foundation

public struct DaemonRequestContext: Sendable, Codable {
    public let clientId: String
    public let capabilityToken: Data
    public let nonce: String

    public init(clientId: String, capabilityToken: Data, nonce: String) {
        self.clientId = clientId
        self.capabilityToken = capabilityToken
        self.nonce = nonce
    }
}

public struct ArtifactRef: Sendable, Codable {
    public let hash: String
    public let mediaType: String
    public let sizeBytes: UInt64

    public init(hash: String, mediaType: String, sizeBytes: UInt64) {
        self.hash = hash
        self.mediaType = mediaType
        self.sizeBytes = sizeBytes
    }
}

/// Result of ingesting an artifact into the vault.
public struct IngestResult: Sendable, Codable {
    public let artifact: ArtifactRef
    public let receiptHash: String

    public init(artifact: ArtifactRef, receiptHash: String) {
        self.artifact = artifact
        self.receiptHash = receiptHash
    }
}

/// Output payload emitted by a job worker.
public struct JobOutputPayload: Sendable, Codable {
    public let data: Data
    public let mediaType: String
    public let kind: String

    public init(data: Data, mediaType: String, kind: String) {
        self.data = data
        self.mediaType = mediaType
        self.kind = kind
    }
}

/// IPC payload used to execute jobs in a subprocess.
public struct WorkerJobPayload: Sendable, Codable {
    public let job: Job
    public let vaultPayloads: [String: Data]

    public init(job: Job, vaultPayloads: [String: Data]) {
        self.job = job
        self.vaultPayloads = vaultPayloads
    }
}

public struct JobSpec: Sendable, Codable {
    public let kind: String
    public let configCanonical: Data
    public let inputs: [ArtifactRef]

    public init(kind: String, configCanonical: Data, inputs: [ArtifactRef]) {
        self.kind = kind
        self.configCanonical = configCanonical
        self.inputs = inputs
    }
}

public struct ErrorStatus: Sendable, Codable {
    public let code: String
    public let message: String
    public let detailJson: String?

    public init(code: String, message: String, detailJson: String?) {
        self.code = code
        self.message = message
        self.detailJson = detailJson
    }
}

public struct Job: Sendable, Identifiable, Codable {
    public let id: String
    public let spec: JobSpec
    public let clientId: String
    public var state: JobState
    public var queuedAt: Date
    public var startedAt: Date?
    public var completedAt: Date?
    public var outputs: [ArtifactRef]
    public var receiptHash: String?
    public var errorMessage: String?

    public init(id: String, spec: JobSpec, clientId: String) {
        self.id = id
        self.spec = spec
        self.clientId = clientId
        self.state = .queued
        self.queuedAt = Date()
        self.outputs = []
    }
}

public enum JobState: String, Codable, Sendable {
    case queued = "QUEUED"
    case running = "RUNNING"
    case succeeded = "SUCCEEDED"
    case failed = "FAILED"
    case canceled = "CANCELED"
}

public struct HealthCheckResponse: Sendable, Codable {
    public let ok: Bool
    public let message: String
    public let apiVersion: String
    public let uptime: TimeInterval?
    public let memoryUsage: UInt64?
    public let jobCount: Int?

    public init(
        ok: Bool, 
        message: String, 
        apiVersion: String, 
        uptime: TimeInterval? = nil, 
        memoryUsage: UInt64? = nil, 
        jobCount: Int? = nil
    ) {
        self.ok = ok
        self.message = message
        self.apiVersion = apiVersion
        self.uptime = uptime
        self.memoryUsage = memoryUsage
        self.jobCount = jobCount
    }
}

public struct DetailedHealthResponse: Sendable, Codable {
    public let health: DaemonHealth
    public let daemonVersion: String
    public let buildHash: String
    
    public init(health: DaemonHealth, daemonVersion: String, buildHash: String) {
        self.health = health
        self.daemonVersion = daemonVersion
        self.buildHash = buildHash
    }
}

public struct OpenSessionResponse: Sendable, Codable {
    public let clientId: String
    public let capabilityToken: Data
    public let expiresUnixMs: UInt64
    public let grantedScopes: [String]

    public init(
        clientId: String, capabilityToken: Data, expiresUnixMs: UInt64, grantedScopes: [String]
    ) {
        self.clientId = clientId
        self.capabilityToken = capabilityToken
        self.expiresUnixMs = expiresUnixMs
        self.grantedScopes = grantedScopes
    }
}

public struct StatusResponse: Sendable, Codable {
    public let apiVersion: String
    public let daemonVersion: String
    public let buildHash: String
    public let socketPath: String
    public let tcpEnabled: Bool
    public let workerProcesses: UInt32
    public let vaultSizeBytes: UInt64
    public let vaultQuotaBytes: UInt64
    public let database: DatabaseCore.DatabaseMetrics?

    public init(
        apiVersion: String,
        daemonVersion: String,
        buildHash: String,
        socketPath: String,
        tcpEnabled: Bool,
        workerProcesses: UInt32,
        vaultSizeBytes: UInt64,
        vaultQuotaBytes: UInt64,
        database: DatabaseCore.DatabaseMetrics? = nil
    ) {
        self.apiVersion = apiVersion
        self.daemonVersion = daemonVersion
        self.buildHash = buildHash
        self.socketPath = socketPath
        self.tcpEnabled = tcpEnabled
        self.workerProcesses = workerProcesses
        self.vaultSizeBytes = vaultSizeBytes
        self.vaultQuotaBytes = vaultQuotaBytes
        self.database = database
    }
}

public struct CancelJobResponse: Sendable, Codable {
    public let canceled: Bool
    public let receiptHash: String?
    public let error: ErrorStatus?

    public init(canceled: Bool, receiptHash: String?, error: ErrorStatus?) {
        self.canceled = canceled
        self.receiptHash = receiptHash
        self.error = error
    }
}

public struct SubmitJobResponse: Sendable, Codable {
    public let jobId: String
    public let receiptHash: String
    public let error: ErrorStatus?

    public init(jobId: String, receiptHash: String, error: ErrorStatus?) {
        self.jobId = jobId
        self.receiptHash = receiptHash
        self.error = error
    }
}

public struct GetJobStatusResponse: Sendable, Codable {
    public let jobId: String
    public let state: String
    public let progressPermille: UInt32
    public let outputs: [ArtifactRef]
    public let finalReceiptHash: String?
    public let error: ErrorStatus?

    public init(
        jobId: String, state: String, progressPermille: UInt32, outputs: [ArtifactRef],
        finalReceiptHash: String?, error: ErrorStatus?
    ) {
        self.jobId = jobId
        self.state = state
        self.progressPermille = progressPermille
        self.outputs = outputs
        self.finalReceiptHash = finalReceiptHash
        self.error = error
    }
}
