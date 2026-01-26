//
//  DaemonServer+Services.swift
//  AnigmaDaemonCore
//

import Foundation
import ContractsCore
import MCP
import AnigmaAgents
import AnigmaPrimitives

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
        
        // Fetch from Antigravity
        let agModels = (try? await antigravityService.listModels()) ?? []
        
        let models = agModels.map { am in
            AnigmaModelInfo(
                id: am.id,
                name: am.name,
                provider: am.provider,
                description: "Hosted via Antigravity",
                capabilities: ["chat", "generate"]
            )
        }
        
        return AnigmaListModelsResponse(
            models: models,
            error: nil
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
        
        do {
            // Parse workspace ID from request or use default
            let workspaceId = UUID(uuidString: request.workspaceId) ?? UUID()
            
            // Parse working directory if provided
            let workingDirectory: URL?
            if let workingDir = request.workingDirectory, !workingDir.isEmpty {
                workingDirectory = URL(fileURLWithPath: workingDir)
            } else {
                workingDirectory = nil
            }
            
            // Execute agent via orchestrator
            let result = try await agentOrchestrator.execute(
                agentId: request.agentId,
                instruction: request.instruction,
                workspaceId: workspaceId,
                workingDirectory: workingDirectory
            )
            
            // Extract job ID from result message
            let jobIdPattern = #/Job ([0-9a-fA-F-]+)/#
            let jobIdMatch = try? jobIdPattern.firstMatch(in: result)
            let runId = jobIdMatch?.1 ?? UUID().uuidString
            
            return AnigmaAgentRunResponse(
                runId: String(runId),
                status: "enqueued",
                error: nil
            )
        } catch AgentError.agentNotFound(let agentId) {
            return AnigmaAgentRunResponse(
                runId: UUID().uuidString,
                status: "failed",
                error: AnigmaErrorStatus(code: "AGENT_NOT_FOUND", message: "Agent '\(agentId)' not registered", detailJson: nil)
            )
        } catch {
            return AnigmaAgentRunResponse(
                runId: UUID().uuidString,
                status: "failed",
                error: AnigmaErrorStatus(code: "INTERNAL_ERROR", message: "Failed to execute agent: \(error.localizedDescription)", detailJson: nil)
            )
        }
    }
    
    // MARK: - Agent Management Handlers
    
    func handleListAgents(ctx: DaemonRequestContext) async throws -> AnigmaListAgentsResponse {
        _ = try await tokenManager.validateToken(ctx.capabilityToken, requiredScope: "agents.list")
        
        do {
            // Try to get agents from registry first
            let registeredAgents = try await aiRegistry?.listAgents() ?? []
            
            let agents = registeredAgents.map { agent in
                AnigmaAgentInfo(
                    id: agent.id,
                    name: agent.name,
                    description: agent.description,
                    capabilities: agent.capabilities.map { $0.rawValue },
                    isEnabled: agent.isEnabled,
                    lastUsed: agent.lastUsed
                )
            }
            
            return AnigmaListAgentsResponse(
                agents: agents,
                error: nil
            )
        } catch {
            return AnigmaListAgentsResponse(
                agents: [],
                error: AnigmaErrorStatus(code: "INTERNAL_ERROR", message: "Failed to list agents: \(error.localizedDescription)", detailJson: nil)
            )
        }
    }
    
    func handleGetAgent(ctx: DaemonRequestContext, agentId: String) async throws -> AnigmaGetAgentResponse {
        _ = try await tokenManager.validateToken(ctx.capabilityToken, requiredScope: "agents.read")
        
        do {
            guard let agents = try await aiRegistry?.listAgents(),
                  let agent = agents.first(where: { $0.id == agentId }) else {
                return AnigmaGetAgentResponse(
                    agent: nil,
                    error: AnigmaErrorStatus(code: "AGENT_NOT_FOUND", message: "Agent '\(agentId)' not found in registry", detailJson: nil)
                )
            }
            
            let agentInfo = AnigmaAgentInfo(
                id: agent.id,
                name: agent.name,
                description: agent.description,
                capabilities: agent.capabilities.map { $0.rawValue },
                isEnabled: agent.isEnabled,
                lastUsed: agent.lastUsed
            )
            
            return AnigmaGetAgentResponse(
                agent: agentInfo,
                error: nil
            )
        } catch {
            return AnigmaGetAgentResponse(
                agent: nil,
                error: AnigmaErrorStatus(code: "INTERNAL_ERROR", message: "Failed to get agent: \(error.localizedDescription)", detailJson: nil)
            )
        }
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

    func handleStreamTelemetry(ctx: DaemonRequestContext) async throws -> AsyncThrowingStream<AnigmaTelemetryEvent, Error> {
        _ = try await tokenManager.validateToken(ctx.capabilityToken, requiredScope: "system.read")
        
        return AsyncThrowingStream { continuation in
            // Send initial connected event
            let connectedEvent = AnigmaTelemetryEvent(
                type: "system.telemetry.connected",
                payloadJson: "{}",
                atUnixMs: UInt64(Date().timeIntervalSince1970 * 1000)
            )
            continuation.yield(connectedEvent)
            
            // Keep stream open (simulate heartbeat)
            // In a real implementation, this would subscribe to a notification center or telemetry bus
            Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 30 * 1_000_000_000) // 30s heartbeat
                    let heartbeat = AnigmaTelemetryEvent(
                        type: "system.heartbeat",
                        payloadJson: "{\"status\":\"ok\"}",
                        atUnixMs: UInt64(Date().timeIntervalSince1970 * 1000)
                    )
                    continuation.yield(heartbeat)
                }
                continuation.finish()
            }
        }
    }

    /// Handle incoming MCP connection
    public func handleMCPConnection(transport: any Transport) async throws {
        try await mcpServer.run(transport: transport)
    }
}

// MARK: - Agent Management Types

public struct AnigmaAgentInfo: Codable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let capabilities: [String]
    public let isEnabled: Bool
    public let lastUsed: Date?
    
    public init(id: String, name: String, description: String, capabilities: [String], isEnabled: Bool, lastUsed: Date? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.capabilities = capabilities
        self.isEnabled = isEnabled
        self.lastUsed = lastUsed
    }
}

public struct AnigmaListAgentsResponse: Codable, Sendable {
    public let agents: [AnigmaAgentInfo]
    public let error: AnigmaErrorStatus?
    
    public init(agents: [AnigmaAgentInfo], error: AnigmaErrorStatus? = nil) {
        self.agents = agents
        self.error = error
    }
}

public struct AnigmaGetAgentResponse: Codable, Sendable {
    public let agent: AnigmaAgentInfo?
    public let error: AnigmaErrorStatus?
    
    public init(agent: AnigmaAgentInfo?, error: AnigmaErrorStatus? = nil) {
        self.agent = agent
        self.error = error
    }
}

public struct AnigmaListAgentsRequest: Codable, Sendable {
    public let ctx: AnigmaRequestContext
    
    public init(ctx: AnigmaRequestContext) {
        self.ctx = ctx
    }
}

public struct AnigmaGetAgentRequest: Codable, Sendable {
    public let ctx: AnigmaRequestContext
    public let agentId: String
    
    public init(ctx: AnigmaRequestContext, agentId: String) {
        self.ctx = ctx
        self.agentId = agentId
    }
}
