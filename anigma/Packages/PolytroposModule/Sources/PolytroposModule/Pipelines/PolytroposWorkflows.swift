//
//  PolytroposWorkflows.swift
//  PolytroposModule
//
//  Workflow definitions for Polytropos processing pipelines.
//

import AnigmaCore
import Foundation
import AnigmaPrimitives

// MARK: - Full Event Workflow

/// Complete pipeline: Ingest → Sync → Analyze → AutoEdit → Caption → Branding → Reframe
public struct FullEventWorkflow: Workflow {
    public var name: String { "Full Event Processing" }
    public var jobTypeId: String { PolytroposJobType.fullEvent }

    public var systemNames: [String] {
        [
            "MediaIngest",
            "AudioSync",
            "AudioAnalysis",
            "VideoAnalysis",
            "AutoEdit",
            "Caption",
            "Branding",
            "Reframe"
        ]
    }

    public init() {}

    public func prepare(job: Job, world: World) async throws {
        await Logger.shared.info(
            "Starting full event workflow for job: \(job.id)",
            category: "Polytropos"
        )

        // Validate input entities exist
        for entityId in job.inputRefs {
            guard await world.getComponent(entityId, ProjectComponent.self) != nil else {
                throw WorkflowError.executionFailed(
                    workflow: name,
                    error: "Input entity not found: \(entityId)"
                )
            }
        }
    }

    public func finalize(job: Job, world: World, result: JobResult) async throws {
        await Logger.shared.info(
            "Full event workflow completed: \(result.outcome.rawValue)",
            category: "Polytropos"
        )

        // Update project status if applicable
        for entityId in job.inputRefs {
            if var project = await world.getComponent(entityId, ProjectComponent.self) {
                project.status = .ready
                project.modifiedAt = Date()
                await world.addComponent(entityId, project)
            }
        }
    }

    public func shouldRunSystem(
        _ systemName: String,
        for entityId: EntityId,
        in world: World
    ) async -> Bool {
        // Run all systems for full event workflow
        return true
    }
}

// MARK: - Quick Clip Workflow

/// Simplified mobile-friendly pipeline for quick social clips.
public struct QuickClipWorkflow: Workflow {
    public var name: String { "Quick Clip Generation" }
    public var jobTypeId: String { PolytroposJobType.quickClip }

    public var systemNames: [String] {
        [
            "MediaIngest",
            "AudioSync",
            "AudioAnalysis",
            "AutoEdit",
            "Export"
        ]
    }

    public init() {}

    public func prepare(job: Job, world: World) async throws {
        await Logger.shared.info(
            "Starting quick clip workflow for job: \(job.id)",
            category: "Polytropos"
        )
    }

    public func finalize(job: Job, world: World, result: JobResult) async throws {
        await Logger.shared.info(
            "Quick clip workflow completed: \(result.outcome.rawValue)",
            category: "Polytropos"
        )
    }
}

// MARK: - Re-Export Workflow

/// Re-render existing timeline with new presets.
public struct ReExportWorkflow: Workflow {
    public var name: String { "Re-Export Timeline" }
    public var jobTypeId: String { PolytroposJobType.reExport }

    public var systemNames: [String] {
        [
            "Reframe",
            "Export"
        ]
    }

    public init() {}

    public func prepare(job: Job, world: World) async throws {
        // Validate timeline exists
        for entityId in job.inputRefs {
            guard await world.getComponent(entityId, TimelineComponent.self) != nil else {
                throw WorkflowError.executionFailed(
                    workflow: name,
                    error: "Timeline not found: \(entityId)"
                )
            }
        }
    }
}

// MARK: - Caption Only Workflow

/// Generate or regenerate captions for existing timeline.
public struct CaptionOnlyWorkflow: Workflow {
    public var name: String { "Caption Generation" }
    public var jobTypeId: String { PolytroposJobType.captioning }

    public var systemNames: [String] {
        ["Caption"]
    }

    public init() {}
}

// MARK: - Analysis Only Workflow

/// Run analysis without auto-editing (for preview/debugging).
public struct AnalysisOnlyWorkflow: Workflow {
    public var name: String { "Analysis Only" }
    public var jobTypeId: String { "polytropos.analysis_only" }

    public var systemNames: [String] {
        [
            "MediaIngest",
            "AudioSync",
            "AudioAnalysis",
            "VideoAnalysis"
        ]
    }

    public init() {}
}
