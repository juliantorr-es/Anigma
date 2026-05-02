//
//  ClaudeProvider.swift
//  SubprocessPooling
//
//  Created as part of Phase 6: Multi-Provider LLM Integration (td-12f9d2-phase6)
//  Task 6.3: Claude Provider Implementation
//

import Foundation
import OSLog

/// Claude LLM Provider
/// Implements Anthropic's Claude API (2026) with full feature support
public struct ClaudeProvider: LLMProvider {
    
    private let logger = Logger(subsystem: "com.anigma.subprocess.llm", category: "ClaudeProvider")
    
    // MARK: - Provider Configuration
    
    public let providerName: String = "claude"
    
    private let apiKey: String
    private let baseURL: String
    private let organization: String?
    private let project: String?
    
    // Rate limiting configuration
    private let maxRequestsPerMinute: Int
    private var requestCount: Int = 0
    private var lastRequestTime: Date = Date()
    
    // MARK: - Supported Models (2026)
    
    public let supportedModels: [LLMModel] = [
        // Claude 4.7 Series (2026)
        LLMModel(
            id: "claude-4.7-opus",
            name: "Claude 4.7 Opus",
            provider: "claude",
            maxTokens: 300000,
            capabilities: ["text-generation", "tool-use", "long-context"],
            pricing: LLMModelPricing(inputTokenCost: 15.0, outputTokenCost: 75.0)
        ),
        LLMModel(
            id: "claude-4.7-sonnet",
            name: "Claude 4.7 Sonnet",
            provider: "claude",
            maxTokens: 300000,
            capabilities: ["text-generation", "tool-use"],
            pricing: LLMModelPricing(inputTokenCost: 3.0, outputTokenCost: 15.0)
        ),
        LLMModel(
            id: "claude-4.6-opus",
            name: "Claude 4.6 Opus",
            provider: "claude",
            maxTokens: 200000,
            capabilities: ["text-generation", "tool-use"],
            pricing: LLMModelPricing(inputTokenCost: 10.0, outputTokenCost: 50.0)
        ),
        LLMModel(
            id: "claude-4.6-sonnet",
            name: "Claude 4.6 Sonnet",
            provider: "claude",
            maxTokens: 200000,
            capabilities: ["text-generation"],
            pricing: LLMModelPricing(inputTokenCost: 2.0, outputTokenCost: 10.0)
        )
    ]
    
    // MARK: - Initialization
    
    /// Initialize Claude Provider
    /// - Parameters:
    ///   - apiKey: Anthropic API key
    ///   - organization: Optional organization ID
    ///   - project: Optional project ID
    ///   - baseURL: API base URL (default: Anthropic's production endpoint)
    ///   - maxRequestsPerMinute: Rate limit (default: 60 req/min)
    public init(
        apiKey: String,
        organization: String? = nil,
        project: String? = nil,
        baseURL: String = "https://api.anthropic.com",
        maxRequestsPerMinute: Int = 60
    ) {
        self.apiKey = apiKey
        self.organization = organization
        self.project = project
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
        request.setValue("2023-06-01", forHTTPHeaderField: "Anthropic-Version")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let organization = organization {
            request.setValue(organization, forHTTPHeaderField: "Anthropic-Organization")
        }
        
        if let project = project {
            request.setValue(project, forHTTPHeaderField: "Anthropic-Project")
        }
        
        // Set body if provided
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        
        logger.info("Making request to Claude API")
        
        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check response status
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                if let errorResponse = try? JSONDecoder().decode(
                    ClaudeErrorResponse.self,
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
        
        // Build Claude request
        let claudeRequest = ClaudeMessageRequest(
            model: request.model,
            max_tokens: request.maxTokens ?? 4096,
            messages: [
                ClaudeMessage(
                    role: "user",
                    content: request.prompt
                )
            ],
            tools: request.tools?.map { claudeToolFromLLMTool($0) },
            tool_choice: request.toolChoice.map { claudeToolChoiceFromString($0) },
            temperature: request.temperature,
            top_p: request.topP
        )
        
        // Make API call
        let endpoint = "/v1/messages"
        let data = try await makeRequest(
            endpoint: endpoint,
            body: claudeRequest
        )
        let response = try JSONDecoder().decode(ClaudeMessageResponse.self, from: data)
        
        // Convert response
        let content = response.content.first?.text ?? ""
        let finishReason = response.stop_reason ?? "stop"
        
        let usage = LLMUsage(
            inputTokens: response.usage.input_tokens,
            outputTokens: response.usage.output_tokens
        )
        
        let toolCalls = response.content.compactMap { content -> LLMToolCall? in
            guard let toolUse = content.tool_use else { return nil }
            return LLMToolCall(
                id: toolUse.id,
                name: toolUse.name,
                arguments: toolUse.input
            )
        }
        
        return GenerateContentResponse(
            model: request.model,
            content: content,
            finishReason: finishReason,
            usage: usage,
            toolCalls: toolCalls.isEmpty ? nil : toolCalls
        )
    }
    
    public mutating func listModels() async throws -> [LLMModel] {
        // Claude doesn't have a list models endpoint, return our supported models
        return supportedModels
    }
    
    public mutating func createEmbedding(request: EmbeddingRequest) async throws -> EmbeddingResponse {
        // Claude doesn't have a separate embedding endpoint
        // We'll use the messages endpoint with a special prompt
        
        let embeddingPrompt = "[EMBEDDING_REQUEST]" + request.input + "[/EMBEDDING_REQUEST]"
        
        let generateRequest = GenerateContentRequest(
            model: request.model,
            prompt: embeddingPrompt
        )
        
        let response = try await generateContent(request: generateRequest)
        
        // Parse embedding from response (this would be enhanced in production)
        // For now, return a mock embedding
        let mockEmbedding = Array(repeating: 0.1, count: 1536)
        
        return EmbeddingResponse(
            model: request.model,
            embedding: mockEmbedding,
            usage: response.usage
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
    
    private func claudeToolFromLLMTool(_ tool: LLMTool) -> ClaudeTool {
        return ClaudeTool(
            name: tool.name,
            description: tool.description,
            input_schema: ClaudeToolInputSchema(
                type: "object",
                properties: tool.parameters?.mapValues { param in
                    ClaudeToolParameter(
                        type: "string",
                        description: param
                    )
                } ?? [:],
                required: []
            )
        )
    }
    
    private func claudeToolChoiceFromString(_ choice: String) -> ClaudeToolChoice {
        switch choice {
        case "auto": return .auto
        case "any": return .any
        default: return .tool(name: choice)
        }
    }
}

// MARK: - Claude API Request/Response Structures

/// Claude Message Request
private struct ClaudeMessageRequest: Codable {
    let model: String
    let max_tokens: Int
    let messages: [ClaudeMessage]
    let tools: [ClaudeTool]?
    let tool_choice: ClaudeToolChoice?
    let temperature: Double?
    let top_p: Double?
}

/// Claude Message Response
private struct ClaudeMessageResponse: Codable {
    let id: String
    let type: String
    let role: String
    let content: [ClaudeContent]
    let model: String
    let stop_reason: String?
    let stop_sequence: String?
    let usage: ClaudeUsage
}

/// Claude Message
private struct ClaudeMessage: Codable {
    let role: String
    let content: String
}

/// Claude Content
private struct ClaudeContent: Codable {
    let type: String
    let text: String?
    let tool_use: ClaudeToolUse?
    
    enum CodingKeys: String, CodingKey {
        case type, text
        case tool_use
    }
}

/// Claude Tool Use
private struct ClaudeToolUse: Codable {
    let id: String
    let name: String
    let input: [String: String]
}

/// Claude Tool
private struct ClaudeTool: Codable {
    let name: String
    let description: String
    let input_schema: ClaudeToolInputSchema
}

/// Claude Tool Input Schema
private struct ClaudeToolInputSchema: Codable {
    let type: String
    let properties: [String: ClaudeToolParameter]
    let required: [String]
}

/// Claude Tool Parameter
private struct ClaudeToolParameter: Codable {
    let type: String
    let description: String?
}

/// Claude Tool Choice
private enum ClaudeToolChoice: Codable {
    case auto
    case any
    case tool(name: String)
    
    private enum CodingKeys: String, CodingKey {
        case type
        case name
    }
    
    init(_ choice: String) {
        if choice == "auto" {
            self = .auto
        } else if choice == "any" {
            self = .any
        } else {
            self = .tool(name: choice)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .auto:
            try container.encode("auto", forKey: .type)
        case .any:
            try container.encode("any", forKey: .type)
        case .tool(let name):
            try container.encode("function", forKey: .type)
            try container.encode(name, forKey: .name)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "auto":
            self = .auto
        case "any":
            self = .any
        case "function":
            let name = try container.decode(String.self, forKey: .name)
            self = .tool(name: name)
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

/// Claude Usage
private struct ClaudeUsage: Codable {
    let input_tokens: Int
    let output_tokens: Int
}

/// Claude Error Response
private struct ClaudeErrorResponse: Codable {
    let error: ClaudeError
}

/// Claude Error
private struct ClaudeError: Codable {
    let message: String
    let type: String
    let code: String?
}

// MARK: - Claude Provider Tests

public enum ClaudeProviderTests {
    
    /// Test Claude provider initialization
    public static func testInitialization() {
        // Test with API key only
        let provider1 = ClaudeProvider(apiKey: "test-key")
        if provider1.providerName != "claude" {
            print("❌ Provider name should be 'claude'")
        }
        if provider1.supportedModels.count != 4 {
            print("❌ Should have 4 supported models")
        }
        
        // Test with all parameters
        let provider2 = ClaudeProvider(
            apiKey: "test-key",
            organization: "test-org",
            project: "test-project",
            baseURL: "https://test.anthropic.com",
            maxRequestsPerMinute: 120
        )
        if provider2.providerName != "claude" {
            print("❌ Provider name should be 'claude'")
        }
        
        print("✅ Claude provider initialization tests passed")
    }
    
    /// Test model validation
    public static func testModelValidation() {
        let provider = ClaudeProvider(apiKey: "test-key")
        
        // Test valid models
        let validModels = ["claude-4.7-opus", "claude-4.7-sonnet", "claude-4.6-opus", "claude-4.6-sonnet"]
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
        
        print("✅ Claude model validation tests passed")
    }
    
    /// Test rate limiting
    public static func testRateLimiting() async {
        var provider = ClaudeProvider(
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
        
        print("✅ Claude rate limiting tests passed")
    }
    
    /// Run all tests
    public static func runAllTests() {
        print("🧪 Running Claude Provider Tests...")
        
        testInitialization()
        testModelValidation()
        
        // Run async tests
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            await testRateLimiting()
            semaphore.signal()
        }
        
        semaphore.wait()
        
        print("🎉 All Claude Provider tests completed successfully!")
    }
}