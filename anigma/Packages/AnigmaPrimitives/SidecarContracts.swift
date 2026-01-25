//
//  SidecarContracts.swift
//  AnigmaPrimitives
//
//  Consolidated API contracts for the Anigma daemon and sidecar bridge.
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

public struct AnigmaGetJobStatusRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var jobId: String
    
    public init(ctx: AnigmaRequestContext, jobId: String) {
        self.ctx = ctx
        self.jobId = jobId
    }
}

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

// MARK: - Model Registry API

public struct AnigmaOnboardingStatusRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public init(ctx: AnigmaRequestContext) { self.ctx = ctx }
}

public struct AnigmaOnboardingStatusResponse: Codable, Sendable {
    public var isOnboarded: Bool
    public var error: AnigmaErrorStatus?
    
    public init(isOnboarded: Bool, error: AnigmaErrorStatus? = nil) {
        self.isOnboarded = isOnboarded
        self.error = error
    }
}

public struct AnigmaListToolsRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public init(ctx: AnigmaRequestContext) { self.ctx = ctx }
}

public struct AnigmaListToolsResponse: Codable, Sendable {
    public var tools: [AnigmaToolInfo]
    public var error: AnigmaErrorStatus?
    
    public init(tools: [AnigmaToolInfo], error: AnigmaErrorStatus? = nil) {
        self.tools = tools
        self.error = error
    }
}

public struct AnigmaToolInfo: Codable, Sendable {
    public var name: String
    public var description: String?
    public var inputSchemaJson: String
    
    public init(name: String, description: String?, inputSchemaJson: String) {
        self.name = name
        self.description = description
        self.inputSchemaJson = inputSchemaJson
    }
}

public struct ModelInfo: Codable, Sendable {
    public var id: String
    public var name: String
    public var type: String
    public var sizeGB: Double
    public var quantization: String
    public var installedAt: Date?
    
    public init(id: String, name: String, type: String, sizeGB: Double, quantization: String, installedAt: Date?) {
        self.id = id
        self.name = name
        self.type = type
        self.sizeGB = sizeGB
        self.quantization = quantization
        self.installedAt = installedAt
    }
}

public struct AnigmaListModelsRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public init(ctx: AnigmaRequestContext) { self.ctx = ctx }
}

public struct AnigmaListModelsResponse: Codable, Sendable {
    public var models: [ModelInfo]
    public var error: AnigmaErrorStatus?
    
    public init(models: [ModelInfo], error: AnigmaErrorStatus? = nil) {
        self.models = models
        self.error = error
    }
}

public struct AnigmaInstallModelRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var modelId: String
    public var repo: String?
    public var revision: String?
    
    public init(ctx: AnigmaRequestContext, modelId: String, repo: String? = nil, revision: String? = nil) {
        self.ctx = ctx
        self.modelId = modelId
        self.repo = repo
        self.revision = revision
    }
}

public struct AnigmaInstallModelResponse: Codable, Sendable {
    public var modelId: String
    public var installPath: String?
    public var error: AnigmaErrorStatus?
    
    public init(modelId: String, installPath: String? = nil, error: AnigmaErrorStatus? = nil) {
        self.modelId = modelId
        self.installPath = installPath
        self.error = error
    }
}

// MARK: - ML Operations API

public struct ChatMessage: Codable, Sendable {
    public let role: String
    public let content: String
    
    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

public struct AnigmaChatRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var messages: [ChatMessage]
    public var model: String?
    public var temperature: Double
    public var provider: String?
    public var sessionId: String?
    
    public init(ctx: AnigmaRequestContext, messages: [ChatMessage], model: String? = nil, temperature: Double = 0.7, provider: String? = nil, sessionId: String? = nil) {
        self.ctx = ctx
        self.messages = messages
        self.model = model
        self.temperature = temperature
        self.provider = provider
        self.sessionId = sessionId
    }
}

public struct AnigmaChatResponse: Codable, Sendable {
    public var message: String
    public var model: String
    public var executionTimeMs: UInt64
    public var error: AnigmaErrorStatus?
    
    public init(message: String, model: String, executionTimeMs: UInt64, error: AnigmaErrorStatus? = nil) {
        self.message = message
        self.model = model
        self.executionTimeMs = executionTimeMs
        self.error = error
    }
}

public struct AnigmaEmbedRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var text: String
    public var model: String
    public var sessionId: String?
    
    public init(ctx: AnigmaRequestContext, text: String, model: String, sessionId: String? = nil) {
        self.ctx = ctx
        self.text = text
        self.model = model
        self.sessionId = sessionId
    }
}

public struct AnigmaEmbedResponse: Codable, Sendable {
    public var vector: [Float]
    public var dimension: Int
    public var model: String
    public var executionTimeMs: UInt64
    public var error: AnigmaErrorStatus?
    
    public init(vector: [Float], dimension: Int, model: String, executionTimeMs: UInt64, error: AnigmaErrorStatus? = nil) {
        self.vector = vector
        self.dimension = dimension
        self.model = model
        self.executionTimeMs = executionTimeMs
        self.error = error
    }
}

public struct AnigmaSearchRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var query: String
    public var model: String
    public var topK: Int
    public var threshold: Double
    public var sessionId: String?
    
    public init(ctx: AnigmaRequestContext, query: String, model: String, topK: Int = 10, threshold: Double = 0.7, sessionId: String? = nil) {
        self.ctx = ctx
        self.query = query
        self.model = model
        self.topK = topK
        self.threshold = threshold
        self.sessionId = sessionId
    }
}

public struct AnigmaSearchResponse: Codable, Sendable {
    public var results: [AnigmaSearchResult]
    public var query: String
    public var model: String
    public var executionTimeMs: UInt64
    public var error: AnigmaErrorStatus?
    
    public init(results: [AnigmaSearchResult], query: String, model: String, executionTimeMs: UInt64, error: AnigmaErrorStatus? = nil) {
        self.results = results
        self.query = query
        self.model = model
        self.executionTimeMs = executionTimeMs
        self.error = error
    }
}

public struct AnigmaSearchResult: Codable, Sendable {
    public var artifactHash: String
    public var snippet: String
    public var score: Double
    public var metadata: [String: String]
    
    public init(artifactHash: String, snippet: String, score: Double, metadata: [String: String] = [:]) {
        self.artifactHash = artifactHash
        self.snippet = snippet
        self.score = score
        self.metadata = metadata
    }
}

// MARK: - Evidence Operations

public struct AnigmaEvidence: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var jobId: UUID?
    public var contextId: UUID?
    public var timestamp: Date
    public var type: EvidenceType
    public var summary: String
    public var hash: String?

    public enum EvidenceType: String, Codable, Sendable {
        case importEvent
        case jobCompletion
        case policyCheck
        case export
        case userAction

        public var icon: String {
            switch self {
            case .importEvent: return "square.and.arrow.down"
            case .jobCompletion: return "checkmark.seal"
            case .policyCheck: return "shield.check"
            case .export: return "square.and.arrow.up"
            case .userAction: return "person.fill"
            }
        }
    }
    
    public init(id: UUID, jobId: UUID? = nil, contextId: UUID? = nil, timestamp: Date = Date(), type: EvidenceType, summary: String, hash: String? = nil) {
        self.id = id
        self.jobId = jobId
        self.contextId = contextId
        self.timestamp = timestamp
        self.type = type
        self.summary = summary
        self.hash = hash
    }
}

public struct AnigmaSessionEvidenceRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var sessionId: String
    
    public init(ctx: AnigmaRequestContext, sessionId: String) {
        self.ctx = ctx
        self.sessionId = sessionId
    }
}

public struct AnigmaSessionEvidenceResponse: Codable, Sendable {
    public var sessionId: String
    public var evidenceCount: Int
    public var evidence: [AnigmaEvidence]
    public var error: AnigmaErrorStatus?
    
    public init(sessionId: String, evidenceCount: Int, evidence: [AnigmaEvidence], error: AnigmaErrorStatus? = nil) {
        self.sessionId = sessionId
        self.evidenceCount = evidenceCount
        self.evidence = evidence
        self.error = error
    }
}

// MARK: - Plan Operations

public struct AnigmaPlanSubmitRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var operationType: String
    public var sessionContext: String?
    public var parameters: [String: String]
    public var priority: String
    
    public init(ctx: AnigmaRequestContext, operationType: String, sessionContext: String? = nil, parameters: [String: String], priority: String = "normal") {
        self.ctx = ctx
        self.operationType = operationType
        self.sessionContext = sessionContext
        self.parameters = parameters
        self.priority = priority
    }
}

public struct AnigmaPlanSubmitResponse: Codable, Sendable {
    public var planId: String
    public var status: String
    public var evidenceHash: String?
    public var error: AnigmaErrorStatus?
    
    public init(planId: String, status: String, evidenceHash: String? = nil, error: AnigmaErrorStatus? = nil) {
        self.planId = planId
        self.status = status
        self.evidenceHash = evidenceHash
        self.error = error
    }
}

// MARK: - Agent Operations

public struct AnigmaAgentRunRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var agentId: String
    public var task: String
    public var parameters: [String: String]?
    
    public init(ctx: AnigmaRequestContext, agentId: String, task: String, parameters: [String: String]? = nil) {
        self.ctx = ctx
        self.agentId = agentId
        self.task = task
        self.parameters = parameters
    }
}

public struct AnigmaAgentRunResponse: Codable, Sendable {
    public var runId: String
    public var status: String
    public var error: AnigmaErrorStatus?
    
    public init(runId: String, status: String, error: AnigmaErrorStatus? = nil) {
        self.runId = runId
        self.status = status
        self.error = error
    }
}

// MARK: - Export Operations

public struct AnigmaExportStartRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var format: String
    public var documentIds: [String]
    public var options: [String: String]?
    
    public init(ctx: AnigmaRequestContext, format: String, documentIds: [String], options: [String: String]? = nil) {
        self.ctx = ctx
        self.format = format
        self.documentIds = documentIds
        self.options = options
    }
}

public struct AnigmaExportStartResponse: Codable, Sendable {
    public var exportId: String
    public var jobId: String
    public var error: AnigmaErrorStatus?
    
    public init(exportId: String, jobId: String, error: AnigmaErrorStatus? = nil) {
        self.exportId = exportId
        self.jobId = jobId
        self.error = error
    }
}

// MARK: - Telemetry API

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

public struct AnigmaStreamTelemetryRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    
    public init(ctx: AnigmaRequestContext) {
        self.ctx = ctx
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
