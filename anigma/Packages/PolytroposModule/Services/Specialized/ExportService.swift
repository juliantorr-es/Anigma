//
//  ExportService.swift
//  PolytroposModule
//
//  Handles video export and rendering operations.
//

import AnigmaCore
import Foundation
import AnigmaPrimitives

// MARK: - Export Service

/// Specialized service for video export and rendering.
public actor ExportService {

    private let world: World
    private let workDirectory: URL
    private var activeJobs: [UUID: ExportTask] = [:]

    public init(world: World, workDirectory: URL) {
        self.world = world
        self.workDirectory = workDirectory
    }

    // MARK: - Job Management

    /// Queues an export job for a timeline.
    public func queueExport(
        timelineId: EntityId,
        preset: ExportPresetComponent,
        sceneId: EntityId? = nil
    ) async throws -> EntityId {
        // Validate timeline exists
        guard await world.getComponent(timelineId, TimelineComponent.self) != nil else {
            throw ExportError.timelineNotFound(timelineId)
        }

        // Create preset entity if needed
        let presetId = await world.createEntity()
        await world.addComponent(presetId, preset)

        // Create job entity
        let jobId = await world.createEntity()

        let outputPath = workDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(extensionFor(codec: preset.videoCodec))
            .path

        let job = ExportJobComponent(
            timelineId: timelineId,
            sceneId: sceneId,
            presetId: presetId,
            outputPath: outputPath,
            status: .queued
        )
        await world.addComponent(jobId, job)

        await Logger.shared.info(
            "Queued export job: \(job.id) for timeline \(timelineId)",
            category: "Polytropos"
        )

        return jobId
    }

    /// Starts processing a queued export job.
    public func startExport(_ jobId: EntityId) async throws {
        guard var job = await world.getComponent(jobId, ExportJobComponent.self) else {
            throw ExportError.jobNotFound(jobId)
        }

        guard job.status == .queued || job.status == .pending else {
            throw ExportError.invalidJobState(job.status)
        }

        // Update status
        job.status = .preparing
        job.startedAt = Date()
        await world.addComponent(jobId, job)

        // Get timeline and preset
        guard let timeline = await world.getComponent(job.timelineId, TimelineComponent.self),
              let tracks = await world.getComponent(job.timelineId, TimelineTracksComponent.self),
              let preset = await world.getComponent(job.presetId, ExportPresetComponent.self) else {
            job.status = .failed
            job.errorMessage = "Missing timeline or preset data"
            await world.addComponent(jobId, job)
            throw ExportError.missingData("Timeline or preset not found")
        }

        // Create export task
        let task = ExportTask(
            jobId: job.id,
            entityId: jobId,
            timeline: timeline,
            tracks: tracks,
            preset: preset,
            outputPath: job.outputPath ?? "",
            sceneId: job.sceneId
        )
        activeJobs[job.id] = task

        // Start export (in real implementation, this would be async)
        await performExport(task: task)
    }

    /// Gets the status of an export job.
    public func getJobStatus(_ jobId: EntityId) async -> ExportJobComponent? {
        await world.getComponent(jobId, ExportJobComponent.self)
    }

    /// Cancels an export job.
    public func cancelExport(_ jobId: EntityId) async throws {
        guard var job = await world.getComponent(jobId, ExportJobComponent.self) else {
            throw ExportError.jobNotFound(jobId)
        }

        guard !job.status.isTerminal else {
            throw ExportError.invalidJobState(job.status)
        }

        activeJobs.removeValue(forKey: job.id)

        job.status = .cancelled
        job.completedAt = Date()
        await world.addComponent(jobId, job)
    }

    /// Lists all export jobs.
    public func listJobs() async -> [(EntityId, ExportJobComponent)] {
        let entities = await world.entitiesWith(ExportJobComponent.self)
        var results: [(EntityId, ExportJobComponent)] = []

        for entityId in entities {
            if let job = await world.getComponent(entityId, ExportJobComponent.self) {
                results.append((entityId, job))
            }
        }

        return results.sorted { $0.1.createdAt > $1.1.createdAt }
    }

    // MARK: - Batch Export

    /// Queues multiple exports for different presets.
    public func queueBatchExport(
        timelineId: EntityId,
        presets: [ExportPresetComponent]
    ) async throws -> [EntityId] {
        var jobIds: [EntityId] = []

        for preset in presets {
            let jobId = try await queueExport(timelineId: timelineId, preset: preset)
            jobIds.append(jobId)
        }

        return jobIds
    }

    /// Queues exports for all scenes matching a filter.
    public func queueSceneExports(
        scenes: [EntityId],
        preset: ExportPresetComponent
    ) async throws -> [EntityId] {
        var jobIds: [EntityId] = []

        for sceneId in scenes {
            guard let scene = await world.getComponent(sceneId, SceneComponent.self),
                  let timelineId = scene.timelineId else {
                continue
            }

            let jobId = try await queueExport(
                timelineId: timelineId,
                preset: preset,
                sceneId: sceneId
            )
            jobIds.append(jobId)
        }

        return jobIds
    }

    // MARK: - Export Execution

    private func performExport(task: ExportTask) async {
        guard var job = await world.getComponent(task.entityId, ExportJobComponent.self) else {
            return
        }

        // Update to rendering
        job.status = .rendering
        job.progress = 0
        await world.addComponent(task.entityId, job)

        let startTime = Date()

        // Simulate rendering progress
        // In real implementation, this would use AVAssetExportSession or custom composition
        for progress in stride(from: 0.0, to: 1.0, by: 0.1) {
            job.progress = progress
            job.estimatedTimeRemaining = estimateRemainingTime(
                progress: progress,
                startTime: startTime,
                duration: task.timeline.duration
            )
            await world.addComponent(task.entityId, job)

            // Check for cancellation
            if activeJobs[task.jobId] == nil {
                return
            }

            // Simulate work
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }

        // Finalize
        job.status = .finalizing
        job.progress = 0.95
        await world.addComponent(task.entityId, job)

        // Complete
        job.status = .completed
        job.progress = 1.0
        job.completedAt = Date()
        job.renderDuration = Date().timeIntervalSince(startTime)
        job.outputSize = Int64.random(in: 10_000_000...100_000_000) // Simulated
        await world.addComponent(task.entityId, job)

        activeJobs.removeValue(forKey: task.jobId)

        await Logger.shared.info(
            "Export completed: \(job.outputPath ?? "unknown")",
            category: "Polytropos"
        )
    }

    private func estimateRemainingTime(
        progress: Double,
        startTime: Date,
        duration: TimeInterval
    ) -> TimeInterval {
        guard progress > 0 else { return duration }

        let elapsed = Date().timeIntervalSince(startTime)
        let estimatedTotal = elapsed / progress
        return max(0, estimatedTotal - elapsed)
    }

    private func extensionFor(codec: VideoCodec) -> String {
        switch codec {
        case .h264, .hevc, .av1:
            return "mp4"
        case .prores422, .prores4444:
            return "mov"
        }
    }
}

// MARK: - Supporting Types

/// Active export task tracking.
struct ExportTask {
    let jobId: UUID
    let entityId: EntityId
    let timeline: TimelineComponent
    let tracks: TimelineTracksComponent
    let preset: ExportPresetComponent
    let outputPath: String
    let sceneId: EntityId?
}

/// Errors from export operations.
public enum ExportError: Error, LocalizedError {
    case timelineNotFound(EntityId)
    case jobNotFound(EntityId)
    case invalidJobState(ExportJobStatus)
    case missingData(String)
    case encodingFailed(String)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .timelineNotFound(let id):
            return "Timeline not found: \(id)"
        case .jobNotFound(let id):
            return "Export job not found: \(id)"
        case .invalidJobState(let status):
            return "Invalid job state: \(status.rawValue)"
        case .missingData(let detail):
            return "Missing data: \(detail)"
        case .encodingFailed(let reason):
            return "Encoding failed: \(reason)"
        case .cancelled:
            return "Export was cancelled"
        }
    }
}

// MARK: - Export Report

/// Summary of an export job for UI display.
public struct ExportReport: Sendable {
    public let jobId: EntityId
    public let status: ExportJobStatus
    public let progress: Double
    public let outputPath: String?
    public let outputSize: Int64?
    public let renderDuration: TimeInterval?
    public let error: String?

    public var formattedSize: String {
        guard let size = outputSize else { return "—" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    public var formattedDuration: String {
        guard let duration = renderDuration else { return "—" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "—"
    }
}

extension ExportService {
    /// Generates a report for a job.
    public func generateReport(for jobId: EntityId) async -> ExportReport? {
        guard let job = await world.getComponent(jobId, ExportJobComponent.self) else {
            return nil
        }

        return ExportReport(
            jobId: jobId,
            status: job.status,
            progress: job.progress,
            outputPath: job.outputPath,
            outputSize: job.outputSize,
            renderDuration: job.renderDuration,
            error: job.errorMessage
        )
    }
}
