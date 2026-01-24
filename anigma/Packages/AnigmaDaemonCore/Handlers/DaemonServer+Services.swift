//
//  DaemonServer+Services.swift
//  AnigmaDaemonCore
//

import Foundation
import ContractsCore
import MCP

extension DaemonServer {
    func handleListTools(ctx: DaemonRequestContext) async throws -> AnigmaListToolsResponse {
        _ = try await tokenManager.validateToken(ctx.capabilityToken, requiredScope: "system.read")
        
        let mcpTools = await mcpServer.getToolsInternal()
        let tools = mcpTools.map { tool in
            AnigmaToolInfo(
                name: tool.name,
                description: tool.description,
                inputSchemaJson: tool.inputSchema.description // Simplified
            )
        }
        
        return AnigmaListToolsResponse(tools: tools, error: nil)
    }

    // MARK: - Gemini Bridge Handlers

    public func handleGeminiListTools() async throws -> [String: AnyCodable] {
        return try await mcpServer.listToolsForGemini()
    }

    public func handleGeminiCallTool(name: String, arguments: [String: AnyCodable]) async throws -> [String: AnyCodable] {
        return try await mcpServer.callToolForGemini(name: name, arguments: arguments)
    }

    // MARK: - OAuth Handlers
    
    func handleOAuthToken(request: OAuthTokenRequest) async throws -> TokenResponse {
        if request.grantType == "password", let username = request.username {
            return try await oAuthManager.authorize(
                username: username,
                clientId: request.clientId,
                scopes: request.scope?.split(separator: " ").map(String.init) ?? []
            )
        }
        
        if request.grantType == "refresh_token", let refreshToken = request.refreshToken {
            return try await oAuthManager.refreshToken(token: refreshToken)
        }
        
        throw OAuthError.invalidUser // Should be invalid_grant
    }

    // MARK: - Model Registry Handlers

    func handleListModels(ctx: DaemonRequestContext) async throws -> AnigmaListModelsResponse {
        _ = try await tokenManager.validateToken(ctx.capabilityToken, requiredScope: "models.list")
        
        return AnigmaListModelsResponse(
            models: [],
            error: AnigmaErrorStatus(code: "NOT_IMPLEMENTED", message: "Model registry not yet integrated", detailJson: nil)
        )
    }

    func handleInstallModel(
        ctx: DaemonRequestContext,
        modelId: String,
        repo: String?,
        revision: String?
    ) async throws -> AnigmaInstallModelResponse {
        _ = try await tokenManager.validateToken(ctx.capabilityToken, requiredScope: "models.install")
        
        guard let repo = repo else {
            return AnigmaInstallModelResponse(
                modelId: modelId,
                installPath: nil,
                error: AnigmaErrorStatus(code: "INVALID_ARGUMENT", message: "Repo is required for installation", detailJson: nil)
            )
        }
        
        do {
            logInfo("Starting installation for model: \(modelId) from \(repo)", category: "ModelRegistry")
            
            let result = try await hfAdapter.fetchAndVerify(repo: repo, revision: revision)
            
            // Register model in registry
            _ = try await modelRegistry.register(result.spec, installPath: result.installPath)
            
            return AnigmaInstallModelResponse(
                modelId: modelId,
                installPath: result.installPath,
                error: nil
            )
        } catch {
            logError("Model installation failed: \(error)", category: "ModelRegistry")
            return AnigmaInstallModelResponse(
                modelId: modelId,
                installPath: nil,
                error: AnigmaErrorStatus(code: "INSTALL_FAILED", message: error.localizedDescription, detailJson: nil)
            )
        }
    }


    // MARK: - ML Operation Handlers

    func handleMLEmbed(
        ctx: DaemonRequestContext,
        request: AnigmaEmbedRequest
    ) async throws -> AnigmaEmbedResponse {
        _ = try await tokenManager.validateToken(ctx.capabilityToken, requiredScope: "ml.embed")
        
        return AnigmaEmbedResponse(
            vector: [],
            dimension: 0,
            model: request.model,
            executionTimeMs: 0,
            error: AnigmaErrorStatus(code: "NOT_IMPLEMENTED", message: "Embedding service not yet integrated", detailJson: nil)
        )
    }

    func handleMLSearch(
        ctx: DaemonRequestContext,
        request: AnigmaSearchRequest
    ) async throws -> AnigmaSearchResponse {
        _ = try await tokenManager.validateToken(ctx.capabilityToken, requiredScope: "ml.search")
        
        return AnigmaSearchResponse(
            results: [],
            query: request.query,
            model: request.model,
            executionTimeMs: 0,
            error: AnigmaErrorStatus(code: "NOT_IMPLEMENTED", message: "Search service not yet integrated", detailJson: nil)
        )
    }

    // MARK: - Evidence Handlers

    func handleGetSessionEvidence(
        ctx: DaemonRequestContext,
        sessionId: String
    ) async throws -> AnigmaSessionEvidenceResponse {
        _ = try await tokenManager.validateToken(ctx.capabilityToken, requiredScope: "evidence.read")
        
        return AnigmaSessionEvidenceResponse(
            sessionId: sessionId,
            evidenceCount: 0,
            evidence: [],
            error: AnigmaErrorStatus(code: "NOT_IMPLEMENTED", message: "Evidence system not yet integrated", detailJson: nil)
        )
    }

    // MARK: - Plan Handlers

    func handleSubmitPlan(
        ctx: DaemonRequestContext,
        request: AnigmaPlanSubmitRequest
    ) async throws -> AnigmaPlanSubmitResponse {
        _ = try await tokenManager.validateToken(ctx.capabilityToken, requiredScope: "plan.submit")
        
        return AnigmaPlanSubmitResponse(
            planId: UUID().uuidString,
            status: "not_implemented",
            evidenceHash: nil,
            error: AnigmaErrorStatus(code: "NOT_IMPLEMENTED", message: "Plan coordination not yet integrated", detailJson: nil)
        )
    }

    // MARK: - Agent Handlers

    func handleAgentRun(
        ctx: DaemonRequestContext,
        request: AnigmaAgentRunRequest
    ) async throws -> AnigmaAgentRunResponse {
        _ = try await tokenManager.validateToken(ctx.capabilityToken, requiredScope: "agents.run")
        
        return AnigmaAgentRunResponse(
            runId: UUID().uuidString,
            status: "not_implemented",
            error: AnigmaErrorStatus(code: "NOT_IMPLEMENTED", message: "Agent orchestration not yet integrated", detailJson: nil)
        )
    }

    // MARK: - Export Handlers

    func handleExportStart(
        ctx: DaemonRequestContext,
        request: AnigmaExportStartRequest
    ) async throws -> AnigmaExportStartResponse {
        _ = try await tokenManager.validateToken(ctx.capabilityToken, requiredScope: "export.create")
        
        return AnigmaExportStartResponse(
            exportId: UUID().uuidString,
            jobId: "",
            error: AnigmaErrorStatus(code: "NOT_IMPLEMENTED", message: "Export engine not yet integrated", detailJson: nil)
        )
    }

    /// Handle incoming MCP connection
    public func handleMCPConnection(transport: any Transport) async throws {
        try await mcpServer.run(transport: transport)
    }
}
