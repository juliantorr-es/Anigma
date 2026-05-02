//
//  LLMProviderFrameworkTests.swift
//  SubprocessPoolingTests
//
//  Created as part of Phase 6: Multi-Provider LLM Integration (td-12f9d2-phase6)
//  Tests for the unified LLM provider framework
//

import XCTest
import Foundation
@testable import SubprocessPooling

final class LLMProviderFrameworkTests: XCTestCase {
    
    func testLLMProviderProtocol() async {
        // Test that the protocol compiles and basic functionality works
        let testProvider = TestProvider()
        
        // Test basic properties
        XCTAssertEqual(testProvider.providerName, "test")
        XCTAssertEqual(testProvider.supportedModels.count, 1)
        XCTAssertEqual(testProvider.supportedModels[0].name, "Test Model 1")
        
        // Test health check
        XCTAssertTrue(testProvider.isHealthy())
        
        // Test metrics
        let metrics = testProvider.getMetrics()
        XCTAssertEqual(metrics.requestsCompleted, 100)
        XCTAssertEqual(metrics.requestsFailed, 2)
        XCTAssertEqual(metrics.averageLatency, 45.2)
        
        print("✅ LLMProvider protocol tests passed")
    }
    
    func testProviderRegistry() async {
        let registry = LLMProviderRegistry()
        let testProvider = TestProvider()
        
        // Test registration
        await registry.registerProvider(testProvider)
        
        // Test provider listing
        let providers = await registry.listProviders()
        XCTAssertTrue(providers.contains("test"))
        XCTAssertEqual(providers.count, 1)
        
        // Test provider retrieval
        let retrievedProvider = await registry.getProvider(named: "test")
        XCTAssertNotNil(retrievedProvider)
        
        // Test health check
        let isHealthy = await registry.isProviderHealthy(named: "test")
        XCTAssertTrue(isHealthy)
        
        // Test metrics retrieval
        let metrics = await registry.getMetrics(for: "test")
        XCTAssertNotNil(metrics)
        XCTAssertEqual(metrics?.requestsCompleted, 100)
        
        // Test provider removal
        await registry.unregisterProvider(named: "test")
        let providersAfterRemoval = await registry.listProviders()
        XCTAssertEqual(providersAfterRemoval.count, 0)
        
        print("✅ Provider registry tests passed")
    }
    
    func testContentGeneration() async {
        var provider = TestProvider()
        
        let request = GenerateContentRequest(
            model: "test-model-1",
            prompt: "Hello from XCTest!"
        )
        
        do {
            let response = try await provider.generateContent(request: request)
            XCTAssertEqual(response.model, "test-model-1")
            XCTAssertTrue(response.content.contains("Hello from XCTest!"))
            XCTAssertEqual(response.finishReason, "stop")
            XCTAssertGreaterThan(response.usage.totalTokens, 0)
            
            print("✅ Content generation tests passed")
        } catch {
            XCTFail("Content generation failed: \(error)")
        }
    }
    
    func testModelListing() async {
        var provider = TestProvider()
        
        do {
            let models = try await provider.listModels()
            XCTAssertEqual(models.count, 1)
            
            let model = models[0]
            XCTAssertEqual(model.id, "test-model-1")
            XCTAssertEqual(model.name, "Test Model 1")
            XCTAssertEqual(model.provider, "test")
            XCTAssertEqual(model.maxTokens, 4096)
            XCTAssertTrue(model.capabilities.contains("text-generation"))
            XCTAssertTrue(model.capabilities.contains("embeddings"))
            
            XCTAssertNotNil(model.pricing)
            XCTAssertEqual(model.pricing?.inputTokenCost, 0.5)
            XCTAssertEqual(model.pricing?.outputTokenCost, 1.5)
            XCTAssertEqual(model.pricing?.currency, "USD")
            
            print("✅ Model listing tests passed")
        } catch {
            XCTFail("Model listing failed: \(error)")
        }
    }
    
    func testEmbeddingCreation() async {
        var provider = TestProvider()
        
        let request = EmbeddingRequest(
            model: "test-model-1",
            input: "Test embedding input"
        )
        
        do {
            let response = try await provider.createEmbedding(request: request)
            XCTAssertEqual(response.model, "test-model-1")
            XCTAssertEqual(response.embedding.count, 1536)
            XCTAssertGreaterThan(response.usage.inputTokens, 0)
            
            print("✅ Embedding creation tests passed")
        } catch {
            XCTFail("Embedding creation failed: \(error)")
        }
    }
    
    func testAnyCodable() {
        // Test AnyCodable encoding/decoding
        let testString = AnyCodable("hello")
        let testInt = AnyCodable(42)
        let testDouble = AnyCodable(3.14)
        let testBool = AnyCodable(true)
        
        let testArray = AnyCodable(["a", "b", "c"])
        let testDict = AnyCodable(["key": "value", "other": "data"])
        
        // Test that values are stored correctly
        XCTAssertEqual(testString.value as? String, "hello")
        XCTAssertEqual(testInt.value as? Int, 42)
        XCTAssertEqual(testDouble.value as? Double, 3.14)
        XCTAssertEqual(testBool.value as? Bool, true)
        
        if let array = testArray.value as? [Any] {
            XCTAssertEqual(array.count, 3)
        } else {
            XCTFail("Array value not stored correctly")
        }
        
        if let dict = testDict.value as? [String: Any] {
            XCTAssertEqual(dict["key"] as? String, "value")
            XCTAssertEqual(dict["number"] as? Int, 123)
        } else {
            XCTFail("Dictionary value not stored correctly")
        }
        
        print("✅ AnyCodable tests passed")
    }
    
    func testErrorTypes() {
        // Test LLMProviderError cases
        let errors: [LLMProviderError] = [
            .providerUnavailable(provider: "test"),
            .authenticationFailed(provider: "test"),
            .rateLimitExceeded(provider: "test", retryAfter: 60.0),
            .modelNotFound(provider: "test", model: "unknown"),
            .invalidRequest(reason: "Invalid parameters"),
            .apiError(provider: "test", statusCode: 404, message: "Not found"),
            .networkError(provider: "test", error: NSError(domain: "test", code: 500)),
            .unknownError(provider: "test", message: "Something went wrong")
        ]
        
        for error in errors {
            // Just verify we can create and describe all error types
            let description = error.localizedDescription
            XCTAssertFalse(description.isEmpty, "Error description should not be empty")
        }
        
        print("✅ Error type tests passed")
    }
    
    func testFrameworkIntegration() async {
        // Test that the framework integrates properly with the rest of the system
        let registry = LLMProviderRegistry()
        let testProvider = TestProvider()
        
        await registry.registerProvider(testProvider)
        
        // Verify we can get all metrics
        let allMetrics = await registry.getAllMetrics()
        XCTAssertEqual(allMetrics.count, 1)
        XCTAssertNotNil(allMetrics["test"])
        
        // Test updating metrics
        var updatedMetrics = allMetrics["test"]!
        updatedMetrics.requestsCompleted = 200
        await registry.updateMetrics(for: "test", with: updatedMetrics)
        
        let metricsAfterUpdate = await registry.getMetrics(for: "test")
        XCTAssertEqual(metricsAfterUpdate?.requestsCompleted, 200)
        
        print("✅ Framework integration tests passed")
    }
}