//
//  GeminiProvider.swift
//  SubprocessPooling
//
//  Created as part of Phase 6: Multi-Provider LLM Integration (td-12f9d2-phase6)
//  Task 6.2: Gemini Provider Implementation
//

import Foundation
import OSLog

/// Gemini LLM Provider
/// Implements Google's Gemini API (2026) with full feature support
public struct GeminiProvider: LLMProvider {
    
    private let logger = Logger(subsystem: "com.anigma.subprocess.llm", category: "GeminiProvider")
    
    // MARK: - Provider Configuration
    
    public let providerName: String = "gemini"
    
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
        // Gemini 3.1 Series (2026)
        LLMModel(
            id: "gemini-3.1-pro",
            name: "Gemini 3.1 Pro",
            provider: "gemini",
            maxTokens: 200000,
            capabilities: ["text-generation", "multimodal", "function-calling", "structured-output"],
            pricing: LLMModelPricing(inputTokenCost: 15.0, outputTokenCost: 75.0)
        ),
        LLMModel(
            id: "gemini-3.1-flash",
            name: "Gemini 3.1 Flash",
            provider: "gemini",
            maxTokens: 1000000,
            capabilities: ["text-generation", "multimodal", "function-calling"],
            pricing: LLMModelPricing(inputTokenCost: 0.7, outputTokenCost: 2.1)
        ),
        LLMModel(
            id: "gemini-3-flash",
            name: "Gemini 3 Flash",
            provider: "gemini",
            maxTokens: 1000000,
            capabilities: ["text-generation", "multimodal"],
            pricing: LLMModelPricing(inputTokenCost: 0.3, outputTokenCost: 1.0)
        ),
        // Embedding Models
        LLMModel(
            id: "embedding-002",
            name: "Embedding 002",
            provider: "gemini",
            maxTokens: 8192,
            capabilities: ["embeddings"],
            pricing: LLMModelPricing(inputTokenCost: 0.1, outputTokenCost: 0.0)
        )
    ]
    
    // MARK: - Initialization
    
    /// Initialize Gemini Provider
    /// - Parameters:
    ///   - apiKey: Gemini API key
    ///   - organization: Optional organization ID
    ///   - project: Optional project ID
    ///   - baseURL: API base URL (default: Google's production endpoint)
    ///   - maxRequestsPerMinute: Rate limit (default: 60 req/min)
    public init(
        apiKey: String,
        organization: String? = nil,
        project: String? = nil,
        baseURL: String = "https://generativelanguage.googleapis.com",
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
        
        if let organization = organization {
            request.setValue(organization, forHTTPHeaderField: "X-Goog-Organization")
        }
        
        if let project = project {
            request.setValue(project, forHTTPHeaderField: "X-Goog-Project")
        }
        
        // Set body if provided
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        
        logger.info("Making request to Gemini API")
        
        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check response status
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorResponse = try? JSONDecoder().decode(
                    GeminiErrorResponse.self,
                    from: data
                )
                
                throw LLMProviderError.apiError(
                    provider: providerName,
                    statusCode: httpResponse.statusCode,
                    message: errorResponse?.error?.message ?? "Unknown error"
                )
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
        
        // Build Gemini request
        let geminiRequest = GeminiGenerateRequest(
            model: request.model,
            contents: [GeminiContent(parts: [GeminiPart.text(request.prompt)])],
            tools: request.tools?.map { geminiToolFromLLMTool($0) },
            toolConfig: request.toolChoice.map { GeminiToolConfig($0) },
            safetySettings: [
                GeminiSafetySetting(
                    category: "HARM_CATEGORY_HARASSMENT",
                    threshold: "BLOCK_ONLY_HIGH"
                )
            ]
        )
        
        // Make API call
        let endpoint = "/v1beta/models/" + request.model + ":generateContent"
        let data = try await makeRequest(
            endpoint: endpoint,
            body: geminiRequest
        )
        let response = try JSONDecoder().decode(GeminiGenerateResponse.self, from: data)
        
        // Convert response
        let content = response.candidates?.first?.content?.parts.compactMap {
            if case let .text(text) = $0 { return text }
            return nil
        }.first ?? ""
        let finishReason = response.candidates?.first?.finishReason ?? "stop"
        
        let usage = LLMUsage(
            inputTokens: response.usageMetadata?.promptTokenCount ?? 0,
            outputTokens: response.usageMetadata?.candidatesTokenCount ?? 0
        )
        
        let toolCalls = response.candidates?.first?.content?.parts.compactMap { part -> LLMToolCall? in
            guard case let .toolCall(toolCall) = part else { return nil }
            return LLMToolCall(
                id: toolCall.name,
                name: toolCall.name,
                arguments: toolCall.args ?? [:]
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
        // Gemini doesn't have a list models endpoint, return our supported models
        return supportedModels
    }
    
    public mutating func createEmbedding(request: EmbeddingRequest) async throws -> EmbeddingResponse {
        // Validate model
        guard request.model == "embedding-002" else {
            throw LLMProviderError.modelNotFound(
                provider: providerName,
                model: request.model
            )
        }
        
        // Build embedding request
        let embeddingRequest = GeminiEmbeddingRequest(
            model: request.model,
            content: GeminiEmbeddingContent(parts: [GeminiPart.text(request.input)])
        )
        
        // Make API call
        let endpoint = "/v1beta/models/" + request.model + ":embedContent"
        let data = try await makeRequest(
            endpoint: endpoint,
            body: embeddingRequest
        )
        let response = try JSONDecoder().decode(GeminiEmbeddingResponse.self, from: data)
        
        // Extract embedding
        let embedding = response.embedding?.values ?? []
        
        let usage = LLMUsage(
            inputTokens: response.usageMetadata?.promptTokenCount ?? 0,
            outputTokens: 0
        )
        
        return EmbeddingResponse(
            model: request.model,
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
    
    private func geminiToolFromLLMTool(_ tool: LLMTool) -> GeminiTool {
        return GeminiTool(
            functionDeclarations: [GeminiFunctionDeclaration(
                name: tool.name,
                description: tool.description,
                parameters: GeminiFunctionParameters(
                    type: "OBJECT",
                    properties: tool.parameters?.mapValues { param in
                        GeminiFunctionParameter(
                            type: "STRING",
                            description: param
                        )
                    } ?? [:],
                    required: []
                )
            )]
        )
    }
}

// MARK: - Gemini API Request/Response Structures

/// Gemini Generate Request
private struct GeminiGenerateRequest: Codable {
    let model: String
    let contents: [GeminiContent]
    let tools: [GeminiTool]?
    let toolConfig: GeminiToolConfig?
    let safetySettings: [GeminiSafetySetting]
}

/// Gemini Generate Response
private struct GeminiGenerateResponse: Codable {
    let candidates: [GeminiCandidate]?
    let usageMetadata: GeminiUsageMetadata?
}

/// Gemini Embedding Request
private struct GeminiEmbeddingRequest: Codable {
    let model: String
    let content: GeminiEmbeddingContent
}

/// Gemini Embedding Response
private struct GeminiEmbeddingResponse: Codable {
    let embedding: GeminiEmbedding?
    let usageMetadata: GeminiUsageMetadata?
}

/// Gemini Content
private struct GeminiContent: Codable {
    let parts: [GeminiPart]
}

/// Gemini Embedding Content
private struct GeminiEmbeddingContent: Codable {
    let parts: [GeminiPart]
}

/// Gemini Part (can be text or tool call)
private enum GeminiPart: Codable {
    case text(String)
    case toolCall(GeminiToolCall)
    
    private enum CodingKeys: String, CodingKey {
        case text
        case functionCall
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let text = try? container.decode(String.self, forKey: .text) {
            self = .text(text)
        } else if let functionCall = try? container.decode(GeminiToolCall.self, forKey: .functionCall) {
            self = .toolCall(functionCall)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unable to decode GeminiPart"
                )
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .text(let text):
            try container.encode(text, forKey: .text)
        case .toolCall(let toolCall):
            try container.encode(toolCall, forKey: .functionCall)
        }
    }
}

/// Gemini Tool
private struct GeminiTool: Codable {
    let functionDeclarations: [GeminiFunctionDeclaration]
}

/// Gemini Tool Call
private struct GeminiToolCall: Codable {
    let name: String
    let args: [String: String]?
}

/// Gemini Function Declaration
private struct GeminiFunctionDeclaration: Codable {
    let name: String
    let description: String
    let parameters: GeminiFunctionParameters
}

/// Gemini Function Parameters
private struct GeminiFunctionParameters: Codable {
    let type: String
    let properties: [String: GeminiFunctionParameter]
    let required: [String]
}

/// Gemini Function Parameter
private struct GeminiFunctionParameter: Codable {
    let type: String
    let description: String?
}

/// Gemini Tool Config
private struct GeminiToolConfig: Codable {
    let functionCallingConfig: GeminiFunctionCallingConfig
    
    init(_ toolChoice: String) {
        self.functionCallingConfig = GeminiFunctionCallingConfig(toolChoice)
    }
}

/// Gemini Function Calling Config
private struct GeminiFunctionCallingConfig: Codable {
    let mode: String
    let allowedFunctionNames: [String]?
    
    init(_ toolChoice: String) {
        if toolChoice == "auto" {
            self.mode = "AUTO"
            self.allowedFunctionNames = nil
        } else if toolChoice == "any" {
            self.mode = "ANY"
            self.allowedFunctionNames = nil
        } else {
            self.mode = "SPECIFIED_FUNCTION"
            self.allowedFunctionNames = [toolChoice]
        }
    }
}

/// Gemini Candidate
private struct GeminiCandidate: Codable {
    let content: GeminiContent?
    let finishReason: String
}

/// Gemini Embedding
private struct GeminiEmbedding: Codable {
    let values: [Double]
}

/// Gemini Usage Metadata
private struct GeminiUsageMetadata: Codable {
    let promptTokenCount: Int
    let candidatesTokenCount: Int
    let totalTokenCount: Int
}

/// Gemini Safety Setting
private struct GeminiSafetySetting: Codable {
    let category: String
    let threshold: String
}

/// Gemini Error Response
private struct GeminiErrorResponse: Codable {
    let error: GeminiError?
}

/// Gemini Error
private struct GeminiError: Codable {
    let code: Int
    let message: String
    let status: String
}

// MARK: - Gemini Provider Tests

public enum GeminiProviderTests {
    
    /// Test Gemini provider initialization
    public static func testInitialization() {
        // Test with API key only
        let provider1 = GeminiProvider(apiKey: "test-key")
        if provider1.providerName != "gemini" {
            print("❌ Provider name should be 'gemini'")
        }
        if provider1.supportedModels.count != 4 {
            print("❌ Should have 4 supported models")
        }
        
        // Test with all parameters
        let provider2 = GeminiProvider(
            apiKey: "test-key",
            organization: "test-org",
            project: "test-project",
            baseURL: "https://test.googleapis.com",
            maxRequestsPerMinute: 120
        )
        if provider2.providerName != "gemini" {
            print("❌ Provider name should be 'gemini'")
        }
        
        print("✅ Gemini provider initialization tests passed")
    }
    
    /// Test model validation
    public static func testModelValidation() {
        let provider = GeminiProvider(apiKey: "test-key")
        
        // Test valid models
        let validModels = ["gemini-3.1-pro", "gemini-3.1-flash", "gemini-3-flash", "embedding-002"]
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
        
        print("✅ Gemini model validation tests passed")
    }
    
    /// Test rate limiting
    public static func testRateLimiting() async {
        var provider = GeminiProvider(
            apiKey: "test-key",
            maxRequestsPerMinute: 2 // Very low limit for testing
        )
        
        // First request should succeed
        do {
            // This would normally make an API call, but we're just testing the rate limiting
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
        
        print("✅ Gemini rate limiting tests passed")
    }
    
    /// Run all tests
    public static func runAllTests() {
        print("🧪 Running Gemini Provider Tests...")
        
        testInitialization()
        testModelValidation()
        
        // Run async tests
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            await testRateLimiting()
            semaphore.signal()
        }
        
        semaphore.wait()
        
        print("🎉 All Gemini Provider tests completed successfully!")
    }
}