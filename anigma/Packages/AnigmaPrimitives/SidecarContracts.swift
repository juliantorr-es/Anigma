//
//  SidecarContracts.swift
//  AnigmaSidecar
//
//  Created by Gemini on 2026-01-10.
//
//  Native Swift Codable replacements for the Protobuf definitions.
//  This eliminates the dependency on SwiftProtobuf and grpc-swift.
//

import Foundation

public struct AnigmaRequestContext: Codable, Sendable {
    public var clientId: String
    public var capabilityToken: Data
    public var nonce: String

    public init(clientId: String = "", capabilityToken: Data = Data(), nonce: String = "") {
        self.clientId = clientId
        self.capabilityToken = capabilityToken
        self.nonce = nonce
    }
}

public struct AnigmaErrorStatus: Codable, Sendable {
    public var code: String
    public var message: String
    public var detailJson: String?

    public init(code: String, message: String, detailJson: String? = nil) {
        self.code = code
        self.message = message
        self.detailJson = detailJson
    }
}

public struct AnigmaHealthRequest: Codable, Sendable {
    public init() {}
}

public struct AnigmaHealthResponse: Codable, Sendable {
    public var ok: Bool
    public var message: String
    public var apiVersion: String

    public init(ok: Bool, message: String, apiVersion: String) {
        self.ok = ok
        self.message = message
        self.apiVersion = apiVersion
    }
}

public struct AnigmaStatusRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public init(ctx: AnigmaRequestContext) {
        self.ctx = ctx
    }
}

public struct AnigmaStatusResponse: Codable, Sendable {
    public var apiVersion: String
    public var daemonVersion: String
    public var buildHash: String
    public var socketPath: String
    public var tcpEnabled: Bool
    public var workerProcesses: UInt32
    public var vaultSizeBytes: UInt64
    public var vaultQuotaBytes: UInt64
    public var extraJson: String?

    public init(
        apiVersion: String,
        daemonVersion: String,
        buildHash: String,
        socketPath: String,
        tcpEnabled: Bool,
        workerProcesses: UInt32,
        vaultSizeBytes: UInt64,
        vaultQuotaBytes: UInt64,
        extraJson: String? = nil
    ) {
        self.apiVersion = apiVersion
        self.daemonVersion = daemonVersion
        self.buildHash = buildHash
        self.socketPath = socketPath
        self.tcpEnabled = tcpEnabled
        self.workerProcesses = workerProcesses
        self.vaultSizeBytes = vaultSizeBytes
        self.vaultQuotaBytes = vaultQuotaBytes
        self.extraJson = extraJson
    }
}

public struct AnigmaOpenSessionRequest: Codable, Sendable {
    public var requestedClientName: String
    public var requestedScopes: [String]

    public init(requestedClientName: String, requestedScopes: [String]) {
        self.requestedClientName = requestedClientName
        self.requestedScopes = requestedScopes
    }
}

public struct AnigmaOpenSessionResponse: Codable, Sendable {
    public var clientId: String
    public var capabilityToken: Data
    public var expiresUnixMs: UInt64
    public var grantedScopes: [String]

    public init(clientId: String, capabilityToken: Data, expiresUnixMs: UInt64, grantedScopes: [String]) {
        self.clientId = clientId
        self.capabilityToken = capabilityToken
        self.expiresUnixMs = expiresUnixMs
        self.grantedScopes = grantedScopes
    }
}

// MARK: - API Key Authentication

public struct AnigmaAPIKeyExchangeRequest: Codable, Sendable {
    public var apiKey: String
    public var clientName: String

    public init(apiKey: String, clientName: String) {
        self.apiKey = apiKey
        self.clientName = clientName
    }
}

public struct AnigmaAPIKeyExchangeResponse: Codable, Sendable {
    public var clientId: String
    public var capabilityToken: Data
    public var expiresUnixMs: UInt64
    public var grantedScopes: [String]

    public init(clientId: String, capabilityToken: Data, expiresUnixMs: UInt64, grantedScopes: [String]) {
        self.clientId = clientId
        self.capabilityToken = capabilityToken
        self.expiresUnixMs = expiresUnixMs
        self.grantedScopes = grantedScopes
    }
}

public struct AnigmaArtifactRef: Codable, Sendable {
    public var hash: String
    public var mediaType: String
    public var sizeBytes: UInt64

    public init(hash: String, mediaType: String, sizeBytes: UInt64) {
        self.hash = hash
        self.mediaType = mediaType
        self.sizeBytes = sizeBytes
    }
}

public struct AnigmaJobSpec: Codable, Sendable {
    public var kind: String
    public var configCanonical: Data
    public var inputs: [AnigmaArtifactRef]

    public init(kind: String, configCanonical: Data, inputs: [AnigmaArtifactRef]) {
        self.kind = kind
        self.configCanonical = configCanonical
        self.inputs = inputs
    }
}

public struct AnigmaSubmitJobRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var spec: AnigmaJobSpec

    public init(ctx: AnigmaRequestContext, spec: AnigmaJobSpec) {
        self.ctx = ctx
        self.spec = spec
    }
}

public struct AnigmaSubmitJobResponse: Codable, Sendable {
    public var jobId: String?
    public var receiptHash: String?
    public var error: AnigmaErrorStatus?

    public init(jobId: String? = nil, receiptHash: String? = nil, error: AnigmaErrorStatus? = nil) {
        self.jobId = jobId
        self.receiptHash = receiptHash
        self.error = error
    }
}

// Additional structs for ListArtifacts, Retrieve, etc. can be added here

public struct AnigmaListRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var pageToken: String
    public var pageSize: UInt32

    public init(ctx: AnigmaRequestContext, pageToken: String = "", pageSize: UInt32 = 0) {
        self.ctx = ctx
        self.pageToken = pageToken
        self.pageSize = pageSize
    }
}

public struct AnigmaListResponse: Codable, Sendable {
    public var artifacts: [AnigmaArtifactRef]
    public var nextPageToken: String
    public var error: AnigmaErrorStatus?

    public init(artifacts: [AnigmaArtifactRef] = [], nextPageToken: String = "", error: AnigmaErrorStatus? = nil) {
        self.artifacts = artifacts
        self.nextPageToken = nextPageToken
        self.error = error
    }
}

public struct AnigmaListJobsRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var pageToken: String
    public var pageSize: UInt32
    public var filterByState: [String]

    public init(ctx: AnigmaRequestContext, pageToken: String = "", pageSize: UInt32 = 0, filterByState: [String] = []) {
        self.ctx = ctx
        self.pageToken = pageToken
        self.pageSize = pageSize
        self.filterByState = filterByState
    }
}

public struct AnigmaListJobsResponse: Codable, Sendable {
    public var jobs: [AnigmaJob]
    public var nextPageToken: String
    public var error: AnigmaErrorStatus?

    public init(jobs: [AnigmaJob] = [], nextPageToken: String = "", error: AnigmaErrorStatus? = nil) {
        self.jobs = jobs
        self.nextPageToken = nextPageToken
        self.error = error
    }
}

public struct AnigmaJob: Codable, Sendable {
    public var jobId: String
    public var spec: AnigmaJobSpec
    public var state: String
    public var progressPermille: UInt32
    public var outputs: [AnigmaArtifactRef]
    public var finalReceiptHash: String

    public init(jobId: String, spec: AnigmaJobSpec, state: String, progressPermille: UInt32, outputs: [AnigmaArtifactRef], finalReceiptHash: String = "") {
        self.jobId = jobId
        self.spec = spec
        self.state = state
        self.progressPermille = progressPermille
        self.outputs = outputs
        self.finalReceiptHash = finalReceiptHash
    }
}

public struct AnigmaStreamJobEventsRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var jobId: String

    public init(ctx: AnigmaRequestContext, jobId: String) {
        self.ctx = ctx
        self.jobId = jobId
    }
}

public struct AnigmaJobEvent: Codable, Sendable {
    public var jobId: String
    public var type: String
    public var message: String
    public var progressPermille: UInt32
    public var output: AnigmaArtifactRef?
    public var receiptHash: String
    public var error: AnigmaErrorStatus?

    public init(jobId: String, type: String, message: String = "", progressPermille: UInt32 = 0, output: AnigmaArtifactRef? = nil, receiptHash: String = "", error: AnigmaErrorStatus? = nil) {
        self.jobId = jobId
        self.type = type
        self.message = message
        self.progressPermille = progressPermille
        self.output = output
        self.receiptHash = receiptHash
        self.error = error
    }
}

public struct AnigmaCancelJobRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var jobId: String

    public init(ctx: AnigmaRequestContext, jobId: String) {
        self.ctx = ctx
        self.jobId = jobId
    }
}

public struct AnigmaCancelJobResponse: Codable, Sendable {
    public var canceled: Bool
    public var receiptHash: String
    public var error: AnigmaErrorStatus?

    public init(canceled: Bool = false, receiptHash: String = "", error: AnigmaErrorStatus? = nil) {
        self.canceled = canceled
        self.receiptHash = receiptHash
        self.error = error
    }
}

public struct AnigmaReceiptRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var receiptHash: String

    public init(ctx: AnigmaRequestContext, receiptHash: String) {
        self.ctx = ctx
        self.receiptHash = receiptHash
    }
}

public struct AnigmaReceiptResponse: Codable, Sendable {
    public var receiptCanonicalJson: String
    public var error: AnigmaErrorStatus?

    public init(receiptCanonicalJson: String = "", error: AnigmaErrorStatus? = nil) {
        self.receiptCanonicalJson = receiptCanonicalJson
        self.error = error
    }
}

public struct AnigmaVerifyChainRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var headReceiptHash: String

    public init(ctx: AnigmaRequestContext, headReceiptHash: String) {
        self.ctx = ctx
        self.headReceiptHash = headReceiptHash
    }
}

public struct AnigmaVerifyChainResponse: Codable, Sendable {
    public var ok: Bool
    public var message: String
    public var error: AnigmaErrorStatus?

    public init(ok: Bool = false, message: String = "", error: AnigmaErrorStatus? = nil) {
        self.ok = ok
        self.message = message
        self.error = error
    }
}
// MARK: - Ingest Artifact

public struct AnigmaIngestArtifactRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var mediaType: String
    public var filenameHint: String?
    public var data: Data
    public var plaintextSha256: String?
    public var kind: String
    
    public init(ctx: AnigmaRequestContext, mediaType: String, filenameHint: String? = nil, data: Data, plaintextSha256: String? = nil, kind: String = "original") {
        self.ctx = ctx
        self.mediaType = mediaType
        self.filenameHint = filenameHint
        self.data = data
        self.plaintextSha256 = plaintextSha256
        self.kind = kind
    }
}

public struct AnigmaIngestArtifactResponse: Codable, Sendable {
    public var artifact: AnigmaArtifactRef
    public var receiptHash: String
    public var error: AnigmaErrorStatus?
    
    public init(artifact: AnigmaArtifactRef, receiptHash: String, error: AnigmaErrorStatus? = nil) {
        self.artifact = artifact
        self.receiptHash = receiptHash
        self.error = error
    }
}

// MARK: - Retrieve Artifact

public struct AnigmaRetrieveArtifactRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var hash: String
    
    public init(ctx: AnigmaRequestContext, hash: String) {
        self.ctx = ctx
        self.hash = hash
    }
}

public struct AnigmaRetrieveArtifactResponse: Codable, Sendable {
    public var data: Data
    public var receiptHash: String?
    public var error: AnigmaErrorStatus?
    
    public init(data: Data, receiptHash: String? = nil, error: AnigmaErrorStatus? = nil) {
        self.data = data
        self.receiptHash = receiptHash
        self.error = error
    }
}

// MARK: - Get Job Status

public struct AnigmaGetJobStatusRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var jobId: String
    
    public init(ctx: AnigmaRequestContext, jobId: String) {
        self.ctx = ctx
        self.jobId = jobId
    }
}

// Response uses existing AnigmaJob struct (already defined)

public struct AnigmaGetJobStatusResponse: Codable, Sendable {
    public var jobId: String
    public var state: String
    public var progressPermille: UInt32
    public var outputs: [AnigmaArtifactRef]
    public var finalReceiptHash: String?
    public var error: AnigmaErrorStatus?
    
    public init(jobId: String, state: String, progressPermille: UInt32, outputs: [AnigmaArtifactRef], finalReceiptHash: String? = nil, error: AnigmaErrorStatus? = nil) {
        self.jobId = jobId
        self.state = state
        self.progressPermille = progressPermille
        self.outputs = outputs
        self.finalReceiptHash = finalReceiptHash
        self.error = error
    }
}

// MARK: - Stream Telemetry (placeholder)

public struct AnigmaStreamTelemetryRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var events: [AnigmaTelemetryEvent]
    
    public init(ctx: AnigmaRequestContext, events: [AnigmaTelemetryEvent] = []) {
        self.ctx = ctx
        self.events = events
    }
}

public struct AnigmaTelemetryEvent: Codable, Sendable {
    public var type: String
    public var payloadJson: String
    public var atUnixMs: UInt64
    
    public init(type: String, payloadJson: String, atUnixMs: UInt64) {
        self.type = type
        self.payloadJson = payloadJson
        self.atUnixMs = atUnixMs
    }
}

public struct AnigmaStreamTelemetryResponse: Codable, Sendable {
    public var ok: Bool
    public var error: AnigmaErrorStatus?
    public var receiptHash: String?
    
    public init(ok: Bool = false, error: AnigmaErrorStatus? = nil, receiptHash: String? = nil) {
        self.ok = ok
        self.error = error
        self.receiptHash = receiptHash
    }
}
