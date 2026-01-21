//
//  ContextCompressionService.swift
//  AnigmaCore
//
//  Summarizes and prunes long conversation histories to fit model limits.
//  Inspired by Gemini CLI's ChatCompressionService.
//

import Foundation
import InferenceCore

public actor ContextCompressionService {
    private let tokenLimit: Int
    private let reservedTokens: Int // Tokens kept for the next prompt

    public init(tokenLimit: Int = 32000, reservedTokens: Int = 4000) {
        self.tokenLimit = tokenLimit
        self.reservedTokens = reservedTokens
    }

    public func compress(
        _ messages: [InferenceMessage],
        runtime: RuntimeServices,
        context: ExecutionContext
    ) async throws -> [InferenceMessage] {
        let currentEstimate = estimateTokens(messages)

        guard currentEstimate > (tokenLimit - reservedTokens) else {
            return messages
        }

        // Strategy: Keep last 5 messages raw, summarize older history
        let recentCount = 5
        guard messages.count > recentCount else { return messages }

        let olderHistory = messages.prefix(messages.count - recentCount)
        let recentHistory = messages.suffix(recentCount)

        let summaryPrompt = "Summarize the following conversation history concisely while preserving key facts and decisions:\n\n" +
            olderHistory.map { "\($0.role): \($0.content)" }.joined(separator: "\n")

        let request = InferenceRequest(
            task: .textGeneration,
            input: summaryPrompt,
            options: ["max_tokens": .integer(500)]
        )

        // Use background plane for compression
        let response = try await runtime.inference.backgroundTask(request, context: context)

        var newHistory: [InferenceMessage] = []
        newHistory.append(InferenceMessage(role: "system", content: "Previous conversation summary: " + response.output))
        newHistory.append(contentsOf: recentHistory)

        return newHistory
    }

    private func estimateTokens(_ messages: [InferenceMessage]) -> Int {
        // Rough estimation: 4 chars per token
        return messages.reduce(0) { $0 + ($1.content.count / 4) }
    }
}
