//
//  WorkflowProtocols.swift
//  AnigmaFoundation
//
//  Protocols for workflow management and execution to support dependency injection.
//

import Foundation
import AnigmaPrimitives
import AnigmaFoundation

// MARK: - Workflow Registry Protocol

/// Protocol for looking up workflows by job type.
public protocol WorkflowRegistry: Sendable {
    /// Registers a workflow for a job type.
    func register(_ workflow: any Workflow) async
    
    /// Unregisters a workflow.
    func unregister(jobTypeId: String) async
    
    /// Looks up a workflow by job type.
    func workflow(for jobTypeId: String) async -> (any Workflow)?
    
    /// Returns all registered workflow names.
    func allWorkflowNames() async -> [String]
    
    /// Returns all registered job type IDs.
    func allJobTypeIds() async -> [String]
}

// MARK: - Workflow Runner Protocol

/// Protocol for executing workflows for jobs in a World.
public protocol WorkflowRunner: Sendable {
    /// Registers a system that can be used by workflows.
    func registerSystem(_ system: any System) async
    
    /// Executes the appropriate workflow for a job with timeout enforcement.
    func execute(job: Job, in world: World) async throws -> JobResult
}
