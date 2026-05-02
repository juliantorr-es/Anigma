//
//  AnigmaCLICore.swift
//  AnigmaCLICore
//
//  Core types for the Anigma CLI modular monolith.
//

import Foundation

public enum TaskSource: String, Codable, Sendable {
    case cli
    case api
    case mcp
}

public struct TaskIntent: Sendable, Codable, Hashable {
    public let id: UUID
    public let summary: String
    public let details: String?
    public let createdAt: Date
    public let source: TaskSource

    public init(
        id: UUID = UUID(),
        summary: String,
        details: String? = nil,
        createdAt: Date = Date(),
        source: TaskSource = .cli
    ) {
        self.id = id
        self.summary = summary
        self.details = details
        self.createdAt = createdAt
        self.source = source
    }
}

public struct TaskRequirement: Sendable, Codable, Hashable {
    public let description: String

    public init(description: String) {
        self.description = description
    }
}

public struct TaskContract: Sendable, Codable, Hashable {
    public let id: UUID
    public let taskId: UUID
    public let objective: String
    public let requirements: [TaskRequirement]
    public let acceptanceCriteria: [String]
    public let createdAt: Date
    public let builder: String

    public init(
        id: UUID = UUID(),
        taskId: UUID,
        objective: String,
        requirements: [TaskRequirement],
        acceptanceCriteria: [String],
        createdAt: Date = Date(),
        builder: String
    ) {
        self.id = id
        self.taskId = taskId
        self.objective = objective
        self.requirements = requirements
        self.acceptanceCriteria = acceptanceCriteria
        self.createdAt = createdAt
        self.builder = builder
    }
}

public enum ExecutionMode: String, Codable, Sendable {
    case plan
    case run
}

public enum ExecutionStatus: String, Codable, Sendable {
    case planned
    case running
    case succeeded
    case failed
}

public struct ExecutionResult: Sendable, Codable, Hashable {
    public let taskId: UUID
    public let providerId: String
    public let status: ExecutionStatus
    public let message: String
    public let startedAt: Date
    public let endedAt: Date?

    public init(
        taskId: UUID,
        providerId: String,
        status: ExecutionStatus,
        message: String,
        startedAt: Date = Date(),
        endedAt: Date? = nil
    ) {
        self.taskId = taskId
        self.providerId = providerId
        self.status = status
        self.message = message
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
}

public struct TaskContext: Sendable, Codable, Hashable {
    public let repoRoot: URL
    public let worktreeRoot: URL
    public let artifactsRoot: URL?

    public init(
        repoRoot: URL,
        worktreeRoot: URL,
        artifactsRoot: URL? = nil
    ) {
        self.repoRoot = repoRoot
        self.worktreeRoot = worktreeRoot
        self.artifactsRoot = artifactsRoot
    }
}

public protocol ContractBuilder: Sendable {
    func buildContract(for task: TaskIntent, context: TaskContext) async throws -> TaskContract
}
