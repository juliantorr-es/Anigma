// Copyright (c) 2025 Anigma
// Licensed under the MIT License

import Foundation

// MARK: - Harmonia Coordinator

public actor HarmoniaCoordinator {
    private let registry: ServiceRegistry
    private var workflows: [String: WorkflowExecution] = [:]
    private var executors: [String: WorkflowExecutor] = [:]
    
    public static let shared = HarmoniaCoordinator()
    
    public init(registry: ServiceRegistry = ServiceRegistry()) {
        self.registry = registry
    }
    
    // MARK: - Service Management
    
    public func registerService(_ service: ServiceHandler) throws {
        try registry.register(service: service)
    }
    
    public func getAvailableServices() -> [ServiceDescriptor] {
        registry.getAllServices()
    }
    
    public func getServiceHealth() -> [String: HealthStatus] {
        let services = registry.getAllServices()
        var health: [String: HealthStatus] = [:]
        for service in services {
            health[service.id] = service.healthStatus
        }
        return health
    }
    
    // MARK: - Workflow Submission
    
    public func submitWorkflow(_ definition: WorkflowDefinition) throws -> WorkflowExecution {
        let executionId = UUID().uuidString
        
        // Create execution record
        var execution = WorkflowExecution(
            id: executionId,
            definitionId: definition.id,
            state: .pending,
            steps: definition.steps.map { step in
                StepExecution(
                    id: UUID().uuidString,
                    stepId: step.id,
                    state: .pending
                )
            },
            startTime: nil,
            endTime: nil
        )
        
        // Store execution
        workflows[executionId] = execution
        
        // Create executor
        let executor = WorkflowExecutor(
            coordinator: self,
            definition: definition,
            execution: &execution,
            registry: registry
        )
        executors[executionId] = executor
        
        // Start execution asynchronously
        Task {
            await executor.execute()
        }
        
        return execution
    }
    
    // MARK: - Workflow Status & Control
    
    public func getWorkflowStatus(executionId: String) throws -> WorkflowExecution {
        guard let execution = workflows[executionId] else {
            throw CoordinatorError.workflowNotFound(executionId)
        }
        return execution
    }
    
    public func listWorkflows(state: WorkflowState? = nil) -> [WorkflowExecution] {
        let allWorkflows = workflows.values
        if let state = state {
            return allWorkflows.filter { $0.state == state }
        }
        return Array(allWorkflows)
    }
    
    public func cancelWorkflow(executionId: String) throws {
        guard var execution = workflows[executionId] else {
            throw CoordinatorError.workflowNotFound(executionId)
        }
        
        guard execution.state == .running || execution.state == .pending else {
            throw CoordinatorError.invalidWorkflowState(execution.state, "Cannot cancel workflow in state: \(execution.state)")
        }
        
        execution.state = .cancelled
        execution.endTime = Date()
        workflows[executionId] = execution
        
        if let executor = executors[executionId] {
            await executor.cancel()
        }
    }
    
    public func pauseWorkflow(executionId: String) throws {
        guard var execution = workflows[executionId] else {
            throw CoordinatorError.workflowNotFound(executionId)
        }
        
        guard execution.state == .running else {
            throw CoordinatorError.invalidWorkflowState(execution.state, "Can only pause running workflows")
        }
        
        execution.state = .paused
        workflows[executionId] = execution
    }
    
    public func resumeWorkflow(executionId: String) throws {
        guard var execution = workflows[executionId] else {
            throw CoordinatorError.workflowNotFound(executionId)
        }
        
        guard execution.state == .paused else {
            throw CoordinatorError.invalidWorkflowState(execution.state, "Can only resume paused workflows")
        }
        
        execution.state = .running
        workflows[executionId] = execution
    }
    
    // MARK: - Workflow Results
    
    public func getWorkflowResult(executionId: String) throws -> [String: AnyCodable] {
        guard let execution = workflows[executionId] else {
            throw CoordinatorError.workflowNotFound(executionId)
        }
        
        guard execution.state == .completed else {
            throw CoordinatorError.workflowNotCompleted(executionId, "Workflow state: \(execution.state)")
        }
        
        // Aggregate results from all steps
        var aggregatedResult: [String: AnyCodable] = [:]
        for step in execution.steps {
            if let output = step.output {
                aggregatedResult[step.stepId] = .dictionary(output)
            }
        }
        
        return aggregatedResult
    }
    
    // MARK: - Internal Updates
    
    func updateExecution(_ execution: WorkflowExecution) {
        workflows[execution.id] = execution
    }
    
    func getRegistry() -> ServiceRegistry {
        registry
    }
    
    // MARK: - Statistics
    
    public func getStatistics() -> CoordinatorStatistics {
        let allExecutions = workflows.values
        let completedCount = allExecutions.filter { $0.state == .completed }.count
        let failedCount = allExecutions.filter { $0.state == .failed }.count
        let runningCount = allExecutions.filter { $0.state == .running }.count
        
        let totalDuration = allExecutions.compactMap { $0.duration }.reduce(0, +)
        let averageDuration = totalDuration / Double(allExecutions.count)
        
        return CoordinatorStatistics(
            totalWorkflows: allExecutions.count,
            completedWorkflows: completedCount,
            failedWorkflows: failedCount,
            runningWorkflows: runningCount,
            averageWorkflowDuration: averageDuration,
            registeredServices: registry.registeredServiceCount
        )
    }
}

// MARK: - Statistics Model

public struct CoordinatorStatistics: Sendable {
    public let totalWorkflows: Int
    public let completedWorkflows: Int
    public let failedWorkflows: Int
    public let runningWorkflows: Int
    public let averageWorkflowDuration: TimeInterval
    public let registeredServices: Int
    
    public var successRate: Double {
        guard totalWorkflows > 0 else { return 0 }
        return Double(completedWorkflows) / Double(totalWorkflows) * 100
    }
}

// MARK: - Errors

public enum CoordinatorError: LocalizedError, Sendable {
    case workflowNotFound(String)
    case workflowNotCompleted(String, String)
    case invalidWorkflowState(WorkflowState, String)
    case serviceNotAvailable(String)
    case executionFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .workflowNotFound(let id):
            return "Workflow not found: \(id)"
        case .workflowNotCompleted(let id, let reason):
            return "Workflow \(id) not completed: \(reason)"
        case .invalidWorkflowState(let state, let reason):
            return "Invalid workflow state \(state): \(reason)"
        case .serviceNotAvailable(let id):
            return "Service not available: \(id)"
        case .executionFailed(let reason):
            return "Execution failed: \(reason)"
        }
    }
}
