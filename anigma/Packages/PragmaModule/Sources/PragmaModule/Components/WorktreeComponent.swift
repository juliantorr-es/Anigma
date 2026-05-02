import AnigmaPrimitives

import AnigmaPrimitives

//
//  WorktreeComponent.swift
//  PragmaModule
//
//  Component representing a worktree linked to an attempt.
//

import Foundation
import AnigmaCore

/// Component representing a worktree linked to an attempt.
public struct WorktreeComponent: Component, Codable, Identifiable, Sendable {
    /// Worktree identifier (logical ID, not a filesystem path).
    public let id: String

    /// Attempt this worktree is attached to.
    public let attemptId: AttemptId

    /// Base ref for the worktree.
    public let baseRef: String

    /// Base commit SHA for the worktree.
    public let baseCommit: String

    /// Display name for UI presentation.
    public let displayName: String

    /// When the worktree was attached.
    public let createdAt: Date

    public init(
        id: String,
        attemptId: AttemptId,
        baseRef: String,
        baseCommit: String,
        displayName: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.attemptId = attemptId
        self.baseRef = baseRef
        self.baseCommit = baseCommit
        self.displayName = displayName
        self.createdAt = createdAt
    }
}
