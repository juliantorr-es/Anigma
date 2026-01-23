//
//  MockInferenceAuthority.swift
//  AnigmaDaemonCore
//
//  Dummy implementation of InferenceAuthority for testing and development.
//

import Foundation
import AnigmaCore
import InferenceCore

actor MockInferenceAuthority: InferenceAuthority {
    func chatCompletion(
        _ request: InferenceRequest,
        priority: InferencePriority,
        speculativeConfig: SpeculativeConfiguration?,
        context: ExecutionContext
    ) async throws -> InferenceResponse {
        // Return a mock response with some generated code
        let mockOutput = """
        // Generated code based on context
        func example() {
            print("Hello, world!")
        }
        """
        return InferenceResponse(
            output: mockOutput,
            usage: InferenceUsage(inputTokens: 10, outputTokens: 20),
            metadata: ["model": "mock"]
        )
    }
    
    func backgroundTask(
        _ task: InferenceRequest,
        context: ExecutionContext
    ) async throws -> InferenceResponse {
        // Same as chatCompletion but with background flavor
        try await chatCompletion(task, priority: .background, speculativeConfig: nil, context: context)
    }
    
    func rerank(
        _ request: RerankRequest,
        priority: InferencePriority,
        context: ExecutionContext
    ) async throws -> RerankResponse {
        // Return a dummy rerank response
        let results = request.documents.enumerated().map { index, document in
            RerankResultItem(index: index, score: Double.random(in: 0.5...1.0), document: document)
        }
        return RerankResponse(results: results, usage: InferenceUsage(inputTokens: 5, outputTokens: 0))
    }
    
    func getStatus() async -> [InferencePlaneStatus] {
        return [
            InferencePlaneStatus(planeId: "ui", isAvailable: true, currentLoad: 0.0),
            InferencePlaneStatus(planeId: "worker", isAvailable: true, currentLoad: 0.0)
        ]
    }
}