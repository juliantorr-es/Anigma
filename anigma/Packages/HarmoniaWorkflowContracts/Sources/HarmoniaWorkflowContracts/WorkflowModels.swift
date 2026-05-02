// Copyright (c) 2025 Anigma
// Licensed under the MIT License

import Foundation
import AnigmaPrimitives

// MARK: - Workflow State Machine

public enum WorkflowState: String, Codable, Sendable {
    case pending
    case running
    case paused
    case completed
    case failed
    case cancelled
}

public enum StepState: String, Codable, Sendable {
    case pending
    case running
    case completed
    case failed
    case skipped
}

// MARK: - Workflow Models

public struct WorkflowDefinition: Codable, Sendable {
    public let id: String
    public let name: String
    public let description: String?
    public let steps: [WorkflowStep]
    public let parallelizable: Bool
    public let retryPolicy: RetryPolicy?
    public let timeout: TimeInterval?

    public init(
        id: String,
        name: String,
        description: String? = nil,
        steps: [WorkflowStep],
        parallelizable: Bool = false,
        retryPolicy: RetryPolicy? = nil,
        timeout: TimeInterval? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.steps = steps
        self.parallelizable = parallelizable
        self.retryPolicy = retryPolicy
        self.timeout = timeout
    }
}

public struct WorkflowStep: Codable, Sendable, Identifiable {
    public let id: String
    public let serviceId: String
    public let action: String
    public let input: [String: AnyCodable]?
    public let dependencies: [String]?
    public let timeout: TimeInterval?
    public let retryCount: Int

    public init(
        id: String,
        serviceId: String,
        action: String,
        input: [String: AnyCodable]? = nil,
        dependencies: [String]? = nil,
        timeout: TimeInterval? = nil,
        retryCount: Int = 1
    ) {
        self.id = id
        self.serviceId = serviceId
        self.action = action
        self.input = input
        self.dependencies = dependencies
        self.timeout = timeout
        self.retryCount = retryCount
    }
}

public struct WorkflowExecution: Codable, Sendable, Identifiable {
    public let id: String
    public let definitionId: String
    public var state: WorkflowState
    public var steps: [StepExecution]
    public var startTime: Date?
    public var endTime: Date?
    public var error: String?

    public var duration: TimeInterval? {
        guard let start = startTime, let end = endTime else { return nil }
        return end.timeIntervalSince(start)
    }

    public var progress: Double {
        guard !steps.isEmpty else { return 0 }
        let completed = steps.filter { $0.state == .completed }.count
        return Double(completed) / Double(steps.count)
    }

    public init(
        id: String,
        definitionId: String,
        state: WorkflowState = .pending,
        steps: [StepExecution] = [],
        startTime: Date? = nil,
        endTime: Date? = nil,
        error: String? = nil
    ) {
        self.id = id
        self.definitionId = definitionId
        self.state = state
        self.steps = steps
        self.startTime = startTime
        self.endTime = endTime
        self.error = error
    }
}

public struct StepExecution: Codable, Sendable, Identifiable {
    public let id: String
    public let stepId: String
    public var state: StepState
    public var input: [String: AnyCodable]?
    public var output: [String: AnyCodable]?
    public var error: String?
    public var startTime: Date?
    public var endTime: Date?
    public var retryCount: Int

    public var duration: TimeInterval? {
        guard let start = startTime, let end = endTime else { return nil }
        return end.timeIntervalSince(start)
    }

    public init(
        id: String,
        stepId: String,
        state: StepState = .pending,
        input: [String: AnyCodable]? = nil,
        output: [String: AnyCodable]? = nil,
        error: String? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        retryCount: Int = 0
    ) {
        self.id = id
        self.stepId = stepId
        self.state = state
        self.input = input
        self.output = output
        self.error = error
        self.startTime = startTime
        self.endTime = endTime
        self.retryCount = retryCount
    }
}

public struct RetryPolicy: Codable, Sendable {
    public let maxRetries: Int
    public let backoffMultiplier: Double
    public let initialDelay: TimeInterval
    public let maxDelay: TimeInterval

    public init(
        maxRetries: Int = 3,
        backoffMultiplier: Double = 2.0,
        initialDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 60.0
    ) {
        self.maxRetries = maxRetries
        self.backoffMultiplier = backoffMultiplier
        self.initialDelay = initialDelay
        self.maxDelay = maxDelay
    }

    public func delayForAttempt(_ attempt: Int) -> TimeInterval {
        let delay = initialDelay * pow(backoffMultiplier, Double(attempt))
        return min(delay, maxDelay)
    }
}

import AnigmaPrimitives
