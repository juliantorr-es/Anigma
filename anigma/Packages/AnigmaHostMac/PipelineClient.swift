//
//  PipelineClient.swift
//  AnigmaHostMac
//
//  Diaplasion pipeline processing client.
//

import Foundation

public struct PipelineClient: Sendable {
    private let binaryPath: String

    public init(binaryPath: String = "/usr/local/bin/diaplasion-pipeline") {
        self.binaryPath = binaryPath
    }

    public func listPipelines() async throws -> PipelineListResponse {
        let output = try await execute(["list", "--format", "json"])
        return try JSONDecoder().decode(PipelineListResponse.self, from: output)
    }

    public func createPipeline(name: String, stages: [PipelineStage]) async throws -> PipelineResponse {
        let stagesJSON = try JSONEncoder().encode(stages)
        let stagesString = String(data: stagesJSON, encoding: .utf8) ?? "[]"
        let output = try await execute(["create", "--name", name, "--stages", stagesString, "--format", "json"])
        return try JSONDecoder().decode(PipelineResponse.self, from: output)
    }

    public func runPipeline(id: String, inputs: [String: String]) async throws -> PipelineRunResponse {
        let inputsJSON = try JSONEncoder().encode(inputs)
        let inputsString = String(data: inputsJSON, encoding: .utf8) ?? "{}"
        let output = try await execute(["run", "--id", id, "--inputs", inputsString, "--format", "json"])
        return try JSONDecoder().decode(PipelineRunResponse.self, from: output)
    }

    public func getPipelineStatus(runId: String) async throws -> PipelineStatusResponse {
        let output = try await execute(["status", "--run-id", runId, "--format", "json"])
        return try JSONDecoder().decode(PipelineStatusResponse.self, from: output)
    }

    public func cancelPipeline(runId: String) async throws -> PipelineSuccessResponse {
        let output = try await execute(["cancel", "--run-id", runId, "--format", "json"])
        return try JSONDecoder().decode(PipelineSuccessResponse.self, from: output)
    }

    private func execute(_ arguments: [String]) async throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw PipelineClientError.executionFailed(message: errorMessage)
        }

        return outputData
    }
}

public struct PipelineStage: Codable {
    public let name: String
    public let type: String
    public let config: [String: String]

    public init(name: String, type: String, config: [String: String]) {
        self.name = name
        self.type = type
        self.config = config
    }
}

public struct PipelineListResponse: Codable {
    public let pipelines: [PipelineInfo]
}

public struct PipelineInfo: Codable, Identifiable {
    public let id: String
    public let name: String
    public let stageCount: Int
    public let createdAt: Date
}

public struct PipelineResponse: Codable {
    public let id: String
    public let name: String
    public let stages: [PipelineStage]
}

public struct PipelineRunResponse: Codable {
    public let runId: String
    public let pipelineId: String
    public let status: String
    public let startedAt: Date
}

public struct PipelineStatusResponse: Codable {
    public let runId: String
    public let status: String
    public let currentStage: String?
    public let progress: Double
    public let outputs: [String: String]?
}

public struct PipelineSuccessResponse: Codable {
    public let success: Bool
    public let message: String?
}

public enum PipelineClientError: Error, LocalizedError {
    case executionFailed(message: String)

    public var errorDescription: String? {
        switch self {
        case .executionFailed(let message):
            return "Pipeline execution failed: \(message)"
        }
    }
}
