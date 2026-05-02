import AnigmaPrimitives

import AnigmaPrimitives

//
//  AttemptComponent.swift
//  PragmaModule
//
//  Component representing an agent attempt for a work item.
//

import Foundation
import AnigmaCore
import ContractsCore

/// Component representing an agent attempt for a work item.
public struct AttemptComponent: Component, Codable, Identifiable, Sendable {
    /// Unique attempt identifier.
    public let id: AttemptId
    public var identifiableId: UUID { id.raw }

    /// Work item the attempt belongs to.
    public let taskId: WorkItemId

    /// Executor profile used for this attempt.
    public let executorProfileId: String

    /// Base ref used when starting the attempt.
    public let baseRef: String?

    /// Base commit used when starting the attempt.
    public let baseCommit: String?

    /// Current attempt status.
    public var status: AttemptStatus

    /// When the attempt was created.
    public let createdAt: Date

    /// When the attempt started.
    public var startedAt: Date?

    /// When the attempt completed.
    public var completedAt: Date?

    /// Receipts produced by governed intent handling.
    public var receipts: [ReceiptRef]

    /// Diff summary artifact reference (if any).
    public var diffSummaryArtifactId: ArtifactId?

    public init(
        id: AttemptId = AttemptId(),
        taskId: WorkItemId,
        executorProfileId: String,
        baseRef: String? = nil,
        baseCommit: String? = nil,
        status: AttemptStatus = .pending,
        createdAt: Date = Date(),
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        receipts: [ReceiptRef] = [],
        diffSummaryArtifactId: ArtifactId? = nil
    ) {
        self.id = id
        self.taskId = taskId
        self.executorProfileId = executorProfileId
        self.baseRef = baseRef
        self.baseCommit = baseCommit
        self.status = status
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.receipts = receipts
        self.diffSummaryArtifactId = diffSummaryArtifactId
    }
}

extension AttemptComponent {
    /// Returns a copy with an updated status and timestamps.
    public func withStatus(_ status: AttemptStatus, completedAt: Date? = nil) -> AttemptComponent {
        var copy = self
        copy.status = status
        if let completedAt {
            copy.completedAt = completedAt
        }
        return copy
    }

    /// Returns a copy with a receipt appended.
    public func appendingReceipt(_ receipt: ReceiptRef) -> AttemptComponent {
        var copy = self
        copy.receipts.append(receipt)
        return copy
    }

    /// Returns a copy with a diff summary artifact reference.
    public func withDiffSummary(_ artifactId: ArtifactId) -> AttemptComponent {
        var copy = self
        copy.diffSummaryArtifactId = artifactId
        return copy
    }
}
