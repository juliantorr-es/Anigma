//
//  OutlineumModule.swift
//  OutlineumModule
//
//  Outline/zine generation systems and components.
//  Ported from: Outlineum/backend/outlineum/ecs/
//
//  This module provides:
//  - Components: ImageComponent, OutlineComponent, OutlineQAComponent, ZineComponent
//  - Systems: IngestSystem, OutlineSystem, OutlineQASystem
//  - Workflows: OutlineWorkflow, ZineWorkflow
//
//  The Python backend (using ImageMagick + Potrace) is replaced with:
//  - CoreImage for image processing and edge detection
//  - Optional Potrace for vectorization (if installed)
//

import AnigmaCore
import Foundation
import AnigmaPrimitives
import OSLog

// MARK: - Module Info

/// OutlineumModule version information.
public enum OutlineumModuleVersion {
    public static let major = 0
    public static let minor = 1
    public static let patch = 0
    public static let string = "\(major).\(minor).\(patch)"
}

// MARK: - Module Registration

/// Registers Outlineum-specific systems and workflows with the ECS.
///
/// ## Usage
/// ```swift
/// let world = World()
/// let registry = WorkflowRegistry()
/// try await OutlineumModule.register(world: world, registry: registry)
/// ```
public enum OutlineumModule: CapabilityModule {
    public static func register(runtime: PlatformRuntime) async throws {
        let world = await runtime.getWorld()
        let registry = await runtime.getWorkflowRegistry()
        try await register(world: world, registry: registry)
    }

    /// Registers all Outlineum systems and workflows.
    public static func register(
        world: World,
        registry: WorkflowRegistry,
        workDirectory: URL? = nil
    ) async throws {
        let workDir = workDirectory ?? defaultWorkDirectory()

        // Register systems
        await world.registerSystem(IngestSystem(workDirectory: workDir.appendingPathComponent("normalized")))
        await world.registerSystem(OutlineSystem(workDirectory: workDir.appendingPathComponent("outlines")))
        await world.registerSystem(OutlineQASystem())
        await world.registerSystem(ZineLayoutSystem(config: ZineLayoutConfig()))
        await world.registerSystem(ZineExportSystem(workDirectory: workDir.appendingPathComponent("zines"), config: ZineLayoutConfig()))

        // Register workflows
        await registry.register(OutlineWorkflow())
        await registry.register(ZineWorkflow())

        let logger = Logger(subsystem: "com.anigma.outlineum", category: "OutlineumModule")
        logger.info("OutlineumModule registered with 5 systems and 2 workflows")
    }

    /// Creates a job for outline generation from an image file.
    public static func createOutlineJob(
        imagePath: String,
        world: World
    ) async -> (job: Job, entityId: EntityId) {
        // Create entity with ImageComponent
        let entityId = await world.createEntity()
        await world.addComponent(entityId, ImageComponent(originalPath: imagePath))

        // Create job
        let job = Job(
            typeId: OutlineJobType.identifier,
            inputRefs: [entityId],
            label: "Outline: \((imagePath as NSString).lastPathComponent)"
        )

        return (job, entityId)
    }

    /// Default work directory for Outlineum outputs.
    public static func defaultWorkDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("outlineum", isDirectory: true)
    }
}

// MARK: - Convenience Extensions

extension World {
    /// Convenience method to run the outline pipeline on a single image.
    public func runOutlinePipeline(imagePath: String) async -> (entityId: EntityId, qa: OutlineQAComponent?) {
        // Create entity
        let entityId = createEntity()
        addComponent(entityId, ImageComponent(originalPath: imagePath))

        // Run systems manually (for testing/debugging)
        await runSystem(IngestSystem())
        await runSystem(OutlineSystem())
        await runSystem(OutlineQASystem())

        // Return results
        let qa = getComponent(entityId, OutlineQAComponent.self)
        return (entityId, qa)
    }
}
