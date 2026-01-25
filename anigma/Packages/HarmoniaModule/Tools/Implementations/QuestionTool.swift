//
//  QuestionTool.swift
//  HarmoniaModule
//
//  A tool that allows the AI to ask the user a question.
//  Uses the interactive permission/ask mechanism.
//

import AnigmaPrimitives
@preconcurrency import Foundation

public struct QuestionTool: Tool {
    public static let id = "question"
    public static let description = "Ask the user a question to clarify requirements or get missing information."

    public struct Parameters: Codable, Sendable {
        public let question: String

        public init(question: String) {
            self.question = question
        }
    }

    public struct Metadata: Codable, Sendable {
        public let response: String
    }

    public init() {}

    public func execute(params: Parameters, context: ToolContext) async throws -> ToolResult<Metadata> {
        // We use the 'ask' mechanism to effectively pause the tool and wait for user input.
        // The permission string is used as the prompt prefix.
        try await context.ask(permission: "question", pattern: params.question)

        // In a real implementation, the context.ask would return the user's string response.
        // For this scaffold, we assume the response is collected and available.
        // Since our current ask() returns Void, we'll need to enhance it later to return a result.
        // For now, we'll return a placeholder.

        return ToolResult(
            title: "Question Asked",
            output: "User answered the question.",
            metadata: Metadata(response: "User input collected via CLI.")
        )
    }
}
