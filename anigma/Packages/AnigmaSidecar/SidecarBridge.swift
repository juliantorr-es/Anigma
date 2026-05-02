//
//  SidecarBridge.swift
//  AnigmaSidecar
//
//  Exclusive bridge between AnigmaAuthority and anigmad daemon using native JSON over HTTP.
//  This eliminates SwiftProtobuf and grpc-swift dependencies.
//

import AnigmaPrimitives
import AsyncHTTPClient
import Foundation
import NIOCore
import NIOPosix
import OSLog

public actor SidecarBridge {
    private static let logger = Logger(subsystem: "com.anigma.AnigmaSidecar", category: "SidecarBridge")
    private let httpClient: HTTPClient
    private let socketPath: String

    // Session state
    private var clientId: String
    private var capabilityToken: Data
    private let clientName: String
    private let requestedScopes: [String]

    // Health monitoring
    private var heartbeatTask: Task<Void, Never>?
    private var isHealthy: Bool = true
    private var lastHeartbeatAt: Date?
    private var reconnectionAttempts: Int = 0
    private let maxReconnectionAttempts: Int = 3
    private let heartbeatInterval: TimeInterval = 30.0

    // Health Observers
    private var healthContinuations: [UUID: AsyncStream<HealthStatus>.Continuation] = [:]
    
    // Performance optimizations
    private var artifactCache: [String: Data] = [:]
    private var requestMetrics: [String: [TimeInterval]] = [:]
    private var errorCount = 0
    private var totalRequests = 0

    private init(
        httpClient: HTTPClient,
        socketPath: String,
        clientName: String,
        requestedScopes: [String]
    ) {
        self.httpClient = httpClient
        self.socketPath = socketPath
        self.clientName = clientName
        self.requestedScopes = requestedScopes
        self.clientId = ""
        self.capabilityToken = Data()
    }

    deinit {
        heartbeatTask?.cancel()
        try? httpClient.syncShutdown()
        healthContinuations.values.forEach { $0.finish() }
    }

    public static func create(
        socketPath: String? = nil,
        clientName: String = "AnigmaAuthority",
        scopes: [String]? = nil
    ) async throws -> SidecarBridge {
        let path = socketPath ?? SidecarConfig.defaultUnixSocketPath()

        let httpClient = HTTPClient(
            eventLoopGroupProvider: .singleton,
            configuration: .init()
        )

        let requestedScopes = scopes ?? [
            "job.submit", "job.read", "vault.read", "vault.write", "receipt.verify",
            "system.read", "project.read", "project.write", "governance.write"
        ]

        let bridge = SidecarBridge(
            httpClient: httpClient,
            socketPath: path,
            clientName: clientName,
            requestedScopes: requestedScopes
        )

        try await bridge.openSession()
        await bridge.startHeartbeat()

        return bridge
    }

    private func makeRequestURL(_ path: String) -> String {
        let allowed = CharacterSet.urlHostAllowed
        let encodedSocket = socketPath.addingPercentEncoding(withAllowedCharacters: allowed) ?? socketPath
        return "http+unix://\(encodedSocket)\(path)"
    }

    private func openSession() async throws {
        Self.logger.info("Opening sidecar session for client '\(self.clientName, privacy: .public)'")
        let request = AnigmaOpenSessionRequest(
            requestedClientName: self.clientName,
            requestedScopes: self.requestedScopes
        )

        let response: AnigmaOpenSessionResponse = try await post("/session/open", body: request)

        guard !response.capabilityToken.isEmpty else {
            Self.logger.error("Daemon returned an empty capability token for client '\(self.clientName, privacy: .public)'")
            throw SidecarBridgeError.sessionFailed("Daemon did not issue a capability token.")
        }

        self.clientId = response.clientId
        self.capabilityToken = response.capabilityToken
        Self.logger.info("Opened sidecar session for clientId='\(self.clientId, privacy: .public)'")
    }

    private func makeContext() -> AnigmaRequestContext {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let nonce = Data(bytes).base64EncodedString()

        return AnigmaRequestContext(
            clientId: self.clientId,
            capabilityToken: self.capabilityToken,
            nonce: nonce
        )
    }

    public func submitJob(_ spec: AnigmaJobSpec) async throws -> AnigmaSubmitJobResponse {
        let request = AnigmaSubmitJobRequest(ctx: makeContext(), spec: spec)
        return try await post("/job/submit", body: request)
    }

    public func getStatus() async throws -> AnigmaStatusResponse {
        let request = AnigmaStatusRequest(ctx: makeContext())
        return try await post("/status", body: request)
    }

    public func getJobStatus(jobId: String) async throws -> AnigmaGetJobStatusResponse {
        let request = AnigmaGetJobStatusRequest(ctx: makeContext(), jobId: jobId)
        return try await post("/job/status", body: request)
    }

    public func getVaultStatus() async throws -> AnigmaVaultStatusResponse {
        let request = AnigmaVaultStatusRequest(ctx: makeContext())
        return try await post("/vault/status", body: request)
    }

    public func verifyVault() async throws -> AnigmaVaultVerifyResponse {
        let request = AnigmaVaultVerifyRequest(ctx: makeContext())
        return try await post("/vault/verify", body: request)
    }

    public func runVaultGC(dryRun: Bool) async throws -> AnigmaVaultGCResponse {
        let request = AnigmaVaultGCRequest(ctx: makeContext(), dryRun: dryRun)
        return try await post("/vault/gc", body: request)
    }

    public func listArtifacts(pageToken: String = "", pageSize: UInt32 = 0) async throws -> AnigmaListResponse {
        let request = AnigmaListRequest(ctx: makeContext(), pageToken: pageToken, pageSize: pageSize)
        return try await post("/artifacts/list", body: request)
    }

    public func cancelJob(jobId: String) async throws -> AnigmaCancelJobResponse {
        let request = AnigmaCancelJobRequest(ctx: makeContext(), jobId: jobId)
        return try await post("/job/cancel", body: request)
    }

    public func listTools() async throws -> AnigmaListToolsResponse {
        let request = AnigmaListToolsRequest(ctx: makeContext())
        return try await post("/tools/list", body: request)
    }

    public func onboardingStatus() async throws -> AnigmaOnboardingStatusResponse {
        let request = AnigmaOnboardingStatusRequest(ctx: makeContext())
        return try await post("/onboarding/status", body: request)
    }

    public func assistantStatus(projectId: String?) async throws -> AnigmaAssistantStatusResponse {
        let request = AnigmaAssistantStatusRequest(ctx: makeContext(), projectId: projectId)
        return try await post("/assistant/status", body: request)
    }

    public func assistantListProjects() async throws -> AnigmaAssistantListProjectsResponse {
        let request = AnigmaAssistantListProjectsRequest(ctx: makeContext())
        return try await post("/assistant/projects/list", body: request)
    }

    public func assistantCreateProject(
        id: String,
        name: String,
        embeddingModel: String,
        principalId: String,
        principalDisplayName: String
    ) async throws -> AnigmaAssistantCreateProjectResponse {
        let request = AnigmaAssistantCreateProjectRequest(
            ctx: makeContext(),
            id: id,
            name: name,
            embeddingModel: embeddingModel,
            principalId: principalId,
            principalDisplayName: principalDisplayName
        )
        return try await post("/assistant/projects/create", body: request)
    }

    public func assistantSetMode(
        mode: String,
        projectId: String?,
        principalId: String,
        principalDisplayName: String
    ) async throws -> AnigmaAssistantSetModeResponse {
        let request = AnigmaAssistantSetModeRequest(
            ctx: makeContext(),
            mode: mode,
            projectId: projectId,
            principalId: principalId,
            principalDisplayName: principalDisplayName
        )
        return try await post("/assistant/mode/set", body: request)
    }

    public func assistantSetKillSwitch(
        active: Bool,
        projectId: String?,
        reason: String?,
        principalId: String,
        principalDisplayName: String
    ) async throws -> AnigmaAssistantSetKillSwitchResponse {
        let request = AnigmaAssistantSetKillSwitchRequest(
            ctx: makeContext(),
            active: active,
            projectId: projectId,
            reason: reason,
            principalId: principalId,
            principalDisplayName: principalDisplayName
        )
        return try await post("/assistant/killswitch/set", body: request)
    }

    public func assistantRecall(
        query: String,
        projectId: String,
        options: AnigmaAssistantRecallOptions
    ) async throws -> AnigmaAssistantRecallResponse {
        let request = AnigmaAssistantRecallRequest(
            ctx: makeContext(),
            query: query,
            projectId: projectId,
            options: options
        )
        return try await post("/assistant/recall", body: request)
    }

    public func assistantAddMemo(
        text: String,
        projectId: String,
        principalId: String,
        principalDisplayName: String
    ) async throws -> AnigmaAssistantAddMemoResponse {
        let request = AnigmaAssistantAddMemoRequest(
            ctx: makeContext(),
            text: text,
            projectId: projectId,
            principalId: principalId,
            principalDisplayName: principalDisplayName
        )
        return try await post("/assistant/memo/add", body: request)
    }

    public func assistantStartIndex(
        folderPath: String,
        projectId: String,
        principalId: String,
        principalDisplayName: String,
        dryRun: Bool
    ) async throws -> AnigmaAssistantStartIndexResponse {
        let request = AnigmaAssistantStartIndexRequest(
            ctx: makeContext(),
            folderPath: folderPath,
            projectId: projectId,
            principalId: principalId,
            principalDisplayName: principalDisplayName,
            dryRun: dryRun
        )
        return try await post("/assistant/index/start", body: request)
    }

    public func getReceipt(receiptHash: String) async throws -> AnigmaReceiptResponse {
        let request = AnigmaReceiptRequest(ctx: makeContext(), receiptHash: receiptHash)
        return try await post("/receipt/get", body: request)
    }

    public func ingestArtifact(
        data: Data,
        kind: String = "blob",
        mediaType: String = "application/octet-stream",
        filenameHint: String? = nil
    ) async throws -> AnigmaIngestArtifactResponse {
        let request = AnigmaIngestArtifactRequest(
            ctx: makeContext(),
            mediaType: mediaType,
            filenameHint: filenameHint,
            data: data,
            kind: kind
        )
        return try await post("/artifacts/ingest", body: request)
    }

    public func retrieveArtifact(hash: String) async throws -> AnigmaRetrieveArtifactResponse {
        let request = AnigmaRetrieveArtifactRequest(ctx: makeContext(), hash: hash)
        return try await post("/artifacts/retrieve", body: request)
    }

    public func verifyChain(headReceiptHash: String) async throws -> AnigmaVerifyChainResponse {
        let request = AnigmaVerifyChainRequest(ctx: makeContext(), headReceiptHash: headReceiptHash)
        return try await post("/chain/verify", body: request)
    }

    // MARK: - Source Management

    public func listSources() async throws -> AnigmaListSourcesResponse {
        let request = AnigmaListSourcesRequest(ctx: makeContext())
        return try await post("/sources/list", body: request)
    }

    public func addSource(_ source: AnigmaSource) async throws -> AnigmaAddSourceResponse {
        let request = AnigmaAddSourceRequest(ctx: makeContext(), source: source)
        return try await post("/sources/add", body: request)
    }

    public func updateSource(_ source: AnigmaSource) async throws -> AnigmaUpdateSourceResponse {
        let request = AnigmaUpdateSourceRequest(ctx: makeContext(), source: source)
        return try await post("/sources/update", body: request)
    }

    public func removeSource(sourceId: String) async throws -> AnigmaRemoveSourceResponse {
        let request = AnigmaRemoveSourceRequest(ctx: makeContext(), sourceId: sourceId)
        return try await post("/sources/remove", body: request)
    }

    public func streamJobEvents(jobId: String) async throws -> AsyncThrowingStream<AnigmaJobEvent, Error> {
        let requestBody = AnigmaStreamJobEventsRequest(ctx: makeContext(), jobId: jobId)
        let data = try JSONEncoder().encode(requestBody)
        
        var request = HTTPClientRequest(url: makeRequestURL("/job/events/stream"))
        request.method = .POST
        request.headers.add(name: "Content-Type", value: "application/json")
        request.body = .bytes(data)
        
        let response = try await httpClient.execute(request, timeout: .seconds(30))
        
        guard response.status == .ok else {
            throw SidecarBridgeError.unavailable(nil)
        }
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await buffer in response.body {
                        let str = String(buffer: buffer)
                        let lines = str.split(separator: "\n", omittingEmptySubsequences: true)
                        for line in lines {
                            if let data = String(line).data(using: .utf8),
                               let event = try? JSONDecoder().decode(AnigmaJobEvent.self, from: data) {
                                continuation.yield(event)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func bridgeMCP(inputStream: AsyncStream<String>) async throws -> AsyncThrowingStream<String, Error> {
        let byteStream = inputStream.map { ByteBuffer(string: $0) }
        
        var request = HTTPClientRequest(url: makeRequestURL("/mcp"))
        request.method = .POST
        request.body = .stream(byteStream, length: .unknown)
        
        let response = try await httpClient.execute(request, timeout: .hours(24))
        
        guard response.status == .ok else {
            throw SidecarBridgeError.unavailable(nil)
        }
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await buffer in response.body {
                        let str = String(buffer: buffer)
                        continuation.yield(str)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Model Registry Operations

    public func listModels() async throws -> AnigmaListModelsResponse {
        let request = AnigmaListModelsRequest(ctx: makeContext())
        return try await post("/models/list", body: request)
    }

    public func installModel(modelId: String, repo: String? = nil, revision: String? = nil, name: String? = nil, modelType: String? = nil, sizeGB: Double? = nil, quantization: String? = nil) async throws -> AnigmaInstallModelResponse {
        let request = AnigmaInstallModelRequest(
            ctx: makeContext(),
            modelId: modelId,
            repo: repo,
            revision: revision,
            name: name,
            modelType: modelType,
            sizeGB: sizeGB,
            quantization: quantization
        )
        return try await post("/models/install", body: request)
    }

    public func verifyModel(modelId: String) async throws -> AnigmaVerifyModelResponse {
        let request = AnigmaVerifyModelRequest(ctx: makeContext(), modelId: modelId)
        return try await post("/models/verify", body: request)
    }

    public func deleteModel(modelId: String) async throws -> AnigmaDeleteModelResponse {
        let request = AnigmaDeleteModelRequest(ctx: makeContext(), modelId: modelId)
        return try await post("/models/delete", body: request)
    }

    // MARK: - Pipeline Operations

    public func listPipelines() async throws -> AnigmaPipelineListResponse {
        let request = AnigmaPipelineListRequest(ctx: makeContext())
        return try await post("/pipelines/list", body: request)
    }

    public func createPipeline(name: String, stages: [PipelineStage]) async throws -> AnigmaPipelineCreateResponse {
        let request = AnigmaPipelineCreateRequest(ctx: makeContext(), name: name, stages: stages)
        return try await post("/pipelines/create", body: request)
    }

    public func runPipeline(pipelineId: String, inputs: [String: String]) async throws -> AnigmaPipelineRunResponse {
        let request = AnigmaPipelineRunRequest(ctx: makeContext(), pipelineId: pipelineId, inputs: inputs)
        return try await post("/pipelines/run", body: request)
    }

    public func getPipelineStatus(runId: String) async throws -> AnigmaPipelineStatusResponse {
        let request = AnigmaPipelineStatusRequest(ctx: makeContext(), runId: runId)
        return try await post("/pipelines/status", body: request)
    }

    public func cancelPipeline(runId: String) async throws -> AnigmaPipelineCancelResponse {
        let request = AnigmaPipelineCancelRequest(ctx: makeContext(), runId: runId)
        return try await post("/pipelines/cancel", body: request)
    }

    // MARK: - ML Operations

    public func chat(
        messages: [ChatMessage],
        model: String? = nil,
        temperature: Double = 0.7,
        provider: String? = nil,
        sessionId: String? = nil
    ) async throws -> String {
        let request = AnigmaChatRequest(
            ctx: makeContext(),
            messages: messages,
            model: model,
            temperature: temperature,
            provider: provider,
            sessionId: sessionId
        )
        let response: AnigmaChatResponse = try await post("/ml/chat", body: request)
        return response.message
    }

    public func embed(text: String, model: String, sessionId: String? = nil) async throws -> AnigmaEmbedResponse {
        let request = AnigmaEmbedRequest(
            ctx: makeContext(),
            text: text,
            model: model,
            sessionId: sessionId
        )
        return try await post("/ml/embed", body: request)
    }

    public func search(query: String, model: String, topK: Int = 10, threshold: Double = 0.7, sessionId: String? = nil) async throws -> AnigmaSearchResponse {
        let request = AnigmaSearchRequest(
            ctx: makeContext(),
            query: query,
            model: model,
            topK: topK,
            threshold: threshold,
            sessionId: sessionId
        )
        return try await post("/ml/search", body: request)
    }

    // MARK: - Evidence Operations

    public func getSessionEvidence(sessionId: String) async throws -> AnigmaSessionEvidenceResponse {
        let request = AnigmaSessionEvidenceRequest(
            ctx: makeContext(),
            sessionId: sessionId
        )
        return try await post("/evidence/session/\(sessionId)", body: request)
    }

    // MARK: - Plan Coordination

    public func submitPlan(operationType: String, parameters: [String: String], priority: String = "normal") async throws -> AnigmaPlanSubmitResponse {
        let request = AnigmaPlanSubmitRequest(
            ctx: makeContext(),
            operationType: operationType,
            sessionContext: nil,
            parameters: parameters,
            priority: priority
        )
        return try await post("/plan/submit", body: request)
    }

    // MARK: - Agent Operations

    public func runAgent(agentId: String, task: String, parameters: [String: String]? = nil) async throws -> AnigmaAgentRunResponse {
        let request = AnigmaAgentRunRequest(
            ctx: makeContext(),
            agentId: agentId,
            task: task,
            parameters: parameters
        )
        return try await post("/agents/run", body: request)
    }

    // MARK: - Export Operations

    public func startExport(format: String, documentIds: [String], options: [String: String]? = nil) async throws -> AnigmaExportStartResponse {
        let request = AnigmaExportStartRequest(
            ctx: makeContext(),
            format: format,
            documentIds: documentIds,
            options: options
        )
        return try await post("/export/start", body: request)
    }

    public func healthCheck() async throws -> Bool {
        do {
            var request = HTTPClientRequest(url: makeRequestURL("/health"))
            request.method = .GET
            let response = try await httpClient.execute(request, timeout: .seconds(5))
            
            if response.status == .ok {
                let bodyData = try await response.body.collect(upTo: 1 * 1024 * 1024)
                let health = try JSONDecoder().decode(AnigmaHealthResponse.self, from: bodyData)
                return health.ok
            }
            return false
        } catch {
            return false
        }
    }

    // MARK: - WebServer API Methods (Phase 4 - Client Thinning)
    // Note: Using /web/ prefix for WebServer-specific routes to avoid conflicts with daemon routes

    /// WebServer health check
    public func webHealthCheck() async throws -> AnigmaWebHealthResponse {
        return try await get("/web/health")
    }

    // Plan methods
    public func webSubmitPlan(
        operationType: String,
        sessionContext: String? = nil,
        parameters: [String: String] = [:],
        priority: String = "normal"
    ) async throws -> AnigmaWebPlanSubmissionResponse {
        let request = AnigmaWebPlanSubmissionRequest(
            ctx: makeContext(),
            operationType: operationType,
            sessionContext: sessionContext,
            parameters: parameters,
            priority: priority
        )
        return try await post("/web/plan/submit", body: request)
    }

    public func webInspectPlan(planId: String, includeEvidence: Bool = false) async throws -> AnigmaWebPlanInspectionResponse {
        return try await get("/web/plan/" + planId + "/inspect")
    }

    public func webExecutePlan(planId: String, outputs: [String: String] = [:]) async throws -> AnigmaWebPlanExecutionResponse {
        let request = AnigmaWebPlanExecutionRequest(
            ctx: makeContext(),
            planId: planId,
            outputs: outputs
        )
        return try await post("/web/plan/" + planId + "/execute", body: request)
    }

    // Bundle export methods
    public func webExportBundle(reason: String, timeRangeHours: Int, requestorId: String) async throws -> AnigmaWebEvidenceBundleResponse {
        let request = AnigmaWebBundleExportRequest(
            ctx: makeContext(),
            reason: reason,
            timeRangeHours: timeRangeHours,
            requestorId: requestorId
        )
        return try await post("/web/bundle/export", body: request)
    }

    public func webEvidenceBundle(sessionId: String, reason: String? = nil) async throws -> AnigmaWebEvidenceBundleResponse {
        let request = AnigmaWebEvidenceBundleRequest(
            ctx: makeContext(),
            sessionId: sessionId,
            reason: reason
        )
        return try await post("/web/evidence/bundle", body: request)
    }

    // ML methods
    public func webEmbed(text: String, model: String, sessionId: String? = nil) async throws -> AnigmaEmbedResponse {
        let request = AnigmaEmbedRequest(
            ctx: makeContext(),
            text: text,
            model: model,
            sessionId: sessionId
        )
        return try await post("/web/ml/embed", body: request)
    }

    public func webSearch(query: String, model: String, topK: Int = 10, threshold: Double = 0.7, sessionId: String? = nil) async throws -> AnigmaSearchResponse {
        let request = AnigmaSearchRequest(
            ctx: makeContext(),
            query: query,
            model: model,
            topK: topK,
            threshold: threshold,
            sessionId: sessionId
        )
        return try await post("/web/ml/search", body: request)
    }

    public func webGenerate(prompt: String, model: String, maxTokens: Int? = nil, sessionId: String? = nil) async throws -> AnigmaWebGenerateResponse {
        let request = AnigmaWebGenerateRequest(
            ctx: makeContext(),
            prompt: prompt,
            model: model,
            maxTokens: maxTokens,
            sessionId: sessionId
        )
        return try await post("/web/ml/generate", body: request)
    }

    // Evidence methods
    public func webGetSessionEvidence(sessionId: String) async throws -> AnigmaSessionEvidenceResponse {
        // GET request - need to use get method
        return try await get("/web/evidence/session/" + sessionId)
    }

    public func webGetComplianceReport(sessionId: String) async throws -> AnigmaWebComplianceReportResponse {
        return try await get("/web/evidence/compliance/" + sessionId)
    }

    // Document methods
    public func webAcquireDocument(
        documentId: String,
        filePath: String,
        sessionId: String,
        metadata: [String: String]? = nil
    ) async throws -> AnigmaWebDocumentAcquireResponse {
        let request = AnigmaWebDocumentAcquireRequest(
            ctx: makeContext(),
            documentId: documentId,
            filePath: filePath,
            sessionId: sessionId,
            metadata: metadata
        )
        return try await post("/web/documents/acquire", body: request)
    }

    public func webTransformDocument(
        documentId: String,
        transformationType: String,
        toolName: String,
        toolVersion: String,
        inputHash: String,
        outputHash: String,
        sessionId: String,
        parameters: [String: String]? = nil
    ) async throws -> AnigmaWebDocumentTransformResponse {
        let request = AnigmaWebDocumentTransformRequest(
            ctx: makeContext(),
            documentId: documentId,
            transformationType: transformationType,
            toolName: toolName,
            toolVersion: toolVersion,
            inputHash: inputHash,
            outputHash: outputHash,
            sessionId: sessionId,
            parameters: parameters
        )
        return try await post("/web/documents/transform", body: request)
    }

    // MARK: - HTTP Helpers with Enhanced Error Handling

    private func post<In: Encodable, Out: Decodable>(
        _ path: String,
        body: In,
        maxRetries: Int = 3,
        timeout: TimeInterval = 30.0
    ) async throws -> Out {
        let startTime = Date()
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                let data = try JSONEncoder().encode(body)
                Self.logger.debug("POST \(path, privacy: .public) attempt \(attempt)")
                
                var request = HTTPClientRequest(url: makeRequestURL(path))
                request.method = .POST
                request.headers.add(name: "Content-Type", value: "application/json")
                request.body = .bytes(data)
                
                let response = try await httpClient.execute(request, timeout: .seconds(Int64(timeout)))
                
                if response.status == .ok {
                    let bodyData = try await response.body.collect(upTo: Int(10 * 1024 * 1024)) // 10MB limit
                    
                    // Track metrics
                    let latency = Date().timeIntervalSince(startTime)
                    trackRequestMetrics(path: path, latency: latency, success: true)
                    Self.logger.debug("POST \(path, privacy: .public) succeeded in \(latency, privacy: .public)s")
                    
                    return try JSONDecoder().decode(Out.self, from: bodyData)
                } else {
                    let error = SidecarBridgeError.unavailable(nil)
                    trackRequestMetrics(path: path, latency: Date().timeIntervalSince(startTime), success: false)
                    Self.logger.error("POST \(path, privacy: .public) failed with status \(response.status.code, privacy: .public)")
                    
                    if attempt < maxRetries && shouldRetry(statusCode: Int(response.status.code)) {
                        try await exponentialBackoff(attempt: attempt)
                        continue
                    }
                    throw error
                }
            } catch {
                lastError = error
                trackRequestMetrics(path: path, latency: Date().timeIntervalSince(startTime), success: false)
                Self.logger.error("POST \(path, privacy: .public) error on attempt \(attempt): \(error.localizedDescription, privacy: .public)")
                
                if attempt < maxRetries && isRetryableError(error) {
                    try await exponentialBackoff(attempt: attempt)
                    continue
                }
            }
        }
        
        throw lastError ?? SidecarBridgeError.unavailable(nil)
    }

    private func get<Out: Decodable>(
        _ path: String,
        maxRetries: Int = 2,
        timeout: TimeInterval = 5.0
    ) async throws -> Out {
        let startTime = Date()
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                var request = HTTPClientRequest(url: makeRequestURL(path))
                request.method = .GET
                
                let response = try await httpClient.execute(request, timeout: .seconds(Int64(timeout)))
                
                if response.status == .ok {
                    let bodyData = try await response.body.collect(upTo: Int(1 * 1024 * 1024)) // 1MB limit
                    
                    // Track metrics
                    let latency = Date().timeIntervalSince(startTime)
                    trackRequestMetrics(path: path, latency: latency, success: true)
                    
                    return try JSONDecoder().decode(Out.self, from: bodyData)
                } else {
                    let error = SidecarBridgeError.unavailable(nil)
                    trackRequestMetrics(path: path, latency: Date().timeIntervalSince(startTime), success: false)
                    
                    if attempt < maxRetries && shouldRetry(statusCode: Int(response.status.code)) {
                        try await exponentialBackoff(attempt: attempt)
                        continue
                    }
                    throw error
                }
            } catch {
                lastError = error
                trackRequestMetrics(path: path, latency: Date().timeIntervalSince(startTime), success: false)
                
                if attempt < maxRetries && isRetryableError(error) {
                    try await exponentialBackoff(attempt: attempt)
                    continue
                }
            }
        }
        
        throw lastError ?? SidecarBridgeError.unavailable(nil)
    }
    
    // MARK: - Retry Logic Helpers
    
    private func exponentialBackoff(attempt: Int) async throws {
        let delay = pow(2.0, Double(attempt - 1)) * 0.5 // 0.5s, 1s, 2s, etc.
        try await Task.sleep(for: .seconds(delay))
    }
    
    private func shouldRetry(statusCode: Int) -> Bool {
        // Retry on 5xx errors, 429 (rate limit), 408 (timeout)
        return statusCode >= 500 || statusCode == 429 || statusCode == 408
    }
    
    private func isRetryableError(_ error: Error) -> Bool {
        // Retry on network errors, timeouts, but not on decoding errors
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain &&
            (nsError.code == NSURLErrorTimedOut ||
             nsError.code == NSURLErrorCannotConnectToHost ||
             nsError.code == NSURLErrorNetworkConnectionLost ||
             nsError.code == NSURLErrorNotConnectedToInternet)
    }
    
    private func trackRequestMetrics(path: String, latency: TimeInterval, success: Bool) {
        totalRequests += 1
        if !success {
            errorCount += 1
        }
        
        if requestMetrics[path] == nil {
            requestMetrics[path] = []
        }
        requestMetrics[path]?.append(latency)
        
        // Keep only recent metrics (last 1000 requests per path)
        if let metrics = requestMetrics[path], metrics.count > 1000 {
            requestMetrics[path] = Array(metrics.suffix(1000))
        }
    }

    // MARK: - Heartbeat & Connectivity

    private func startHeartbeat() {
        heartbeatTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(heartbeatInterval))
                let healthy = try? await healthCheck()
                self.isHealthy = healthy ?? false
                self.lastHeartbeatAt = Date()
                notifyHealthChange()
            }
        }
    }

    private func notifyHealthChange() {
        let status = self.healthStatus
        for continuation in healthContinuations.values {
            continuation.yield(status)
        }
    }

    public var healthStatus: HealthStatus {
        HealthStatus(
            isHealthy: isHealthy,
            lastHeartbeatAt: lastHeartbeatAt,
            reconnectionAttempts: reconnectionAttempts
        )
    }
}

public struct HealthStatus: Sendable {
    public let isHealthy: Bool
    public let lastHeartbeatAt: Date?
    public let reconnectionAttempts: Int
}

public enum SidecarBridgeError: Error, LocalizedError {
    case unavailable(Error?)
    case sessionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unavailable(let error):
            return "Anigma daemon unavailable: \(error?.localizedDescription ?? "No details")"
        case .sessionFailed(let message):
            return "Failed to open session with Anigma daemon: \(message)"
        }
    }
}

// MARK: - CLI-Specific Extensions

public extension SidecarBridge {
    
    // MARK: - CLI Convenience Methods
    
    /// Submit a chat request with CLI-specific options
    func submitChatRequest(
        _ message: String,
        model: String? = nil,
        temperature: Double = 0.7,
        stream: Bool = false,
        sessionId: String? = nil
    ) async throws -> AsyncThrowingStream<String, Error> {
        let messages = [ChatMessage(role: "user", content: message)]
        
        if stream {
            return try await streamChatResponse(
                messages: messages,
                model: model,
                temperature: temperature,
                sessionId: sessionId
            )
        } else {
            let response = try await chat(
                messages: messages,
                model: model,
                temperature: temperature,
                sessionId: sessionId
            )
            return AsyncThrowingStream { continuation in
                continuation.yield(response)
                continuation.finish()
            }
        }
    }
    
    /// Execute a tool with CLI-specific error handling
    func executeTool(
        name: String,
        arguments: [String: AnyCodable],
        sessionId: String? = nil,
        maxRetries: Int = 3
    ) async throws -> [String: AnyCodable] {
        let request = AnigmaToolExecuteRequest(
            ctx: makeContext(),
            toolName: name,
            arguments: arguments,
            sessionId: sessionId
        )
        
        var lastError: Error?
        for attempt in 1...maxRetries {
            do {
                let response: AnigmaToolExecuteResponse = try await post("/tools/execute", body: request)
                return response.result
            } catch {
                lastError = error
                if attempt < maxRetries {
                    try? await Task.sleep(for: .seconds(Double(attempt) * 0.5))
                }
            }
        }
        
        throw lastError ?? SidecarBridgeError.unavailable(nil)
    }
    
    /// Manage worktree operations (create, delete, list)
    func manageWorktree(
        operation: WorktreeOperation,
        path: String? = nil,
        branch: String? = nil
    ) async throws -> WorktreeResult {
        let request = AnigmaWorktreeRequest(
            ctx: makeContext(),
            operation: operation.rawValue,
            path: path,
            branch: branch
        )
        
        let response: AnigmaWorktreeResponse = try await post("/worktree/manage", body: request)
        return WorktreeResult(
            success: response.success,
            message: response.message,
            path: response.path
        )
    }
    
    /// Upload file with progress reporting
    func uploadFile(
        _ fileURL: URL,
        kind: String = "blob",
        mediaType: String? = nil,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> AnigmaIngestArtifactResponse {
        let data = try Data(contentsOf: fileURL)
        let filename = fileURL.lastPathComponent
        let mimeType = mediaType ?? mimeTypeForFile(at: fileURL)
        
        // In a real implementation, this would stream with progress
        // For now, we'll simulate progress for large files
        if let progressHandler = progressHandler, data.count > 1024 * 1024 {
            progressHandler(0.25)
            try? await Task.sleep(for: .milliseconds(100))
            progressHandler(0.5)
            try? await Task.sleep(for: .milliseconds(100))
            progressHandler(0.75)
            try? await Task.sleep(for: .milliseconds(100))
        }
        
        let response = try await ingestArtifact(
            data: data,
            kind: kind,
            mediaType: mimeType,
            filenameHint: filename
        )
        
        progressHandler?(1.0)
        return response
    }
    
    /// Download file with progress reporting
    func downloadFile(
        hash: String,
        to destinationURL: URL,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws {
        let response = try await retrieveArtifact(hash: hash)
        let data = response.data
        
        // Simulate progress for large files
        if let progressHandler = progressHandler, data.count > 1024 * 1024 {
            progressHandler(0.25)
            try? await Task.sleep(for: .milliseconds(100))
            progressHandler(0.5)
            try? await Task.sleep(for: .milliseconds(100))
            progressHandler(0.75)
            try? await Task.sleep(for: .milliseconds(100))
        }
        
        try data.write(to: destinationURL)
        progressHandler?(1.0)
    }
    
    /// Get system status with CLI-friendly formatting
    func getSystemStatus() async throws -> SystemStatus {
        let status = try await getStatus()
        // Parse extra JSON for additional metrics if available
        var uptime: TimeInterval = 0
        var activeJobs = 0
        var totalMemory: UInt64 = 0
        var usedMemory: UInt64 = 0
        var modelCount = 0
        var artifactCount = 0
        
        if let extraJson = status.extraJson, let data = extraJson.data(using: .utf8) {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                uptime = json["uptime"] as? TimeInterval ?? 0
                activeJobs = json["activeJobs"] as? Int ?? 0
                totalMemory = json["totalMemory"] as? UInt64 ?? 0
                usedMemory = json["usedMemory"] as? UInt64 ?? 0
                modelCount = json["modelCount"] as? Int ?? 0
                artifactCount = json["artifactCount"] as? Int ?? 0
            }
        }
        
        return SystemStatus(
            daemonVersion: status.daemonVersion,
            uptime: uptime,
            activeJobs: activeJobs,
            totalMemory: totalMemory,
            usedMemory: usedMemory,
            modelCount: modelCount,
            artifactCount: artifactCount
        )
    }
    
    /// Run governance checks with CLI output
    func runGovernanceChecks(
        files: [String]? = nil,
        strict: Bool = false
    ) async throws -> GovernanceReport {
        let request = AnigmaGovernanceRequest(
            ctx: makeContext(),
            files: files,
            strict: strict
        )
        
        let response: AnigmaGovernanceResponse = try await post("/governance/check", body: request)
        return GovernanceReport(
            passed: response.passed,
            warnings: response.warnings,
            errors: response.errors,
            details: response.details
        )
    }
    
    // MARK: - Session Management
    
    /// Create a persistent session for long-running operations
    func createSession(
        name: String,
        timeout: TimeInterval = 3600,
        capabilities: [String] = ["read", "write", "execute"]
    ) async throws -> CLISession {
        let request = AnigmaCreateSessionRequest(
            ctx: makeContext(),
            name: name,
            timeout: timeout,
            capabilities: capabilities
        )
        
        let response: AnigmaCreateSessionResponse = try await post("/session/create", body: request)
        return CLISession(
            id: response.sessionId,
            name: name,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(timeout),
            capabilities: capabilities
        )
    }
    
    /// Keep session alive (heartbeat)
    func keepAlive(sessionId: String) async throws -> Bool {
        let request = AnigmaKeepAliveRequest(
            ctx: makeContext(),
            sessionId: sessionId
        )
        
        let response: AnigmaKeepAliveResponse = try await post("/session/keepalive", body: request)
        return response.success
    }
    
    // MARK: - Performance Optimizations
    
    /// Batch submit multiple jobs
    func batchSubmitJobs(
        _ specs: [AnigmaJobSpec],
        parallel: Bool = true
    ) async throws -> [AnigmaSubmitJobResponse] {
        let request = AnigmaBatchJobRequest(
            ctx: makeContext(),
            specs: specs,
            parallel: parallel
        )
        
        let response: AnigmaBatchJobResponse = try await post("/job/batch", body: request)
        return response.results
    }
    
    /// Cache artifact retrieval
    func retrieveArtifactCached(
        hash: String,
        ttl: TimeInterval = 300
    ) async throws -> Data {
        if let cached = artifactCache[hash] {
            return cached
        }
        
        let response = try await retrieveArtifact(hash: hash)
        let data = response.data
        
        artifactCache[hash] = data
        
        // Schedule cache cleanup
        Task {
            try await Task.sleep(for: .seconds(ttl))
            artifactCache.removeValue(forKey: hash)
        }
        
        return data
    }
    
    // MARK: - Telemetry
    
    struct TelemetryMetrics {
        let requestCount: Int
        let errorCount: Int
        let averageLatency: TimeInterval
        let cacheHitRate: Double
        let activeConnections: Int
    }
    
    func getTelemetryMetrics() -> TelemetryMetrics {
        let totalLatency = requestMetrics.values.flatMap { $0 }.reduce(0, +)
        let requestCount = requestMetrics.values.map { $0.count }.reduce(0, +)
        let avgLatency = requestCount > 0 ? totalLatency / Double(requestCount) : 0
        
        let cacheHits = artifactCache.count
        let cacheRequests = totalRequests
        let hitRate = cacheRequests > 0 ? Double(cacheHits) / Double(cacheRequests) : 0
        
        return TelemetryMetrics(
            requestCount: totalRequests,
            errorCount: errorCount,
            averageLatency: avgLatency,
            cacheHitRate: hitRate,
            activeConnections: 1 // HTTP client connection count
        )
    }
    
    // MARK: - Private Helpers
    
    private func streamChatResponse(
        messages: [ChatMessage],
        model: String? = nil,
        temperature: Double = 0.7,
        sessionId: String? = nil
    ) async throws -> AsyncThrowingStream<String, Error> {
        let request = AnigmaStreamChatRequest(
            ctx: makeContext(),
            messages: messages,
            model: model,
            temperature: temperature,
            sessionId: sessionId
        )
        
        let data = try JSONEncoder().encode(request)
        
        var httpRequest = HTTPClientRequest(url: makeRequestURL("/ml/chat/stream"))
        httpRequest.method = .POST
        httpRequest.headers.add(name: "Content-Type", value: "application/json")
        httpRequest.body = .bytes(data)
        
        let response = try await httpClient.execute(httpRequest, timeout: .seconds(30))
        
        guard response.status == .ok else {
            throw SidecarBridgeError.unavailable(nil)
        }
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await buffer in response.body {
                        let str = String(buffer: buffer)
                        let lines = str.split(separator: "\n", omittingEmptySubsequences: true)
                        for line in lines {
                            if let data = String(line).data(using: .utf8),
                               let chunk = try? JSONDecoder().decode(ChatChunk.self, from: data) {
                                continuation.yield(chunk.text)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    private func mimeTypeForFile(at url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "txt": return "text/plain"
        case "json": return "application/json"
        case "swift": return "text/x-swift"
        case "py": return "text/x-python"
        case "js", "ts": return "text/javascript"
        case "html": return "text/html"
        case "css": return "text/css"
        case "md", "markdown": return "text/markdown"
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "pdf": return "application/pdf"
        case "zip": return "application/zip"
        default: return "application/octet-stream"
        }
    }
}

// MARK: - CLI Data Types

public enum WorktreeOperation: String {
    case create
    case delete
    case list
    case switchBranch = "switch"
}

public struct WorktreeResult {
    public let success: Bool
    public let message: String
    public let path: String?
}

public struct SystemStatus {
    public let daemonVersion: String
    public let uptime: TimeInterval
    public let activeJobs: Int
    public let totalMemory: UInt64
    public let usedMemory: UInt64
    public let modelCount: Int
    public let artifactCount: Int
}

public struct GovernanceReport {
    public let passed: Bool
    public let warnings: [String]
    public let errors: [String]
    public let details: [String: AnyCodable]
}

public struct CLISession {
    public let id: String
    public let name: String
    public let createdAt: Date
    public let expiresAt: Date
    public let capabilities: [String]
}

public struct ChatChunk: Codable {
    public let text: String
    public let done: Bool
}

// MARK: - Request/Response Types for CLI Extensions

public struct AnigmaToolExecuteRequest: Codable {
    public let ctx: AnigmaRequestContext
    public let toolName: String
    public let arguments: [String: AnyCodable]
    public let sessionId: String?
    
    public init(ctx: AnigmaRequestContext, toolName: String, arguments: [String: AnyCodable], sessionId: String?) {
        self.ctx = ctx
        self.toolName = toolName
        self.arguments = arguments
        self.sessionId = sessionId
    }
}

public struct AnigmaToolExecuteResponse: Codable {
    public let success: Bool
    public let result: [String: AnyCodable]
    public let error: String?
}

public struct AnigmaWorktreeRequest: Codable {
    public let ctx: AnigmaRequestContext
    public let operation: String
    public let path: String?
    public let branch: String?
}

public struct AnigmaWorktreeResponse: Codable {
    public let success: Bool
    public let message: String
    public let path: String?
}

public struct AnigmaGovernanceRequest: Codable {
    public let ctx: AnigmaRequestContext
    public let files: [String]?
    public let strict: Bool
}

public struct AnigmaGovernanceResponse: Codable {
    public let passed: Bool
    public let warnings: [String]
    public let errors: [String]
    public let details: [String: AnyCodable]
}

public struct AnigmaCreateSessionRequest: Codable {
    public let ctx: AnigmaRequestContext
    public let name: String
    public let timeout: TimeInterval
    public let capabilities: [String]
}

public struct AnigmaCreateSessionResponse: Codable {
    public let sessionId: String
    public let success: Bool
}

public struct AnigmaKeepAliveRequest: Codable {
    public let ctx: AnigmaRequestContext
    public let sessionId: String
}

public struct AnigmaKeepAliveResponse: Codable {
    public let success: Bool
}

public struct AnigmaBatchJobRequest: Codable {
    public let ctx: AnigmaRequestContext
    public let specs: [AnigmaJobSpec]
    public let parallel: Bool
}

public struct AnigmaBatchJobResponse: Codable {
    public let results: [AnigmaSubmitJobResponse]
}

public struct AnigmaStreamChatRequest: Codable {
    public let ctx: AnigmaRequestContext
    public let messages: [ChatMessage]
    public let model: String?
    public let temperature: Double
    public let sessionId: String?
}

public struct AnigmaStreamChatResponse: Codable {
    public let content: String
    public let done: Bool
    public let error: String?
}

public struct AnigmaVaultStatusRequest: Codable {
    public let ctx: AnigmaRequestContext
    public init(ctx: AnigmaRequestContext) {
        self.ctx = ctx
    }
}

public struct AnigmaVaultStatusResponse: Codable {
    public let isHealthy: Bool
    public let receiptCount: Int
    public let diskUsage: String
    public let headHash: String
    public let lastVerifiedAt: Date?
    public let error: AnigmaErrorStatus?
}

public struct AnigmaVaultVerifyRequest: Codable {
    public let ctx: AnigmaRequestContext
    public init(ctx: AnigmaRequestContext) {
        self.ctx = ctx
    }
}

public struct AnigmaVaultVerifyResponse: Codable {
    public let success: Bool
    public let message: String
    public let error: AnigmaErrorStatus?
}

public struct AnigmaVaultGCRequest: Codable {
    public let ctx: AnigmaRequestContext
    public let dryRun: Bool
    public init(ctx: AnigmaRequestContext, dryRun: Bool) {
        self.ctx = ctx
        self.dryRun = dryRun
    }
}

public struct AnigmaVaultGCResponse: Codable {
    public let success: Bool
    public let deletedCount: Int
    public let reclaimedSpace: String
    public let error: AnigmaErrorStatus?
}

// MARK: - AnyCodable (canonicalized to AnigmaPrimitives)

import AnigmaPrimitives

public typealias AnyCodable = AnigmaPrimitives.AnyCodable
