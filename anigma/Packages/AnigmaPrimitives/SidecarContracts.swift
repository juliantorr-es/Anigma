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

// MARK: - Plan WebServer Types (Phase 3 - Daemon Consolidation)

/// Plan submission request for WebServer API
public struct AnigmaWebPlanSubmissionRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var operationType: String
    public var sessionContext: String?
    public var parameters: [String: String]
    public var priority: String
    
    public init(ctx: AnigmaRequestContext, operationType: String, sessionContext: String? = nil, parameters: [String: String] = [:], priority: String = "normal") {
        self.ctx = ctx
        self.operationType = operationType
        self.sessionContext = sessionContext
        self.parameters = parameters
        self.priority = priority
    }
}

/// Plan submission response for WebServer API
public struct AnigmaWebPlanSubmissionResponse: Codable, Sendable {
    public var planId: String
    public var status: String
    public var plan: [String: String]?
    public var reason: String?
    public var submittedAt: Date
    public var error: AnigmaErrorStatus?
    
    public init(planId: String, status: String, plan: [String: String]? = nil, reason: String? = nil, submittedAt: Date = Date(), error: AnigmaErrorStatus? = nil) {
        self.planId = planId
        self.status = status
        self.plan = plan
        self.reason = reason
        self.submittedAt = submittedAt
        self.error = error
    }
}

/// Plan inspection request for WebServer API
public struct AnigmaWebPlanInspectionRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var planId: String
    public var includeEvidence: Bool
    
    public init(ctx: AnigmaRequestContext, planId: String, includeEvidence: Bool = false) {
        self.ctx = ctx
        self.planId = planId
        self.includeEvidence = includeEvidence
    }
}

/// Plan inspection response for WebServer API
public struct AnigmaWebPlanInspectionResponse: Codable, Sendable {
    public var planId: String
    public var isValid: Bool
    public var violations: [String]
    public var dependencyCount: Int
    public var inspectedAt: Date
    public var error: AnigmaErrorStatus?
    
    public init(planId: String, isValid: Bool, violations: [String] = [], dependencyCount: Int = 0, inspectedAt: Date = Date(), error: AnigmaErrorStatus? = nil) {
        self.planId = planId
        self.isValid = isValid
        self.violations = violations
        self.dependencyCount = dependencyCount
        self.inspectedAt = inspectedAt
        self.error = error
    }
}

/// Plan execution request for WebServer API
public struct AnigmaWebPlanExecutionRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var planId: String
    public var outputs: [String: String]
    
    public init(ctx: AnigmaRequestContext, planId: String, outputs: [String: String] = [:]) {
        self.ctx = ctx
        self.planId = planId
        self.outputs = outputs
    }
}

/// Plan execution response for WebServer API
public struct AnigmaWebPlanExecutionResponse: Codable, Sendable {
    public var planId: String
    public var status: String
    public var outputs: [String]
    public var evidenceBinding: [String]?
    public var executedAt: Date
    public var error: AnigmaErrorStatus?
    
    public init(planId: String, status: String, outputs: [String] = [], evidenceBinding: [String]? = nil, executedAt: Date = Date(), error: AnigmaErrorStatus? = nil) {
        self.planId = planId
        self.status = status
        self.outputs = outputs
        self.evidenceBinding = evidenceBinding
        self.executedAt = executedAt
        self.error = error
    }
}

// MARK: - ML Generate Types (Phase 3)

/// Generate request for WebServer API
public struct AnigmaWebGenerateRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var prompt: String
    public var model: String
    public var maxTokens: Int?
    public var sessionId: String?
    
    public init(ctx: AnigmaRequestContext, prompt: String, model: String, maxTokens: Int? = nil, sessionId: String? = nil) {
        self.ctx = ctx
        self.prompt = prompt
        self.model = model
        self.maxTokens = maxTokens
        self.sessionId = sessionId
    }
}

/// Generate response for WebServer API
public struct AnigmaWebGenerateResponse: Codable, Sendable {
    public var generated: String
    public var model: String
    public var tokensGenerated: Int
    public var executionTimeMs: UInt64
    public var error: AnigmaErrorStatus?
    
    public init(generated: String, model: String, tokensGenerated: Int = 0, executionTimeMs: UInt64 = 0, error: AnigmaErrorStatus? = nil) {
        self.generated = generated
        self.model = model
        self.tokensGenerated = tokensGenerated
        self.executionTimeMs = executionTimeMs
        self.error = error
    }
}

// MARK: - Evidence Compliance Types (Phase 3)

/// Compliance report request for WebServer API
public struct AnigmaWebComplianceReportRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var sessionId: String
    
    public init(ctx: AnigmaRequestContext, sessionId: String) {
        self.ctx = ctx
        self.sessionId = sessionId
    }
}

/// Compliance report response for WebServer API
public struct AnigmaWebComplianceReportResponse: Codable, Sendable {
    public var sessionId: String
    public var chainValid: Bool
    public var complianceScore: Double
    public var isCompliant: Bool
    public var violations: [AnigmaViolationItem]
    public var error: AnigmaErrorStatus?
    
    public init(sessionId: String, chainValid: Bool, complianceScore: Double, isCompliant: Bool, violations: [AnigmaViolationItem] = [], error: AnigmaErrorStatus? = nil) {
        self.sessionId = sessionId
        self.chainValid = chainValid
        self.complianceScore = complianceScore
        self.isCompliant = isCompliant
        self.violations = violations
        self.error = error
    }
}

/// Violation item for compliance reports
public struct AnigmaViolationItem: Codable, Sendable {
    public var id: String
    public var type: String
    public var severity: String
    public var description: String
    public var detectedAt: Date
    
    public init(id: String, type: String, severity: String, description: String, detectedAt: Date = Date()) {
        self.id = id
        self.type = type
        self.severity = severity
        self.description = description
        self.detectedAt = detectedAt
    }
}

// MARK: - Evidence Bundle Types (Phase 3)

/// Evidence bundle export request for WebServer API
public struct AnigmaWebEvidenceBundleRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var sessionId: String
    public var reason: String?
    
    public init(ctx: AnigmaRequestContext, sessionId: String, reason: String? = nil) {
        self.ctx = ctx
        self.sessionId = sessionId
        self.reason = reason
    }
}

/// Evidence bundle export response for WebServer API
public struct AnigmaWebEvidenceBundleResponse: Codable, Sendable {
    public var bundleId: String
    public var sessionId: String
    public var evidenceCount: Int
    public var isCourtAdmissible: Bool
    public var bundleHash: String
    public var exportedAt: Date
    public var error: AnigmaErrorStatus?
    
    public init(bundleId: String, sessionId: String, evidenceCount: Int, isCourtAdmissible: Bool, bundleHash: String, exportedAt: Date = Date(), error: AnigmaErrorStatus? = nil) {
        self.bundleId = bundleId
        self.sessionId = sessionId
        self.evidenceCount = evidenceCount
        self.isCourtAdmissible = isCourtAdmissible
        self.bundleHash = bundleHash
        self.exportedAt = exportedAt
        self.error = error
    }
}

// MARK: - Document Types (Phase 3)

/// Document acquire request for WebServer API
public struct AnigmaWebDocumentAcquireRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var documentId: String
    public var filePath: String
    public var sessionId: String
    public var metadata: [String: String]?
    
    public init(ctx: AnigmaRequestContext, documentId: String, filePath: String, sessionId: String, metadata: [String: String]? = nil) {
        self.ctx = ctx
        self.documentId = documentId
        self.filePath = filePath
        self.sessionId = sessionId
        self.metadata = metadata
    }
}

/// Document acquire response for WebServer API
public struct AnigmaWebDocumentAcquireResponse: Codable, Sendable {
    public var documentId: String
    public var recorded: Bool
    public var timestamp: Date
    public var error: AnigmaErrorStatus?
    
    public init(documentId: String, recorded: Bool, timestamp: Date = Date(), error: AnigmaErrorStatus? = nil) {
        self.documentId = documentId
        self.recorded = recorded
        self.timestamp = timestamp
        self.error = error
    }
}

/// Document transform request for WebServer API
public struct AnigmaWebDocumentTransformRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var documentId: String
    public var transformationType: String
    public var toolName: String
    public var toolVersion: String
    public var inputHash: String
    public var outputHash: String
    public var sessionId: String
    public var parameters: [String: String]?
    
    public init(ctx: AnigmaRequestContext, documentId: String, transformationType: String, toolName: String, toolVersion: String, inputHash: String, outputHash: String, sessionId: String, parameters: [String: String]? = nil) {
        self.ctx = ctx
        self.documentId = documentId
        self.transformationType = transformationType
        self.toolName = toolName
        self.toolVersion = toolVersion
        self.inputHash = inputHash
        self.outputHash = outputHash
        self.sessionId = sessionId
        self.parameters = parameters
    }
}

/// Document transform response for WebServer API
public struct AnigmaWebDocumentTransformResponse: Codable, Sendable {
    public var transformationId: String
    public var recorded: Bool
    public var timestamp: Date
    public var error: AnigmaErrorStatus?
    
    public init(transformationId: String, recorded: Bool, timestamp: Date = Date(), error: AnigmaErrorStatus? = nil) {
        self.transformationId = transformationId
        self.recorded = recorded
        self.timestamp = timestamp
        self.error = error
    }
}

// MARK: - WebServer Health Types (Phase 3)

/// WebServer health response
public struct AnigmaWebHealthResponse: Codable, Sendable {
    public var status: String
    public var cathedral: String?
    public var cathedralVersion: String?
    public var timestamp: Date?
    public var error: AnigmaErrorStatus?
    
    public init(status: String, cathedral: String? = nil, cathedralVersion: String? = nil, timestamp: Date? = nil, error: AnigmaErrorStatus? = nil) {
        self.status = status
        self.cathedral = cathedral
        self.cathedralVersion = cathedralVersion
        self.timestamp = timestamp
        self.error = error
    }
}

// MARK: - Bundle Export Types (Phase 3 - WebServer)

/// Bundle export request for /api/v1/bundle/export (different from evidence/bundle)
public struct AnigmaWebBundleExportRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var reason: String
    public var timeRangeHours: Int
    public var requestorId: String
    
    public init(ctx: AnigmaRequestContext, reason: String, timeRangeHours: Int, requestorId: String) {
        self.ctx = ctx
        self.reason = reason
        self.timeRangeHours = timeRangeHours
        self.requestorId = requestorId
    }
}

/// Bundle export response for WebServer API
public struct AnigmaWebBundleExportResponse: Codable, Sendable {
    public var bundleId: String
    public var sessionId: String
    public var downloadUrl: String?
    public var error: AnigmaErrorStatus?
    
    public init(bundleId: String, sessionId: String, downloadUrl: String? = nil, error: AnigmaErrorStatus? = nil) {
        self.bundleId = bundleId
        self.sessionId = sessionId
        self.downloadUrl = downloadUrl
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
    public var plaintextHash: String?
    public var kind: String
    
    public init(ctx: AnigmaRequestContext, mediaType: String, filenameHint: String? = nil, data: Data, plaintextHash: String? = nil, kind: String = "original") {
        self.ctx = ctx
        self.mediaType = mediaType
        self.filenameHint = filenameHint
        self.data = data
        self.plaintextHash = plaintextHash
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

// MARK: - Pipeline Control API

public struct PipelineStage: Codable, Sendable {
    public var name: String
    public var type: String
    public var config: [String: String]

    public init(name: String, type: String, config: [String: String]) {
        self.name = name
        self.type = type
        self.config = config
    }
}

public struct PipelineInfo: Codable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var stageCount: Int
    public var createdAt: Date

    public init(id: String, name: String, stageCount: Int, createdAt: Date) {
        self.id = id
        self.name = name
        self.stageCount = stageCount
        self.createdAt = createdAt
    }
}

public struct PipelineListResponse: Codable, Sendable {
    public var pipelines: [PipelineInfo]

    public init(pipelines: [PipelineInfo]) {
        self.pipelines = pipelines
    }
}

public struct PipelineResponse: Codable, Sendable {
    public var id: String
    public var name: String
    public var stages: [PipelineStage]

    public init(id: String, name: String, stages: [PipelineStage]) {
        self.id = id
        self.name = name
        self.stages = stages
    }
}

public struct PipelineRunResponse: Codable, Sendable {
    public var runId: String
    public var pipelineId: String
    public var status: String
    public var startedAt: Date

    public init(runId: String, pipelineId: String, status: String, startedAt: Date) {
        self.runId = runId
        self.pipelineId = pipelineId
        self.status = status
        self.startedAt = startedAt
    }
}

public struct PipelineStatusResponse: Codable, Sendable {
    public var runId: String
    public var status: String
    public var currentStage: String?
    public var progress: Double
    public var outputs: [String: String]?

    public init(runId: String, status: String, currentStage: String? = nil, progress: Double, outputs: [String: String]? = nil) {
        self.runId = runId
        self.status = status
        self.currentStage = currentStage
        self.progress = progress
        self.outputs = outputs
    }
}

public struct PipelineSuccessResponse: Codable, Sendable {
    public var success: Bool
    public var message: String?

    public init(success: Bool, message: String? = nil) {
        self.success = success
        self.message = message
    }
}

public struct AnigmaPipelineListRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext

    public init(ctx: AnigmaRequestContext) {
        self.ctx = ctx
    }
}

public struct AnigmaPipelineListResponse: Codable, Sendable {
    public var pipelines: [PipelineInfo]
    public var error: AnigmaErrorStatus?

    public init(pipelines: [PipelineInfo], error: AnigmaErrorStatus? = nil) {
        self.pipelines = pipelines
        self.error = error
    }
}

public struct AnigmaPipelineCreateRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var name: String
    public var stages: [PipelineStage]

    public init(ctx: AnigmaRequestContext, name: String, stages: [PipelineStage]) {
        self.ctx = ctx
        self.name = name
        self.stages = stages
    }
}

public struct AnigmaPipelineCreateResponse: Codable, Sendable {
    public var pipelineId: String
    public var name: String
    public var error: AnigmaErrorStatus?

    public init(pipelineId: String, name: String, error: AnigmaErrorStatus? = nil) {
        self.pipelineId = pipelineId
        self.name = name
        self.error = error
    }
}

public struct AnigmaPipelineRunRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var pipelineId: String
    public var inputs: [String: String]

    public init(ctx: AnigmaRequestContext, pipelineId: String, inputs: [String: String]) {
        self.ctx = ctx
        self.pipelineId = pipelineId
        self.inputs = inputs
    }
}

public struct AnigmaPipelineRunResponse: Codable, Sendable {
    public var runId: String
    public var pipelineId: String
    public var status: String
    public var error: AnigmaErrorStatus?

    public init(runId: String, pipelineId: String, status: String, error: AnigmaErrorStatus? = nil) {
        self.runId = runId
        self.pipelineId = pipelineId
        self.status = status
        self.error = error
    }
}

public struct AnigmaPipelineStatusRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var runId: String

    public init(ctx: AnigmaRequestContext, runId: String) {
        self.ctx = ctx
        self.runId = runId
    }
}

public struct AnigmaPipelineStatusResponse: Codable, Sendable {
    public var runId: String
    public var status: String
    public var currentStage: String?
    public var progress: Double
    public var outputs: [String: String]?
    public var error: AnigmaErrorStatus?

    public init(runId: String, status: String, currentStage: String? = nil, progress: Double, outputs: [String: String]? = nil, error: AnigmaErrorStatus? = nil) {
        self.runId = runId
        self.status = status
        self.currentStage = currentStage
        self.progress = progress
        self.outputs = outputs
        self.error = error
    }
}

public struct AnigmaPipelineCancelRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var runId: String

    public init(ctx: AnigmaRequestContext, runId: String) {
        self.ctx = ctx
        self.runId = runId
    }
}

public struct AnigmaPipelineCancelResponse: Codable, Sendable {
    public var success: Bool
    public var message: String?
    public var error: AnigmaErrorStatus?

    public init(success: Bool, message: String? = nil, error: AnigmaErrorStatus? = nil) {
        self.success = success
        self.message = message
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

// MARK: - Assistant Runtime API

public struct AnigmaAssistantProject: Codable, Sendable {
    public var id: String
    public var name: String
    public var createdAtUnixMs: UInt64
    public var embeddingModel: String

    public init(id: String, name: String, createdAtUnixMs: UInt64, embeddingModel: String) {
        self.id = id
        self.name = name
        self.createdAtUnixMs = createdAtUnixMs
        self.embeddingModel = embeddingModel
    }
}

public struct AnigmaAssistantStatusRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var projectId: String?

    public init(ctx: AnigmaRequestContext, projectId: String? = nil) {
        self.ctx = ctx
        self.projectId = projectId
    }
}

public struct AnigmaAssistantStatusResponse: Codable, Sendable {
    public var operatingMode: String
    public var modeSource: String
    public var killSwitchActive: Bool
    public var killSwitchReason: String?
    public var lastDenialSummary: String?
    public var error: AnigmaErrorStatus?

    public init(
        operatingMode: String,
        modeSource: String,
        killSwitchActive: Bool,
        killSwitchReason: String? = nil,
        lastDenialSummary: String? = nil,
        error: AnigmaErrorStatus? = nil
    ) {
        self.operatingMode = operatingMode
        self.modeSource = modeSource
        self.killSwitchActive = killSwitchActive
        self.killSwitchReason = killSwitchReason
        self.lastDenialSummary = lastDenialSummary
        self.error = error
    }
}

public struct AnigmaAssistantListProjectsRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext

    public init(ctx: AnigmaRequestContext) {
        self.ctx = ctx
    }
}

public struct AnigmaAssistantListProjectsResponse: Codable, Sendable {
    public var projects: [AnigmaAssistantProject]
    public var error: AnigmaErrorStatus?

    public init(projects: [AnigmaAssistantProject], error: AnigmaErrorStatus? = nil) {
        self.projects = projects
        self.error = error
    }
}

public struct AnigmaAssistantCreateProjectRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var id: String
    public var name: String
    public var embeddingModel: String
    public var principalId: String
    public var principalDisplayName: String

    public init(
        ctx: AnigmaRequestContext,
        id: String,
        name: String,
        embeddingModel: String,
        principalId: String,
        principalDisplayName: String
    ) {
        self.ctx = ctx
        self.id = id
        self.name = name
        self.embeddingModel = embeddingModel
        self.principalId = principalId
        self.principalDisplayName = principalDisplayName
    }
}

public struct AnigmaAssistantCreateProjectResponse: Codable, Sendable {
    public var project: AnigmaAssistantProject?
    public var error: AnigmaErrorStatus?

    public init(project: AnigmaAssistantProject?, error: AnigmaErrorStatus? = nil) {
        self.project = project
        self.error = error
    }
}

public struct AnigmaAssistantSetModeRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var mode: String
    public var projectId: String?
    public var principalId: String
    public var principalDisplayName: String

    public init(
        ctx: AnigmaRequestContext,
        mode: String,
        projectId: String? = nil,
        principalId: String,
        principalDisplayName: String
    ) {
        self.ctx = ctx
        self.mode = mode
        self.projectId = projectId
        self.principalId = principalId
        self.principalDisplayName = principalDisplayName
    }
}

public struct AnigmaAssistantSetModeResponse: Codable, Sendable {
    public var success: Bool
    public var error: AnigmaErrorStatus?

    public init(success: Bool, error: AnigmaErrorStatus? = nil) {
        self.success = success
        self.error = error
    }
}

public struct AnigmaAssistantSetKillSwitchRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var active: Bool
    public var projectId: String?
    public var reason: String?
    public var principalId: String
    public var principalDisplayName: String

    public init(
        ctx: AnigmaRequestContext,
        active: Bool,
        projectId: String? = nil,
        reason: String? = nil,
        principalId: String,
        principalDisplayName: String
    ) {
        self.ctx = ctx
        self.active = active
        self.projectId = projectId
        self.reason = reason
        self.principalId = principalId
        self.principalDisplayName = principalDisplayName
    }
}

public struct AnigmaAssistantSetKillSwitchResponse: Codable, Sendable {
    public var success: Bool
    public var error: AnigmaErrorStatus?

    public init(success: Bool, error: AnigmaErrorStatus? = nil) {
        self.success = success
        self.error = error
    }
}

public struct AnigmaAssistantRecallOptions: Codable, Sendable {
    public var topK: Int
    public var scanLimit: Int?
    public var threshold: Float?
    public var hybrid: Bool
    public var explain: Bool

    public init(topK: Int, scanLimit: Int? = nil, threshold: Float? = nil, hybrid: Bool = true, explain: Bool = false) {
        self.topK = topK
        self.scanLimit = scanLimit
        self.threshold = threshold
        self.hybrid = hybrid
        self.explain = explain
    }
}

public struct AnigmaAssistantRecallRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var query: String
    public var projectId: String
    public var options: AnigmaAssistantRecallOptions

    public init(ctx: AnigmaRequestContext, query: String, projectId: String, options: AnigmaAssistantRecallOptions) {
        self.ctx = ctx
        self.query = query
        self.projectId = projectId
        self.options = options
    }
}

public struct AnigmaAssistantRecallItem: Codable, Sendable {
    public var id: String
    public var content: String
    public var similarity: Float
    public var rank: Int
    public var vectorRank: Int?
    public var ftsRank: Float?
    public var rrfScore: Float?
    public var metadata: [String: String]

    public init(
        id: String,
        content: String,
        similarity: Float,
        rank: Int,
        vectorRank: Int? = nil,
        ftsRank: Float? = nil,
        rrfScore: Float? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.content = content
        self.similarity = similarity
        self.rank = rank
        self.vectorRank = vectorRank
        self.ftsRank = ftsRank
        self.rrfScore = rrfScore
        self.metadata = metadata
    }
}

public struct AnigmaAssistantRecallStats: Codable, Sendable {
    public var rowsScanned: Int
    public var scanLimit: Int?
    public var executionTime: TimeInterval

    public init(rowsScanned: Int, scanLimit: Int? = nil, executionTime: TimeInterval) {
        self.rowsScanned = rowsScanned
        self.scanLimit = scanLimit
        self.executionTime = executionTime
    }
}

public struct AnigmaAssistantRecallResponse: Codable, Sendable {
    public var query: String
    public var projectId: String
    public var results: [AnigmaAssistantRecallItem]
    public var stats: AnigmaAssistantRecallStats?
    public var error: AnigmaErrorStatus?

    public init(
        query: String,
        projectId: String,
        results: [AnigmaAssistantRecallItem],
        stats: AnigmaAssistantRecallStats? = nil,
        error: AnigmaErrorStatus? = nil
    ) {
        self.query = query
        self.projectId = projectId
        self.results = results
        self.stats = stats
        self.error = error
    }
}

public struct AnigmaAssistantMemoryRecord: Codable, Sendable {
    public var id: String
    public var content: String
    public var metadata: [String: String]
    public var embeddingModel: String?
    public var createdAtUnixMs: UInt64

    public init(
        id: String,
        content: String,
        metadata: [String: String],
        embeddingModel: String? = nil,
        createdAtUnixMs: UInt64
    ) {
        self.id = id
        self.content = content
        self.metadata = metadata
        self.embeddingModel = embeddingModel
        self.createdAtUnixMs = createdAtUnixMs
    }
}

public struct AnigmaAssistantAddMemoRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var text: String
    public var projectId: String
    public var principalId: String
    public var principalDisplayName: String

    public init(
        ctx: AnigmaRequestContext,
        text: String,
        projectId: String,
        principalId: String,
        principalDisplayName: String
    ) {
        self.ctx = ctx
        self.text = text
        self.projectId = projectId
        self.principalId = principalId
        self.principalDisplayName = principalDisplayName
    }
}

public struct AnigmaAssistantAddMemoResponse: Codable, Sendable {
    public var record: AnigmaAssistantMemoryRecord?
    public var error: AnigmaErrorStatus?

    public init(record: AnigmaAssistantMemoryRecord? = nil, error: AnigmaErrorStatus? = nil) {
        self.record = record
        self.error = error
    }
}

public struct AnigmaAssistantIndexResult: Codable, Sendable {
    public var chunksCreated: Int
    public var chunksReused: Int
    public var embeddingsCreated: Int
    public var duration: TimeInterval

    public init(chunksCreated: Int, chunksReused: Int, embeddingsCreated: Int, duration: TimeInterval) {
        self.chunksCreated = chunksCreated
        self.chunksReused = chunksReused
        self.embeddingsCreated = embeddingsCreated
        self.duration = duration
    }
}

public struct AnigmaAssistantStartIndexRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var folderPath: String
    public var projectId: String
    public var principalId: String
    public var principalDisplayName: String
    public var dryRun: Bool

    public init(
        ctx: AnigmaRequestContext,
        folderPath: String,
        projectId: String,
        principalId: String,
        principalDisplayName: String,
        dryRun: Bool
    ) {
        self.ctx = ctx
        self.folderPath = folderPath
        self.projectId = projectId
        self.principalId = principalId
        self.principalDisplayName = principalDisplayName
        self.dryRun = dryRun
    }
}

public struct AnigmaAssistantStartIndexResponse: Codable, Sendable {
    public var jobId: String?
    public var totalFiles: Int
    public var result: AnigmaAssistantIndexResult?
    public var error: AnigmaErrorStatus?

    public init(
        jobId: String? = nil,
        totalFiles: Int,
        result: AnigmaAssistantIndexResult? = nil,
        error: AnigmaErrorStatus? = nil
    ) {
        self.jobId = jobId
        self.totalFiles = totalFiles
        self.result = result
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
    
    // Optional fields for direct URL installation (Phase 4)
    public var name: String?
    public var modelType: String?
    public var sizeGB: Double?
    public var quantization: String?
    
    public init(ctx: AnigmaRequestContext, modelId: String, repo: String? = nil, revision: String? = nil, name: String? = nil, modelType: String? = nil, sizeGB: Double? = nil, quantization: String? = nil) {
        self.ctx = ctx
        self.modelId = modelId
        self.repo = repo
        self.revision = revision
        self.name = name
        self.modelType = modelType
        self.sizeGB = sizeGB
        self.quantization = quantization
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

public struct AnigmaVerifyModelRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var modelId: String
    
    public init(ctx: AnigmaRequestContext, modelId: String) {
        self.ctx = ctx
        self.modelId = modelId
    }
}

public struct AnigmaVerifyModelResponse: Codable, Sendable {
    public var modelId: String
    public var isValid: Bool
    public var error: AnigmaErrorStatus?
    
    public init(modelId: String, isValid: Bool, error: AnigmaErrorStatus? = nil) {
        self.modelId = modelId
        self.isValid = isValid
        self.error = error
    }
}

public struct AnigmaDeleteModelRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var modelId: String
    
    public init(ctx: AnigmaRequestContext, modelId: String) {
        self.ctx = ctx
        self.modelId = modelId
    }
}

public struct AnigmaDeleteModelResponse: Codable, Sendable {
    public var modelId: String
    public var success: Bool
    public var error: AnigmaErrorStatus?
    
    public init(modelId: String, success: Bool, error: AnigmaErrorStatus? = nil) {
        self.modelId = modelId
        self.success = success
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

public struct AnigmaMLInput: Codable, Sendable {
    public var role: String
    public var content: String
    public var mediaType: String?
    
    public init(role: String, content: String, mediaType: String? = nil) {
        self.role = role
        self.content = content
        self.mediaType = mediaType
    }
}

public struct AnigmaExecuteMLRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var modelId: String
    public var taskKind: String
    public var inputs: [AnigmaMLInput]
    public var backend: String
    public var seed: Int?
    public var temperature: Double?
    public var topP: Double?
    public var maxTokens: Int?
    
    public init(ctx: AnigmaRequestContext, modelId: String, taskKind: String, inputs: [AnigmaMLInput], backend: String, seed: Int? = nil, temperature: Double? = nil, topP: Double? = nil, maxTokens: Int? = nil) {
        self.ctx = ctx
        self.modelId = modelId
        self.taskKind = taskKind
        self.inputs = inputs
        self.backend = backend
        self.seed = seed
        self.temperature = temperature
        self.topP = topP
        self.maxTokens = maxTokens
    }
}

public struct AnigmaExecutorProfile: Codable, Sendable {
    public var id: String
    public var displayName: String
    public var version: String
    
    public init(id: String, displayName: String, version: String) {
        self.id = id
        self.displayName = displayName
        self.version = version
    }
}

public struct AnigmaMLOutput: Codable, Sendable {
    public var data: Data
    public var mediaType: String
    
    public init(data: Data, mediaType: String) {
        self.data = data
        self.mediaType = mediaType
    }
}

public struct AnigmaExecuteMLResponse: Codable, Sendable {
    public var receiptHash: String
    public var artifactHash: String
    public var executedAt: Date
    public var executor: AnigmaExecutorProfile
    public var evidenceHash: String
    public var output: AnigmaMLOutput
    public var error: AnigmaErrorStatus?
    
    public init(receiptHash: String, artifactHash: String, executedAt: Date, executor: AnigmaExecutorProfile, evidenceHash: String, output: AnigmaMLOutput, error: AnigmaErrorStatus? = nil) {
        self.receiptHash = receiptHash
        self.artifactHash = artifactHash
        self.executedAt = executedAt
        self.executor = executor
        self.evidenceHash = evidenceHash
        self.output = output
        self.error = error
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

// MARK: - Source Connection API

/// Content source types
public enum AnigmaSourceType: String, Codable, Sendable, CaseIterable {
    case filesystem = "Filesystem"
    case git = "Git Repo"
    case googleDrive = "Google Drive"
    case slack = "Slack"
    case microsoft365 = "Microsoft 365"
    case jira = "Jira"
    case confluence = "Confluence"
    case salesforce = "Salesforce"
    case notion = "Notion"
    case email = "Email"
    case photos = "Photos"
}

/// Depth of knowledge digestion
public enum AnigmaIndexingDepth: String, Codable, Sendable, CaseIterable {
    case discovery = "Discovery"     // Metadata only (names, dates, sizes)
    case indexing = "Indexing"       // Content extraction (text, OCR)
    case understanding = "Understanding" // Entities, embeddings, relationship graph
}

/// Compute constraints for digestion
public struct AnigmaComputePolicy: Codable, Sendable, Hashable {
    public var allowOnBattery: Bool
    public var cpuThrottle: Double // 0 to 1.0
    public var diskCapGB: Int
    public var schedule: String // "Always", "Overnight", "When Idle"

    public init(allowOnBattery: Bool = false, cpuThrottle: Double = 0.5, diskCapGB: Int = 10, schedule: String = "Always") {
        self.allowOnBattery = allowOnBattery
        self.cpuThrottle = cpuThrottle
        self.diskCapGB = diskCapGB
        self.schedule = schedule
    }
}

/// Retention and storage policy
public struct AnigmaStoragePolicy: Codable, Sendable, Hashable {
    public var storeOriginals: Bool // Usually false, index only
    public var storeExtractedText: Bool
    public var storeEmbeddings: Bool
    public var purgeDerivedAfterDays: Int? // Optional expiration
    public var excludePatterns: String
    public var sensitivePaths: String

    public init(storeOriginals: Bool = false, storeExtractedText: Bool = true, storeEmbeddings: Bool = true, purgeDerivedAfterDays: Int? = nil, excludePatterns: String = "", sensitivePaths: String = "") {
        self.storeOriginals = storeOriginals
        self.storeExtractedText = storeExtractedText
        self.storeEmbeddings = storeEmbeddings
        self.purgeDerivedAfterDays = purgeDerivedAfterDays
        self.excludePatterns = excludePatterns
        self.sensitivePaths = sensitivePaths
    }
}

public enum AnigmaSourceStatus: String, Codable, Sendable {
    case connected = "Connected"
    case indexing = "Indexing"
    case paused = "Paused"
    case restricted = "Restricted"
    case revoked = "Revoked"
}

public struct AnigmaSourceStats: Codable, Hashable, Sendable {
    public let fileCount: Int
    public let totalSize: Int // Bytes
    public let entityCount: Int
    public let durationEstimateMinutes: Int

    public init(fileCount: Int, totalSize: Int, entityCount: Int, durationEstimateMinutes: Int) {
        self.fileCount = fileCount
        self.totalSize = totalSize
        self.entityCount = entityCount
        self.durationEstimateMinutes = durationEstimateMinutes
    }
}

/// A connection to something external (Filesystem, Cloud, Repo, etc.)
public struct AnigmaSource: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var type: AnigmaSourceType
    public var path: String
    public var depth: AnigmaIndexingDepth
    public var computePolicy: AnigmaComputePolicy
    public var storagePolicy: AnigmaStoragePolicy
    public var isConnected: Bool
    public var lastIndexed: Date?
    public var status: AnigmaSourceStatus
    public var stats: AnigmaSourceStats?

    public init(
        id: String = UUID().uuidString,
        name: String = "",
        type: AnigmaSourceType = .filesystem,
        path: String = "",
        depth: AnigmaIndexingDepth = .discovery,
        computePolicy: AnigmaComputePolicy = AnigmaComputePolicy(),
        storagePolicy: AnigmaStoragePolicy = AnigmaStoragePolicy(),
        isConnected: Bool = false,
        lastIndexed: Date? = nil,
        status: AnigmaSourceStatus = .connected,
        stats: AnigmaSourceStats? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.path = path
        self.depth = depth
        self.computePolicy = computePolicy
        self.storagePolicy = storagePolicy
        self.isConnected = isConnected
        self.lastIndexed = lastIndexed
        self.status = status
        self.stats = stats
    }
}

public struct AnigmaListSourcesRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public init(ctx: AnigmaRequestContext) { self.ctx = ctx }
}

public struct AnigmaListSourcesResponse: Codable, Sendable {
    public var sources: [AnigmaSource]
    public var error: AnigmaErrorStatus?

    public init(sources: [AnigmaSource] = [], error: AnigmaErrorStatus? = nil) {
        self.sources = sources
        self.error = error
    }
}

public struct AnigmaAddSourceRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var source: AnigmaSource

    public init(ctx: AnigmaRequestContext, source: AnigmaSource) {
        self.ctx = ctx
        self.source = source
    }
}

public struct AnigmaAddSourceResponse: Codable, Sendable {
    public var source: AnigmaSource?
    public var error: AnigmaErrorStatus?

    public init(source: AnigmaSource? = nil, error: AnigmaErrorStatus? = nil) {
        self.source = source
        self.error = error
    }
}

public struct AnigmaRemoveSourceRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var sourceId: String

    public init(ctx: AnigmaRequestContext, sourceId: String) {
        self.ctx = ctx
        self.sourceId = sourceId
    }
}

public struct AnigmaRemoveSourceResponse: Codable, Sendable {
    public var success: Bool
    public var error: AnigmaErrorStatus?

    public init(success: Bool = false, error: AnigmaErrorStatus? = nil) {
        self.success = success
        self.error = error
    }
}

public struct AnigmaUpdateSourceRequest: Codable, Sendable {
    public var ctx: AnigmaRequestContext
    public var source: AnigmaSource

    public init(ctx: AnigmaRequestContext, source: AnigmaSource) {
        self.ctx = ctx
        self.source = source
    }
}

public struct AnigmaUpdateSourceResponse: Codable, Sendable {
    public var source: AnigmaSource?
    public var error: AnigmaErrorStatus?

    public init(source: AnigmaSource? = nil, error: AnigmaErrorStatus? = nil) {
        self.source = source
        self.error = error
    }
}
