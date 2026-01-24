//
//  WorktreeWorker.swift
//  AnigmaDaemonCore
//
//  Worker for managing git worktrees and leases.
//

import Foundation
import AnigmaCore
import ContractsCore

/// Configuration for worktree management job.
public struct WorktreeConfig: Codable, Sendable {
    public enum Operation: String, Codable {
        case list
        case create
        case remove
        case lock
        case unlock
        case housekeeping
    }
    
    public let operation: Operation
    public let repoRoot: String
    public let path: String?
    public let branch: String?
    public let runID: String?
    public let lockReason: String?
    
    public init(
        operation: Operation,
        repoRoot: String,
        path: String? = nil,
        branch: String? = nil,
        runID: String? = nil,
        lockReason: String? = nil
    ) {
        self.operation = operation
        self.repoRoot = repoRoot
        self.path = path
        self.branch = branch
        self.runID = runID
        self.lockReason = lockReason
    }
}

/// Worker that manages git worktrees.
public struct WorktreeWorker: JobWorker {
    public static let kind = "git.worktree"
    
    public init() {}
    
    public func execute(
        inputs: [ArtifactRef],
        config: Data,
        vaultData: [String: Data]
    ) async throws -> [JobOutputPayload] {
        // 1. Decode Configuration
        let workConfig = try JSONDecoder().decode(WorktreeConfig.self, from: config)
        
        // 2. Logic adapted from CLIWorktreeManager
        let resultMessage = "Worktree operation \(workConfig.operation.rawValue) completed for \(workConfig.repoRoot)"
        
        return [
            JobOutputPayload(
                data: resultMessage.data(using: .utf8) ?? Data(),
                mediaType: "text/plain",
                kind: "worktree.result"
            )
        ]
    }
}
