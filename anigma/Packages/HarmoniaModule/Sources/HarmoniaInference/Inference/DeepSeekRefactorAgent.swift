//
//  DeepSeekRefactorAgent.swift
//  HarmoniaModule
//
//  Created by Anigma Agent on 2026-01-12.
//

import Foundation
import HarmoniaCore
import AnigmaCore
import AnigmaPrimitives
import InferenceCore
import os.log
@preconcurrency import Foundation

/// AI agent powered by DeepSeek for intelligent refactoring.
private let log = Logger(subsystem: "com.anigma.harmonia", category: "actor")
public actor DeepSeekRefactorAgent {
    public let agentId: Int
    private let apiKey: String
    private let apiUrl = URL(string: "https://api.deepseek.com/v1/chat/completions")!
    private let model = "deepseek-chat"
    
    public var totalTokensUsed: Int = 0
    
    public init(agentId: Int, apiKey: String) {
        self.agentId = agentId
        self.apiKey = apiKey
    }
    
    /// Use DeepSeek to analyze and improve the proposed refactoring.
    public func analyzeAndRefactor(task: RefactoringTask, ruleContext: String = "") async -> (success: Bool, code: String, reasoning: String) {
        let prompt = buildRefactoringPrompt(task: task, ruleContext: ruleContext)
        
        do {
            let (responseContent, usage) = try await callDeepSeek(prompt: prompt)
            self.totalTokensUsed += usage.totalTokens
            
            let result = parseRefactoringResponse(responseContent)
            
            if result.approved {
                log.info("  🤖 Agent #\(agentId) approved: \(task.file)")
                return (true, result.code, result.reasoning)
            } else {
                log.info("  🤖 Agent #\(agentId) rejected: \(task.file) (\(result.reasoning))")
                return (false, "", result.reasoning)
            }
        } catch {
            log.info("  ❌ Agent #\(agentId) failed: \(error)")
            return (false, "", "API Error: \(error.localizedDescription)")
        }
    }
    
    private func buildRefactoringPrompt(task: RefactoringTask, ruleContext: String) -> String {
        return """
        You are an expert Swift engineer (Swift 6 concurrency aware) working on the Anigma project.
        Your task is to fix a SwiftLint violation or build error in a specific file.
        
        TASK INFO:
        Type: \(task.type)
        File: \(task.file)
        Line: \(task.line)
        Description: \(task.description)
        Strategy: \(task.metadata["fix_strategy"] ?? "Apply Swift best practices.")
        
        CONTEXT:
        The following is the code around the violation:
        --------------------------------------------------
        \(task.originalCode)
        --------------------------------------------------
        
        SwiftLint Config (.swiftlint.yml) Context:
        \(ruleContext)
        
        INSTRUCTIONS:
        1. Analyze the original code and the violation.
        2. Apply the fix strategy strictly.
        3. ENSURE the code is Swift 6 compliant (Sendable, actor isolation).
        4. Preserve indentation and formatting.
        5. Return ONLY a JSON object with the following structure:
        {
            "approved": true,
            "reasoning": "Explanation of changes...",
            "code": "The COMPLETE replaced code block (no markdown fencing)"
        }
        
        If the code cannot be fixed safely without more context, return "approved": false.
        """
    }
    
    private struct DeepSeekResponse: Codable {
        struct Choice: Codable {
            struct Message: Codable {
                let content: String
            }
            let message: Message
        }
        struct Usage: Codable {
            let total_tokens: Int
        }
        let choices: [Choice]
        let usage: Usage?
    }
    
    private struct TokenUsage {
        let totalTokens: Int
    }
    
    private func callDeepSeek(prompt: String) async throws -> (String, TokenUsage) {
        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": "You are a senior Swift engineer."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.0,
            "response_format": ["type": "json_object"]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown"
            throw NSError(domain: "DeepSeekError", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: "API Error: \(errorText)"])
        }
        
        let decoded = try JSONDecoder().decode(DeepSeekResponse.self, from: data)
        let content = decoded.choices.first?.message.content ?? "{}"
        let usage = TokenUsage(totalTokens: decoded.usage?.total_tokens ?? 0)
        
        return (content, usage)
    }
    
    private struct RefactorResult: Codable {
        let approved: Bool
        let reasoning: String
        let code: String
        
        // Handle loose decoding
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.approved = try container.decodeIfPresent(Bool.self, forKey: .approved) ?? false
            self.reasoning = try container.decodeIfPresent(String.self, forKey: .reasoning) ?? "No reasoning provided"
            self.code = try container.decodeIfPresent(String.self, forKey: .code) ?? ""
        }
        
        enum CodingKeys: String, CodingKey {
            case approved, reasoning, code
        }
        
        init(approved: Bool, reasoning: String, code: String) {
            self.approved = approved
            self.reasoning = reasoning
            self.code = code
        }
    }
    
    private func parseRefactoringResponse(_ content: String) -> RefactorResult {
        guard let data = content.data(using: .utf8) else {
            return RefactorResult(approved: false, reasoning: "Invalid response encoding", code: "")
        }
        
        do {
            return try JSONDecoder().decode(RefactorResult.self, from: data)
        } catch {
            return RefactorResult(approved: false, reasoning: "JSON Parse Error: \(error)", code: "")
        }
    }
}
