//
//  AgenticLoopExecutor.swift
//  AnigmaCore
//
//  Advanced agentic execution loop (OODA: Observe-Orient-Decide-Act).
//  Inspired by Gemini CLI's LocalAgentExecutor.
//

import Foundation
import ContractsCore
import InferenceCore

public actor AgenticLoopExecutor {
    private let maxTurns = 30
    private var currentTurn = 0
    private var history: [InferenceMessage] = []
    private let compressionService = ContextCompressionService()

    public init() {}

    public enum TurnResult {
        case `continue`(InferenceMessage)
        case toolCall([InferenceToolCall])
        case complete(String)
        case error(Error)
    }

    public func executeTurn(
        input: String,
        context: ExecutionContext,
        runtime: RuntimeServices
    ) async throws -> TurnResult {
        currentTurn += 1
        guard currentTurn <= maxTurns else {
            return .error(AgentError.maxTurnsReached)
        }

        // 1. Observe & Orient (History Management)
        history.append(InferenceMessage(role: "user", content: input))

        // Trigger compression if history is approaching limit
        let tokenEstimate = history.reduce(0) { $0 + ($1.content.count / 4) }
        if tokenEstimate > 24000 {
            print("AgenticLoopExecutor: Context approaching limit (\(tokenEstimate) tokens). Compressing...")
            history = try await compressionService.compress(history, runtime: runtime, context: context)
        }

        // 2. Decide (Inference Call)
        let request = InferenceRequest(
            task: .chat,
            input: input,
            options: ["temperature": .number(0.7)]
        )

        let response = try await runtime.inference.chatCompletion(request, priority: .ui, speculativeConfig: nil, context: context)

        // 3. Act (Parse Response)
        if response.output.contains("TOOL_CALL:") {
            let toolCalls = parseToolCalls(from: response.output)
            return .toolCall(toolCalls)
        } else if response.output.contains("TASK_COMPLETE:") {
            return .complete(response.output)
        }

        let assistantMessage = InferenceMessage(role: "assistant", content: response.output)
        history.append(assistantMessage)

        return .continue(assistantMessage)
    }

    private func parseToolCalls(from output: String) -> [InferenceToolCall] {
        // Implementation for parsing TOOL_CALL: { "name": "...", "args": { ... } }
        return []
    }
}

public struct InferenceMessage: Codable, Sendable {
    public let role: String
    public let content: String
}

public struct InferenceToolCall: Codable, Sendable {
    public let id: String
    public let name: String
    public let arguments: [String: String]
}

public enum AgentError: Error {
    case maxTurnsReached
}
