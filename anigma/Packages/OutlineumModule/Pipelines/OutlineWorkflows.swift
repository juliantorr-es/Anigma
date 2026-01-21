//
//  OutlineWorkflows.swift
//  OutlineumModule
//
//  Workflows for Outlineum job processing.
//  Connects job types to system execution sequences.
//

import AnigmaCore
import Foundation

// MARK: - Job Types

/// Job type for outline generation from an uploaded image.
public struct OutlineJobType: JobType {
    public static let identifier = "outlineum.outline"
    public static let displayName = "Outline Generation"
}

/// Job type for zine creation (multi-image).
public struct ZineJobType: JobType {
    public static let identifier = "outlineum.zine"
    public static let displayName = "Zine Creation"
}

// MARK: - Workflows

/// Workflow for generating outlines from a single image.
///
/// Pipeline: Ingest → Outline → QA
public struct OutlineWorkflow: Workflow {
    public var name: String { "Outline Generation" }
    public var jobTypeId: String { OutlineJobType.identifier }
    public var systemNames: [String] { ["Ingest", "Outline", "OutlineQA"] }

    public init() {}

    public func prepare(job: Job, world: World) async throws {
        // Validate that input refs exist and have ImageComponent
        for entityId in job.inputRefs {
            guard await world.entityExists(entityId) else {
                throw WorkflowError.executionFailed(
                    workflow: name,
                    error: "Entity \(entityId) does not exist"
                )
            }

            guard await world.hasComponent(entityId, ImageComponent.self) else {
                throw WorkflowError.executionFailed(
                    workflow: name,
                    error: "Entity \(entityId) missing ImageComponent"
                )
            }
        }
    }

    public func finalize(job: Job, world: World, result: JobResult) async throws {
        // Log completion stats
        var passedCount = 0
        var failedCount = 0

        for entityId in job.inputRefs {
            if let qa = await world.getComponent(entityId, OutlineQAComponent.self) {
                if qa.overallPass {
                    passedCount += 1
                } else {
                    failedCount += 1
                }
            }
        }

        logInfo("Workflow complete: \(passedCount) passed, \(failedCount) failed QA",
                category: "OutlineWorkflow")
    }
}

/// Workflow for creating a complete zine from multiple images.
///
/// Pipeline: Ingest → Outline → QA → ZineLayout → ZineExport
public struct ZineWorkflow: Workflow {
    public var name: String { "Zine Creation" }
    public var jobTypeId: String { ZineJobType.identifier }
    public var systemNames: [String] { ["Ingest", "Outline", "OutlineQA", "ZineLayout", "ZineExport"] }

    public init() {}

    public func prepare(job: Job, world: World) async throws {
        // Validate that input refs exist and have ImageComponent or ZineComponent
        for entityId in job.inputRefs {
            guard await world.entityExists(entityId) else {
                throw WorkflowError.executionFailed(
                    workflow: name,
                    error: "Entity \(entityId) does not exist"
                )
            }

            // Should have either ImageComponent (for direct images) or ZineComponent (for existing zine spec)
            let hasImage = await world.hasComponent(entityId, ImageComponent.self)
            let hasZine = await world.hasComponent(entityId, ZineComponent.self)

            guard hasImage || hasZine else {
                throw WorkflowError.executionFailed(
                    workflow: name,
                    error: "Entity \(entityId) missing ImageComponent or ZineComponent"
                )
            }
        }
    }

    public func finalize(job: Job, world: World, result: JobResult) async throws {
        // Log completion stats
        var publishedCount = 0
        var failedCount = 0

        for entityId in job.inputRefs {
            if let zine = await world.getComponent(entityId, ZineComponent.self) {
                if zine.status == .published {
                    publishedCount += 1
                } else {
                    failedCount += 1
                }
            }
        }

        logInfo("Zine workflow complete: \(publishedCount) published, \(failedCount) failed",
                category: "ZineWorkflow")
    }
}
