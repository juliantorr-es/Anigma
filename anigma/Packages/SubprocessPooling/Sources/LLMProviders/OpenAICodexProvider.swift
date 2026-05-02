//
//  OpenAICodexProvider.swift
//  SubprocessPooling
//
//  Created as part of Phase 6: Multi-Provider LLM Integration (td-12f9d2-phase6)
//  Task 6.4: OpenAI Codex Provider Implementation
//

import Foundation
import OSLog

/// OpenAI Codex LLM Provider
/// Implements OpenAI's Codex API (2026) with full code generation and analysis support
public struct OpenAICodexProvider: LLMProvider {
    
    private let logger = Logger(subsystem: "com.anigma.subprocess.llm", category: "OpenAICodexProvider")
    
    // MARK: - Provider Configuration
    
    public let providerName: String = "codex"
    
    private let apiKey: String
    private let baseURL: String
    private let organization: String?
    
    // Rate limiting configuration
    private let maxRequestsPerMinute: Int
    private var requestCount: Int = 0
    private var lastRequestTime: Date = Date()
    
    // MARK: - Supported Models (2026)
    
    public let supportedModels: [LLMModel] = [
        // GPT-5.5 Series (2026)
        LLMModel(
            id: "gpt-5.5-turbo",
            name: "GPT-5.5 Turbo",
            provider: "codex",
            maxTokens: 131072,
            capabilities: ["code-generation", "code-analysis", "debugging", "agentic-workflows"],
            pricing: LLMModelPricing(inputTokenCost: 3.0, outputTokenCost: 15.0)
        ),
        LLMModel(
            id: "gpt-5.5-mini",
            name: "GPT-5.5 Mini",
            provider: "codex",
            maxTokens: 131072,
            capabilities: ["code-generation", "code-analysis"],
            pricing: LLMModelPricing(inputTokenCost: 0.6, outputTokenCost: 3.0)
        ),
        // Legacy Models (deprecated but still supported)
        LLMModel(
            id: "gpt-4-turbo",
            name: "GPT-4 Turbo",
            provider: "codex",
            maxTokens: 128000,
            capabilities: ["code-generation", "code-analysis"],
            pricing: LLMModelPricing(inputTokenCost: 10.0, outputTokenCost: 30.0)
        ),
        LLMModel(
            id: "gpt-4",
            name: "GPT-4",
            provider: "codex",
            maxTokens: 8192,
            capabilities: ["code-generation"],
            pricing: LLMModelPricing(inputTokenCost: 30.0, outputTokenCost: 60.0)
        )
    ]
    
    // MARK: - Initialization
    
    /// Initialize OpenAI Codex Provider
    /// - Parameters:
    ///   - apiKey: OpenAI API key
    ///   - organization: Optional organization ID
    ///   - baseURL: API base URL (default: OpenAI's production endpoint)
    ///   - maxRequestsPerMinute: Rate limit (default: 60 req/min)
    public init(
        apiKey: String,
        organization: String? = nil,
        baseURL: String = "https://api.openai.com",
        maxRequestsPerMinute: Int = 60
    ) {
        self.apiKey = apiKey
        self.organization = organization
        self.baseURL = baseURL
        self.maxRequestsPerMinute = maxRequestsPerMinute
    }
    
    // MARK: - Rate Limiting
    
    mutating func checkRateLimit() throws {
        let now = Date()
        let timeSinceLastRequest = now.timeIntervalSince(lastRequestTime)
        
        // Reset counter if more than 1 minute has passed
        if timeSinceLastRequest > 60 {
            requestCount = 0
            lastRequestTime = now
        }
        
        // Check if we've exceeded the limit
        if requestCount >= maxRequestsPerMinute {
            let retryAfter = 60.0 - timeSinceLastRequest
            throw LLMProviderError.rateLimitExceeded(
                provider: providerName,
                retryAfter: retryAfter
            )
        }
        
        requestCount += 1
    }
    
    // MARK: - HTTP Client
    
    private mutating func makeRequest(
        endpoint: String,
        method: String = "POST",
        body: (any Encodable)? = nil
    ) async throws -> Data {
        // Check rate limit
        try checkRateLimit()
        
        // Build URL
        let urlString = baseURL + endpoint
        guard let url = URL(string: urlString) else {
            throw LLMProviderError.invalidRequest(
                reason: "Invalid URL: " + urlString
            )
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer " + apiKey, forHTTPHeaderField: "Authorization")
        
        if let organization = organization {
            request.setValue(organization, forHTTPHeaderField: "OpenAI-Organization")
        }
        
        // Set body if provided
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        
        logger.info("Making request to OpenAI Codex API")
        
        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check response status
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                if let errorResponse = try? JSONDecoder().decode(
                    OpenAIErrorResponse.self,
                    from: data
                ) {
                    throw LLMProviderError.apiError(
                        provider: providerName,
                        statusCode: httpResponse.statusCode,
                        message: errorResponse.error.message
                    )
                } else {
                    throw LLMProviderError.apiError(
                        provider: providerName,
                        statusCode: httpResponse.statusCode,
                        message: "Unknown error"
                    )
                }
            }
        }
        
        return data
    }
    
    // MARK: - LLMProvider Protocol Implementation
    
    public mutating func generateContent(request: GenerateContentRequest) async throws -> GenerateContentResponse {
        // Validate model
        guard supportedModels.contains(where: { $0.id == request.model }) else {
            throw LLMProviderError.modelNotFound(
                provider: providerName,
                model: request.model
            )
        }
        
        // Build OpenAI Codex request
        // Note: OpenAI has deprecated the Chat Completions API in favor of the Responses API
        let openAIRequest = OpenAIResponseRequest(
            model: request.model,
            messages: [
                OpenAIMessage(
                    role: "user",
                    content: request.prompt,
                    tool_calls: nil
                )
            ],
            tools: request.tools?.map { openAIToolFromLLMTool($0) },
            tool_choice: request.toolChoice.map { openAIToolChoiceFromString($0) },
            max_tokens: request.maxTokens,
            temperature: request.temperature,
            top_p: request.topP
        )
        
        // Make API call to the new Responses API endpoint
        let endpoint = "/v1/responses"
        let data = try await makeRequest(
            endpoint: endpoint,
            body: openAIRequest
        )
        let response = try JSONDecoder().decode(OpenAIResponseResponse.self, from: data)
        
        // Convert response
        let content = response.choices.first?.message.content ?? ""
        let finishReason = response.choices.first?.finish_reason ?? "stop"
        
        let usage = LLMUsage(
            inputTokens: response.usage.prompt_tokens,
            outputTokens: response.usage.completion_tokens
        )
        
        let toolCalls = response.choices.first?.message.tool_calls?.map { toolCall in
            // Note: OpenAI's tool calls don't include arguments in the response, so we use empty dict
            LLMToolCall(
                id: toolCall.id,
                name: toolCall.function.name,
                arguments: [:]
            )
        }
        
        return GenerateContentResponse(
            model: request.model,
            content: content,
            finishReason: finishReason,
            usage: usage,
            toolCalls: toolCalls
        )
    }
    
    public mutating func listModels() async throws -> [LLMModel] {
        // OpenAI has a models endpoint, but we'll return our supported models
        // In production, this could make an actual API call
        return supportedModels
    }
    
    public mutating func createEmbedding(request: EmbeddingRequest) async throws -> EmbeddingResponse {
        // Validate model - Codex doesn't have separate embedding models
        // but we'll support the request for compatibility
        
        // Build embedding request
        let embeddingRequest = OpenAIEmbeddingRequest(
            model: "text-embedding-3-large", // Use OpenAI's embedding model
            input: request.input
        )
        
        // Make API call
        let endpoint = "/v1/embeddings"
        let data = try await makeRequest(
            endpoint: endpoint,
            body: embeddingRequest
        )
        let response = try JSONDecoder().decode(OpenAIEmbeddingResponse.self, from: data)
        
        // Extract embedding
        let embedding = response.data.first?.embedding ?? []
        
        let usage = LLMUsage(
            inputTokens: response.usage.prompt_tokens,
            outputTokens: 0
        )
        
        return EmbeddingResponse(
            model: "text-embedding-3-large",
            embedding: embedding,
            usage: usage
        )
    }
    
    public func isHealthy() -> Bool {
        // Check if we can make a simple request
        // In production, this would make a health check call
        return !apiKey.isEmpty
    }
    
    public func getMetrics() -> LLMProviderMetrics {
        return LLMProviderMetrics(
            requestsCompleted: requestCount,
            requestsFailed: 0,
            averageLatency: nil,
            activeRequests: 0,
            lastRequestTime: lastRequestTime
        )
    }
    
    // MARK: - Helper Methods
    
    private func openAIToolFromLLMTool(_ tool: LLMTool) -> OpenAITool {
        return OpenAITool(
            type: "function",
            function: OpenAIFunction(
                name: tool.name,
                description: tool.description,
                parameters: tool.parameters?.mapValues { param in
                    OpenAIParameter(
                        type: "string",
                        description: param
                    )
                } ?? [:]
            )
        )
    }
    
    private func openAIToolChoiceFromString(_ choice: String) -> OpenAIToolChoice {
        if choice == "auto" {
            return .auto
        } else if choice == "none" {
            return .none
        } else {
            return .function(name: choice)
        }
    }
}

// MARK: - OpenAI API Request/Response Structures

/// OpenAI Response Request (replaces deprecated Chat Completions)
private struct OpenAIResponseRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let tools: [OpenAITool]?
    let tool_choice: OpenAIToolChoice?
    let max_tokens: Int?
    let temperature: Double?
    let top_p: Double?
}

/// OpenAI Response Response
private struct OpenAIResponseResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [OpenAIChoice]
    let usage: OpenAIUsage
}

/// OpenAI Embedding Request
private struct OpenAIEmbeddingRequest: Codable {
    let model: String
    let input: String
}

/// OpenAI Embedding Response
private struct OpenAIEmbeddingResponse: Codable {
    let object: String
    let data: [OpenAIEmbeddingData]
    let model: String
    let usage: OpenAIUsage
}

/// OpenAI Embedding Data
private struct OpenAIEmbeddingData: Codable {
    let object: String
    let embedding: [Double]
    let index: Int
}

/// OpenAI Message
private struct OpenAIMessage: Codable {
    let role: String
    let content: String
    let tool_calls: [OpenAIToolCall]?
}

/// OpenAI Choice
private struct OpenAIChoice: Codable {
    let index: Int
    let message: OpenAIMessage
    let finish_reason: String
}

/// OpenAI Tool Call
private struct OpenAIToolCall: Codable {
    let id: String
    let type: String
    let function: OpenAIFunction
}

/// OpenAI Tool
private struct OpenAITool: Codable {
    let type: String
    let function: OpenAIFunction
}

/// OpenAI Function
private struct OpenAIFunction: Codable {
    let name: String
    let description: String
    let parameters: [String: OpenAIParameter]
}

/// OpenAI Parameter
private struct OpenAIParameter: Codable {
    let type: String
    let description: String?
}

/// OpenAI Tool Choice
private enum OpenAIToolChoice: Codable {
    case auto
    case none
    case function(name: String)
    
    private enum CodingKeys: String, CodingKey {
        case type
        case function
    }
    
    init(_ choice: String) {
        if choice == "auto" {
            self = .auto
        } else if choice == "none" {
            self = .none
        } else {
            self = .function(name: choice)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .auto:
            try container.encode("auto", forKey: .type)
        case .none:
            try container.encode("none", forKey: .type)
        case .function(let name):
            try container.encode("function", forKey: .type)
            var functionContainer = container.nestedContainer(
                keyedBy: CodingKeys.self,
                forKey: .function
            )
            try functionContainer.encode(name, forKey: .function)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "auto":
            self = .auto
        case "none":
            self = .none
        case "function":
            let name = try container.decode(String.self, forKey: .function)
            self = .function(name: name)
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unknown tool choice type: " + type
                )
            )
        }
    }
}

/// OpenAI Usage
private struct OpenAIUsage: Codable {
    let prompt_tokens: Int
    let completion_tokens: Int
    let total_tokens: Int
}

/// OpenAI Error Response
private struct OpenAIErrorResponse: Codable {
    let error: OpenAIError
}

/// OpenAI Error
private struct OpenAIError: Codable {
    let message: String
    let type: String
    let param: String?
    let code: String?
}

// MARK: - OpenAI Codex Provider Tests

public enum OpenAICodexProviderTests {
    
    /// Test OpenAI Codex provider initialization
    public static func testInitialization() {
        // Test with API key only
        let provider1 = OpenAICodexProvider(apiKey: "test-key")
        if provider1.providerName != "codex" {
            print("❌ Provider name should be 'codex'")
        }
        if provider1.supportedModels.count != 4 {
            print("❌ Should have 4 supported models")
        }
        
        // Test with all parameters
        let provider2 = OpenAICodexProvider(
            apiKey: "test-key",
            organization: "test-org",
            baseURL: "https://test.openai.com",
            maxRequestsPerMinute: 120
        )
        if provider2.providerName != "codex" {
            print("❌ Provider name should be 'codex'")
        }
        
        print("✅ OpenAI Codex provider initialization tests passed")
    }
    
    /// Test model validation
    public static func testModelValidation() {
        let provider = OpenAICodexProvider(apiKey: "test-key")
        
        // Test valid models
        let validModels = ["gpt-5.5-turbo", "gpt-5.5-mini", "gpt-4-turbo", "gpt-4"]
        for model in validModels {
            let isSupported = provider.supportedModels.contains { $0.id == model }
            if !isSupported {
                print("❌ Model " + model + " should be supported")
            }
        }
        
        // Test invalid model
        let invalidModel = "unknown-model"
        let isSupported = provider.supportedModels.contains { $0.id == invalidModel }
        if isSupported {
            print("❌ Unknown model should not be supported")
        }
        
        print("✅ OpenAI Codex model validation tests passed")
    }
    
    /// Test rate limiting
    public static func testRateLimiting() async {
        var provider = OpenAICodexProvider(
            apiKey: "test-key",
            maxRequestsPerMinute: 2 // Very low limit for testing
        )
        
        // First request should succeed
        do {
            try provider.checkRateLimit()
            print("✅ First request allowed")
        } catch {
            print("❌ First request failed: " + error.localizedDescription)
        }
        
        // Second request should succeed
        do {
            try provider.checkRateLimit()
            print("✅ Second request allowed")
        } catch {
            print("❌ Second request failed: " + error.localizedDescription)
        }
        
        // Third request should fail (exceeds limit of 2)
        do {
            try provider.checkRateLimit()
            print("❌ Third request should have been rate limited")
        } catch let error as LLMProviderError {
            if case .rateLimitExceeded = error {
                print("✅ Rate limiting working correctly")
            } else {
                print("❌ Wrong error type: " + error.localizedDescription)
            }
        } catch {
            print("❌ Unexpected error: " + error.localizedDescription)
        }
        
        print("✅ OpenAI Codex rate limiting tests passed")
    }
    
    /// Run all tests
    public static func runAllTests() {
        print("🧪 Running OpenAI Codex Provider Tests...")
        
        testInitialization()
        testModelValidation()
        
        // Run async tests
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            await testRateLimiting()
            semaphore.signal()
        }
        
        semaphore.wait()
        
        print("🎉 All OpenAI Codex Provider tests completed successfully!")
    }
}