// Copyright (c) 2025 Anigma
// Licensed under the MIT License

import Foundation

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
    public let state: WorkflowState
    public let steps: [StepExecution]
    public let startTime: Date?
    public let endTime: Date?
    public let error: String?
    
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
    public let state: StepState
    public let input: [String: AnyCodable]?
    public let output: [String: AnyCodable]?
    public let error: String?
    public let startTime: Date?
    public let endTime: Date?
    public let retryCount: Int
    
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

// MARK: - Retry Policy

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

// MARK: - Codable Helper for Dynamic Values

public enum AnyCodable: Codable, Sendable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([AnyCodable])
    case dictionary([String: AnyCodable])
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([AnyCodable].self) {
            self = .array(array)
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self = .dictionary(dictionary)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode AnyCodable")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let bool):
            try container.encode(bool)
        case .int(let int):
            try container.encode(int)
        case .double(let double):
            try container.encode(double)
        case .string(let string):
            try container.encode(string)
        case .array(let array):
            try container.encode(array)
        case .dictionary(let dictionary):
            try container.encode(dictionary)
        }
    }
}
