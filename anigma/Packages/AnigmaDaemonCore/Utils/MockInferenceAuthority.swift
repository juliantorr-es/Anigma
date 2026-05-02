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
        speculativeConfig: AnigmaCore.SpeculativeConfiguration?,
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
        try await chatCompletion(task, priority: InferencePriority.background, speculativeConfig: nil as AnigmaCore.SpeculativeConfiguration?, context: context)
    }
    
    func rerank(
        _ request: AnigmaCore.RerankRequest,
        priority: InferencePriority,
        context: ExecutionContext
    ) async throws -> AnigmaCore.RerankResponse {
        // Return an empty rerank response via Codable since the response type
        // does not expose a public memberwise initializer here.
        let data = Data(#"{"results":[]}"#.utf8)
        return try JSONDecoder().decode(AnigmaCore.RerankResponse.self, from: data)
    }
    
    func getStatus() async -> [InferencePlaneStatus] {
        return [
            InferencePlaneStatus(planeId: "ui", isAvailable: true, currentLoad: 0.0),
            InferencePlaneStatus(planeId: "worker", isAvailable: true, currentLoad: 0.0)
        ]
    }
}
