//
//  Workflow.swift
//  AnigmaCore
//
//  Workflow abstraction for defining sequences of systems to run.
//  Workflows connect job types to the systems that process them.
//
//  This implementation provides:
//  - Workflow protocol for defining processing pipelines
//  - WorkflowRegistry for looking up workflows by job type
//  - WorkflowRunner for executing workflows in a World
//
//  Migration notes:
//  - Harmonia's BatchRunner logic can use WorkflowRunner
//  - Each domain module registers its workflows at startup
//

import Foundation
import AnigmaPrimitives

// MARK: - Workflow Protocol

/// A workflow defines a sequence of systems to run for a specific job type.
/// Workflows are the bridge between jobs and the ECS system execution.
///
/// ## Example
/// ```swift
/// struct OcrWorkflow: Workflow {
///     var name: String { "OCR Processing" }
///     var jobTypeId: String { "ocr" }
///     var systemNames: [String] { ["FileLoad", "OCR", "QACheck", "Persist"] }
/// }
/// ```
public protocol Workflow: Sendable {
    /// Human-readable name for this workflow.
    var name: String { get }

    /// The job type identifier this workflow handles.
    var jobTypeId: String { get }

    /// Ordered list of system names to run.
    var systemNames: [String] { get }

    /// Optional pre-processing hook before systems run.
    func prepare(job: Job, world: World) async throws

    /// Optional post-processing hook after all systems complete.
    func finalize(job: Job, world: World, result: JobResult) async throws

    /// Determines if a system should run for a given entity.
    /// Override to implement conditional execution based on entity state.
    /// Default implementation returns true (always run).
    func shouldRunSystem(_ systemName: String, for entityId: EntityId, in world: World) async -> Bool
}

// MARK: - Workflow Defaults

public extension Workflow {
    func prepare(job: Job, world: World) async throws {}
    func finalize(job: Job, world: World, result: JobResult) async throws {}

    /// Default implementation: always run all systems.
    func shouldRunSystem(_ systemName: String, for entityId: EntityId, in world: World) async -> Bool {
        return true
    }
}

// MARK: - Workflow Registry

/// Registry for looking up workflows by job type.
/// Domain modules register their workflows here at startup.
public actor WorkflowRegistry {
    private var workflows: [String: any Workflow] = [:]

    public init() {}

    /// Registers a workflow for a job type.
    public func register(_ workflow: any Workflow) {
        workflows[workflow.jobTypeId] = workflow
    }

    /// Unregisters a workflow.
    public func unregister(jobTypeId: String) {
        workflows[jobTypeId] = nil
    }

    /// Looks up a workflow by job type.
    public func workflow(for jobTypeId: String) -> (any Workflow)? {
        workflows[jobTypeId]
    }

    /// Returns all registered workflow names.
    public func allWorkflowNames() -> [String] {
        workflows.values.map { $0.name }
    }

    /// Returns all registered job type IDs.
    public func allJobTypeIds() -> [String] {
        Array(workflows.keys)
    }
}

// MARK: - Workflow Runner

/// Executes workflows for jobs in a World.
/// Connects the job system to the ECS system execution.
public actor WorkflowRunner {
    private let registry: WorkflowRegistry
    private var systemCache: [String: any System] = [:]

    public init(registry: WorkflowRegistry) {
        self.registry = registry
    }

    /// Registers a system that can be used by workflows.
    public func registerSystem(_ system: any System) {
        systemCache[system.name] = system
    }

    /// Executes the appropriate workflow for a job with timeout enforcement.
    /// Returns the job result.
    public func execute(job: Job, in world: World) async throws -> JobResult {
        guard let workflow = await registry.workflow(for: job.typeId) else {
            throw WorkflowError.noWorkflowFound(jobTypeId: job.typeId)
        }

        let startTime = Date()
        var actionsApplied = 0
        var systemsSkipped = 0
        var timedOut = false
        
        // Calculate timeout
        let timeoutPolicy = job.timeoutPolicy ?? .default
        let effectiveTimeout = timeoutPolicy.effectiveTimeout(jobTimeout: job.timeoutDuration)
        
        // Prepare phase (with timeout if specified)
        try await executeWithTimeout(
            duration: effectiveTimeout,
            operation: {
                try await workflow.prepare(job: job, world: world)
            },
            timeoutMessage: "Job \(job.id) prepare phase timed out"
        )

        // Run each system in order with timeout monitoring
        for systemName in workflow.systemNames {
            guard let system = systemCache[systemName] else {
                throw WorkflowError.systemNotFound(name: systemName, workflow: workflow.name)
            }

            // Check if this system should run for the job's input entities
            var shouldRun = true
            if !job.inputRefs.isEmpty {
                shouldRun = false
                for entityId in job.inputRefs {
                    if await workflow.shouldRunSystem(systemName, for: entityId, in: world) {
                        shouldRun = true
                        break
                    }
                }
            }

            if shouldRun {
                let systemStartTime = Date()
                
                // Calculate remaining timeout for this system
                let elapsed = Date().timeIntervalSince(startTime)
                let remainingTimeout = max(effectiveTimeout - elapsed, 1.0) // At least 1 second
                
                try await executeWithTimeout(
                    duration: remainingTimeout,
                    operation: {
                        await system.update(world: world)
                    },
                    timeoutMessage: "Job \(job.id) system '\(systemName)' timed out"
                )
                
                actionsApplied += 1
                
                // Check if we should extend timeout due to progress
                let systemElapsed = Date().timeIntervalSince(systemStartTime)
                if timeoutPolicy.allowProgressExtension && systemElapsed < remainingTimeout * 0.8 {
                    // System completed within 80% of its allocated time, we might be making good progress
                    // This could trigger timeout extension in the scheduler
                }
                
            } else {
                systemsSkipped += 1
            }
            
            // Check if we've exceeded overall deadline
            let totalElapsed = Date().timeIntervalSince(startTime)
            if totalElapsed > effectiveTimeout {
                timedOut = true
                break
            }
        }

        let durationMs = Int64(Date().timeIntervalSince(startTime) * 1000)

        var summary = "Workflow '\(workflow.name)' completed"
        if systemsSkipped > 0 {
            summary += " (\(systemsSkipped) systems skipped)"
        }
        if timedOut {
            summary += " (timed out)"
        }

        let result = JobResult(
            outcome: timedOut ? .partialSuccess : .success,
            summary: summary,
            actionsApplied: actionsApplied,
            durationMs: durationMs,
            timeoutDuration: effectiveTimeout,
            timedOut: timedOut,
            outputRefs: job.outputRefs
        )

        // Finalize phase (with timeout if specified)
        if !timedOut {
            let finalizeElapsed = Date().timeIntervalSince(startTime)
            let remainingTimeout = max(effectiveTimeout - finalizeElapsed, 1.0)
            
            try? await executeWithTimeout(
                duration: remainingTimeout,
                operation: {
                    try await workflow.finalize(job: job, world: world, result: result)
                },
                timeoutMessage: "Job \(job.id) finalize phase timed out"
            )
        }

        return result
    }
    
    /// Execute an operation with timeout enforcement.
    private func executeWithTimeout<T>(
        duration: TimeInterval,
        operation: @Sendable () async throws -> T,
        timeoutMessage: String
    ) async throws -> T {
        guard duration.isFinite && duration > 0 else {
            return try await operation()
        }
        
        return try await withThrowingTaskGroup(of: T.self) { group in
            // Add the main operation
            group.addTask {
                return try await operation()
            }
            
            // Add timeout task
            group.addTask {
                try await Task.sleep(for: .seconds(duration))
                throw WorkflowError.executionTimeout(timeoutMessage)
            }
            
            // Wait for first completion
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

// MARK: - Workflow Errors

/// Errors related to workflow operations.
public enum WorkflowError: Error, LocalizedError, Sendable {
    case noWorkflowFound(jobTypeId: String)
    case systemNotFound(name: String, workflow: String)
    case executionFailed(workflow: String, error: String)
    case executionTimeout(String)

    public var errorDescription: String? {
        switch self {
        case .noWorkflowFound(let jobTypeId):
            return "No workflow found for job type: \(jobTypeId)"
        case .systemNotFound(let name, let workflow):
            return "System '\(name)' not found for workflow '\(workflow)'"
        case .executionFailed(let workflow, let error):
            return "Workflow '\(workflow)' failed: \(error)"
        case .executionTimeout(let message):
            return message
        }
    }
}

// MARK: - Simple Workflow Builder

/// Helper for building simple linear workflows.
public struct SimpleWorkflow: Workflow {
    public let name: String
    public let jobTypeId: String
    public let systemNames: [String]

    public init(name: String, jobTypeId: String, systems: [String]) {
        self.name = name
        self.jobTypeId = jobTypeId
        self.systemNames = systems
    }
}
