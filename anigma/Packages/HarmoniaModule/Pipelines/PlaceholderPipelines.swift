//
//  PlaceholderPipelines.swift
//  HarmoniaModule
//
//  Minimal workflow catalog for Harmonia job processing.
//

import AnigmaCore
import Foundation

// MARK: - Harmonia Workflow Catalog

/// Default job type for Harmonia orchestration.
public struct HarmoniaGenericJobType: JobType {
    public static let identifier = "harmonia.generic"
    public static let displayName = "Harmonia Generic Job"
}

/// Minimal workflow that performs no system execution.
public struct HarmoniaNoOpWorkflow: Workflow {
    public var name: String { "Harmonia No-Op" }
    public var jobTypeId: String { HarmoniaGenericJobType.identifier }
    public var systemNames: [String] { [] }

    public init() {}
}

/// Registers the default workflows for Harmonia.
public enum HarmoniaWorkflowCatalog {
    public static func registerAll(into registry: WorkflowRegistry) async {
        await registry.register(HarmoniaNoOpWorkflow())
    }
}

// MARK: - Notes
//
// When defining workflows:
// 1. Create a JobType struct for each job type you handle
// 2. Create a Workflow struct that specifies the system execution order
// 3. Register workflows with WorkflowRegistry during module initialization
// 4. Systems referenced in systemNames must be registered with WorkflowRunner
