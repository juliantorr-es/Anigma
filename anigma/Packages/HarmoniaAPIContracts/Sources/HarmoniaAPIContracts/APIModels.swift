// Copyright (c) 2025 Anigma
// Licensed under the MIT License

import Foundation
import HarmoniaWorkflowContracts
import AnigmaPrimitives

// MARK: - Request Models

public struct SubmitWorkflowRequest: Codable, Sendable {
    public let definition: WorkflowDefinition

    public init(definition: WorkflowDefinition) {
        self.definition = definition
    }
}

public struct ListWorkflowsRequest: Codable, Sendable {
    public let state: WorkflowState?

    public init(state: WorkflowState? = nil) {
        self.state = state
    }
}

// MARK: - Response Models

public struct APIResponse<T: Codable & Sendable>: Codable, Sendable {
    let success: Bool
    let data: T?
    let error: APIError?
    let timestamp: Date

    public init(data: T, timestamp: Date = Date()) {
        self.success = true
        self.data = data
        self.error = nil
        self.timestamp = timestamp
    }

    public init(error: APIError, timestamp: Date = Date()) {
        self.success = false
        self.data = nil
        self.error = error
        self.timestamp = timestamp
    }
}

public struct SubmitWorkflowResponse: Codable, Sendable {
    public let executionId: String
    public let state: WorkflowState
    public let message: String

    public init(executionId: String, state: WorkflowState, message: String = "Workflow submitted successfully") {
        self.executionId = executionId
        self.state = state
        self.message = message
    }
}

public struct WorkflowStatusResponse: Codable, Sendable {
    public let execution: WorkflowExecution
    public let progress: Double
    public let stepStatuses: [StepStatusInfo]

    public init(execution: WorkflowExecution) {
        self.execution = execution
        self.progress = execution.progress
        self.stepStatuses = execution.steps.map { StepStatusInfo(stepExecution: $0) }
    }
}

public struct StepStatusInfo: Codable, Sendable {
    public let stepId: String
    public let state: StepState
    public let duration: TimeInterval?
    public let retryCount: Int
    public let error: String?

    public init(stepExecution: StepExecution) {
        self.stepId = stepExecution.stepId
        self.state = stepExecution.state
        self.duration = stepExecution.duration
        self.retryCount = stepExecution.retryCount
        self.error = stepExecution.error
    }
}

public struct ListWorkflowsResponse: Codable, Sendable {
    public let workflows: [WorkflowListItem]
    public let total: Int

    public init(workflows: [WorkflowExecution]) {
        self.workflows = workflows.map { WorkflowListItem(execution: $0) }
        self.total = workflows.count
    }
}

public struct WorkflowListItem: Codable, Sendable {
    public let id: String
    public let definitionId: String
    public let state: WorkflowState
    public let progress: Double
    public let duration: TimeInterval?
    public let stepCount: Int

    public init(execution: WorkflowExecution) {
        self.id = execution.id
        self.definitionId = execution.definitionId
        self.state = execution.state
        self.progress = execution.progress
        self.duration = execution.duration
        self.stepCount = execution.steps.count
    }
}

public struct WorkflowControlResponse: Codable, Sendable {
    public let executionId: String
    public let action: String
    public let newState: WorkflowState
    public let message: String

    public init(executionId: String, action: String, newState: WorkflowState) {
        self.executionId = executionId
        self.action = action
        self.newState = newState
        self.message = "Workflow \(action) successful"
    }
}

public struct WorkflowResultResponse: Codable, Sendable {
    public let executionId: String
    public let state: WorkflowState
    public let results: [String: AnyCodable]
    public let duration: TimeInterval?

    public init(executionId: String, state: WorkflowState, results: [String: AnyCodable], duration: TimeInterval? = nil) {
        self.executionId = executionId
        self.state = state
        self.results = results
        self.duration = duration
    }
}

public struct ServicesListResponse: Codable, Sendable {
    public let services: [ServiceDescriptor]
    public let total: Int

    public init(services: [ServiceDescriptor]) {
        self.services = services
        self.total = services.count
    }
}

public struct ServiceHealthResponse: Codable, Sendable {
    public let serviceId: String
    public let health: HealthStatus
    public let lastCheck: Date?

    public init(serviceId: String, health: HealthStatus, lastCheck: Date? = nil) {
        self.serviceId = serviceId
        self.health = health
        self.lastCheck = lastCheck
    }

    enum CodingKeys: String, CodingKey {
        case serviceId
        case health
        case lastCheck
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        serviceId = try container.decode(String.self, forKey: .serviceId)
        let healthValue = try container.decode(String.self, forKey: .health)
        health = HealthStatus(rawValue: healthValue) ?? .unknown
        lastCheck = try container.decodeIfPresent(Date.self, forKey: .lastCheck)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(serviceId, forKey: .serviceId)
        try container.encode(health.rawValue, forKey: .health)
        try container.encodeIfPresent(lastCheck, forKey: .lastCheck)
    }
}

// MARK: - Error Response

public struct APIError: Codable, Sendable {
    public let code: String
    public let message: String
    public let statusCode: Int

    public init(code: String, message: String, statusCode: Int) {
        self.code = code
        self.message = message
        self.statusCode = statusCode
    }
}

// MARK: - HTTP Status Codes

enum HTTPStatusCode {
    static let ok = 200
    static let created = 201
    static let badRequest = 400
    static let notFound = 404
    static let conflict = 409
    static let internalServerError = 500
}
