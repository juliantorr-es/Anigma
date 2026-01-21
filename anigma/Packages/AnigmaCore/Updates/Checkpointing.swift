//
//  Checkpointing.swift
//  AnigmaCore
//
//  AnigmaCore - Draft and Checkpoint Management
//
//  Handles saving work-in-progress so users don't lose data during updates.
//  Drafts are first-class ECS entities with governed lifecycle.
//

import Foundation
import AnigmaPrimitives

// MARK: - Draft State

/// State of a draft
public enum DraftState: String, Sendable, Codable {
    case active       // Currently being edited
    case saved        // Saved but not submitted
    case submitted    // Converted to real entity
    case abandoned    // Explicitly abandoned
    case expired      // Auto-expired after retention period
}

// MARK: - Draft Component

/// ECS Component for draft storage
public struct DraftComponent: Component {
    public let draftId: UUID
    public let draftType: String
    public let principalId: String
    public let deviceId: String?
    public let createdAt: Date
    public var updatedAt: Date
    public var state: DraftState
    public var data: Data
    public var metadata: DraftMetadata
    public var checkpointVersion: Int

    public init(
        draftId: UUID = UUID(),
        draftType: String,
        principalId: String,
        deviceId: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        state: DraftState = .active,
        data: Data,
        metadata: DraftMetadata = DraftMetadata(),
        checkpointVersion: Int = 1
    ) {
        self.draftId = draftId
        self.draftType = draftType
        self.principalId = principalId
        self.deviceId = deviceId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.state = state
        self.data = data
        self.metadata = metadata
        self.checkpointVersion = checkpointVersion
    }
}

/// Draft metadata
public struct DraftMetadata: Sendable, Codable {
    public var title: String?
    public var description: String?
    public var relatedEntityId: EntityId?
    public var module: String?
    public var formPath: String?
    public var autoSaveInterval: TimeInterval
    public var retentionDays: Int

    public init(
        title: String? = nil,
        description: String? = nil,
        relatedEntityId: EntityId? = nil,
        module: String? = nil,
        formPath: String? = nil,
        autoSaveInterval: TimeInterval = 30,
        retentionDays: Int = 30
    ) {
        self.title = title
        self.description = description
        self.relatedEntityId = relatedEntityId
        self.module = module
        self.formPath = formPath
        self.autoSaveInterval = autoSaveInterval
        self.retentionDays = retentionDays
    }
}

// MARK: - Workflow Checkpoint

/// Checkpoint for multi-step workflows
public struct WorkflowCheckpoint: Sendable, Codable {
    public let checkpointId: UUID
    public let workflowType: String
    public let principalId: String
    public let currentStep: Int
    public let totalSteps: Int
    public let stepData: [Int: Data]
    public let startedAt: Date
    public var lastStepAt: Date
    public var state: WorkflowCheckpointState
    public var clientVersion: SemanticVersion?

    public init(
        checkpointId: UUID = UUID(),
        workflowType: String,
        principalId: String,
        currentStep: Int = 0,
        totalSteps: Int,
        stepData: [Int: Data] = [:],
        startedAt: Date = Date(),
        lastStepAt: Date = Date(),
        state: WorkflowCheckpointState = .inProgress,
        clientVersion: SemanticVersion? = nil
    ) {
        self.checkpointId = checkpointId
        self.workflowType = workflowType
        self.principalId = principalId
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.stepData = stepData
        self.startedAt = startedAt
        self.lastStepAt = lastStepAt
        self.state = state
        self.clientVersion = clientVersion
    }

    /// Progress as percentage
    public var progress: Double {
        guard totalSteps > 0 else { return 0 }
        return Double(currentStep) / Double(totalSteps)
    }

    /// Check if workflow spans a version change
    public func crossesVersion(_ newVersion: SemanticVersion) -> Bool {
        guard let started = clientVersion else { return false }
        return started < newVersion
    }
}

/// Workflow checkpoint state
public enum WorkflowCheckpointState: String, Sendable, Codable {
    case inProgress
    case paused
    case completed
    case failed
    case abandoned
    case requiresReview  // Needs review after version change
}

// MARK: - Checkpoint Component

/// ECS Component for workflow checkpoints
public struct WorkflowCheckpointComponent: Component {
    public var checkpoint: WorkflowCheckpoint
    public var validationErrors: [String]
    public var canResume: Bool

    public init(checkpoint: WorkflowCheckpoint, validationErrors: [String] = [], canResume: Bool = true) {
        self.checkpoint = checkpoint
        self.validationErrors = validationErrors
        self.canResume = canResume
    }
}

// MARK: - Checkpoint Service

/// Service for managing drafts and checkpoints
public actor CheckpointService {
    private var drafts: [UUID: DraftComponent] = [:]
    private var checkpoints: [UUID: WorkflowCheckpoint] = [:]
    private let retentionDays: Int

    public init(retentionDays: Int = 30) {
        self.retentionDays = retentionDays
    }

    // MARK: - Draft Management

    /// Create a new draft
    public func createDraft(
        type: String,
        principalId: String,
        deviceId: String? = nil,
        data: Data,
        metadata: DraftMetadata = DraftMetadata()
    ) -> DraftComponent {
        let draft = DraftComponent(
            draftType: type,
            principalId: principalId,
            deviceId: deviceId,
            data: data,
            metadata: metadata
        )
        drafts[draft.draftId] = draft
        return draft
    }

    /// Update draft data
    public func updateDraft(
        draftId: UUID,
        data: Data
    ) -> DraftComponent? {
        guard var draft = drafts[draftId] else { return nil }
        draft.data = data
        draft.updatedAt = Date()
        draft.checkpointVersion += 1
        drafts[draftId] = draft
        return draft
    }

    /// Get draft by ID
    public func getDraft(_ draftId: UUID) -> DraftComponent? {
        return drafts[draftId]
    }

    /// Get all drafts for a principal
    public func getDrafts(forPrincipal principalId: String) -> [DraftComponent] {
        return drafts.values.filter { $0.principalId == principalId && $0.state == .active }
    }

    /// Get drafts by type
    public func getDrafts(ofType type: String) -> [DraftComponent] {
        return drafts.values.filter { $0.draftType == type && $0.state == .active }
    }

    /// Submit draft (convert to real entity)
    public func submitDraft(_ draftId: UUID) -> DraftComponent? {
        guard var draft = drafts[draftId] else { return nil }
        draft.state = .submitted
        draft.updatedAt = Date()
        drafts[draftId] = draft
        return draft
    }

    /// Abandon draft
    public func abandonDraft(_ draftId: UUID) -> DraftComponent? {
        guard var draft = drafts[draftId] else { return nil }
        draft.state = .abandoned
        draft.updatedAt = Date()
        drafts[draftId] = draft
        return draft
    }

    // MARK: - Workflow Checkpoints

    /// Create workflow checkpoint
    public func createCheckpoint(
        workflowType: String,
        principalId: String,
        totalSteps: Int,
        clientVersion: SemanticVersion? = nil
    ) -> WorkflowCheckpoint {
        let checkpoint = WorkflowCheckpoint(
            workflowType: workflowType,
            principalId: principalId,
            totalSteps: totalSteps,
            clientVersion: clientVersion
        )
        checkpoints[checkpoint.checkpointId] = checkpoint
        return checkpoint
    }

    /// Update checkpoint step
    public func updateCheckpoint(
        checkpointId: UUID,
        step: Int,
        stepData: Data
    ) -> WorkflowCheckpoint? {
        guard var checkpoint = checkpoints[checkpointId] else { return nil }
        var newStepData = checkpoint.stepData
        newStepData[step] = stepData
        checkpoint = WorkflowCheckpoint(
            checkpointId: checkpoint.checkpointId,
            workflowType: checkpoint.workflowType,
            principalId: checkpoint.principalId,
            currentStep: step,
            totalSteps: checkpoint.totalSteps,
            stepData: newStepData,
            startedAt: checkpoint.startedAt,
            lastStepAt: Date(),
            state: checkpoint.state,
            clientVersion: checkpoint.clientVersion
        )
        checkpoints[checkpointId] = checkpoint
        return checkpoint
    }

    /// Get checkpoint
    public func getCheckpoint(_ checkpointId: UUID) -> WorkflowCheckpoint? {
        return checkpoints[checkpointId]
    }

    /// Get checkpoints for principal
    public func getCheckpoints(forPrincipal principalId: String) -> [WorkflowCheckpoint] {
        return checkpoints.values.filter {
            $0.principalId == principalId && $0.state == .inProgress
        }
    }

    /// Pause checkpoint for update
    public func pauseCheckpoint(_ checkpointId: UUID) -> WorkflowCheckpoint? {
        guard var checkpoint = checkpoints[checkpointId] else { return nil }
        checkpoint = WorkflowCheckpoint(
            checkpointId: checkpoint.checkpointId,
            workflowType: checkpoint.workflowType,
            principalId: checkpoint.principalId,
            currentStep: checkpoint.currentStep,
            totalSteps: checkpoint.totalSteps,
            stepData: checkpoint.stepData,
            startedAt: checkpoint.startedAt,
            lastStepAt: Date(),
            state: .paused,
            clientVersion: checkpoint.clientVersion
        )
        checkpoints[checkpointId] = checkpoint
        return checkpoint
    }

    /// Mark checkpoint for review after version change
    public func markForReview(_ checkpointId: UUID, newVersion: SemanticVersion) -> WorkflowCheckpoint? {
        guard var checkpoint = checkpoints[checkpointId] else { return nil }

        // Only mark if it crosses version boundary
        guard checkpoint.crossesVersion(newVersion) else {
            return checkpoint
        }

        checkpoint = WorkflowCheckpoint(
            checkpointId: checkpoint.checkpointId,
            workflowType: checkpoint.workflowType,
            principalId: checkpoint.principalId,
            currentStep: checkpoint.currentStep,
            totalSteps: checkpoint.totalSteps,
            stepData: checkpoint.stepData,
            startedAt: checkpoint.startedAt,
            lastStepAt: Date(),
            state: .requiresReview,
            clientVersion: checkpoint.clientVersion
        )
        checkpoints[checkpointId] = checkpoint
        return checkpoint
    }

    /// Complete checkpoint
    public func completeCheckpoint(_ checkpointId: UUID) -> WorkflowCheckpoint? {
        guard var checkpoint = checkpoints[checkpointId] else { return nil }
        checkpoint = WorkflowCheckpoint(
            checkpointId: checkpoint.checkpointId,
            workflowType: checkpoint.workflowType,
            principalId: checkpoint.principalId,
            currentStep: checkpoint.totalSteps,
            totalSteps: checkpoint.totalSteps,
            stepData: checkpoint.stepData,
            startedAt: checkpoint.startedAt,
            lastStepAt: Date(),
            state: .completed,
            clientVersion: checkpoint.clientVersion
        )
        checkpoints[checkpointId] = checkpoint
        return checkpoint
    }

    // MARK: - Bulk Operations

    /// Trigger checkpoint sweep before update
    public func checkpointSweep(forPrincipal principalId: String? = nil) -> CheckpointSweepResult {
        var result = CheckpointSweepResult()

        // Save all active drafts
        for (id, draft) in drafts {
            if draft.state == .active {
                if principalId == nil || draft.principalId == principalId {
                    var updated = draft
                    updated.state = .saved
                    updated.updatedAt = Date()
                    drafts[id] = updated
                    result.draftsSaved += 1
                }
            }
        }

        // Pause all in-progress checkpoints
        for (id, checkpoint) in checkpoints {
            if checkpoint.state == .inProgress {
                if principalId == nil || checkpoint.principalId == principalId {
                    let paused = WorkflowCheckpoint(
                        checkpointId: checkpoint.checkpointId,
                        workflowType: checkpoint.workflowType,
                        principalId: checkpoint.principalId,
                        currentStep: checkpoint.currentStep,
                        totalSteps: checkpoint.totalSteps,
                        stepData: checkpoint.stepData,
                        startedAt: checkpoint.startedAt,
                        lastStepAt: Date(),
                        state: .paused,
                        clientVersion: checkpoint.clientVersion
                    )
                    checkpoints[id] = paused
                    result.checkpointsPaused += 1
                }
            }
        }

        result.sweepTime = Date()
        return result
    }

    /// Clean up expired drafts
    public func cleanupExpired() -> Int {
        let now = Date()
        var cleaned = 0

        for (id, draft) in drafts {
            let expirationDate = draft.createdAt.addingTimeInterval(TimeInterval(draft.metadata.retentionDays * 86400))
            if now > expirationDate && draft.state != .submitted {
                var expired = draft
                expired.state = .expired
                drafts[id] = expired
                cleaned += 1
            }
        }

        return cleaned
    }

    // MARK: - Statistics

    /// Get checkpoint statistics
    public func getStatistics() -> CheckpointStatistics {
        var stats = CheckpointStatistics()

        for draft in drafts.values {
            switch draft.state {
            case .active: stats.activeDrafts += 1
            case .saved: stats.savedDrafts += 1
            case .submitted: stats.submittedDrafts += 1
            case .abandoned: stats.abandonedDrafts += 1
            case .expired: stats.expiredDrafts += 1
            }
        }

        for checkpoint in checkpoints.values {
            switch checkpoint.state {
            case .inProgress: stats.inProgressWorkflows += 1
            case .paused: stats.pausedWorkflows += 1
            case .completed: stats.completedWorkflows += 1
            case .failed: stats.failedWorkflows += 1
            case .abandoned: stats.abandonedWorkflows += 1
            case .requiresReview: stats.reviewRequiredWorkflows += 1
            }
        }

        return stats
    }
}

// MARK: - Result Types

/// Result of checkpoint sweep
public struct CheckpointSweepResult: Sendable {
    public var draftsSaved: Int = 0
    public var checkpointsPaused: Int = 0
    public var sweepTime = Date()
}

/// Checkpoint statistics
public struct CheckpointStatistics: Sendable {
    public var activeDrafts: Int = 0
    public var savedDrafts: Int = 0
    public var submittedDrafts: Int = 0
    public var abandonedDrafts: Int = 0
    public var expiredDrafts: Int = 0

    public var inProgressWorkflows: Int = 0
    public var pausedWorkflows: Int = 0
    public var completedWorkflows: Int = 0
    public var failedWorkflows: Int = 0
    public var abandonedWorkflows: Int = 0
    public var reviewRequiredWorkflows: Int = 0

    public var totalDrafts: Int {
        activeDrafts + savedDrafts + submittedDrafts + abandonedDrafts + expiredDrafts
    }

    public var totalWorkflows: Int {
        inProgressWorkflows + pausedWorkflows + completedWorkflows + failedWorkflows + abandonedWorkflows + reviewRequiredWorkflows
    }
}
