//
//  ProgressTracker.swift
//  DiaplasionModule
//
//  Tracks progress of long-running document processing jobs.
//

import AnigmaCore
import Foundation
import AnigmaPrimitives

/// Tracks progress of document processing jobs with real-time updates.
public struct ProgressTracker: Sendable {
    
    // MARK: - Configuration
    
    /// Update interval for progress reporting (in seconds)
    public let updateInterval: TimeInterval
    
    /// Enable detailed progress logging
    public let enableDetailedLogging: Bool
    
    /// Progress change callback
    public let onProgressUpdate: ((ProgressUpdate) -> Void)?
    
    // MARK: - State
    
    private var currentProgress: [EntityID: JobProgress] = [:]
    private var lastUpdateTime: [EntityID: Date] = [:]
    
    // MARK: - Initialization
    
    public init(
        updateInterval: TimeInterval = 1.0,
        enableDetailedLogging: Bool = true,
        onProgressUpdate: ((ProgressUpdate) -> Void)? = nil
    ) {
        self.updateInterval = updateInterval
        self.enableDetailedLogging = enableDetailedLogging
        self.onProgressUpdate = onProgressUpdate
    }
    
    // MARK: - Public Interface
    
    /// Start tracking a new job.
    public func startJob(
        entityId: EntityID,
        jobType: JobType,
        totalSteps: Int,
        metadata: [String: String] = [:]
    ) {
        let progress = JobProgress(
            entityId: entityId,
            jobType: jobType,
            startedAt: Date(),
            totalSteps: totalSteps,
            currentStep: 0,
            stage: .started,
            metadata: metadata
        )
        
        currentProgress[entityId] = progress
        lastUpdateTime[entityId] = Date()
        
        let update = ProgressUpdate(
            entityId: entityId,
            jobType: jobType,
            stage: .started,
            percentage: 0.0,
            message: "Job started",
            estimatedTimeRemaining: nil,
            metadata: metadata
        )
        
        onProgressUpdate?(update)
        
        if enableDetailedLogging {
            Task {
                await Logger.shared.info(
                    "Started tracking job \(entityId) (\(jobType))",
                    category: "Diaplasion"
                )
            }
        }
    }
    
    /// Update progress for a job.
    public func updateProgress(
        entityId: EntityID,
        currentStep: Int,
        stage: ProcessingStage,
        message: String? = nil,
        additionalMetadata: [String: String] = [:]
    ) {
        guard var progress = currentProgress[entityId] else {
            if enableDetailedLogging {
                Task {
                    await Logger.shared.warning(
                        "Attempted to update unknown job: \(entityId)",
                        category: "Diaplasion"
                    )
                }
            }
            return
        }
        
        let previousStep = progress.currentStep
        progress.currentStep = min(currentStep, progress.totalSteps)
        progress.stage = stage
        progress.lastUpdatedAt = Date()
        
        // Merge additional metadata
        for (key, value) in additionalMetadata {
            progress.metadata[key] = value
        }
        
        currentProgress[entityId] = progress
        
        // Check if we should report progress (time-based or significant change)
        let shouldReport = shouldReportProgress(
            entityId: entityId,
            stepChange: currentStep - previousStep
        )
        
        if shouldReport {
            let update = createProgressUpdate(for: progress, message: message)
            onProgressUpdate?(update)
            lastUpdateTime[entityId] = Date()
        }
        
        // Log significant milestones
        if enableDetailedLogging && isSignificantMilestone(progress: progress) {
            Task {
                await Logger.shared.info(
                    "Job \(entityId) milestone: \(progress.currentStep)/\(progress.totalSteps) (\(String(format: "%.1f", progress.percentage))%)",
                    category: "Diaplasion"
                )
            }
        }
    }
    
    /// Complete a job.
    public func completeJob(
        entityId: EntityID,
        success: Bool,
        finalMessage: String? = nil,
        resultMetadata: [String: String] = [:]
    ) {
        guard var progress = currentProgress[entityId] else { return }
        
        progress.completedAt = Date()
        progress.success = success
        progress.stage = success ? .completed : .error
        
        // Merge result metadata
        for (key, value) in resultMetadata {
            progress.metadata[key] = value
        }
        
        currentProgress[entityId] = progress
        
        let update = ProgressUpdate(
            entityId: entityId,
            jobType: progress.jobType,
            stage: success ? .completed : .error,
            percentage: 100.0,
            message: finalMessage ?? (success ? "Job completed successfully" : "Job failed"),
            estimatedTimeRemaining: nil,
            metadata: progress.metadata
        )
        
        onProgressUpdate?(update)
        
        if enableDetailedLogging {
            Task {
                await Logger.shared.info(
                    "Job \(entityId) \(success ? "completed" : "failed") in \(String(format: "%.1f", progress.duration))s",
                    category: "Diaplasion"
                )
            }
        }
    }
    
    /// Get current progress for a job.
    public func getProgress(entityId: EntityID) -> JobProgress? {
        return currentProgress[entityId]
    }
    
    /// Get all active jobs.
    public func getActiveJobs() -> [EntityID: JobProgress] {
        return currentProgress.filter { _, progress in
            progress.completedAt == nil
        }
    }
    
    /// Get progress statistics.
    public func getProgressStatistics() -> ProgressStatistics {
        let total = currentProgress.count
        let completed = currentProgress.values.filter { $0.completedAt != nil }.count
        let active = total - completed
        let averageProgress = currentProgress.values.reduce(0.0) { sum, progress in
            sum + progress.percentage
        } / Double(total)
        
        return ProgressStatistics(
            totalJobs: total,
            activeJobs: active,
            completedJobs: completed,
            averageProgress: total > 0 ? averageProgress : 0.0
        )
    }
    
    /// Clean up completed jobs older than the specified interval.
    public func cleanupCompletedJobs(olderThan interval: TimeInterval) {
        let cutoff = Date().addingTimeInterval(-interval)
        let toRemove = currentProgress.filter { _, progress in
            guard let completedAt = progress.completedAt else { return false }
            return completedAt < cutoff
        }
        
        for entityId in toRemove.keys {
            currentProgress.removeValue(forKey: entityId)
            lastUpdateTime.removeValue(forKey: entityId)
        }
        
        if !toRemove.isEmpty && enableDetailedLogging {
            Task {
                await Logger.shared.debug(
                    "Cleaned up \(toRemove.count) completed jobs",
                    category: "Diaplasion"
                )
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Determine if progress should be reported based on time and step changes.
    private func shouldReportProgress(entityId: EntityID, stepChange: Int) -> Bool {
        guard let lastUpdate = lastUpdateTime[entityId],
              let progress = currentProgress[entityId] else { return true }
        
        let timeSinceLastUpdate = Date().timeIntervalSince(lastUpdate)
        let significantStepChange = stepChange >= max(1, progress.totalSteps / 20) // 5% increments
        
        return timeSinceLastUpdate >= updateInterval || significantStepChange || progress.stage == .completed
    }
    
    /// Check if a progress update represents a significant milestone.
    private func isSignificantMilestone(progress: JobProgress) -> Bool {
        let percentage = progress.percentage
        return [25.0, 50.0, 75.0, 100.0].contains { abs(percentage - $0) < 2.5 }
    }
    
    /// Create a progress update from job progress.
    private func createProgressUpdate(for progress: JobProgress, message: String?) -> ProgressUpdate {
        let eta = progress.stage == .processing ? calculateETA(for: progress) : nil
        
        return ProgressUpdate(
            entityId: progress.entityId,
            jobType: progress.jobType,
            stage: progress.stage,
            percentage: progress.percentage,
            message: message ?? progress.stage.defaultMessage,
            estimatedTimeRemaining: eta,
            metadata: progress.metadata
        )
    }
    
    /// Calculate estimated time remaining for a job.
    private func calculateETA(for progress: JobProgress) -> TimeInterval? {
        guard progress.currentStep > 0 else { return nil }
        
        let elapsed = Date().timeIntervalSince(progress.startedAt)
        let averageTimePerStep = elapsed / Double(progress.currentStep)
        let remainingSteps = progress.totalSteps - progress.currentStep
        
        return averageTimePerStep * Double(remainingSteps)
    }
}

// MARK: - Supporting Types

/// Types of jobs that can be tracked.
public enum JobType: String, CaseIterable, Sendable {
    case documentIngest = "document_ingest"
    case ocrExtraction = "ocr_extraction"
    case textChunking = "text_chunking"
    case epubExport = "epub_export"
    case brailleExport = "braille_export"
    case audioGeneration = "audio_generation"
    case qualityAssurance = "quality_assurance"
    case multiFormatConversion = "multi_format_conversion"
}

/// Progress information for a specific job.
public struct JobProgress: Sendable {
    public let entityId: EntityID
    public let jobType: JobType
    public let startedAt: Date
    public let totalSteps: Int
    public var currentStep: Int
    public var stage: ProcessingStage
    public var lastUpdatedAt: Date
    public var completedAt: Date?
    public var success: Bool?
    public var metadata: [String: String]
    
    public init(
        entityId: EntityID,
        jobType: JobType,
        startedAt: Date,
        totalSteps: Int,
        currentStep: Int = 0,
        stage: ProcessingStage = .started,
        lastUpdatedAt: Date = Date(),
        completedAt: Date? = nil,
        success: Bool? = nil,
        metadata: [String: String] = [:]
    ) {
        self.entityId = entityId
        self.jobType = jobType
        self.startedAt = startedAt
        self.totalSteps = totalSteps
        self.currentStep = currentStep
        self.stage = stage
        self.lastUpdatedAt = lastUpdatedAt
        self.completedAt = completedAt
        self.success = success
        self.metadata = metadata
    }
    
    /// Percentage completion of the job.
    public var percentage: Double {
        guard totalSteps > 0 else { return 0.0 }
        return min(Double(currentStep) / Double(totalSteps) * 100.0, 100.0)
    }
    
    /// Duration of the job so far.
    public var duration: TimeInterval {
        return Date().timeIntervalSince(startedAt)
    }
    
    /// Whether the job is currently active.
    public var isActive: Bool {
        return completedAt == nil
    }
}

/// Progress update sent to callbacks.
public struct ProgressUpdate: Sendable {
    public let entityId: EntityID
    public let jobType: JobType
    public let stage: ProcessingStage
    public let percentage: Double
    public let message: String
    public let estimatedTimeRemaining: TimeInterval?
    public let metadata: [String: String]
    
    public init(
        entityId: EntityID,
        jobType: JobType,
        stage: ProcessingStage,
        percentage: Double,
        message: String,
        estimatedTimeRemaining: TimeInterval?,
        metadata: [String: String]
    ) {
        self.entityId = entityId
        self.jobType = jobType
        self.stage = stage
        self.percentage = percentage
        self.message = message
        self.estimatedTimeRemaining = estimatedTimeRemaining
        self.metadata = metadata
    }
}

/// Statistics about tracked jobs.
public struct ProgressStatistics: Sendable {
    public let totalJobs: Int
    public let activeJobs: Int
    public let completedJobs: Int
    public let averageProgress: Double
    
    public init(
        totalJobs: Int,
        activeJobs: Int,
        completedJobs: Int,
        averageProgress: Double
    ) {
        self.totalJobs = totalJobs
        self.activeJobs = activeJobs
        self.completedJobs = completedJobs
        self.averageProgress = averageProgress
    }
}

// MARK: - Extensions

extension ProcessingStage {
    /// Default message for each stage.
    var defaultMessage: String {
        switch self {
        case .starting:
            return "Starting processing..."
        case .processing:
            return "Processing..."
        case .finalizing:
            return "Finalizing..."
        case .completed:
            return "Completed"
        case .error:
            return "Error occurred"
        }
    }
}

// MARK: - System Integration

/// System that manages progress tracking for all Diaplasion jobs.
public struct ProgressTrackingSystem: System {
    public var name: String { "ProgressTracking" }
    
    private let tracker: ProgressTracker
    
    public init(tracker: ProgressTracker = ProgressTracker()) {
        self.tracker = tracker
    }
    
    public func update(world: World) async {
        // Clean up old completed jobs periodically
        tracker.cleanupCompletedJobs(olderThan: 3600) // 1 hour
        
        // Handle progress updates from components
        let progressEntities = await world.query(ProgressUpdateComponent.self)
        
        for (entity, updateComponent) in progressEntities {
            switch updateComponent.action {
            case .start(let jobType, let totalSteps, let metadata):
                tracker.startJob(
                    entityId: entity,
                    jobType: jobType,
                    totalSteps: totalSteps,
                    metadata: metadata
                )
                
            case .update(let currentStep, let stage, let message, let metadata):
                tracker.updateProgress(
                    entityId: entity,
                    currentStep: currentStep,
                    stage: stage,
                    message: message,
                    additionalMetadata: metadata
                )
                
            case .complete(let success, let message, let metadata):
                tracker.completeJob(
                    entityId: entity,
                    success: success,
                    finalMessage: message,
                    resultMetadata: metadata
                )
            }
            
            // Remove the update component after processing
            await world.removeComponent(entity, ProgressUpdateComponent.self)
        }
    }
}

/// Component for triggering progress updates.
public struct ProgressUpdateComponent: Component {
    public let action: ProgressAction
    
    public init(action: ProgressAction) {
        self.action = action
    }
}

/// Actions for progress updates.
public enum ProgressAction: Sendable {
    case start(jobType: JobType, totalSteps: Int, metadata: [String: String])
    case update(currentStep: Int, stage: ProcessingStage, message: String?, metadata: [String: String])
    case complete(success: Bool, message: String?, metadata: [String: String])
}