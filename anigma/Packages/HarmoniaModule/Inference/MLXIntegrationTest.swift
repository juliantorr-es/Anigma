//
//  MLXIntegrationTest.swift
//  HarmoniaModule
//
//  Integration test for MLX inference functionality.
//

@preconcurrency import Foundation
import AnigmaCore

/// Simple integration test for MLX functionality
public actor MLXIntegrationTest {
    
    /// Test basic MLX inference workflow
    public static func testMLXIntegration() async -> Bool {
        do {
            print("🧪 Starting MLX Integration Test...")
            
            // Test 1: Initialize InferenceService
            let inferenceService = InferenceService()
            print("✅ InferenceService initialized")
            
            // Test 2: Test embedding generation
            let embeddingResult = try await testEmbedding(inferenceService: inferenceService)
            if embeddingResult {
                print("✅ Embedding generation test passed")
            } else {
                print("❌ Embedding generation test failed")
                return false
            }
            
            // Test 3: Test chat completion
            let chatResult = try await testChatCompletion(inferenceService: inferenceService)
            if chatResult {
                print("✅ Chat completion test passed")
            } else {
                print("❌ Chat completion test failed")
                return false
            }
            
            print("🎉 All MLX integration tests passed!")
            return true
            
        } catch {
            print("❌ MLX Integration Test failed: \(error)")
            return false
        }
    }
    
    private static func testEmbedding(inferenceService: InferenceService) async throws -> Bool {
        let context = InferenceContext(
            tenantId: "test-tenant",
            userId: "test-user",
            requestId: "test-embed-001"
        )
        
        let embedding = try await inferenceService.embed(
            text: "This is a test sentence for embedding generation.",
            context: context
        )
        
        // Verify embedding has expected dimension (typically 384 for small models)
        return embedding.count >= 300 && embedding.count <= 1536 // Reasonable range
    }
    
    private static func testChatCompletion(inferenceService: InferenceService) async throws -> Bool {
        let context = InferenceContext(
            tenantId: "test-tenant",
            userId: "test-user", 
            requestId: "test-chat-001"
        )
        
        let constraints = InferenceConstraints(
            localOnly: true,
            privacyLevel: .local,
            maxCostTier: .free
        )
        
        let response = try await inferenceService.complete(
            prompt: "Hello! Can you tell me a short joke?",
            context: context,
            constraints: constraints
        )
        
        // Verify we got a reasonable response
        return response.count > 10 && response.count < 1000
    }
    
    /// Performance benchmark for MLX inference
    public static func performanceBenchmark() async -> [String: TimeInterval] {
        var results: [String: TimeInterval] = [:]
        
        do {
            let inferenceService = InferenceService()
            let context = InferenceContext(
                tenantId: "benchmark",
                userId: "benchmark-user",
                requestId: "perf-test"
            )
            
            // Benchmark embeddings
            let embeddingStart = Date()
            _ = try await inferenceService.embed(text: "Performance test sentence for embedding generation.", context: context)
            let embeddingTime = Date().timeIntervalSince(embeddingStart)
            results["embedding"] = embeddingTime
            
            // Benchmark chat completion
            let chatStart = Date()
            _ = try await inferenceService.complete(
                prompt: "Explain quantum computing in one sentence.",
                context: context
            )
            let chatTime = Date().timeIntervalSince(chatStart)
            results["chat"] = chatTime
            
            print("📊 Performance Results:")
            print("   Embedding: \(String(format: "%.3f", embeddingTime))s")
            print("   Chat: \(String(format: "%.3f", chatTime))s")
            
        } catch {
            print("❌ Performance benchmark failed: \(error)")
        }
        
        return results
    }
}