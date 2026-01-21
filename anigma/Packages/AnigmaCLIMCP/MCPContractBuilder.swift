//
//  MCPContractBuilder.swift
//  AnigmaCLIMCP
//
//  Builds task contracts by calling anigma-mcp tools with a local-first fallback.
//

import AnigmaCLICore
import AnigmaCLIEventing
import AnigmaCLIGovernance
import Foundation
import MCP

public struct MCPContractBuilderConfiguration: Sendable {
    public let enabled: Bool
    public let includeDigest: Bool
    public let maxTokens: Int
    public let temperature: Double

    public init(
        enabled: Bool,
        includeDigest: Bool,
        maxTokens: Int,
        temperature: Double
    ) {
        self.enabled = enabled
        self.includeDigest = includeDigest
        self.maxTokens = maxTokens
        self.temperature = temperature
    }

    public static func fromEnvironment(_ environment: [String: String] = ProcessInfo.processInfo.environment)
        -> MCPContractBuilderConfiguration {
        let enabled = MCPContractBuilderConfiguration.boolValue(
            from: environment,
            key: "ANIGMA_MCP_ENABLE",
            defaultValue: true
        )
        let includeDigest = MCPContractBuilderConfiguration.boolValue(
            from: environment,
            key: "ANIGMA_MCP_DIGEST",
            defaultValue: false
        )
        let maxTokens = Int(environment["ANIGMA_MCP_MAX_TOKENS"] ?? "") ?? 512
        let temperature = Double(environment["ANIGMA_MCP_TEMPERATURE"] ?? "") ?? 0.2

        return MCPContractBuilderConfiguration(
            enabled: enabled,
            includeDigest: includeDigest,
            maxTokens: maxTokens,
            temperature: temperature
        )
    }

    private static func boolValue(from environment: [String: String], key: String, defaultValue: Bool)
        -> Bool {
        guard let raw = environment[key]?.lowercased(), !raw.isEmpty else {
            return defaultValue
        }
        switch raw {
        case "1", "true", "yes", "y", "on":
            return true
        case "0", "false", "no", "n", "off":
            return false
        default:
            return defaultValue
        }
    }
}

public struct MCPContractBuilder: ContractBuilder {
    private let configuration: MCPContractBuilderConfiguration
    private let eventStream: CLIEventStream?
    private let resolver: MCPExecutableResolver
    private let fallback: ContractBuilder
    private let policy: ContractPolicy

    public init(
        configuration: MCPContractBuilderConfiguration = .fromEnvironment(),
        eventStream: CLIEventStream? = nil,
        resolver: MCPExecutableResolver = MCPExecutableResolver(),
        fallback: ContractBuilder,
        policy: ContractPolicy = .default
    ) {
        self.configuration = configuration
        self.eventStream = eventStream
        self.resolver = resolver
        self.fallback = fallback
        self.policy = policy
    }

    public func buildContract(for task: TaskIntent, context: TaskContext) async throws -> TaskContract {
        guard configuration.enabled else {
            return try await fallback.buildContract(for: task, context: context)
        }

        guard let executableURL = resolver.resolve(repoRoot: context.repoRoot) else {
            await eventStream?.emit(
                CLIEvent(
                    kind: .warning,
                    message: "anigma-mcp not found. Falling back to local contract builder.",
                    metadata: ["repoRoot": context.repoRoot.path]
                )
            )
            return try await fallback.buildContract(for: task, context: context)
        }

        let client = MCPClientController(
            executableURL: executableURL,
            workingDirectory: context.repoRoot,
            eventStream: eventStream
        )

        do {
            await eventStream?.emit(
                CLIEvent(
                    kind: .info,
                    message: "Connecting to anigma-mcp for contract build.",
                    metadata: ["path": executableURL.path]
                )
            )

            try await client.connect()

            let contextSummary = try await fetchContext(task: task, client: client)
            let digestSummary = configuration.includeDigest
                ? try await fetchDigest(client: client)
                : nil

            let contract = try await buildWithChat(
                task: task,
                contextSummary: contextSummary,
                digestSummary: digestSummary,
                client: client
            )

            await client.disconnect()
            return contract
        } catch {
            await eventStream?.emit(
                CLIEvent(
                    kind: .warning,
                    message: "MCP contract build failed. Falling back to local builder.",
                    metadata: ["error": "\(error)"]
                )
            )
            await client.disconnect()
            return try await fallback.buildContract(for: task, context: context)
        }
    }

    private func fetchContext(task: TaskIntent, client: MCPClientController) async throws -> String? {
        await eventStream?.emit(
            CLIEvent(
                kind: .progress,
                message: "Requesting context search from MCP.",
                metadata: ["tool": "context_search"]
            )
        )

        let arguments: [String: Value] = [
            "query": .string(task.summary),
            "limit": .int(8)
        ]
        let response = try await client.callTool(name: "context_search", arguments: arguments)

        let text = try extractText(from: response)
        guard let text, let data = text.data(using: .utf8) else {
            return nil
        }

        let decoded = try JSONDecoder().decode(ContextSearchResponse.self, from: data)
        let topResults = decoded.results.prefix(5)
        if topResults.isEmpty {
            return nil
        }

        let summaryLines = topResults.map { result -> String in
            if let summary = result.summary, !summary.isEmpty {
                return "\(result.filePath): \(summary)"
            }
            return "\(result.filePath): \(result.matchReason)"
        }

        return summaryLines.joined(separator: "\n")
    }

    private func fetchDigest(client: MCPClientController) async throws -> String? {
        await eventStream?.emit(
            CLIEvent(
                kind: .progress,
                message: "Requesting codebase digest from MCP.",
                metadata: ["tool": "digest_codebase"]
            )
        )

        let response = try await client.callTool(name: "digest_codebase", arguments: [:])
        return try extractText(from: response)
    }

    private func buildWithChat(
        task: TaskIntent,
        contextSummary: String?,
        digestSummary: String?,
        client: MCPClientController
    ) async throws -> TaskContract {
        await eventStream?.emit(
            CLIEvent(
                kind: .progress,
                message: "Requesting contract draft from MCP chat.",
                metadata: ["tool": "chat"]
            )
        )

        let prompt = buildPrompt(
            task: task,
            contextSummary: contextSummary,
            digestSummary: digestSummary
        )

        let response = try await client.callTool(
            name: "chat",
            arguments: [
                "message": .string(prompt),
                "max_tokens": .int(configuration.maxTokens),
                "temperature": .double(configuration.temperature)
            ]
        )

        let text = try extractText(from: response)
        guard let text else {
            throw MCPContractError.invalidResponse("Chat response was empty.")
        }

        let contractPayload = try decodeContractPayload(from: text)
        let acceptance = ensureBaselineCriteria(contractPayload.acceptanceCriteria)

        return TaskContract(
            taskId: task.id,
            objective: contractPayload.objective,
            requirements: contractPayload.requirements.map { TaskRequirement(description: $0) },
            acceptanceCriteria: acceptance,
            builder: "mcp-contract-builder"
        )
    }

    private func buildPrompt(
        task: TaskIntent,
        contextSummary: String?,
        digestSummary: String?
    ) -> String {
        let criteriaLines = policy.bannedPatterns.map { pattern in
            "- Output must not contain \(pattern.token.uppercased()) markers."
        }

        var sections: [String] = []
        sections.append("You are an orchestrator generating a task contract.")
        sections.append("Return JSON only with keys: objective, requirements, acceptanceCriteria.")
        sections.append("Objective: \(task.summary)")
        if let details = task.details, !details.isEmpty {
            sections.append("Details: \(details)")
        }
        if let contextSummary, !contextSummary.isEmpty {
            sections.append("Context search results:\n\(contextSummary)")
        }
        if let digestSummary, !digestSummary.isEmpty {
            sections.append("Codebase digest:\n\(digestSummary)")
        }
        sections.append("Acceptance criteria must include:\n\(criteriaLines.joined(separator: "\n"))")
        sections.append("Also include: All requested deliverables are completed in full.")

        return sections.joined(separator: "\n\n")
    }

    private func decodeContractPayload(from text: String) throws -> ContractPayload {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = trimmed.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(ContractPayload.self, from: data) {
            return decoded
        }

        guard let jsonSubstring = extractJSON(from: trimmed),
              let data = jsonSubstring.data(using: .utf8)
        else {
            throw MCPContractError.invalidResponse("Unable to find JSON contract payload.")
        }

        return try JSONDecoder().decode(ContractPayload.self, from: data)
    }

    private func extractJSON(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}")
        else {
            return nil
        }
        return String(text[start...end])
    }

    private func extractText(from response: (content: [Tool.Content], isError: Bool?)) throws -> String? {
        if response.isError == true {
            let message = response.content.compactMap { content -> String? in
                if case .text(let text) = content { return text }
                return nil
            }.joined(separator: "\n")
            throw MCPContractError.invalidResponse(message.isEmpty ? "MCP tool call failed." : message)
        }

        let texts = response.content.compactMap { content -> String? in
            if case .text(let text) = content { return text }
            return nil
        }
        if texts.isEmpty {
            return nil
        }
        return texts.joined(separator: "\n")
    }

    private func ensureBaselineCriteria(_ criteria: [String]) -> [String] {
        var updated = criteria
        let lowercased = criteria.map { $0.lowercased() }
        for pattern in policy.bannedPatterns {
            if !lowercased.contains(where: { $0.contains(pattern.token.lowercased()) }) {
                updated.append("Output must not contain \(pattern.token.uppercased()) markers.")
            }
        }
        if !lowercased.contains(where: { $0.contains("deliverables") }) {
            updated.append("All requested deliverables are completed in full.")
        }
        return updated
    }
}

private struct ContextSearchResponse: Codable {
    let results: [ContextSearchResult]
}

private struct ContextSearchResult: Codable {
    let filePath: String
    let matchReason: String
    let summary: String?
}

private struct ContractPayload: Codable {
    let objective: String
    let requirements: [String]
    let acceptanceCriteria: [String]
}

private enum MCPContractError: LocalizedError {
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse(let message):
            return message
        }
    }
}
