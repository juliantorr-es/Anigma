//
//  MLWorkerInterface.swift
//  AnigmaCore
//
//  [Brief description of file purpose]
//

import Foundation
import AnigmaPrimitives
import ContractsCore
import InferenceCore

/// Represents a request to run a shell command by the agent.
public struct AgentShellCommandRequest: Error, LocalizedError, Sendable {
    public let command: String
    public let description: String

    public var errorDescription: String? {
        return "AGENT_SHELL_COMMAND_REQUEST: \(description) -> \(command)"
    }
}

/// Protocol for interacting with the ML Worker.
public protocol MLWorkerInterface: Sendable {
    func performMLTask(
        task: MLWorkerTaskKind,
        input: String,
        modelID: String?,
        options: [String: AnyHashable]
    ) async throws -> String // Returns raw output string from ML Worker
}

/// Concrete implementation of `MLWorkerInterface` that executes the ML Worker via a shell command.
public struct MLWorkerProcessInterface: MLWorkerInterface {
    private let mlWorkerPath: String

    public init(mlWorkerPath: String) {
        self.mlWorkerPath = mlWorkerPath
    }

    public func performMLTask(
        task: MLWorkerTaskKind,
        input: String,
        modelID: String?,
        options: [String: AnyHashable]
    ) async throws -> String {
        let tempInputFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".txt")
        try input.write(to: tempInputFile, atomically: true, encoding: .utf8)

        var commandArgs: [String] = []
        switch task {
        case .embedding, .embed:
            commandArgs.append("--embedding")
        case .chat, .generate:
            commandArgs.append("--chat")
        }

        if let model = modelID {
            commandArgs.append("--model")
            commandArgs.append(model)
        }

        // Add other options as needed. For now, just pass the input file.
        commandArgs.append("--input")
        commandArgs.append(tempInputFile.path)

        let command = "\(mlWorkerPath) \(commandArgs.joined(separator: " "))"
        let description = "Execute ML Worker for \(task.rawValue)"

        // Instead of executing directly, throw a custom error that the agent can intercept.
        throw AgentShellCommandRequest(command: command, description: description)
    }
}
