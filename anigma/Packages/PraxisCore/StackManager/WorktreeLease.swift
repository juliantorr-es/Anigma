//
//  WorktreeLease.swift
//  PraxisCore
//
//  Model for git worktree leases.
//

import Foundation

public struct WorktreeLease: Codable, Sendable, Identifiable {
    public var id: String { worktreePath }
    public var worktreePath: String
    public var repoRoot: String
    public var baseCommit: String
    public var branchName: String
    public var runId: String?
    public var createdAt: Date
    public var lastUsedAt: Date
    public var intendedTTL: TimeInterval
    public var isLocked: Bool
    public var protectedReason: String?

    public init(
        worktreePath: String,
        repoRoot: String,
        baseCommit: String,
        branchName: String,
        runId: String? = nil,
        createdAt: Date = Date(),
        lastUsedAt: Date = Date(),
        intendedTTL: TimeInterval = 72 * 3600,
        isLocked: Bool = false,
        protectedReason: String? = nil
    ) {
        self.worktreePath = worktreePath
        self.repoRoot = repoRoot
        self.baseCommit = baseCommit
        self.branchName = branchName
        self.runId = runId
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.intendedTTL = intendedTTL
        self.isLocked = isLocked
        self.protectedReason = protectedReason
    }
}
