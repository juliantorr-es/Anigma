//
//  ContextCompressionService.swift
//  AnigmaCore
//
//  Summarizes and prunes long conversation histories to fit model limits.
//  Inspired by Gemini CLI's ChatCompressionService.
//

import AnigmaFoundation
import AnigmaGovernance
import AnigmaPrimitives
import ContractsCore
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

    // MARK: - Optimization Strategies

    public enum PruningStrategy {
        case supersedeWrites
    }

    /// Optimizes message history by applying pruning strategies to remove redundant information.
    /// This is a deterministic operation that does not require model inference.
    public func optimize(
        _ messages: [InferenceMessage],
        strategies: [PruningStrategy] = [.supersedeWrites]
    ) -> [InferenceMessage] {
        var currentMessages = messages
        
        if strategies.contains(.supersedeWrites) {
            currentMessages = pruneSupersededWrites(currentMessages)
        }
        
        return currentMessages
    }

    private func pruneSupersededWrites(_ messages: [InferenceMessage]) -> [InferenceMessage] {
        // 1. Identify write operations
        // Map of FilePath -> [Indices of write messages]
        var writesByPath: [String: [Int]] = [:]
        
        // Map of Index -> ToolCall info
        struct ToolCallInfo {
            let name: String
            let path: String
        }
        var toolCallsByIndex: [Int: ToolCallInfo] = [:]

        for (index, message) in messages.enumerated() {
            if let toolCall = parseToolCall(from: message.content) {
                if let path = toolCall.path {
                    toolCallsByIndex[index] = ToolCallInfo(name: toolCall.name, path: path)
                    
                    if toolCall.name == "write" || toolCall.name == "write_file" {
                        var indices = writesByPath[path] ?? []
                        indices.append(index)
                        writesByPath[path] = indices
                    }
                }
            }
        }

        var indicesToPrune: Set<Int> = []

        // 2. Determine which writes are superseded
        // A write is superseded if there is a subsequent read or write to the same path
        for (path, writeIndices) in writesByPath {
            for writeIndex in writeIndices {
                // Look ahead for reads or writes
                let isSuperseded = messages.indices.dropFirst(writeIndex + 1).contains { subsequentIndex in
                    guard let subsequentCall = toolCallsByIndex[subsequentIndex] else { return false }
                    return subsequentCall.path == path && 
                           (subsequentCall.name == "read" || subsequentCall.name == "read_file" || 
                            subsequentCall.name == "write" || subsequentCall.name == "write_file")
                }

                if isSuperseded {
                    indicesToPrune.insert(writeIndex)
                }
            }
        }

        // 3. Apply pruning
        if indicesToPrune.isEmpty {
            return messages
        }

        var newMessages = messages
        for index in indicesToPrune {
            let original = newMessages[index]
            // We assume the tool call is in the format TOOL_CALL: {...}
            // We want to preserve the fact a write happened, but remove the content
            if let prunedContent = createPrunedWriteContent(original.content) {
                newMessages[index] = InferenceMessage(role: original.role, content: prunedContent)
            }
        }

        return newMessages
    }

    // Helper to parse tool calls roughly
    // Returns (name, path)
    private func parseToolCall(from content: String) -> (name: String, path: String?)? {
        // Quick heuristics for JSON parsing
        guard let range = content.range(of: "TOOL_CALL:") else { return nil }
        let jsonString = String(content[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = json["name"] as? String else {
            return nil
        }

        var path: String? = nil
        if let args = json["arguments"] as? [String: Any] {
            path = args["path"] as? String ?? args["file_path"] as? String ?? args["filename"] as? String
        }

        return (name, path)
    }

    private func createPrunedWriteContent(_ originalContent: String) -> String? {
        guard let range = originalContent.range(of: "TOOL_CALL:") else { return nil }
        let prefix = originalContent[..<range.upperBound]
        let jsonString = String(originalContent[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = jsonString.data(using: .utf8),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // Remove content from arguments
        if var args = json["arguments"] as? [String: Any] {
            args["content"] = "[Content pruned: File state superseded by later operations]"
            json["arguments"] = args
            
            if let newData = try? JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]),
               let newJsonString = String(data: newData, encoding: .utf8) {
                return String(prefix) + " " + newJsonString
            }
        }
        
        return nil
    }
}
