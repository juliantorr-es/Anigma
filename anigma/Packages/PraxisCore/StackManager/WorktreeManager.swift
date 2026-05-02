//
//  WorktreeManager.swift
//  PraxisCore
//
//  Manages git worktree leases and housekeeping.
//

import Foundation

public enum WorktreeManagerError: Error, CustomStringConvertible, Sendable {
    case leaseNotFound(String)
    case leaseAlreadyExists(String)
    case worktreeDirectoryExists(String)

    public var description: String {
        switch self {
        case .leaseNotFound(let path): return "Lease not found for path: \(path)"
        case .leaseAlreadyExists(let path): return "Lease already exists for path: \(path)"
        case .worktreeDirectoryExists(let path): return "Directory already exists at path: \(path)"
        }
    }
}

public struct HousekeepingAction: Sendable, Codable {
    public let path: String
    public let action: String // "prune", "skip", "lock_protected", "error"
    public let reason: String

    public init(path: String, action: String, reason: String) {
        self.path = path
        self.action = action
        self.reason = reason
    }
}

public final class WorktreeManager: Sendable {
    public let repoRoot: URL

    public init(repoRoot: URL) {
        self.repoRoot = repoRoot
    }

    private func leasesFile() -> URL {
        repoRoot.appendingPathComponent(".anigma", isDirectory: true)
            .appendingPathComponent("worktrees", isDirectory: true)
            .appendingPathComponent("leases.json", isDirectory: false)
    }

    public func listLeases() throws -> [WorktreeLease] {
        let url = leasesFile()
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try dec.decode([WorktreeLease].self, from: data)
    }

    private func saveLeases(_ leases: [WorktreeLease]) throws {
        let url = leasesFile()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        enc.dateEncodingStrategy = .iso8601
        let data = try enc.encode(leases)
        try data.write(to: url, options: [.atomic])
    }

    public func createLease(
        branchName: String,
        baseCommit: String,
        runId: String?,
        ttl: TimeInterval = 72 * 3600,
        customPath: String? = nil
    ) throws -> WorktreeLease {
        let path: String
        if let customPath = customPath {
            path = customPath
        } else {
            let worktreesDir = repoRoot.appendingPathComponent(".opencode", isDirectory: true)
                .appendingPathComponent("worktrees", isDirectory: true)
            path = worktreesDir.appendingPathComponent(branchName).path
        }

        if FileManager.default.fileExists(atPath: path) {
            throw WorktreeManagerError.worktreeDirectoryExists(path)
        }

        var leases = try listLeases()
        if leases.contains(where: { $0.worktreePath == path }) {
            throw WorktreeManagerError.leaseAlreadyExists(path)
        }

        let lease = WorktreeLease(
            worktreePath: path,
            repoRoot: repoRoot.path,
            baseCommit: baseCommit,
            branchName: branchName,
            runId: runId,
            intendedTTL: ttl
        )

        leases.append(lease)
        try saveLeases(leases)
        return lease
    }

    public func removeLease(path: String) throws {
        var leases = try listLeases()
        leases.removeAll { $0.worktreePath == path }
        try saveLeases(leases)
    }

    public func lock(path: String, reason: String) throws {
        var leases = try listLeases()
        guard let idx = leases.firstIndex(where: { $0.worktreePath == path }) else {
            throw WorktreeManagerError.leaseNotFound(path)
        }
        leases[idx].isLocked = true
        leases[idx].protectedReason = reason
        try saveLeases(leases)
    }

    public func unlock(path: String) throws {
        var leases = try listLeases()
        guard let idx = leases.firstIndex(where: { $0.worktreePath == path }) else {
            throw WorktreeManagerError.leaseNotFound(path)
        }
        leases[idx].isLocked = false
        leases[idx].protectedReason = nil
        try saveLeases(leases)
    }

    public func housekeeping(dryRun: Bool, git: GitRunner) throws -> [HousekeepingAction] {
        let leases = try listLeases()
        var actions: [HousekeepingAction] = []
        var remainingLeases: [WorktreeLease] = []

        let now = Date()

        for lease in leases {
            if lease.isLocked {
                actions.append(HousekeepingAction(path: lease.worktreePath, action: "skip", reason: "Locked: \(lease.protectedReason ?? "")"))
                remainingLeases.append(lease)
                continue
            }

            let expiry = lease.createdAt.addingTimeInterval(lease.intendedTTL)
            if now > expiry {
                if dryRun {
                    actions.append(HousekeepingAction(path: lease.worktreePath, action: "prune", reason: "Expired"))
                    remainingLeases.append(lease)
                } else {
                    do {
                        let artifacts = ArtifactWriter(repoRoot: repoRoot)
                        let op = try git.worktreeRemove(lease.worktreePath, force: true, cwd: repoRoot, artifacts: artifacts)

                        if op.exitCode == 0 {
                            actions.append(HousekeepingAction(path: lease.worktreePath, action: "prune", reason: "Expired"))
                        } else {
                            actions.append(HousekeepingAction(path: lease.worktreePath, action: "error", reason: "git worktree remove failed: exit code \(op.exitCode)"))
                            remainingLeases.append(lease)
                        }
                    } catch {
                        actions.append(HousekeepingAction(path: lease.worktreePath, action: "error", reason: "Failed to remove: \(error)"))
                        remainingLeases.append(lease)
                    }
                }
            } else {
                remainingLeases.append(lease)
            }
        }

        if !dryRun {
            try saveLeases(remainingLeases)
        }

        return actions
    }
}
