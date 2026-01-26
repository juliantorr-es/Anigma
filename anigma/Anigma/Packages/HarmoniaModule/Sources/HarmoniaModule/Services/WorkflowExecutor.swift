// Copyright (c) 2025 Anigma
// Licensed under the MIT License

import Foundation

// MARK: - Workflow Executor

public actor WorkflowExecutor {
    let coordinator: HarmoniaCoordinator
    let definition: WorkflowDefinition
    var execution: WorkflowExecution
    let registry: ServiceRegistry
    
    private var cancelled = false
    private var taskGroup: TaskGroup<(String, Result<[String: AnyCodable], Error>)>?
    
    init(
        coordinator: HarmoniaCoordinator,
        definition: WorkflowDefinition,
        execution: inout WorkflowExecution,
        registry: ServiceRegistry
    ) {
        self.coordinator = coordinator
        self.definition = definition
        self.execution = execution
        self.registry = registry
    }
    
    // MARK: - Main Execution
    
    public func execute() async {
        execution.startTime = Date()
        execution.state = .running
        coordinator.updateExecution(execution)
        
        defer {
            execution.endTime = Date()
            coordinator.updateExecution(execution)
        }
        
        do {
            try await executeWorkflow()
            
            if !cancelled {
                execution.state = .completed
            }
        } catch {
            execution.state = .failed
            execution.error = error.localizedDescription
        }
    }
    
    // MARK: - Execution Logic
    
    private func executeWorkflow() async throws {
        let dependencyGraph = buildDependencyGraph()
        var completedSteps: Set<String> = []
        var stepResults: [String: [String: AnyCodable]] = [:]
        
        // Process steps based on dependencies
        var remainingSteps = Set(definition.steps.map { $0.id })
        
        while !remainingSteps.isEmpty && !cancelled {
            // Find steps that can execute now (dependencies satisfied)
            let readySteps = remainingSteps.filter { stepId in
                let dependencies = dependencyGraph[stepId] ?? []
                return dependencies.allSatisfy { completedSteps.contains($0) }
            }
            
            guard !readySteps.isEmpty else {
                // No progress possible - circular dependency or missing step
                throw ExecutorError.circularDependency
            }
            
            if definition.parallelizable {
                // Execute ready steps in parallel
                await withTaskGroup(of: (String, Result<[String: AnyCodable], Error>).self) { group in
                    for stepId in readySteps {
                        group.addTask {
                            let result = await self.executeStep(stepId: stepId, input: stepResults)
                            return (stepId, result)
                        }
                    }
                    
                    for await (stepId, result) in group {
                        try await processStepResult(stepId: stepId, result: result, stepResults: &stepResults)
                        completedSteps.insert(stepId)
                        remainingSteps.remove(stepId)
                    }
                }
            } else {
                // Execute sequentially
                for stepId in readySteps {
                    if cancelled { return }
                    
                    let result = await executeStep(stepId: stepId, input: stepResults)
                    try await processStepResult(stepId: stepId, result: result, stepResults: &stepResults)
                    completedSteps.insert(stepId)
                    remainingSteps.remove(stepId)
                }
            }
        }
    }
    
    // MARK: - Step Execution
    
    private func executeStep(stepId: String, input: [String: [String: AnyCodable]]) async -> Result<[String: AnyCodable], Error> {
        guard let stepDefinition = definition.steps.first(where: { $0.id == stepId }) else {
            return .failure(ExecutorError.stepNotFound(stepId))
        }
        
        // Update step state
        updateStepState(stepId: stepId, to: .running)
        
        let result: Result<[String: AnyCodable], Error>
        
        do {
            // Resolve input dependencies
            var resolvedInput: [String: AnyCodable] = stepDefinition.input ?? [:]
            if let dependencies = stepDefinition.dependencies {
                for dependency in dependencies {
                    if let depOutput = input[dependency] {
                        resolvedInput["_depInput_\(dependency)"] = .dictionary(depOutput)
                    }
                }
            }
            
            // Get service and execute
            let service = try registry.getService(id: stepDefinition.serviceId)
            let timeout = stepDefinition.timeout ?? 30.0
            
            // Execute with timeout
            let output = try await withThrowingTaskGroup(of: [String: AnyCodable].self) { group in
                group.addTask {
                    try await service.execute(action: stepDefinition.action, input: resolvedInput)
                }
                
                if let output = try? await group.nextResult() {
                    return try output.get()
                } else {
                    throw ExecutorError.executionTimeout(stepId, timeout)
                }
            }
            
            result = .success(output)
        } catch {
            result = .failure(error)
        }
        
        return result
    }
    
    private func processStepResult(
        stepId: String,
        result: Result<[String: AnyCodable], Error>,
        stepResults: inout [String: [String: AnyCodable]]
    ) async throws {
        switch result {
        case .success(let output):
            stepResults[stepId] = output
            updateStepState(stepId: stepId, to: .completed, output: output)
            
        case .failure(let error):
            // Check if step has retry available
            guard let stepExecution = execution.steps.first(where: { $0.stepId == stepId }) else {
                throw ExecutorError.stepNotFound(stepId)
            }
            
            guard let stepDef = definition.steps.first(where: { $0.id == stepId }) else {
                throw ExecutorError.stepNotFound(stepId)
            }
            
            if stepExecution.retryCount < stepDef.retryCount {
                // Retry the step
                let retryDelay = (stepDef.retryCount > 0) ? 1.0 : 0.1
                try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                
                let retryResult = await executeStep(stepId: stepId, input: stepResults)
                try await processStepResult(stepId: stepId, result: retryResult, stepResults: &stepResults)
            } else {
                // Mark as failed
                updateStepState(stepId: stepId, to: .failed, error: error.localizedDescription)
                throw error
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func buildDependencyGraph() -> [String: [String]] {
        var graph: [String: [String]] = [:]
        
        for step in definition.steps {
            graph[step.id] = step.dependencies ?? []
        }
        
        return graph
    }
    
    private func updateStepState(
        stepId: String,
        to newState: StepState,
        output: [String: AnyCodable]? = nil,
        error: String? = nil
    ) {
        guard let index = execution.steps.firstIndex(where: { $0.stepId == stepId }) else {
            return
        }
        
        var stepExecution = execution.steps[index]
        stepExecution.state = newState
        
        if newState == .running && stepExecution.startTime == nil {
            stepExecution.startTime = Date()
        }
        
        if newState == .completed || newState == .failed || newState == .skipped {
            stepExecution.endTime = Date()
        }
        
        if let output = output {
            stepExecution.output = output
        }
        
        if let error = error {
            stepExecution.error = error
        }
        
        if newState == .running {
            stepExecution.retryCount += 1
        }
        
        execution.steps[index] = stepExecution
        coordinator.updateExecution(execution)
    }
    
    public func cancel() async {
        cancelled = true
        execution.state = .cancelled
        execution.endTime = Date()
        coordinator.updateExecution(execution)
    }
}

// MARK: - Errors

public enum ExecutorError: LocalizedError, Sendable {
    case stepNotFound(String)
    case serviceNotFound(String)
    case executionTimeout(String, TimeInterval)
    case circularDependency
    case invalidWorkflowDefinition(String)
    
    public var errorDescription: String? {
        switch self {
        case .stepNotFound(let id):
            return "Step not found: \(id)"
        case .serviceNotFound(let id):
            return "Service not found: \(id)"
        case .executionTimeout(let stepId, let timeout):
            return "Step \(stepId) timed out after \(timeout)s"
        case .circularDependency:
            return "Workflow has circular dependencies"
        case .invalidWorkflowDefinition(let reason):
            return "Invalid workflow definition: \(reason)"
        }
    }
}
