//
//  DaemonServer+LLM.swift
//  AnigmaDaemonCore
//
//  Created as part of Phase 6: Multi-Provider LLM Integration (td-12f9d2-phase6)
//  Task 6.7: Daemon HTTP Endpoints for LLM
//

import AnigmaPrimitives
import Foundation
import OSLog
import SubprocessPooling

// Import LLMToolChoice from SubprocessPooling

private let llmLogger = Logger(subsystem: "com.anigma.AnigmaDaemonCore", category: "LLM")

// MARK: - Error Types

enum LLMHandlerError: Error, Sendable {
    case unauthorized(reason: String)
    case rateLimited(reason: String)
    case invalidProvider(provider: String)
    case modelNotSupported(provider: String, model: String)
    case providerUnavailable(provider: String)
    case invalidRequest(reason: String)
    case serviceUnavailable(reason: String)
    
    var localizedDescription: String {
        switch self {
        case .unauthorized(let reason): return "Unauthorized: \\(reason)"
        case .rateLimited(let reason): return "Rate limited: \\(reason)"
        case .invalidProvider(let provider): return "Invalid provider: \\(provider)"
        case .modelNotSupported(let provider, let model): return "Model \\(model) not supported by provider \\(provider)"
        case .providerUnavailable(let provider): return "Provider \\(provider) unavailable"
        case .invalidRequest(let reason): return "Invalid request: \\(reason)"
        case .serviceUnavailable(let reason): return "Service unavailable: \\(reason)"
        }
    }
}

// MARK: - Request Types

/// Request to list available LLM providers
public struct LLMListProvidersRequest: Codable, Sendable {
    public let ctx: DaemonRequestContext
    
    public init(ctx: DaemonRequestContext) {
        self.ctx = ctx
    }
}

/// Request to list available models from a provider
public struct LLMListModelsRequest: Codable, Sendable {
    public let ctx: DaemonRequestContext
    public let provider: String
    
    public init(ctx: DaemonRequestContext, provider: String) {
        self.ctx = ctx
        self.provider = provider
    }
}

/// Request to generate content using an LLM
public struct LLMGenerateRequest: Codable, Sendable {
    public let ctx: DaemonRequestContext
    public let provider: String
    public let model: String
    public let prompt: String
    public let systemPrompt: String?
    public let maxTokens: Int?
    public let temperature: Double?
    public let topP: Double?
    public let tools: [LLMTool]?
    public let toolChoice: String?
    
    public init(
        ctx: DaemonRequestContext,
        provider: String,
        model: String,
        prompt: String,
        systemPrompt: String? = nil,
        maxTokens: Int? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        tools: [LLMTool]? = nil,
        toolChoice: String? = nil
    ) {
        self.ctx = ctx
        self.provider = provider
        self.model = model
        self.prompt = prompt
        self.systemPrompt = systemPrompt
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.tools = tools
        self.toolChoice = toolChoice
    }
}

/// Request to create an embedding using an LLM
public struct LLMCreateEmbeddingRequest: Codable, Sendable {
    public let ctx: DaemonRequestContext
    public let provider: String
    public let model: String
    public let input: String
    
    public init(ctx: DaemonRequestContext, provider: String, model: String, input: String) {
        self.ctx = ctx
        self.provider = provider
        self.model = model
        self.input = input
    }
}

/// Request to check LLM provider health
public struct LLMHealthCheckRequest: Codable, Sendable {
    public let ctx: DaemonRequestContext
    public let provider: String
    
    public init(ctx: DaemonRequestContext, provider: String) {
        self.ctx = ctx
        self.provider = provider
    }
}

/// Request to get LLM provider metrics
public struct LLMGetMetricsRequest: Codable, Sendable {
    public let ctx: DaemonRequestContext
    public let provider: String
    
    public init(ctx: DaemonRequestContext, provider: String) {
        self.ctx = ctx
        self.provider = provider
    }
}

// MARK: - Response Types

/// Response containing list of available providers
public struct LLMListProvidersResponse: Codable, Sendable {
    public let providers: [String]
    public let error: String?
    
    public init(providers: [String], error: String? = nil) {
        self.providers = providers
        self.error = error
    }
}

/// Response containing list of available models
public struct LLMListModelsResponse: Codable, Sendable {
    public let provider: String
    public let models: [LLMModelResponse]
    public let error: String?
    
    public init(provider: String, models: [LLMModelResponse], error: String? = nil) {
        self.provider = provider
        self.models = models
        self.error = error
    }
}

/// Simplified model response for JSON serialization
public struct LLMModelResponse: Codable, Sendable {
    public let id: String
    public let name: String
    public let provider: String
    public let maxTokens: Int
    public let capabilities: [String]
    public let pricing: LLMModelPricingResponse?
    
    public init(
        id: String,
        name: String,
        provider: String,
        maxTokens: Int,
        capabilities: [String],
        pricing: LLMModelPricingResponse? = nil
    ) {
        self.id = id
        self.name = name
        self.provider = provider
        self.maxTokens = maxTokens
        self.capabilities = capabilities
        self.pricing = pricing
    }
}

/// Simplified pricing response
public struct LLMModelPricingResponse: Codable, Sendable {
    public let inputTokenCost: Double
    public let outputTokenCost: Double
    
    public init(inputTokenCost: Double, outputTokenCost: Double) {
        self.inputTokenCost = inputTokenCost
        self.outputTokenCost = outputTokenCost
    }
}

/// Response containing generated content
public struct LLMGenerateResponse: Codable, Sendable {
    public let provider: String
    public let model: String
    public let content: String
    public let finishReason: String
    public let usage: LLMUsageResponse
    public let toolCalls: [LLMToolCallResponse]?
    public let error: String?
    
    public init(
        provider: String,
        model: String,
        content: String,
        finishReason: String,
        usage: LLMUsageResponse,
        toolCalls: [LLMToolCallResponse]? = nil,
        error: String? = nil
    ) {
        self.provider = provider
        self.model = model
        self.content = content
        self.finishReason = finishReason
        self.usage = usage
        self.toolCalls = toolCalls
        self.error = error
    }
}

/// Simplified usage response
public struct LLMUsageResponse: Codable, Sendable {
    public let inputTokens: Int
    public let outputTokens: Int
    
    public init(inputTokens: Int, outputTokens: Int) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }
}

/// Simplified tool call response
public struct LLMToolCallResponse: Codable, Sendable {
    public let id: String
    public let name: String
    public let arguments: [String: String]
    
    public init(id: String, name: String, arguments: [String: String]) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }
}

/// Response containing embedding
public struct LLMCreateEmbeddingResponse: Codable, Sendable {
    public let provider: String
    public let model: String
    public let embedding: [Double]
    public let usage: LLMUsageResponse
    public let error: String?
    
    public init(
        provider: String,
        model: String,
        embedding: [Double],
        usage: LLMUsageResponse,
        error: String? = nil
    ) {
        self.provider = provider
        self.model = model
        self.embedding = embedding
        self.usage = usage
        self.error = error
    }
}

/// Response for health check
public struct LLMHealthCheckResponse: Codable, Sendable {
    public let provider: String
    public let isHealthy: Bool
    public let error: String?
    
    public init(provider: String, isHealthy: Bool, error: String? = nil) {
        self.provider = provider
        self.isHealthy = isHealthy
        self.error = error
    }
}

/// Response for metrics
public struct LLMGetMetricsResponse: Codable, Sendable {
    public let provider: String
    public let requestsMade: Int
    public let errors: Int
    public let lastRequestTime: String?
    public let lastError: String?
    public let error: String?
    
    public init(
        provider: String,
        requestsMade: Int,
        errors: Int,
        lastRequestTime: String? = nil,
        lastError: String? = nil,
        error: String? = nil
    ) {
        self.provider = provider
        self.requestsMade = requestsMade
        self.errors = errors
        self.lastRequestTime = lastRequestTime
        self.lastError = lastError
        self.error = error
    }
}

// MARK: - Rate Limit Request/Response Types

/// LLM Provider Response
public struct LLMProviderResponse: Codable, Sendable {
    public let name: String
    public let status: String
    public let supportedModels: [String]?
    public let isHealthy: Bool
    
    public init(name: String, status: String = "available", supportedModels: [String]? = nil, isHealthy: Bool = true) {
        self.name = name
        self.status = status
        self.supportedModels = supportedModels
        self.isHealthy = isHealthy
    }
}

/// LLM Rate Limit Status Request
public struct LLMRateLimitStatusRequest: Codable, Sendable {
    public let ctx: DaemonRequestContext
    public let provider: String
    
    public init(ctx: DaemonRequestContext, provider: String) {
        self.ctx = ctx
        self.provider = provider
    }
}

/// LLM Rate Limit Status Response
public struct LLMRateLimitStatusResponse: Codable, Sendable {
    public let provider: String
    public let maxRequestsPerMinute: Int
    public let remainingRequests: Int
    public let resetTime: Date?
    public let error: String?
    
    public init(
        provider: String,
        maxRequestsPerMinute: Int,
        remainingRequests: Int,
        resetTime: Date?,
        error: String? = nil
    ) {
        self.provider = provider
        self.maxRequestsPerMinute = maxRequestsPerMinute
        self.remainingRequests = remainingRequests
        self.resetTime = resetTime
        self.error = error
    }
}

/// LLM Configure Rate Limit Request
public struct LLMConfigureRateLimitRequest: Codable, Sendable {
    public let ctx: DaemonRequestContext
    public let provider: String
    public let requestsPerMinute: Int
    
    public init(ctx: DaemonRequestContext, provider: String, requestsPerMinute: Int) {
        self.ctx = ctx
        self.provider = provider
        self.requestsPerMinute = requestsPerMinute
    }
}

/// LLM Configure Rate Limit Response
public struct LLMConfigureRateLimitResponse: Codable, Sendable {
    public let provider: String
    public let newLimit: Int
    public let success: Bool
    public let error: String?
    
    public init(provider: String, newLimit: Int, success: Bool, error: String? = nil) {
        self.provider = provider
        self.newLimit = newLimit
        self.success = success
        self.error = error
    }
}

// MARK: - Handler Methods

extension DaemonServer {

    /// Handle request to list available LLM providers
    func handleListProviders(ctx: DaemonRequestContext) async -> LLMListProvidersResponse {
        llmLogger.info("Handling list providers request")

        do {
            let registry = LLMProviderRegistry()
            let providers = await registry.listProviders()

            return LLMListProvidersResponse(providers: providers, error: nil)
        } catch {
            llmLogger.error("Failed to list providers: \(error.localizedDescription)")
            return LLMListProvidersResponse(providers: [], error: error.localizedDescription)
        }
    }

    /// Handle request to list available models from a provider
    func handleListModels(ctx: DaemonRequestContext, provider: String) async -> LLMListModelsResponse {
        llmLogger.info("Handling list models request for provider: \(provider)")

        do {
            let registry = LLMProviderRegistry()
            guard var llmProvider = await registry.getProvider(named: provider) else {
                return LLMListModelsResponse(
                    provider: provider,
                    models: [],
                    error: "Provider not found: \(provider)"
                )
            }

            let models = try await llmProvider.listModels()

            let modelResponses = models.map { model in
                LLMModelResponse(
                    id: model.id,
                    name: model.name,
                    provider: model.provider,
                    maxTokens: model.maxTokens,
                    capabilities: model.capabilities,
                    pricing: model.pricing.map { pricing in
                        LLMModelPricingResponse(
                            inputTokenCost: pricing.inputTokenCost,
                            outputTokenCost: pricing.outputTokenCost
                        )
                    }
                )
            }

            return LLMListModelsResponse(provider: provider, models: modelResponses, error: nil)
        } catch {
            llmLogger.error("Failed to list models for provider \(provider): \(error.localizedDescription)")
            return LLMListModelsResponse(provider: provider, models: [], error: error.localizedDescription)
        }
    }

    /// Handle request to generate content using an LLM
    func handleGenerateContent(
        ctx: DaemonRequestContext,
        provider: String,
        model: String,
        prompt: String,
        systemPrompt: String? = nil,
        maxTokens: Int? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        tools: [LLMTool]? = nil,
        toolChoice: String? = nil
    ) async -> LLMGenerateResponse {
        llmLogger.info("Handling generate content request for provider: \(provider), model: \(model)")

        do {
            let registry = LLMProviderRegistry()
            guard var llmProvider = await registry.getProvider(named: provider) else {
                return LLMGenerateResponse(
                    provider: provider,
                    model: model,
                    content: "",
                    finishReason: "",
                    usage: LLMUsageResponse(inputTokens: 0, outputTokens: 0),
                    toolCalls: nil,
                    error: "Provider not found: \(provider)"
                )
            }

            let request = GenerateContentRequest(
                model: model,
                prompt: prompt,
                maxTokens: maxTokens,
                temperature: temperature,
                topP: topP,
                tools: tools,
                toolChoice: toolChoice
            )

            let response = try await llmProvider.generateContent(request: request)

            let toolCallResponses = response.toolCalls?.map { toolCall in
                LLMToolCallResponse(
                    id: toolCall.id,
                    name: toolCall.name,
                    arguments: toolCall.arguments
                )
            }

            return LLMGenerateResponse(
                provider: provider,
                model: response.model,
                content: response.content,
                finishReason: response.finishReason,
                usage: LLMUsageResponse(
                    inputTokens: response.usage.inputTokens,
                    outputTokens: response.usage.outputTokens
                ),
                toolCalls: toolCallResponses,
                error: nil
            )
        } catch let error as LLMProviderError {
            llmLogger.error("Provider error generating content: \(error.localizedDescription)")
            return LLMGenerateResponse(
                provider: provider,
                model: model,
                content: "",
                finishReason: "",
                usage: LLMUsageResponse(inputTokens: 0, outputTokens: 0),
                toolCalls: nil,
                error: error.localizedDescription
            )
        } catch {
            llmLogger.error("Failed to generate content: \(error.localizedDescription)")
            return LLMGenerateResponse(
                provider: provider,
                model: model,
                content: "",
                finishReason: "",
                usage: LLMUsageResponse(inputTokens: 0, outputTokens: 0),
                toolCalls: nil,
                error: error.localizedDescription
            )
        }
    }

    /// Handle request to create an embedding using an LLM
    func handleCreateEmbedding(
        ctx: DaemonRequestContext,
        provider: String,
        model: String,
        input: String
    ) async -> LLMCreateEmbeddingResponse {
        llmLogger.info("Handling create embedding request for provider: \(provider), model: \(model)")

        do {
            let registry = LLMProviderRegistry()
            guard var llmProvider = await registry.getProvider(named: provider) else {
                return LLMCreateEmbeddingResponse(
                    provider: provider,
                    model: model,
                    embedding: [],
                    usage: LLMUsageResponse(inputTokens: 0, outputTokens: 0),
                    error: "Provider not found: \(provider)"
                )
            }

            let request = EmbeddingRequest(model: model, input: input)
            let response = try await llmProvider.createEmbedding(request: request)

            return LLMCreateEmbeddingResponse(
                provider: provider,
                model: response.model,
                embedding: response.embedding,
                usage: LLMUsageResponse(
                    inputTokens: response.usage.inputTokens,
                    outputTokens: response.usage.outputTokens
                ),
                error: nil
            )
        } catch let error as LLMProviderError {
            llmLogger.error("Provider error creating embedding: \(error.localizedDescription)")
            return LLMCreateEmbeddingResponse(
                provider: provider,
                model: model,
                embedding: [],
                usage: LLMUsageResponse(inputTokens: 0, outputTokens: 0),
                error: error.localizedDescription
            )
        } catch {
            llmLogger.error("Failed to create embedding: \(error.localizedDescription)")
            return LLMCreateEmbeddingResponse(
                provider: provider,
                model: model,
                embedding: [],
                usage: LLMUsageResponse(inputTokens: 0, outputTokens: 0),
                error: error.localizedDescription
            )
        }
    }

    /// Handle health check for an LLM provider
    func handleLLMHealthCheck(ctx: DaemonRequestContext, provider: String) async -> LLMHealthCheckResponse {
        llmLogger.info("Handling health check for provider: \(provider)")

        do {
            let registry = LLMProviderRegistry()
            guard var llmProvider = await registry.getProvider(named: provider) else {
                return LLMHealthCheckResponse(
                    provider: provider,
                    isHealthy: false,
                    error: "Provider not found: \(provider)"
                )
            }

            let isHealthy = try await llmProvider.isHealthy()
            return LLMHealthCheckResponse(provider: provider, isHealthy: isHealthy, error: nil)
        } catch {
            llmLogger.error("Health check failed for provider \(provider): \(error.localizedDescription)")
            return LLMHealthCheckResponse(
                provider: provider,
                isHealthy: false,
                error: error.localizedDescription
            )
        }
    }

    /// Handle request to get metrics for an LLM provider
    func handleLLMGetMetrics(ctx: DaemonRequestContext, provider: String) async -> LLMGetMetricsResponse {
        llmLogger.info("Handling get metrics for provider: \(provider)")

        do {
            let registry = LLMProviderRegistry()
            guard var llmProvider = await registry.getProvider(named: provider) else {
                return LLMGetMetricsResponse(
                    provider: provider,
                    requestsMade: 0,
                    errors: 0,
                    lastRequestTime: nil,
                    lastError: nil,
                    error: "Provider not found: \(provider)"
                )
            }

            let metrics = await llmProvider.getMetrics()
            return LLMGetMetricsResponse(
                provider: provider,
                requestsMade: metrics.requestsCompleted,
                errors: metrics.requestsFailed,
                lastRequestTime: metrics.lastRequestTime?.ISO8601Format(),
                lastError: nil, // lastError not available in current metrics structure
                error: nil
            )
        } catch {
            llmLogger.error("Failed to get metrics for provider \(provider): \(error.localizedDescription)")
            return LLMGetMetricsResponse(
                provider: provider,
                requestsMade: 0,
                errors: 0,
                lastRequestTime: nil,
                lastError: nil,
                error: error.localizedDescription
            )
        }
    }

    /// Handle LLM content generation
    func handleLLMGenerateContent(
        ctx: DaemonRequestContext,
        request: LLMGenerateRequest
    ) async -> LLMGenerateResponse {
        llmLogger.info("Handling generate content request for provider: \\(request.provider)")

        do {
            // Validate token and check rate limit
            try await tokenManager.validateToken(String(data: ctx.capabilityToken, encoding: .utf8) ?? "", requiredScope: "llm.generate")
            try LLMSecurityLayer(tokenManager: tokenManager).checkRateLimit(for: request.provider)
            
            let registry = LLMProviderRegistry()
            guard var llmProvider = await registry.getProvider(named: request.provider) else {
                return LLMGenerateResponse(
                    provider: request.provider,
                    model: request.model,
                    content: "",
                    finishReason: "error",
                    usage: LLMUsageResponse(inputTokens: 0, outputTokens: 0),
                    toolCalls: nil,
                    error: "Provider not found: \\(request.provider)"
                )
            }

            // Validate model
            let supportedModels = try await llmProvider.listModels()
            guard supportedModels.contains(where: { $0.id == request.model }) else {
                return LLMGenerateResponse(
                    provider: request.provider,
                    model: request.model,
                    content: "",
                    finishReason: "error",
                    usage: LLMUsageResponse(inputTokens: 0, outputTokens: 0),
                    toolCalls: nil,
                    error: "Model not supported: \\(request.model)"
                )
            }

            // Create generation request
            let generateRequest = GenerateContentRequest(
                model: request.model,
                prompt: request.prompt,
                maxTokens: request.maxTokens,
                temperature: request.temperature,
                topP: request.topP,
                tools: request.tools,
                toolChoice: request.toolChoice.flatMap { LLMToolChoice(rawValue: $0) }
            )

            // Generate content (mutating operation)
            var mutableProvider = llmProvider
            let response = try await mutableProvider.generateContent(request: generateRequest)

            // Convert tool calls
            let toolCallResponses = response.toolCalls?.map { toolCall in
                LLMToolCallResponse(
                    id: toolCall.id,
                    name: toolCall.name,
                    arguments: toolCall.arguments
                )
            }

            return LLMGenerateResponse(
                provider: request.provider,
                model: request.model,
                content: response.content,
                finishReason: response.finishReason,
                usage: LLMUsageResponse(
                    inputTokens: response.usage.inputTokens,
                    outputTokens: response.usage.outputTokens
                ),
                toolCalls: toolCallResponses,
                error: nil
            )
        } catch let error as LLMHandlerError {
            llmLogger.error("Generate content failed for provider \\(request.provider): \\(error.localizedDescription)")
            return LLMGenerateResponse(
                provider: request.provider,
                model: request.model,
                content: "",
                finishReason: "error",
                usage: LLMUsageResponse(inputTokens: 0, outputTokens: 0),
                toolCalls: nil,
                error: error.localizedDescription
            )
        } catch {
            llmLogger.error("Generate content failed for provider \\(request.provider): \\(error.localizedDescription)")
            return LLMGenerateResponse(
                provider: request.provider,
                model: request.model,
                content: "",
                finishReason: "error",
                usage: LLMUsageResponse(inputTokens: 0, outputTokens: 0),
                toolCalls: nil,
                error: error.localizedDescription
            )
        }
    }

    /// Handle LLM model listing
    func handleLLMListModels(
        ctx: DaemonRequestContext,
        request: LLMListModelsRequest
    ) async -> LLMListModelsResponse {
        llmLogger.info("Handling list models request for provider: \\(request.provider)")

        do {
            // Validate token and check rate limit
            try await validateLLMRequest(
                capabilityToken: String(data: ctx.capabilityToken, encoding: .utf8) ?? "",
                requiredScope: "llm.models.read",
                provider: request.provider
            )
            
            let registry = LLMProviderRegistry()
            guard var llmProvider = await registry.getProvider(named: request.provider) else {
                return LLMListModelsResponse(
                    provider: request.provider,
                    models: [],
                    error: "Provider not found: \\(request.provider)"
                )
            }

            var mutableProvider = llmProvider
            let models = try await mutableProvider.listModels()

            // Convert to response format
            let modelResponses = models.map { model in
                LLMModelResponse(
                    id: model.id,
                    name: model.name,
                    provider: model.provider,
                    maxTokens: model.maxTokens,
                    capabilities: model.capabilities,
                    pricing: model.pricing.map { pricing in
                        LLMModelPricingResponse(
                            inputTokenCost: pricing.inputTokenCost,
                            outputTokenCost: pricing.outputTokenCost
                        )
                    }
                )
            }

            return LLMListModelsResponse(
                provider: request.provider,
                models: modelResponses,
                error: nil
            )
        } catch {
            llmLogger.error("List models failed for provider \\(request.provider): \\(error.localizedDescription)")
            return LLMListModelsResponse(
                provider: request.provider,
                models: [],
                error: error.localizedDescription
            )
        }
    }

    /// Handle LLM embedding creation
    func handleLLMCreateEmbedding(
        ctx: DaemonRequestContext,
        request: LLMCreateEmbeddingRequest
    ) async -> LLMCreateEmbeddingResponse {
        llmLogger.info("Handling create embedding request for provider: \\(request.provider)")

        do {
            // Validate token and check rate limit
            try await validateLLMRequest(
                capabilityToken: ctx.capabilityToken,
                requiredScope: "llm.embedding.create",
                provider: request.provider
            )
            
            let registry = LLMProviderRegistry()
            guard var llmProvider = await registry.getProvider(named: request.provider) else {
                return LLMCreateEmbeddingResponse(
                    provider: request.provider,
                    model: request.model,
                    embedding: [],
                    usage: LLMUsageResponse(inputTokens: 0, outputTokens: 0),
                    error: "Provider not found: \\(request.provider)"
                )
            }

            // Validate model
            let supportedModels = try await llmProvider.listModels()
            guard supportedModels.contains(where: { $0.id == request.model }) else {
                return LLMCreateEmbeddingResponse(
                    provider: request.provider,
                    model: request.model,
                    embedding: [],
                    usage: LLMUsageResponse(inputTokens: 0, outputTokens: 0),
                    error: "Model not supported: \\(request.model)"
                )
            }

            // Create embedding request
            let embeddingRequest = EmbeddingRequest(model: request.model, input: request.input)

            // Create embedding (mutating operation)
            var mutableProvider = llmProvider
            let response = try await mutableProvider.createEmbedding(request: embeddingRequest)

            return LLMCreateEmbeddingResponse(
                provider: request.provider,
                model: request.model,
                embedding: response.embedding,
                usage: LLMUsageResponse(
                    inputTokens: response.usage.inputTokens,
                    outputTokens: response.usage.outputTokens
                ),
                error: nil
            )
        } catch {
            llmLogger.error("Create embedding failed for provider \\(request.provider): \\(error.localizedDescription)")
            return LLMCreateEmbeddingResponse(
                provider: request.provider,
                model: request.model,
                embedding: [],
                usage: LLMUsageResponse(inputTokens: 0, outputTokens: 0),
                error: error.localizedDescription
            )
        }
    }

    /// Handle LLM list providers
    func handleLLMListProviders(ctx: DaemonRequestContext) async -> LLMListProvidersResponse {
        llmLogger.info("Handling list providers request")

        do {
            let registry = LLMProviderRegistry()
            let providers = registry.getAllProviderNames()
            
            let providerResponses = providers.map { providerName in
                LLMProviderResponse(name: providerName)
            }

            return LLMListProvidersResponse(
                providers: providerResponses,
                error: nil
            )
        } catch {
            llmLogger.error("List providers failed: \\(error.localizedDescription)")
            return LLMListProvidersResponse(
                providers: [],
                error: error.localizedDescription
            )
        }
    }

    /// Handle LLM rate limit status check
    func handleLLMGetRateLimitStatus(
        ctx: DaemonRequestContext,
        request: LLMRateLimitStatusRequest
    ) async -> LLMRateLimitStatusResponse {
        llmLogger.info("Handling rate limit status request for provider: \\(request.provider)")

        do {
            // Validate admin token for rate limit management
            try await llmSecurityLayer.validateToken(String(data: ctx.capabilityToken, encoding: .utf8) ?? "", requiredScope: "llm.admin")
            
            let status = await getLLMRateLimitStatus(for: request.provider)
            
            return LLMRateLimitStatusResponse(
                provider: request.provider,
                maxRequestsPerMinute: status.maxRequestsPerMinute,
                remainingRequests: status.remainingRequests,
                resetTime: status.resetTime,
                error: nil
            )
        } catch let error as SecurityError {
            llmLogger.error("Rate limit status failed for provider \\(request.provider): \\(error.localizedDescription)")
            return LLMRateLimitStatusResponse(
                provider: request.provider,
                maxRequestsPerMinute: 0,
                remainingRequests: 0,
                resetTime: nil,
                error: error.localizedDescription
            )
        } catch {
            llmLogger.error("Rate limit status failed for provider \\(request.provider): \\(error.localizedDescription)")
            return LLMRateLimitStatusResponse(
                provider: request.provider,
                maxRequestsPerMinute: 0,
                remainingRequests: 0,
                resetTime: nil,
                error: error.localizedDescription
            )
        }
    }

    /// Handle LLM rate limit configuration
    func handleLLMConfigureRateLimit(
        ctx: DaemonRequestContext,
        request: LLMConfigureRateLimitRequest
    ) async -> LLMConfigureRateLimitResponse {
        llmLogger.info("Handling rate limit configuration for provider: \\(request.provider)")

        do {
            // Validate admin token for rate limit management
            try await llmSecurityLayer.validateToken(ctx.capabilityToken, requiredScope: "llm.admin")
            
            // Configure the new rate limit
            configureLLMRateLimit(for: request.provider, requestsPerMinute: request.requestsPerMinute)
            
            return LLMConfigureRateLimitResponse(
                provider: request.provider,
                newLimit: request.requestsPerMinute,
                success: true,
                error: nil
            )
        } catch let error as SecurityError {
            llmLogger.error("Rate limit configuration failed for provider \\(request.provider): \\(error.localizedDescription)")
            return LLMConfigureRateLimitResponse(
                provider: request.provider,
                newLimit: request.requestsPerMinute,
                success: false,
                error: error.localizedDescription
            )
        } catch {
            llmLogger.error("Rate limit configuration failed for provider \\(request.provider): \\(error.localizedDescription)")
            return LLMConfigureRateLimitResponse(
                provider: request.provider,
                newLimit: request.requestsPerMinute,
                success: false,
                error: error.localizedDescription
            )
        }
    }
}
