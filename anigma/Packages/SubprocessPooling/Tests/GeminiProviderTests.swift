//
//  GeminiProviderTests.swift
//  SubprocessPoolingTests
//
//  Created as part of Phase 6: Multi-Provider LLM Integration (td-12f9d2-phase6)
//  Tests for Gemini Provider implementation
//

import XCTest
@testable import SubprocessPooling

final class GeminiProviderTests: XCTestCase {
    
    func testGeminiProviderInitialization() {
        // Test that Gemini provider can be initialized
        var provider = GeminiProvider(apiKey: "test-key")
        
        // Verify basic properties
        XCTAssertEqual(provider.providerName, "gemini")
        XCTAssertFalse(provider.supportedModels.isEmpty)
        XCTAssertEqual(provider.supportedModels.count, 8) // 4 generation + 2 embedding + 2 vision models
        
        // Verify all models are from Gemini
        for model in provider.supportedModels {
            XCTAssertEqual(model.provider, "gemini")
        }
        
        print("✅ Gemini provider initialization tests passed")
    }
    
    func testGeminiProviderModelValidation() {
        var provider = GeminiProvider(apiKey: "test-key")
        
        // Test that model validation works
        let validModels = ["gemini-3.1-pro", "gemini-3.1-flash", "gemini-3-flash", "embedding-002"]
        let invalidModel = "non-existent-model"
        
        for model in validModels {
            let isSupported = provider.supportedModels.contains(where: { $0.id == model })
            XCTAssertTrue(isSupported, "Model \\(\\(model)\\) should be supported")
        }
        
        let isInvalidSupported = provider.supportedModels.contains(where: { $0.id == invalidModel })
        XCTAssertFalse(isInvalidSupported, "Invalid model should not be supported")
        
        print("✅ Gemini provider model validation tests passed")
    }
    
    func testGeminiProviderRateLimiting() async {
        var provider = GeminiProvider(
            apiKey: "test-key",
            maxRequestsPerMinute: 2 // Set low limit for testing
        )
        
        // First request should succeed
        do {
            try provider.checkRateLimit()
            print("✅ First request allowed")
        } catch {
            XCTFail("First request should not be rate limited")
        }
        
        // Second request should succeed
        do {
            try provider.checkRateLimit()
            print("✅ Second request allowed")
        } catch {
            XCTFail("Second request should not be rate limited")
        }
        
        // Third request should fail (exceeds limit of 2)
        do {
            try provider.checkRateLimit()
            XCTFail("Third request should have been rate limited")
        } catch let error as LLMProviderError {
            if case .rateLimitExceeded = error {
                print("✅ Third request correctly rate limited")
            } else {
                XCTFail("Expected rate limit error, got: \\(\\(error)\\)")
            }
        } catch {
            XCTFail("Expected rate limit error, got: \\(\\(error)\\)")
        }
        
        print("✅ Gemini provider rate limiting tests passed")
    }
    
    func testGeminiProviderHealthCheck() {
        var provider = GeminiProvider(apiKey: "test-key")
        
        // Provider should be healthy (basic implementation)
        let isHealthy = provider.isHealthy()
        XCTAssertTrue(isHealthy, "Provider should be healthy")
        
        print("✅ Gemini provider health check tests passed")
    }
    
    func testGeminiProviderMetrics() {
        var provider = GeminiProvider(apiKey: "test-key")
        
        // Test that metrics can be retrieved
        let metrics = provider.getMetrics()
        
        // Verify metrics structure
        XCTAssertEqual(metrics.requestsCompleted, 0)
        XCTAssertEqual(metrics.requestsFailed, 0)
        XCTAssertNil(metrics.averageLatency)
        XCTAssertEqual(metrics.activeRequests, 0)
        XCTAssertNil(metrics.lastRequestTime)
        
        print("✅ Gemini provider metrics tests passed")
    }
    
    static var allTests = [
        ("testGeminiProviderInitialization", testGeminiProviderInitialization),
        ("testGeminiProviderModelValidation", testGeminiProviderModelValidation),
        ("testGeminiProviderRateLimiting", testGeminiProviderRateLimiting),
        ("testGeminiProviderHealthCheck", testGeminiProviderHealthCheck),
        ("testGeminiProviderMetrics", testGeminiProviderMetrics)
    ]
}