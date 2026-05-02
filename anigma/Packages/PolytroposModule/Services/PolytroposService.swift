//
//  PolytroposService.swift
//  PolytroposModule
//
//  High-level orchestration service for Polytropos projects.
//

import AnigmaCore
import Foundation
import AnigmaPrimitives

// MARK: - Polytropos Service

/// High-level service for managing Polytropos projects and workflows.
public actor PolytroposService {

    private let world: World
    private let workflowRegistry: WorkflowRegistry
    private let workflowRunner: WorkflowRunner
    private let workDirectory: URL

    public init(
        world: World,
        workflowRegistry: WorkflowRegistry,
        workflowRunner: WorkflowRunner,
        workDirectory: URL? = nil
    ) {
        self.world = world
        self.workflowRegistry = workflowRegistry
        self.workflowRunner = workflowRunner
        self.workDirectory = workDirectory ?? PolytroposModule.defaultWorkDirectory()
    }

    // MARK: - Project Management

    /// Creates a new Polytropos project.
    public func createProject(
        name: String,
        eventDate: Date? = nil,
        venue: String? = nil,
        performers: [String] = [],
        eventType: EventType = .general
    ) async -> EntityId {
        let entityId = await world.createEntity()

        let project = ProjectComponent(
            name: name,
            eventDate: eventDate,
            venue: venue,
            performers: performers
        )
        await world.addComponent(entityId, project)

        let refs = ProjectReferencesComponent()
        await world.addComponent(entityId, refs)

        let metadata = EventMetadataComponent(eventType: eventType)
        await world.addComponent(entityId, metadata)

        await PlatformLogger.shared.info(
            "Created project: \(name) (\(entityId))",
            category: "Polytropos"
        )

        return entityId
    }

    /// Gets a project by entity ID.
    public func getProject(_ entityId: EntityId) async -> ProjectComponent? {
        await world.getComponent(entityId, ProjectComponent.self)
    }

    /// Lists all projects.
    public func listProjects() async -> [(EntityId, ProjectComponent)] {
        let entities = await world.entitiesWith( ProjectComponent.self)
        var results: [(EntityId, ProjectComponent)] = []

        for entityId in entities {
            if let project = await world.getComponent(entityId, ProjectComponent.self) {
                results.append((entityId, project))
            }
        }

        return results.sorted { $0.1.createdAt > $1.1.createdAt }
    }

    // MARK: - Media Import

    /// Imports media files into a project.
    public func importMedia(
        projectId: EntityId,
        paths: [String]
    ) async throws -> [EntityId] {
        guard var project = await world.getComponent(projectId, ProjectComponent.self) else {
            throw PolytroposError.projectNotFound(projectId)
        }

        guard var refs = await world.getComponent(projectId, ProjectReferencesComponent.self) else {
            throw PolytroposError.invalidProject(projectId)
        }

        var assetIds: [EntityId] = []

        for path in paths {
            let assetId = await world.createEntity()

            let mediaType = classifyMediaType(path: path)
            let asset = MediaAssetComponent(
                originalPath: path,
                mediaType: mediaType,
                status: .pending
            )
            await world.addComponent(assetId, asset)

            assetIds.append(assetId)
            refs.mediaAssetIds.append(assetId)
        }

        await world.addComponent(projectId, refs)

        // Update project status
        project.status = .ingesting
        project.modifiedAt = Date()
        await world.addComponent(projectId, project)

        await PlatformLogger.shared.info(
            "Imported \(paths.count) media files into project \(project.name)",
            category: "Polytropos"
        )

        return assetIds
    }

    private func classifyMediaType(path: String) -> MediaType {
        let ext = (path as NSString).pathExtension.lowercased()

        let videoExtensions = ["mp4", "mov", "m4v", "mkv", "avi", "mxf", "mts"]
        let audioExtensions = ["wav", "mp3", "m4a", "aac", "flac", "aiff"]

        if videoExtensions.contains(ext) {
            return .video
        } else if audioExtensions.contains(ext) {
            return .audio
        } else {
            return .unknown
        }
    }

    // MARK: - Multicam Clustering

    /// Creates a multicam cluster from assets.
    public func createCluster(
        projectId: EntityId,
        name: String,
        assetIds: [EntityId],
        referenceAssetId: EntityId? = nil
    ) async throws -> EntityId {
        guard var refs = await world.getComponent(projectId, ProjectReferencesComponent.self) else {
            throw PolytroposError.invalidProject(projectId)
        }

        let clusterId = await world.createEntity()

        let cluster = MulticamClusterComponent(
            name: name,
            assetIds: assetIds,
            referenceAssetId: referenceAssetId ?? assetIds.first,
            status: .pending
        )
        await world.addComponent(clusterId, cluster)

        refs.clusterIds.append(clusterId)
        await world.addComponent(projectId, refs)

        await PlatformLogger.shared.info(
            "Created cluster: \(name) with \(assetIds.count) assets",
            category: "Polytropos"
        )

        return clusterId
    }

    // MARK: - Processing

    /// Runs the full event processing workflow on a project.
    public func processProject(_ projectId: EntityId) async throws -> JobResult {
        guard let project = await world.getComponent(projectId, ProjectComponent.self) else {
            throw PolytroposError.projectNotFound(projectId)
        }

        let job = Job(
            typeId: PolytroposJobType.fullEvent,
            inputRefs: [projectId],
            label: "Process: \(project.name)"
        )

        return try await workflowRunner.execute(job: job, in: world)
    }

    /// Runs the quick clip workflow for a simple export.
    public func quickClip(_ projectId: EntityId) async throws -> JobResult {
        guard let project = await world.getComponent(projectId, ProjectComponent.self) else {
            throw PolytroposError.projectNotFound(projectId)
        }

        let job = Job(
            typeId: PolytroposJobType.quickClip,
            inputRefs: [projectId],
            label: "Quick Clip: \(project.name)"
        )

        return try await workflowRunner.execute(job: job, in: world)
    }

    // MARK: - Export

    /// Creates an export job for a timeline.
    public func createExportJob(
        timelineId: EntityId,
        presetId: EntityId,
        sceneId: EntityId? = nil
    ) async throws -> EntityId {
        guard await world.getComponent(timelineId, TimelineComponent.self) != nil else {
            throw PolytroposError.timelineNotFound(timelineId)
        }

        let jobId = await world.createEntity()

        let exportJob = ExportJobComponent(
            timelineId: timelineId,
            sceneId: sceneId,
            presetId: presetId,
            status: .pending
        )
        await world.addComponent(jobId, exportJob)

        await PlatformLogger.shared.info(
            "Created export job for timeline \(timelineId)",
            category: "Polytropos"
        )

        return jobId
    }

    /// Gets export job status.
    public func getExportStatus(_ jobId: EntityId) async -> ExportJobComponent? {
        await world.getComponent(jobId, ExportJobComponent.self)
    }

    // MARK: - Branding

    /// Creates a branding profile.
    public func createBrandingProfile(
        name: String,
        primaryColor: String = "#FFFFFF",
        secondaryColor: String = "#000000",
        accentColor: String = "#FF0000"
    ) async -> EntityId {
        let entityId = await world.createEntity()

        let profile = BrandingProfileComponent(
            name: name,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            accentColor: accentColor
        )
        await world.addComponent(entityId, profile)

        return entityId
    }

    /// Associates a branding profile with a project.
    public func setBrandingProfile(
        projectId: EntityId,
        brandingProfileId: EntityId
    ) async throws {
        guard var project = await world.getComponent(projectId, ProjectComponent.self) else {
            throw PolytroposError.projectNotFound(projectId)
        }

        project.brandingProfileId = brandingProfileId
        project.modifiedAt = Date()
        await world.addComponent(projectId, project)
    }

    // MARK: - Scene Management

    /// Gets all scenes for a project.
    public func getScenes(projectId: EntityId) async -> [(EntityId, SceneComponent)] {
        let sceneEntities = await world.entitiesWith( SceneComponent.self)
        var results: [(EntityId, SceneComponent)] = []

        for entityId in sceneEntities {
            if let scene = await world.getComponent(entityId, SceneComponent.self) {
                results.append((entityId, scene))
            }
        }

        return results.sorted { $0.1.sourceRange.start < $1.1.sourceRange.start }
    }

    /// Updates scene status.
    public func updateSceneStatus(
        sceneId: EntityId,
        status: SceneStatus
    ) async throws {
        guard var scene = await world.getComponent(sceneId, SceneComponent.self) else {
            throw PolytroposError.sceneNotFound(sceneId)
        }

        scene.status = status
        await world.addComponent(sceneId, scene)
    }

    /// Sets scene rating.
    public func setSceneRating(
        sceneId: EntityId,
        rating: Int?
    ) async throws {
        guard var scene = await world.getComponent(sceneId, SceneComponent.self) else {
            throw PolytroposError.sceneNotFound(sceneId)
        }

        scene.userRating = rating
        await world.addComponent(sceneId, scene)
    }
}

// MARK: - Errors

/// Polytropos-specific errors.
public enum PolytroposError: Error, LocalizedError {
    case projectNotFound(EntityId)
    case invalidProject(EntityId)
    case timelineNotFound(EntityId)
    case sceneNotFound(EntityId)
    case clusterNotFound(EntityId)
    case exportFailed(String)

    public var errorDescription: String? {
        switch self {
        case .projectNotFound(let id):
            return "Project not found: \(id)"
        case .invalidProject(let id):
            return "Invalid project configuration: \(id)"
        case .timelineNotFound(let id):
            return "Timeline not found: \(id)"
        case .sceneNotFound(let id):
            return "Scene not found: \(id)"
        case .clusterNotFound(let id):
            return "Cluster not found: \(id)"
        case .exportFailed(let message):
            return "Export failed: \(message)"
        }
    }
}
