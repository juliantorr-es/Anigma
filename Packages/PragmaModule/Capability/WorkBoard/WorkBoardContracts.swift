//
//  WorkBoardContracts.swift
//  PragmaModule
//
//  Work Board types for snapshot and intent handling.
//

import AnigmaPrimitives
import ContractsCore
import Foundation

/// Unique identifier for a work board attempt.
public struct AttemptId: Hashable, Sendable, Codable, CustomStringConvertible {
    public let raw: UUID

    public init() {
        self.raw = UUID()
    }

    public init(raw: UUID) {
        self.raw = raw
    }

    public var description: String {
        "Attempt(\(raw.uuidString.prefix(8)))"
    }
}

/// Unique identifier for a work board artifact.
public struct ArtifactId: Hashable, Sendable, Codable, CustomStringConvertible {
    public let raw: UUID

    public init() {
        self.raw = UUID()
    }

    public init(raw: UUID) {
        self.raw = raw
    }

    public var description: String {
        "Artifact(\(raw.uuidString.prefix(8)))"
    }
}

/// Status of an attempt lifecycle.
public enum AttemptStatus: String, Sendable, Codable {
    case pending = "pending"
    case running = "running"
    case inReview = "in_review"
    case merged = "merged"
    case failed = "failed"
    case cancelled = "cancelled"
    case quarantined = "quarantined"

    /// Whether the status is terminal.
    public var isTerminal: Bool {
        switch self {
        case .merged, .failed, .cancelled, .quarantined:
            return true
        case .pending, .running, .inReview:
            return false
        }
    }
}

/// Kind of artifact produced by an attempt.
public enum ArtifactKind: String, Sendable, Codable {
    case receipt = "receipt"
    case log = "log"
    case diff = "diff"
    case diffSummary = "diff_summary"
    case patch = "patch"
    case evidence = "evidence"
}

/// Worktree reference for renderers.
public struct WorktreeRef: Sendable, Codable {
    public let id: String
    public let baseRef: String
    public let baseCommit: String
    public let displayName: String

    public init(id: String, baseRef: String, baseCommit: String, displayName: String) {
        self.id = id
        self.baseRef = baseRef
        self.baseCommit = baseCommit
        self.displayName = displayName
    }
}

/// Scope for work board snapshot queries.
public struct WorkBoardScope: Sendable, Codable, Equatable {
    public let projectId: WorkItemId?
    public let taskIds: [WorkItemId]?
    public let includeArchived: Bool

    public init(
        projectId: WorkItemId? = nil,
        taskIds: [WorkItemId]? = nil,
        includeArchived: Bool = false
    ) {
        self.projectId = projectId
        self.taskIds = taskIds
        self.includeArchived = includeArchived
    }
}

/// Snapshot of work board state for renderers.
public struct WorkBoardSnapshot: Sendable, Codable {
    public let snapshotId: String
    public let generatedAt: Date
    public let scope: WorkBoardScope
    public let projects: [WorkBoardProject]
    public let tasks: [WorkBoardTask]
    public let attempts: [WorkBoardAttempt]
    public let artifacts: [WorkBoardArtifact]
    public let reviewThreads: [WorkBoardReviewThread]
    public let columns: [WorkBoardColumn]

    public init(
        snapshotId: String,
        generatedAt: Date,
        scope: WorkBoardScope,
        projects: [WorkBoardProject],
        tasks: [WorkBoardTask],
        attempts: [WorkBoardAttempt],
        artifacts: [WorkBoardArtifact],
        reviewThreads: [WorkBoardReviewThread],
        columns: [WorkBoardColumn]
    ) {
        self.snapshotId = snapshotId
        self.generatedAt = generatedAt
        self.scope = scope
        self.projects = projects
        self.tasks = tasks
        self.attempts = attempts
        self.artifacts = artifacts
        self.reviewThreads = reviewThreads
        self.columns = columns
    }
}

/// Project projection for work board snapshots.
public struct WorkBoardProject: Sendable, Codable {
    public let id: WorkItemId
    public let keyPrefix: String
    public let name: String
    public let status: ProjectStatus

    public init(id: WorkItemId, keyPrefix: String, name: String, status: ProjectStatus) {
        self.id = id
        self.keyPrefix = keyPrefix
        self.name = name
        self.status = status
    }
}

/// Task projection for work board snapshots.
public struct WorkBoardTask: Sendable, Codable {
    public let id: WorkItemId
    public let key: String
    public let title: String
    public let statusId: String
    public let priority: WorkPriority
    public let latestAttemptId: AttemptId?

    public init(
        id: WorkItemId,
        key: String,
        title: String,
        statusId: String,
        priority: WorkPriority,
        latestAttemptId: AttemptId?
    ) {
        self.id = id
        self.key = key
        self.title = title
        self.statusId = statusId
        self.priority = priority
        self.latestAttemptId = latestAttemptId
    }
}

/// Attempt projection for work board snapshots.
public struct WorkBoardAttempt: Sendable, Codable {
    public let id: AttemptId
    public let taskId: WorkItemId
    public let executorProfileId: String
    public let status: AttemptStatus
    public let worktree: WorktreeRef?
    public let startedAt: Date?
    public let completedAt: Date?
    public let receipts: [ReceiptRef]
    public let diffSummaryArtifactId: ArtifactId?

    public init(
        id: AttemptId,
        taskId: WorkItemId,
        executorProfileId: String,
        status: AttemptStatus,
        worktree: WorktreeRef?,
        startedAt: Date?,
        completedAt: Date?,
        receipts: [ReceiptRef],
        diffSummaryArtifactId: ArtifactId?
    ) {
        self.id = id
        self.taskId = taskId
        self.executorProfileId = executorProfileId
        self.status = status
        self.worktree = worktree
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.receipts = receipts
        self.diffSummaryArtifactId = diffSummaryArtifactId
    }
}

/// Artifact projection for work board snapshots.
public struct WorkBoardArtifact: Sendable, Codable {
    public let id: ArtifactId
    public let attemptId: AttemptId
    public let kind: ArtifactKind
    public let uri: String
    public let sha256: String
    public let summary: String?

    public init(
        id: ArtifactId,
        attemptId: AttemptId,
        kind: ArtifactKind,
        uri: String,
        sha256: String,
        summary: String?
    ) {
        self.id = id
        self.attemptId = attemptId
        self.kind = kind
        self.uri = uri
        self.sha256 = sha256
        self.summary = summary
    }
}

/// Review thread for an attempt.
public struct WorkBoardReviewThread: Sendable, Codable {
    public let attemptId: AttemptId
    public let comments: [WorkBoardReviewComment]

    public init(attemptId: AttemptId, comments: [WorkBoardReviewComment]) {
        self.attemptId = attemptId
        self.comments = comments
    }
}

/// Review comment projection.
public struct WorkBoardReviewComment: Sendable, Codable {
    public let id: UUID
    public let attemptId: AttemptId
    public let authorId: String
    public let body: String
    public let filePath: String?
    public let line: Int?
    public let createdAt: Date

    public init(
        id: UUID,
        attemptId: AttemptId,
        authorId: String,
        body: String,
        filePath: String?,
        line: Int?,
        createdAt: Date
    ) {
        self.id = id
        self.attemptId = attemptId
        self.authorId = authorId
        self.body = body
        self.filePath = filePath
        self.line = line
        self.createdAt = createdAt
    }
}

/// Column grouping for attempt status.
public struct WorkBoardColumn: Sendable, Codable {
    public let status: AttemptStatus
    public let attemptIds: [AttemptId]

    public init(status: AttemptStatus, attemptIds: [AttemptId]) {
        self.status = status
        self.attemptIds = attemptIds
    }
}

/// Intent envelope for work board mutations.
public struct WorkBoardIntent: Sendable, Codable {
    public let header: ActionIntent.Header
    public let action: WorkBoardAction
    public let parameters: [String: BindingValue]

    public init(header: ActionIntent.Header, action: WorkBoardAction, parameters: [String: BindingValue]) {
        self.header = header
        self.action = action
        self.parameters = parameters
    }
}

/// Work board action identifiers.
public enum WorkBoardAction: String, Sendable, Codable {
    case createTask = "create_task"
    case startAttempt = "start_attempt"
    case attachWorktree = "attach_worktree"
    case recordOutput = "record_output"
    case submitReviewComment = "submit_review_comment"
    case requestRerun = "request_rerun"
    case mergeAttempt = "merge_attempt"
    case cancelAttempt = "cancel_attempt"
}

/// Result of a work board intent.
public struct WorkBoardIntentResult: Sendable, Codable {
    public let receipt: ReceiptRef
    public let snapshotId: String
    public let status: Receipt.Status
    public let message: String?

    public init(
        receipt: ReceiptRef,
        snapshotId: String,
        status: Receipt.Status,
        message: String?
    ) {
        self.receipt = receipt
        self.snapshotId = snapshotId
        self.status = status
        self.message = message
    }
}

/// Errors for work board operations.
public enum WorkBoardError: Error, LocalizedError, Sendable {
    case accessDenied(reason: String)
    case staleSnapshot(expected: String, actual: String)
    case invalidTransition(from: AttemptStatus, to: AttemptStatus)
    case attemptNotFound(AttemptId)
    case taskNotFound(WorkItemId)
    case projectNotFound(WorkItemId)
    case worktreeUnavailable(id: String)
    case governanceViolation(code: String, message: String)
    case invalidParameters(message: String)

    public var errorDescription: String? {
        switch self {
        case .accessDenied(let reason):
            return "Access denied: \(reason)"
        case .staleSnapshot(let expected, let actual):
            return "Stale snapshot: expected \(expected), got \(actual)"
        case .invalidTransition(let from, let to):
            return "Invalid transition from \(from.rawValue) to \(to.rawValue)"
        case .attemptNotFound(let id):
            return "Attempt not found: \(id)"
        case .taskNotFound(let id):
            return "Task not found: \(id)"
        case .projectNotFound(let id):
            return "Project not found: \(id)"
        case .worktreeUnavailable(let id):
            return "Worktree unavailable: \(id)"
        case .governanceViolation(let code, let message):
            return "Governance violation (\(code)): \(message)"
        case .invalidParameters(let message):
            return "Invalid parameters: \(message)"
        }
    }
}
