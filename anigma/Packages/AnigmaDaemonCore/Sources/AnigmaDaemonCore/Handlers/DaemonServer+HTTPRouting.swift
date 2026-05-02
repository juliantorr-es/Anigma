//
//  DaemonServer+HTTPRouting.swift
//  AnigmaDaemonCore
//

import AnigmaPrimitives
import Foundation
import OSLog

private let routingLogger = Logger(subsystem: "com.anigma.AnigmaDaemonCore", category: "HTTPRouting")

extension DaemonServer {
    func handleHTTPRequest(_ request: HTTPRequest) async -> HTTPResponse {
        routingLogger.debug("Dispatching HTTP \(request.method, privacy: .public) \(request.path, privacy: .public)")
        do {
            switch (request.method.uppercased(), request.path) {
            case ("GET", "/health"):
                return try makeJSONResponse(await handleHealthCheck())

            case ("POST", "/session/open"):
                let body: AnigmaOpenSessionRequest = try decodeRequestBody(request)
                let response = await handleOpenSession(
                    requestedClientName: body.requestedClientName,
                    requestedScopes: body.requestedScopes
                )
                return try makeJSONResponse(response)

            case ("POST", "/status"):
                let body: AnigmaStatusRequest = try decodeRequestBody(request)
                return try makeJSONResponse(try await handleGetStatus(ctx: body.ctx))

            case ("POST", "/job/submit"):
                let body: AnigmaSubmitJobRequest = try decodeRequestBody(request)
                return try makeJSONResponse(try await handleSubmitJob(ctx: body.ctx, spec: body.spec))

            case ("POST", "/job/status"):
                let body: AnigmaGetJobStatusRequest = try decodeRequestBody(request)
                return try makeJSONResponse(try await handleGetJobStatus(ctx: body.ctx, jobId: body.jobId))

            case ("POST", "/job/cancel"):
                let body: AnigmaCancelJobRequest = try decodeRequestBody(request)
                return try makeJSONResponse(try await handleCancelJob(ctx: body.ctx, jobId: body.jobId))

            case ("POST", "/artifacts/list"):
                let body: AnigmaListRequest = try decodeRequestBody(request)
                let result = try await handleListArtifacts(
                    ctx: body.ctx,
                    pageToken: body.pageToken.isEmpty ? nil : body.pageToken,
                    pageSize: body.pageSize > 0 ? Int(body.pageSize) : nil
                )
                return try makeJSONResponse(
                    AnigmaListResponse(
                        artifacts: result.artifacts,
                        nextPageToken: result.nextPageToken ?? "",
                        error: nil
                    )
                )

            case ("POST", "/artifacts/retrieve"):
                let body: AnigmaRetrieveArtifactRequest = try decodeRequestBody(request)
                let result = try await handleRetrieveArtifact(ctx: body.ctx, hash: body.hash)
                return try makeJSONResponse(
                    AnigmaRetrieveArtifactResponse(
                        data: result.data,
                        receiptHash: result.receiptHash ?? ""
                    )
                )

            case ("POST", "/tools/list"):
                let body: AnigmaListToolsRequest = try decodeRequestBody(request)
                return try makeJSONResponse(try await handleListTools(ctx: body.ctx))

            case ("POST", "/onboarding/status"):
                let body: AnigmaOnboardingStatusRequest = try decodeRequestBody(request)
                return try makeJSONResponse(try await handleOnboardingStatus(ctx: body.ctx))

            case ("POST", "/receipt/get"):
                let body: AnigmaReceiptRequest = try decodeRequestBody(request)
                let result = await handleGetReceipt(ctx: body.ctx, receiptHash: body.receiptHash)
                let receiptCanonicalJson: String
                if let receipt = result.receipt {
                    let encoder = JSONEncoder()
                    encoder.dateEncodingStrategy = .iso8601
                    let data = try encoder.encode(receipt)
                    receiptCanonicalJson = String(data: data, encoding: .utf8) ?? ""
                } else {
                    receiptCanonicalJson = ""
                }
                return try makeJSONResponse(
                    AnigmaReceiptResponse(
                        receiptCanonicalJson: receiptCanonicalJson,
                        error: result.error
                    )
                )

            case ("POST", "/chain/verify"):
                let body: AnigmaVerifyChainRequest = try decodeRequestBody(request)
                let result = await handleVerifyChain(ctx: body.ctx, headReceiptHash: body.headReceiptHash)
                return try makeJSONResponse(
                    AnigmaVerifyChainResponse(ok: result.ok, message: result.message, error: result.error)
                )

            case ("POST", "/assistant/status"):
                let body: AnigmaAssistantStatusRequest = try decodeRequestBody(request)
                return try makeJSONResponse(try await handleAssistantStatus(ctx: body.ctx, request: body))

            case ("POST", "/assistant/projects/list"):
                let body: AnigmaAssistantListProjectsRequest = try decodeRequestBody(request)
                return try makeJSONResponse(try await handleAssistantListProjects(ctx: body.ctx))

            case ("POST", "/assistant/projects/create"):
                let body: AnigmaAssistantCreateProjectRequest = try decodeRequestBody(request)
                return try makeJSONResponse(try await handleAssistantCreateProject(ctx: body.ctx, request: body))

            case ("POST", "/assistant/mode/set"):
                let body: AnigmaAssistantSetModeRequest = try decodeRequestBody(request)
                return try makeJSONResponse(try await handleAssistantSetMode(ctx: body.ctx, request: body))

            case ("POST", "/assistant/killswitch/set"):
                let body: AnigmaAssistantSetKillSwitchRequest = try decodeRequestBody(request)
                return try makeJSONResponse(try await handleAssistantSetKillSwitch(ctx: body.ctx, request: body))

            case ("POST", "/assistant/recall"):
                let body: AnigmaAssistantRecallRequest = try decodeRequestBody(request)
                return try makeJSONResponse(try await handleAssistantRecall(ctx: body.ctx, request: body))

            case ("POST", "/assistant/memo/add"):
                let body: AnigmaAssistantAddMemoRequest = try decodeRequestBody(request)
                return try makeJSONResponse(try await handleAssistantAddMemo(ctx: body.ctx, request: body))

            case ("POST", "/assistant/index/start"):
                let body: AnigmaAssistantStartIndexRequest = try decodeRequestBody(request)
                return try makeJSONResponse(try await handleAssistantStartIndex(ctx: body.ctx, request: body))

            // MARK: - Pipeline Management
            case ("POST", "/pipelines/list"):
                let body: AnigmaPipelineListRequest = try decodeRequestBody(request)
                return try makeJSONResponse(try await handleListPipelines(ctx: body.ctx))

            case ("POST", "/pipelines/create"):
                let body: AnigmaPipelineCreateRequest = try decodeRequestBody(request)
                return try makeJSONResponse(try await handleCreatePipeline(ctx: body.ctx, request: body))

            case ("POST", "/pipelines/run"):
                let body: AnigmaPipelineRunRequest = try decodeRequestBody(request)
                return try makeJSONResponse(try await handleRunPipeline(ctx: body.ctx, request: body))

            case ("POST", "/pipelines/status"):
                let body: AnigmaPipelineStatusRequest = try decodeRequestBody(request)
                return try makeJSONResponse(try await handleGetPipelineStatus(ctx: body.ctx, request: body))

            case ("POST", "/pipelines/cancel"):
                let body: AnigmaPipelineCancelRequest = try decodeRequestBody(request)
                return try makeJSONResponse(try await handleCancelPipeline(ctx: body.ctx, request: body))

            // MARK: - Source Management
            case ("POST", "/sources/list"):
                let body: AnigmaListSourcesRequest = try decodeRequestBody(request)
                return try makeJSONResponse(try await handleListSources(ctx: body.ctx))
            case ("POST", "/sources/add"):
                let body: AnigmaAddSourceRequest = try decodeRequestBody(request)
                return try makeJSONResponse(try await handleAddSource(ctx: body.ctx, request: body))
            case ("POST", "/sources/update"):
                let body: AnigmaUpdateSourceRequest = try decodeRequestBody(request)
                return try makeJSONResponse(try await handleUpdateSource(ctx: body.ctx, request: body))
            case ("POST", "/sources/remove"):
                let body: AnigmaRemoveSourceRequest = try decodeRequestBody(request)
                return try makeJSONResponse(try await handleRemoveSource(ctx: body.ctx, request: body))

            // MARK: - Model Registry Routes (Phase 1)
            case ("POST", "/models/list"):
                let body: AnigmaListModelsRequest = try decodeRequestBody(request)
                return try makeJSONResponse(try await handleListModels(ctx: body.ctx))
            case ("POST", "/models/install"):
                let body: AnigmaInstallModelRequest = try decodeRequestBody(request)
                return try makeJSONResponse(try await handleInstallModel(ctx: body.ctx, modelId: body.modelId, repo: body.repo, revision: body.revision, name: body.name, modelType: body.modelType, sizeGB: body.sizeGB, quantization: body.quantization))
            case ("POST", "/models/uninstall"):
                let body: AnigmaDeleteModelRequest = try decodeRequestBody(request)
                return try makeJSONResponse(try await handleDeleteModel(ctx: body.ctx, modelId: body.modelId))

            // MARK: - ML Operation Routes (Phase 1)
            case ("POST", "/ml/embed"):
                let body: AnigmaEmbedRequest = try decodeRequestBody(request)
                return try makeJSONResponse(try await handleMLEmbed(ctx: body.ctx, request: body))
            case ("POST", "/ml/search"):
                let body: AnigmaSearchRequest = try decodeRequestBody(request)
                return try makeJSONResponse(try await handleMLSearch(ctx: body.ctx, request: body))

            // MARK: - Evidence Routes (Phase 1)
            case ("POST", "/evidence/session"):
                let body: AnigmaSessionEvidenceRequest = try decodeRequestBody(request)
                return try makeJSONResponse(try await handleGetSessionEvidence(ctx: body.ctx, sessionId: body.sessionId))

            // MARK: - Plan Coordination Routes (Phase 1)
            case ("POST", "/plan/submit"):
                let body: AnigmaPlanSubmitRequest = try decodeRequestBody(request)
                return try makeJSONResponse(try await handleSubmitPlan(ctx: body.ctx, request: body))

            // MARK: - Agent Orchestration Routes (Phase 1)
            case ("POST", "/agents/run"):
                let body: AnigmaAgentRunRequest = try decodeRequestBody(request)
                return try makeJSONResponse(try await handleAgentRun(ctx: body.ctx, request: body))

            // MARK: - Export Routes (Phase 1)
            case ("POST", "/export/start"):
                let body: AnigmaExportStartRequest = try decodeRequestBody(request)
                return try makeJSONResponse(try await handleExportStart(ctx: body.ctx, request: body))

            // MARK: - WebServer Routes (Phase 3 - Daemon Consolidation)
            // Note: Using simplified paths without /api/v1/ prefix for consistency with daemon conventions

            // WebServer health check
            case ("GET", "/web/health"):
                return try makeJSONResponse(AnigmaWebHealthResponse(status: "healthy", cathedral: "operational", cathedralVersion: "1.0.0", timestamp: Date()))

            // Plan routes from WebServer
            case ("POST", "/web/plan/submit"):
                let body: AnigmaWebPlanSubmissionRequest = try decodeRequestBody(request)
                return try makeJSONResponse(try await handleWebPlanSubmit(ctx: body.ctx, request: body))

            case ("GET", "/web/plan/:id/inspect"):
                // Extract planId from path
                let pathParts = request.path.split(separator: "/")
                guard pathParts.count >= 4, !pathParts[3].isEmpty else {
                    throw HTTPRouteError.invalidBody
                }
                // GET requests don't have body - use default context
                let ctx = AnigmaRequestContext(clientId: "web", capabilityToken: Data(), nonce: "")
                return try makeJSONResponse(try await handleWebPlanInspect(ctx: ctx, planId: String(pathParts[3]), includeEvidence: false))

            case ("POST", "/web/plan/:id/execute"):
                let pathParts = request.path.split(separator: "/")
                guard pathParts.count >= 4, !pathParts[3].isEmpty else {
                    throw HTTPRouteError.invalidBody
                }
                let body: AnigmaWebPlanExecutionRequest = try decodeRequestBody(request)
                return try makeJSONResponse(try await handleWebPlanExecute(ctx: body.ctx, planId: String(pathParts[3]), request: body))

            // Bundle export route
            case ("POST", "/web/bundle/export"):
                let body: AnigmaWebBundleExportRequest = try decodeRequestBody(request)
                return try makeJSONResponse(try await handleWebBundleExport(ctx: body.ctx, request: body))

            // ML routes from WebServer (note: /ml/embed and /ml/search already exist from Phase 1)
            case ("POST", "/web/ml/generate"):
                let body: AnigmaWebGenerateRequest = try decodeRequestBody(request)
                return try makeJSONResponse(try await handleWebGenerate(ctx: body.ctx, request: body))

            // Evidence routes from WebServer (note: /evidence/session already exists from Phase 1)
            case ("GET", "/web/evidence/compliance/:sessionId"):
                let pathParts = request.path.split(separator: "/")
                guard pathParts.count >= 5, !pathParts[4].isEmpty else {
                    throw HTTPRouteError.invalidBody
                }
                // GET requests don't have body - use default context
                let ctx = AnigmaRequestContext(clientId: "web", capabilityToken: Data(), nonce: "")
                return try makeJSONResponse(try await handleWebComplianceReport(ctx: ctx, sessionId: String(pathParts[4])))

            case ("POST", "/web/evidence/bundle"):
                let body: AnigmaWebEvidenceBundleRequest = try decodeRequestBody(request)
                return try makeJSONResponse(try await handleWebEvidenceBundle(ctx: body.ctx, request: body))

            // Document routes from WebServer
            case ("POST", "/web/documents/acquire"):
                let body: AnigmaWebDocumentAcquireRequest = try decodeRequestBody(request)
                return try makeJSONResponse(try await handleWebDocumentAcquire(ctx: body.ctx, request: body))

            case ("POST", "/web/documents/transform"):
                let body: AnigmaWebDocumentTransformRequest = try decodeRequestBody(request)
                return try makeJSONResponse(try await handleWebDocumentTransform(ctx: body.ctx, request: body))

            // MARK: - LLM Provider Endpoints (Phase 6)

            case ("POST", "/llm/providers/list"):
                let body: LLMListProvidersRequest = try decodeRequestBody(request)
                return try makeJSONResponse(await handleLLMListProviders(ctx: body.ctx))

            case ("POST", "/llm/models/list"):
                let body: LLMListModelsRequest = try decodeRequestBody(request)
                return try makeJSONResponse(await handleLLMListModels(ctx: body.ctx, request: body))

            case ("POST", "/llm/generate"):
                let body: LLMGenerateRequest = try decodeRequestBody(request)
                return try makeJSONResponse(await handleLLMGenerateContent(ctx: body.ctx, request: body))

            case ("POST", "/llm/embedding/create"):
                let body: LLMCreateEmbeddingRequest = try decodeRequestBody(request)
                return try makeJSONResponse(await handleLLMCreateEmbedding(ctx: body.ctx, request: body))

            case ("POST", "/llm/health"):
                let body: LLMHealthCheckRequest = try decodeRequestBody(request)
                return try makeJSONResponse(await handleLLMHealthCheck(ctx: body.ctx, provider: body.provider))

            case ("POST", "/llm/metrics"):
                let body: LLMGetMetricsRequest = try decodeRequestBody(request)
                return try makeJSONResponse(await handleLLMGetMetrics(ctx: body.ctx, provider: body.provider))

            case ("POST", "/llm/rate-limit/status"):
                let body: LLMRateLimitStatusRequest = try decodeRequestBody(request)
                return try makeJSONResponse(await handleLLMGetRateLimitStatus(ctx: body.ctx, request: body))

            case ("POST", "/llm/rate-limit/configure"):
                let body: LLMConfigureRateLimitRequest = try decodeRequestBody(request)
                return try makeJSONResponse(await handleLLMConfigureRateLimit(ctx: body.ctx, request: body))

            default:
                routingLogger.error("No route for HTTP \(request.method, privacy: .public) \(request.path, privacy: .public)")
                return HTTPResponse(
                    statusCode: 404,
                    headers: ["Content-Type": "application/json"],
                    body: try JSONEncoder().encode(
                        AnigmaErrorStatus(code: "NOT_FOUND", message: "Route not found", detailJson: nil)
                    )
                )
            }
        } catch {
            routingLogger.error("HTTP route \(request.method, privacy: .public) \(request.path, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            return makeErrorResponse(error)
        }
    }

    private func decodeRequestBody<T: Decodable>(_ request: HTTPRequest) throws -> T {
        guard let body = request.body else {
            throw HTTPRouteError.missingBody
        }
        return try JSONDecoder().decode(T.self, from: body)
    }

    private func makeJSONResponse<T: Encodable>(_ value: T, statusCode: Int = 200) throws -> HTTPResponse {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return HTTPResponse(
            statusCode: statusCode,
            headers: ["Content-Type": "application/json"],
            body: try encoder.encode(value)
        )
    }

    private func makeErrorResponse(_ error: Error) -> HTTPResponse {
        let status: Int
        let code: String

        switch error {
        case HTTPRouteError.missingBody, HTTPRouteError.invalidBody:
            status = 400
            code = "BAD_REQUEST"
        default:
            status = 500
            code = "INTERNAL_ERROR"
        }

        let body = try? JSONEncoder().encode(
            AnigmaErrorStatus(code: code, message: error.localizedDescription, detailJson: nil)
        )
        return HTTPResponse(
            statusCode: status,
            headers: ["Content-Type": "application/json"],
            body: body
        )
    }
}

enum HTTPRouteError: LocalizedError {
    case missingBody
    case invalidBody

    var errorDescription: String? {
        switch self {
        case .missingBody:
            return "Request body is required"
        case .invalidBody:
            return "Request body could not be decoded"
        }
    }
}
