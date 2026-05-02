//
//  GitProbe.swift
//  PraxisModule
//
//  [Brief description of file purpose]
//

import Foundation

public struct GitProbe: Sendable, Codable {
    public let repoRoot: String
    public let worktreePath: String
    public let branch: String
    public let headSHA: String
    public let isDetached: Bool
    public let isClean: Bool
    public let originURL: String?
    public let worktrees: [String]

    public init(
        repoRoot: String,
        worktreePath: String,
        branch: String,
        headSHA: String,
        isDetached: Bool,
        isClean: Bool,
        originURL: String?,
        worktrees: [String]
    ) {
        self.repoRoot = repoRoot
        self.worktreePath = worktreePath
        self.branch = branch
        self.headSHA = headSHA
        self.isDetached = isDetached
        self.isClean = isClean
        self.originURL = originURL
        self.worktrees = worktrees
    }
}

public protocol GitProbing: Sendable {
    func probe(cwd: URL) throws -> GitProbe
}

public enum RepoIdentityGateFailure: String, Sendable, Codable {
    case notAGitRepo
    case repoRootNotAllowed
    case worktreePathRejected
    case detachedHEADRejected
    case branchNotAllowed
    case dirtyWorkingTreeRejected
    case originURLRejected
}
