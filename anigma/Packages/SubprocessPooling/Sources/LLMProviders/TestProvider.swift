//
//  TestProvider.swift
//  SubprocessPooling
//
//  Created as part of Phase 6: Multi-Provider LLM Integration (td-12f9d2-phase6)
//  Simple test provider to verify the LLMProvider framework
//

import Foundation

/// Test LLM Provider for framework validation
public struct TestProvider: LLMProvider {
    public let providerName: String = "test"
    
    public let supportedModels: [LLMModel] = [
        LLMModel(
            id: "test-model-1",
            name: "Test Model 1",
            provider: "test",
            maxTokens: 4096,
            capabilities: ["text-generation", "embeddings"],
            pricing: LLMModelPricing(inputTokenCost: 0.5, outputTokenCost: 1.5)
        )
    ]
    
    public init() {}
    
    public mutating func generateContent(request: GenerateContentRequest) async throws -> GenerateContentResponse {
        // Simulate content generation
        let content = "This is a test response from " + request.model + ": " + request.prompt
        let usage = LLMUsage(inputTokens: request.prompt.count, outputTokens: content.count)
        
        return GenerateContentResponse(
            model: request.model,
            content: content,
            finishReason: "stop",
            usage: usage
        )
    }
    
    public mutating func listModels() async throws -> [LLMModel] {
        return supportedModels
    }
    
    public mutating func createEmbedding(request: EmbeddingRequest) async throws -> EmbeddingResponse {
        // Simulate embedding creation
        let embedding = Array(repeating: 0.1, count: 1536) // Typical embedding size
        let usage = LLMUsage(inputTokens: request.input.count, outputTokens: 0)
        
        return EmbeddingResponse(
            model: request.model,
            embedding: embedding,
            usage: usage
        )
    }
    
    public func isHealthy() -> Bool {
        return true
    }
    
    public func getMetrics() -> LLMProviderMetrics {
        return LLMProviderMetrics(
            requestsCompleted: 100,
            requestsFailed: 2,
            averageLatency: 45.2,
            activeRequests: 0,
            lastRequestTime: Date()
        )
    }
}

/// Test the LLM Provider Framework
public enum LLMProviderFrameworkTests {
    
    /// Test provider registration and retrieval
    public static func testProviderRegistry() async {
        let registry = LLMProviderRegistry()
        let testProvider = TestProvider()
        
        // Register provider
        await registry.registerProvider(testProvider)
        
        // Verify registration
        let providers = await registry.listProviders()
        assert(providers.contains("test"), "Test provider should be registered")
        
        // Retrieve provider
        let retrievedProvider = await registry.getProvider(named: "test")
        assert(retrievedProvider != nil, "Should be able to retrieve test provider")
        
        // Test health check
        let isHealthy = await registry.isProviderHealthy(named: "test")
        assert(isHealthy, "Test provider should be healthy")
        
        // Test metrics
        let metrics = await registry.getMetrics(for: "test")
        assert(metrics != nil, "Should have metrics for test provider")
        
        print("✅ LLM Provider Registry tests passed")
    }
    
    /// Test provider functionality
    public static func testProviderFunctionality() async {
        var provider = TestProvider()
        
        // Test model listing
        let models = try? await provider.listModels()
        assert(models?.count == 1, "Should have 1 test model")
        assert(models?[0].name == "Test Model 1", "Model name should match")
        
        // Test content generation
        let generateRequest = GenerateContentRequest(
            model: "test-model-1",
            prompt: "Hello, world!"
        )
        
        let generateResponse = try? await provider.generateContent(request: generateRequest)
        assert(generateResponse != nil, "Should generate content successfully")
        assert(generateResponse?.content.contains("Hello, world!") == true, "Response should contain prompt")
        
        // Test embedding creation
        let embeddingRequest = EmbeddingRequest(
            model: "test-model-1",
            input: "Test input"
        )
        
        let embeddingResponse = try? await provider.createEmbedding(request: embeddingRequest)
        assert(embeddingResponse != nil, "Should create embedding successfully")
        assert(embeddingResponse?.embedding.count == 1536, "Embedding should have 1536 dimensions")
        
        print("✅ LLM Provider Functionality tests passed")
    }
    
    /// Run all tests
    public static func runAllTests() async {
        print("🧪 Running LLM Provider Framework Tests...")
        
        await testProviderRegistry()
        await testProviderFunctionality()
        
        print("🎉 All LLM Provider Framework tests completed successfully!")
    }
}