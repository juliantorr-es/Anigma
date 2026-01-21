//
//  CLIWorktreeManager.swift
//  AnigmaCLIDatabase
//
//  Git worktree lifecycle management with lease tracking.
//  Implements safe worktree operations with approval gates.
//

import Foundation

/// Git worktree manager with lease tracking and safety gates.
public actor CLIWorktreeManager {
    private let db: CLIDatabaseActor
    private let gitBinaryPath: String

    public init(database: CLIDatabaseActor, gitBinaryPath: String = "/usr/bin/git") {
        self.db = database
        self.gitBinaryPath = gitBinaryPath
    }

    // MARK: - Worktree Operations

    /// List all worktrees in a repository.
    public func listWorktrees(repoRoot: String) async throws -> [WorktreeInfo] {
        let output = try await runGitCommand(
            args: ["worktree", "list", "--porcelain"],
            workingDirectory: repoRoot
        )

        return parseWorktreeList(output)
    }

    /// Create a new worktree with an associated lease.
    public func createWorktree(
        repoRoot: String,
        branch: String,
        path: String,
        runID: String?
    ) async throws -> WorktreeLease {
        // Create the worktree
        _ = try await runGitCommand(
            args: ["worktree", "add", path, branch],
            workingDirectory: repoRoot
        )

        // Get base commit
        let baseCommit = try await getHeadCommit(repoRoot: repoRoot)

        // Create lease
        let lease = try await createLease(
            worktreePath: path,
            repoRoot: repoRoot,
            baseCommit: baseCommit,
            branchName: branch,
            runID: runID
        )

        return lease
    }

    /// Remove a worktree with safety checks.
    public func removeWorktree(
        path: String,
        force: Bool = false,
        skipApproval: Bool = false
    ) async throws {
        // Get lease info
        guard let lease = try await getLease(path: path) else {
            throw WorktreeError.noLeaseFound(path)
        }

        // Safety checks
        if lease.locked {
            throw WorktreeError.worktreeLocked(path)
        }

        // Check merge status if not forcing
        if !force {
            let status = try await checkMergeStatus(lease: lease)

            if status == .unmerged, !skipApproval {
                throw WorktreeError.unmergedChanges(path)
            }
        }

        // Remove worktree
        let args = force ? ["worktree", "remove", "--force", path] : ["worktree", "remove", path]
        _ = try await runGitCommand(
            args: args,
            workingDirectory: lease.repoRoot
        )

        // Remove lease
        try await removeLease(path: path)
    }

    /// Lock a worktree to prevent removal.
    public func lockWorktree(path: String, reason: String) async throws {
        _ = try await db.execute("""
            UPDATE worktree_leases
            SET locked = 1, protected_reason = ?
            WHERE worktree_path = ?
            """, parameters: [
                .text(reason),
                .text(path)
            ])
    }

    /// Unlock a worktree.
    public func unlockWorktree(path: String) async throws {
        _ = try await db.execute("""
            UPDATE worktree_leases
            SET locked = 0, protected_reason = NULL
            WHERE worktree_path = ?
            """, parameters: [.text(path)])
    }

    // MARK: - Lease Management

    /// Get lease for a worktree.
    public func getLease(path: String) async throws -> WorktreeLease? {
        let rows = try await db.query("""
            SELECT * FROM worktree_leases WHERE worktree_path = ?
            """, parameters: [.text(path)])

        guard let row = rows.first else { return nil }
        return try decodeLease(row)
    }

    /// List all leases.
    public func listLeases(repoRoot: String? = nil) async throws -> [WorktreeLease] {
        let sql: String
        let params: [CLIParameter]

        if let repoRoot {
            sql = "SELECT * FROM worktree_leases WHERE repo_root = ? ORDER BY created_at DESC"
            params = [.text(repoRoot)]
        } else {
            sql = "SELECT * FROM worktree_leases ORDER BY created_at DESC"
            params = []
        }

        let rows = try await db.query(sql, parameters: params)
        return try rows.map { try decodeLease($0) }
    }

    /// Update lease last used time.
    public func touchLease(path: String) async throws {
        _ = try await db.execute("""
            UPDATE worktree_leases
            SET last_used_at = ?
            WHERE worktree_path = ?
            """, parameters: [
                .double(Date().timeIntervalSince1970),
                .text(path)
            ])
    }

    // MARK: - Housekeeping

    /// Perform housekeeping: remove stale worktrees and clean up leases.
    public func housekeeping(
        repoRoot: String,
        dryRun: Bool = true,
        requireApproval: Bool = true
    ) async throws -> HousekeepingResult {
        var removed: [String] = []
        var kept: [String] = []
        var errors: [(String, Error)] = []

        // Get all leases for this repo
        let leases = try await listLeases(repoRoot: repoRoot)

        for lease in leases {
            // Skip locked worktrees
            if lease.locked {
                kept.append(lease.worktreePath)
                continue
            }

            // Check if worktree still exists
            let exists = FileManager.default.fileExists(atPath: lease.worktreePath)

            if !exists {
                // Clean up orphaned lease
                if !dryRun {
                    try await removeLease(path: lease.worktreePath)
                }
                removed.append(lease.worktreePath)
                continue
            }

            // Check if stale (older than TTL)
            let age = Date().timeIntervalSince(
                Date(timeIntervalSince1970: lease.lastUsedAt)
            )

            if age > TimeInterval(lease.intendedTTL) {
                // Check merge status
                let status = try await checkMergeStatus(lease: lease)

                let canRemove: Bool
                if status == .merged {
                    canRemove = true
                } else if status == .unmerged, !requireApproval {
                    canRemove = true
                } else {
                    canRemove = false
                }

                if canRemove {
                    if !dryRun {
                        do {
                            try await removeWorktree(path: lease.worktreePath, force: false, skipApproval: true)
                            removed.append(lease.worktreePath)
                        } catch {
                            errors.append((lease.worktreePath, error))
                        }
                    } else {
                        removed.append(lease.worktreePath)
                    }
                } else {
                    kept.append(lease.worktreePath)
                }
            } else {
                kept.append(lease.worktreePath)
            }
        }

        return HousekeepingResult(
            removed: removed,
            kept: kept,
            errors: errors,
            dryRun: dryRun
        )
    }

    // MARK: - Private Helpers

    private func createLease(
        worktreePath: String,
        repoRoot: String,
        baseCommit: String,
        branchName: String,
        runID: String?
    ) async throws -> WorktreeLease {
        let leaseID = UUID().uuidString
        let now = Date().timeIntervalSince1970

        _ = try await db.execute("""
            INSERT INTO worktree_leases (
                lease_id, worktree_path, repo_root, base_commit, branch_name,
                run_id, created_at, last_used_at, intended_ttl_seconds,
                locked, merged_status, removal_eligibility
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, parameters: [
                .text(leaseID),
                .text(worktreePath),
                .text(repoRoot),
                .text(baseCommit),
                .text(branchName),
                runID.map { .text($0) } ?? .null,
                .double(now),
                .double(now),
                .int(259200), // 72 hours default
                .int(0),
                .text(MergeStatus.unknown.rawValue),
                .text(RemovalEligibility.safe.rawValue)
            ])

        return WorktreeLease(
            leaseID: leaseID,
            worktreePath: worktreePath,
            repoRoot: repoRoot,
            baseCommit: baseCommit,
            branchName: branchName,
            runID: runID,
            createdAt: now,
            lastUsedAt: now,
            intendedTTL: 259200,
            locked: false,
            protectedReason: nil,
            mergedStatus: .unknown,
            removalEligibility: .safe
        )
    }

    private func removeLease(path: String) async throws {
        _ = try await db.execute("""
            DELETE FROM worktree_leases WHERE worktree_path = ?
            """, parameters: [.text(path)])
    }

    private func checkMergeStatus(lease: WorktreeLease) async throws -> MergeStatus {
        guard let branchName = lease.branchName else {
            return .unknown
        }

        // Check if branch exists in remote
        do {
            let branches = try await runGitCommand(
                args: ["branch", "-r", "--merged", branchName],
                workingDirectory: lease.repoRoot
            )

            return branches.contains(branchName) ? .merged : .unmerged
        } catch {
            return .unknown
        }
    }

    private func getHeadCommit(repoRoot: String) async throws -> String {
        let output = try await runGitCommand(
            args: ["rev-parse", "HEAD"],
            workingDirectory: repoRoot
        )

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseWorktreeList(_ output: String) -> [WorktreeInfo] {
        var worktrees: [WorktreeInfo] = []
        var currentWorktree: [String: String] = [:]

        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                // End of worktree entry
                if let info = buildWorktreeInfo(currentWorktree) {
                    worktrees.append(info)
                }
                currentWorktree = [:]
                continue
            }

            // Parse "label value" format
            let components = trimmed.split(separator: " ", maxSplits: 1)
            if components.count == 2 {
                let key = String(components[0])
                let value = String(components[1])
                currentWorktree[key] = value
            }
        }

        // Handle last entry
        if let info = buildWorktreeInfo(currentWorktree) {
            worktrees.append(info)
        }

        return worktrees
    }

    private func buildWorktreeInfo(_ data: [String: String]) -> WorktreeInfo? {
        guard let path = data["worktree"] else { return nil }

        return WorktreeInfo(
            path: path,
            head: data["HEAD"],
            branch: data["branch"],
            bare: data["bare"] == "1",
            detached: data["detached"] != nil,
            locked: data["locked"] != nil,
            prunable: data["prunable"] != nil
        )
    }

    private func decodeLease(_ row: CLIRow) throws -> WorktreeLease {
        guard let leaseID = row["lease_id"]?.asString,
              let worktreePath = row["worktree_path"]?.asString,
              let repoRoot = row["repo_root"]?.asString,
              let createdAt = row["created_at"]?.asDouble,
              let lastUsedAt = row["last_used_at"]?.asDouble,
              let ttl = row["intended_ttl_seconds"]?.asInt,
              let locked = row["locked"]?.asInt else {
            throw WorktreeError.invalidLeaseData
        }

        return WorktreeLease(
            leaseID: leaseID,
            worktreePath: worktreePath,
            repoRoot: repoRoot,
            baseCommit: row["base_commit"]?.asString,
            branchName: row["branch_name"]?.asString,
            runID: row["run_id"]?.asString,
            createdAt: createdAt,
            lastUsedAt: lastUsedAt,
            intendedTTL: ttl,
            locked: locked != 0,
            protectedReason: row["protected_reason"]?.asString,
            mergedStatus: MergeStatus(rawValue: row["merged_status"]?.asString ?? "") ?? .unknown,
            removalEligibility: RemovalEligibility(rawValue: row["removal_eligibility"]?.asString ?? "") ?? .safe
        )
    }

    private func runGitCommand(args: [String], workingDirectory: String) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gitBinaryPath)
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)

        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw WorktreeError.gitCommandFailed(args.joined(separator: " "), errorMsg)
        }

        return String(data: data, encoding: .utf8) ?? ""
    }
}

// MARK: - Supporting Types

public struct WorktreeInfo: Sendable {
    public let path: String
    public let head: String?
    public let branch: String?
    public let bare: Bool
    public let detached: Bool
    public let locked: Bool
    public let prunable: Bool
}

public struct WorktreeLease: Sendable {
    public let leaseID: String
    public let worktreePath: String
    public let repoRoot: String
    public let baseCommit: String?
    public let branchName: String?
    public let runID: String?
    public let createdAt: TimeInterval
    public let lastUsedAt: TimeInterval
    public let intendedTTL: Int
    public let locked: Bool
    public let protectedReason: String?
    public let mergedStatus: MergeStatus
    public let removalEligibility: RemovalEligibility
}

public enum MergeStatus: String, Sendable {
    case unknown
    case merged
    case unmerged
}

public enum RemovalEligibility: String, Sendable {
    case safe
    case approvalRequired = "approval-required"
    case forbidden
}

public struct HousekeepingResult: Sendable {
    public let removed: [String]
    public let kept: [String]
    public let errors: [(String, Error)]
    public let dryRun: Bool
}

public enum WorktreeError: Error, Sendable {
    case gitCommandFailed(String, String)
    case noLeaseFound(String)
    case worktreeLocked(String)
    case unmergedChanges(String)
    case invalidLeaseData
}
