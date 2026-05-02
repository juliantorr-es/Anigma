//
//  RemoteExecutionCoordinator.swift
//  PlatformCore
//
//  Remote execution coordinator for Phase 8.4
//

import Foundation

// MARK: - Remote Execution Request/Response

/// Represents a remote execution request
public struct RemoteExecutionRequest: Codable, Sendable {
    public let id: String
    public let agent: RemoteAgent
    public let task: ExecutionTask
    public let priority: ExecutionPriority
    public let timeout: TimeInterval
    public let metadata: [String: String]

    public init(id: String = UUID().uuidString, agent: RemoteAgent, task: ExecutionTask, priority: ExecutionPriority = .normal, timeout: TimeInterval = 300, metadata: [String: String] = [:]) {
        self.id = id
        self.agent = agent
        self.task = task
        self.priority = priority
        self.timeout = timeout
        self.metadata = metadata
    }
}

/// Information about a remote agent
public struct RemoteAgent: Codable, Sendable {
    public let id: String
    public let name: String
    public let address: String
    public let port: UInt16
    public let capabilities: [String]
    public let version: String

    public init(id: String = UUID().uuidString, name: String, address: String, port: UInt16, capabilities: [String] = [], version: String = "1.0.0") {
        self.id = id
        self.name = name
        self.address = address
        self.port = port
        self.capabilities = capabilities
        self.version = version
    }
}

/// An execution task to be executed on a remote agent
public struct ExecutionTask: Codable, Sendable {
    public let type: String
    public let payload: [String: String]
    public let dependencies: [String]

    public init(type: String, payload: [String: String] = [:], dependencies: [String] = []) {
        self.type = type
        self.payload = payload
        self.dependencies = dependencies
    }
}

/// Priority levels for execution
public enum ExecutionPriority: String, Codable, Sendable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case critical = "critical"
}

/// Response from a remote execution
public struct RemoteExecutionResponse: Codable, Sendable {
    public let requestId: String
    public let agent: RemoteAgent
    public let status: ExecutionStatus
    public let result: ExecutionResult?
    public let error: String?
    public let timestamp: Date

    public init(requestId: String, agent: RemoteAgent, status: ExecutionStatus, result: ExecutionResult? = nil, error: String? = nil, timestamp: Date = Date()) {
        self.requestId = requestId
        self.agent = agent
        self.status = status
        self.result = result
        self.error = error
        self.timestamp = timestamp
    }
}

/// Execution status
public enum ExecutionStatus: String, Codable, Sendable {
    case pending = "pending"
    case running = "running"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
    case timedOut = "timed_out"
}

/// Result of task execution
public struct ExecutionResult: Codable, Sendable {
    public let output: String
    public let metadata: [String: String]
    public let duration: TimeInterval

    public init(output: String, metadata: [String: String] = [:], duration: TimeInterval = 0) {
        self.output = output
        self.metadata = metadata
        self.duration = duration
    }
}

// MARK: - Remote Execution Errors

public enum RemoteExecutionError: Error, LocalizedError {
    case agentNotFound(String)
    case agentUnreachable(String)
    case invalidTask(String)
    case executionFailed(String)
    case timeout
    case dependencyFailed(String)
    case authenticationFailed

    public var errorDescription: String? {
        switch self {
        case .agentNotFound(let id):
            return "Agent '\(id)' not found"
        case .agentUnreachable(let address):
            return "Agent at '\(address)' is unreachable"
        case .invalidTask(let message):
            return "Invalid task: \(message)"
        case .executionFailed(let message):
            return "Execution failed: \(message)"
        case .timeout:
            return "Execution timed out"
        case .dependencyFailed(let taskId):
            return "Dependency task '\(taskId)' failed"
        case .authenticationFailed:
            return "Authentication failed"
        }
    }
}

// MARK: - Remote Agent Manager

/// Manages remote agent registration and discovery
public actor RemoteAgentManager {
    private var agents: [String: RemoteAgent] = [:]
    private var agentStatuses: [String: AgentHealthStatus] = [:]

    public init() {}

    /// Register a new remote agent
    public func registerAgent(_ agent: RemoteAgent) throws {
        agents[agent.id] = agent
        agentStatuses[agent.id] = AgentHealthStatus(agentId: agent.id, healthy: true)
    }

    /// Unregister a remote agent
    public func unregisterAgent(_ agentId: String) throws {
        agents.removeValue(forKey: agentId)
        agentStatuses.removeValue(forKey: agentId)
    }

    /// Get an agent by ID
    public func agent(withId id: String) throws -> RemoteAgent {
        guard let agent = agents[id] else {
            throw RemoteExecutionError.agentNotFound(id)
        }
        return agent
    }

    /// Find agents with specific capabilities
    public func agentsWithCapabilities(_ capabilities: [String]) -> [RemoteAgent] {
        agents.values.filter { agent in
            capabilities.allSatisfy { agent.capabilities.contains($0) }
        }
    }

    /// Get all registered agents
    public var allAgents: [RemoteAgent] {
        Array(agents.values)
    }

    /// Update health status of an agent
    public func updateAgentHealth(agentId: String, healthy: Bool, lastHeartbeat: Date = Date()) {
        agentStatuses[agentId] = AgentHealthStatus(agentId: agentId, healthy: healthy, lastHeartbeat: lastHeartbeat)
    }

    /// Get health status of an agent
    public func agentHealth(agentId: String) -> AgentHealthStatus? {
        agentStatuses[agentId]
    }
}

/// Health status of a remote agent
public struct AgentHealthStatus: Codable, Sendable {
    public let agentId: String
    public let healthy: Bool
    public let lastHeartbeat: Date
    public let errorCount: Int

    public init(agentId: String, healthy: Bool, lastHeartbeat: Date = Date(), errorCount: Int = 0) {
        self.agentId = agentId
        self.healthy = healthy
        self.lastHeartbeat = lastHeartbeat
        self.errorCount = errorCount
    }
}

// MARK: - Remote Execution Coordinator

/// Coordinates distributed task execution across remote agents
public actor RemoteExecutionCoordinator {
    private let agentManager: RemoteAgentManager
    private var executionQueue: [RemoteExecutionRequest] = []
    private var executingTasks: [String: RemoteExecutionRequest] = [:]
    private var completedTasks: [String: RemoteExecutionResponse] = [:]

    public init(agentManager: RemoteAgentManager) {
        self.agentManager = agentManager
    }

    /// Submit a task for remote execution
    public func submitTask(_ request: RemoteExecutionRequest) async throws {
        // Validate the request
        try validateRequest(request)

        // Find available agent
        let agent = try await findAvailableAgent(for: request)

        // Queue the execution
        executingTasks[request.id] = request
        executionQueue.append(request)

        // Schedule execution
        await scheduleExecution(for: request, on: agent)
    }

    /// Get execution status
    public func executionStatus(for requestId: String) -> RemoteExecutionResponse? {
        completedTasks[requestId]
    }

    /// Cancel execution
    public func cancelExecution(_ requestId: String) throws {
        guard executingTasks[requestId] != nil else {
            throw RemoteExecutionError.invalidTask("Task \(requestId) not found")
        }

        executingTasks.removeValue(forKey: requestId)
    }

    /// Get all pending executions
    public var pendingExecutions: [RemoteExecutionRequest] {
        Array(executingTasks.values)
    }

    // MARK: - Private Methods

    private func validateRequest(_ request: RemoteExecutionRequest) throws {
        if request.task.type.isEmpty {
            throw RemoteExecutionError.invalidTask("Task type cannot be empty")
        }

        if request.timeout <= 0 {
            throw RemoteExecutionError.invalidTask("Timeout must be positive")
        }
    }

    private func findAvailableAgent(for request: RemoteExecutionRequest) async throws -> RemoteAgent {
        // First try to use specified agent
        let agent = try await agentManager.agent(withId: request.agent.id)

        // Check agent health
        if let health = await agentManager.agentHealth(agentId: agent.id), !health.healthy {
            throw RemoteExecutionError.agentUnreachable(agent.address)
        }

        return agent
    }

    private func scheduleExecution(for request: RemoteExecutionRequest, on agent: RemoteAgent) async {
        // Simulate remote execution
        let startTime = Date()

        // Simulate some work
        try? await Task.sleep(nanoseconds: UInt64(100_000_000)) // 0.1 seconds

        let result = ExecutionResult(
            output: "Task \(request.id) executed successfully on \(agent.name)",
            metadata: ["agent": agent.id, "task_type": request.task.type],
            duration: Date().timeIntervalSince(startTime)
        )

        let response = RemoteExecutionResponse(
            requestId: request.id,
            agent: agent,
            status: .completed,
            result: result
        )

        completedTasks[request.id] = response
        executingTasks.removeValue(forKey: request.id)
    }
}

// MARK: - Execution Orchestrator

/// High-level orchestrator for coordinated execution across multiple agents
public actor ExecutionOrchestrator {
    private let coordinator: RemoteExecutionCoordinator
    private let inferenceRegistry: InferenceBackendRegistry
    private let agentManager: RemoteAgentManager
    private var workflows: [String: ExecutionWorkflow] = [:]

    public init(coordinator: RemoteExecutionCoordinator, inferenceRegistry: InferenceBackendRegistry, agentManager: RemoteAgentManager) {
        self.coordinator = coordinator
        self.inferenceRegistry = inferenceRegistry
        self.agentManager = agentManager
    }

    /// Register an execution workflow
    public func registerWorkflow(_ workflow: ExecutionWorkflow) {
        workflows[workflow.id] = workflow
    }

    /// Execute a workflow with inference
    public func executeWorkflow(_ workflowId: String, with inferenceBackend: String? = nil) async throws -> WorkflowResult {
        guard let workflow = workflows[workflowId] else {
            throw RemoteExecutionError.invalidTask("Workflow '\(workflowId)' not found")
        }

        var results: [String: RemoteExecutionResponse] = [:]

        // Execute tasks in sequence based on dependencies
        for task in workflow.tasks {
            let request = RemoteExecutionRequest(
                agent: workflow.preferredAgent,
                task: task
            )

            try await coordinator.submitTask(request)

            if let response = await coordinator.executionStatus(for: request.id) {
                results[task.type] = response
            }
        }

        return WorkflowResult(
            workflowId: workflowId,
            results: results,
            timestamp: Date()
        )
    }
}

/// Represents an execution workflow
public struct ExecutionWorkflow: Codable, Sendable {
    public let id: String
    public let name: String
    public let tasks: [ExecutionTask]
    public let preferredAgent: RemoteAgent

    public init(id: String = UUID().uuidString, name: String, tasks: [ExecutionTask], preferredAgent: RemoteAgent) {
        self.id = id
        self.name = name
        self.tasks = tasks
        self.preferredAgent = preferredAgent
    }
}

/// Result of workflow execution
public struct WorkflowResult: Codable, Sendable {
    public let workflowId: String
    public let results: [String: RemoteExecutionResponse]
    public let timestamp: Date

    public init(workflowId: String, results: [String: RemoteExecutionResponse] = [:], timestamp: Date = Date()) {
        self.workflowId = workflowId
        self.results = results
        self.timestamp = timestamp
    }
}
