//
//  LLMProviderProtocol.swift
//  SubprocessPooling
//
//  Created as part of Phase 6: Multi-Provider LLM Integration (td-12f9d2-phase6)
//  Unified LLM Provider Framework - Task 6.1
//

import Foundation

/// Unified LLM Provider Protocol
/// Defines the standard interface that all LLM providers must implement
public protocol LLMProvider: Sendable {
    
    /// Provider name (e.g., "gemini", "claude", "codex")
    var providerName: String { get }
    
    /// List of supported models by this provider
    var supportedModels: [LLMModel] { get }
    
    /// Generate content using the LLM
    /// - Parameter request: Content generation request
    /// - Returns: Content generation response
    mutating func generateContent(request: GenerateContentRequest) async throws -> GenerateContentResponse
    
    /// List available models from this provider
    /// - Returns: Array of available models
    mutating func listModels() async throws -> [LLMModel]
    
    /// Create embeddings using the LLM
    /// - Parameter request: Embedding request
    /// - Returns: Embedding response
    mutating func createEmbedding(request: EmbeddingRequest) async throws -> EmbeddingResponse
    
    /// Check if the provider is healthy and available
    /// - Returns: True if provider is healthy
    func isHealthy() -> Bool
    
    /// Get provider-specific metrics
    /// - Returns: Provider metrics
    func getMetrics() -> LLMProviderMetrics
}

/// Standard LLM Model representation
public struct LLMModel: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let provider: String
    public let maxTokens: Int
    public let capabilities: [String]
    public let pricing: LLMModelPricing?
    
    public init(id: String, name: String, provider: String, maxTokens: Int, capabilities: [String], pricing: LLMModelPricing? = nil) {
        self.id = id
        self.name = name
        self.provider = provider
        self.maxTokens = maxTokens
        self.capabilities = capabilities
        self.pricing = pricing
    }
}

/// LLM Model Pricing Information
public struct LLMModelPricing: Codable, Sendable {
    public let inputTokenCost: Double  // Cost per 1M input tokens
    public let outputTokenCost: Double // Cost per 1M output tokens
    public let currency: String
    
    public init(inputTokenCost: Double, outputTokenCost: Double, currency: String = "USD") {
        self.inputTokenCost = inputTokenCost
        self.outputTokenCost = outputTokenCost
        self.currency = currency
    }
}

/// Content Generation Request
public struct GenerateContentRequest: Codable, Sendable {
    public let model: String
    public let prompt: String
    public let maxTokens: Int?
    public let temperature: Double?
    public let topP: Double?
    public let topK: Int?
    public let stopSequences: [String]?
    public let tools: [LLMTool]?
    public let toolChoice: String?
    public let clientId: String?
    
    public init(
        model: String,
        prompt: String,
        maxTokens: Int? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        topK: Int? = nil,
        stopSequences: [String]? = nil,
        tools: [LLMTool]? = nil,
        toolChoice: String? = nil,
        clientId: String? = nil
    ) {
        self.model = model
        self.prompt = prompt
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.stopSequences = stopSequences
        self.tools = tools
        self.toolChoice = toolChoice
        self.clientId = clientId
    }
}

/// Content Generation Response
public struct GenerateContentResponse: Codable, Sendable {
    public let model: String
    public let content: String
    public let finishReason: String
    public let usage: LLMUsage
    public let toolCalls: [LLMToolCall]?
    
    public init(
        model: String,
        content: String,
        finishReason: String,
        usage: LLMUsage,
        toolCalls: [LLMToolCall]? = nil
    ) {
        self.model = model
        self.content = content
        self.finishReason = finishReason
        self.usage = usage
        self.toolCalls = toolCalls
    }
}

/// Embedding Request
public struct EmbeddingRequest: Codable, Sendable {
    public let model: String
    public let input: String
    public let clientId: String?
    
    public init(model: String, input: String, clientId: String? = nil) {
        self.model = model
        self.input = input
        self.clientId = clientId
    }
}

/// Embedding Response
public struct EmbeddingResponse: Codable, Sendable {
    public let model: String
    public let embedding: [Double]
    public let usage: LLMUsage
    
    public init(model: String, embedding: [Double], usage: LLMUsage) {
        self.model = model
        self.embedding = embedding
        self.usage = usage
    }
}

/// LLM Tool Definition
public struct LLMTool: Codable, Sendable {
    public let name: String
    public let description: String
    public let parameters: [String: String]?  // Simplified to String for Sendable compliance
    
    public init(name: String, description: String, parameters: [String: String]? = nil) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

/// LLM Tool Call
public struct LLMToolCall: Codable, Sendable {
    public let id: String
    public let name: String
    public let arguments: [String: String]  // Simplified to String for Sendable compliance
    
    public init(id: String, name: String, arguments: [String: String]) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }
}

/// LLM Tool Choice
public enum LLMToolChoice: String, Codable, Sendable {
    case auto
    case none
    case specificTool = "specific"
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue.lowercased() {
        case "auto": self = .auto
        case "none": self = .none
        case let toolName: self = .specificTool
        }
    }
}

/// LLM Usage Statistics
public struct LLMUsage: Codable, Sendable {
    public let inputTokens: Int
    public let outputTokens: Int
    public let totalTokens: Int
    
    public init(inputTokens: Int, outputTokens: Int) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = inputTokens + outputTokens
    }
}

/// LLM Provider Metrics
public struct LLMProviderMetrics: Codable, Sendable {
    public var requestsCompleted: Int
    public var requestsFailed: Int
    public var averageLatency: Double? // in milliseconds
    public var activeRequests: Int
    public var lastRequestTime: Date?
    
    public init(
        requestsCompleted: Int = 0,
        requestsFailed: Int = 0,
        averageLatency: Double? = nil,
        activeRequests: Int = 0,
        lastRequestTime: Date? = nil
    ) {
        self.requestsCompleted = requestsCompleted
        self.requestsFailed = requestsFailed
        self.averageLatency = averageLatency
        self.activeRequests = activeRequests
        self.lastRequestTime = lastRequestTime
    }
}

/// LLM Provider Error Types
public enum LLMProviderError: Error, Sendable {
    case providerUnavailable(provider: String)
    case authenticationFailed(provider: String)
    case rateLimitExceeded(provider: String, retryAfter: TimeInterval?)
    case modelNotFound(provider: String, model: String)
    case invalidRequest(reason: String)
    case apiError(provider: String, statusCode: Int, message: String)
    case networkError(provider: String, error: Error)
    case unknownError(provider: String, message: String)
    
    public var localizedDescription: String {
        switch self {
        case .providerUnavailable(let provider):
            return "LLM provider '" + provider + "' is unavailable"
        case .authenticationFailed(let provider):
            return "Authentication failed for provider '" + provider + "'"
        case .rateLimitExceeded(let provider, let retryAfter):
            let retryInfo = retryAfter.map { " (retry after " + String(format: "%.1f", $0) + "s)" } ?? ""
            return "Rate limit exceeded for provider '" + provider + "'" + retryInfo
        case .modelNotFound(let provider, let model):
            return "Model '" + model + "' not found in provider '" + provider + "'"
        case .invalidRequest(let reason):
            return "Invalid request: " + reason
        case .apiError(let provider, let statusCode, let message):
            return "API error from '" + provider + "': " + statusCode.description + " - " + message
        case .networkError(let provider, let error):
            return "Network error with provider '" + provider + "': " + error.localizedDescription
        case .unknownError(let provider, let message):
            return "Unknown error from provider '" + provider + "': " + message
        }
    }
}

// MARK: - LLM Provider Registry

/// Registry for managing multiple LLM providers
public actor LLMProviderRegistry {
    private var providers: [String: any LLMProvider] = [:]
    private var metrics: [String: LLMProviderMetrics] = [:]
    
    public init() {}
    
    /// Register a new LLM provider
    /// - Parameter provider: LLM provider to register
    public func registerProvider(_ provider: any LLMProvider) {
        providers[provider.providerName] = provider
        metrics[provider.providerName] = LLMProviderMetrics()
    }
    
    /// Get a registered provider by name
    /// - Parameter name: Provider name
    /// - Returns: LLM provider if found
    public func getProvider(named name: String) -> (any LLMProvider)? {
        return providers[name]
    }
    
    /// List all registered providers
    /// - Returns: Array of all provider names
    public func listProviders() -> [String] {
        return Array(providers.keys)
    }
    
    /// Get all provider names (alias for listProviders for compatibility)
    /// - Returns: Array of all provider names
    public func getAllProviderNames() -> [String] {
        return listProviders()
    }
    
    /// Check if a provider is healthy
    /// - Parameter name: Provider name
    /// - Returns: True if provider is healthy
    public func isProviderHealthy(named name: String) -> Bool {
        guard let provider = providers[name] else { return false }
        return provider.isHealthy()
    }
    
    /// Get metrics for a specific provider
    /// - Parameter name: Provider name
    /// - Returns: Provider metrics if available
    public func getMetrics(for name: String) -> LLMProviderMetrics? {
        return metrics[name]
    }
    
    /// Update metrics for a provider
    /// - Parameters:
    ///   - name: Provider name
    ///   - metrics: Updated metrics
    public func updateMetrics(for name: String, with metrics: LLMProviderMetrics) {
        self.metrics[name] = metrics
    }
    
    /// Remove a registered provider
    /// - Parameter name: Provider name
    public func unregisterProvider(named name: String) {
        providers.removeValue(forKey: name)
        metrics.removeValue(forKey: name)
    }
    
    /// Get all providers metrics
    /// - Returns: Dictionary of all provider metrics
    public func getAllMetrics() -> [String: LLMProviderMetrics] {
        return metrics
    }
}

// MARK: - AnyCodable for flexible parameter handling

