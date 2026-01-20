//
//  WorktreeCommand.swift
//  AnigmaCLIExecutable
//
//  Worktree lifecycle management commands.
//

import AnigmaCLICore
import AnigmaCLIDatabase
import ArgumentParser
import Foundation

struct AnigmaWorktreeCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "worktree",
            abstract: "Manage Git worktrees with lease tracking.",
            subcommands: [
                WorktreeListCommand.self,
                WorktreeCreateCommand.self,
                WorktreeRemoveCommand.self,
                WorktreeLockCommand.self,
                WorktreeUnlockCommand.self,
                WorktreeCleanCommand.self
            ]
        )
    }
}

// MARK: - Worktree List

struct WorktreeListCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "list",
            abstract: "List all worktrees with lease information."
        )
    }

    @Option(name: .long, help: "Repository root path.")
    var repoRoot: String = FileManager.default.currentDirectoryPath

    @Flag(name: .long, help: "Show detailed information.")
    var verbose: Bool = false

    @OptionGroup var output: OutputOptions

    mutating func run() async throws {
        let config = CLIDatabaseConfig()
        let db = CLIDatabaseActor(config: config)
        try await db.open()
        defer { db.close() }

        let manager = CLIWorktreeManager(database: db)

        // Get worktrees from git
        let worktrees = try await manager.listWorktrees(repoRoot: repoRoot)

        // Get leases
        let leases = try await manager.listLeases(repoRoot: repoRoot)
        let leasesByPath = Dictionary(uniqueKeysWithValues: leases.map { ($0.worktreePath, $0) })

        if worktrees.isEmpty {
            print("No worktrees found in \(repoRoot)")
            return
        }

        print("📁 Worktrees in \(repoRoot):\n")

        for worktree in worktrees {
            let lease = leasesByPath[worktree.path]

            var status: [String] = []
            if worktree.bare { status.append("bare") }
            if worktree.detached { status.append("detached") }
            if worktree.locked { status.append("locked") }
            if worktree.prunable { status.append("prunable") }
            if lease?.locked == true { status.append("lease-locked") }

            let statusStr = status.isEmpty ? "" : " [\(status.joined(separator: ", "))]"

            print("  \(worktree.path)\(statusStr)")

            if verbose {
                if let branch = worktree.branch {
                    print("    Branch: \(branch)")
                }
                if let head = worktree.head {
                    print("    HEAD: \(head)")
                }
                if let lease {
                    let age = Date().timeIntervalSince(Date(timeIntervalSince1970: lease.lastUsedAt))
                    let ageStr = formatDuration(age)
                    print("    Lease: \(lease.leaseID)")
                    print("    Last used: \(ageStr) ago")
                    print("    TTL: \(lease.intendedTTL)s")
                    if let reason = lease.protectedReason {
                        print("    Protected: \(reason)")
                    }
                }
                print("")
            }
        }

        // Show leases without worktrees (orphaned)
        let worktreePaths = Set(worktrees.map { $0.path })
        let orphaned = leases.filter { !worktreePaths.contains($0.worktreePath) }

        if !orphaned.isEmpty {
            print("\n⚠️  Orphaned leases (worktree removed):")
            for lease in orphaned {
                print("  \(lease.worktreePath)")
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours > 24 {
            return "\(hours / 24)d"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Worktree Create

struct WorktreeCreateCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "create",
            abstract: "Create a new worktree with lease tracking."
        )
    }

    @Argument(help: "Branch name to create worktree for.")
    var branch: String

    @Option(name: .long, help: "Path for the new worktree.")
    var path: String?

    @Option(name: .long, help: "Repository root path.")
    var repoRoot: String = FileManager.default.currentDirectoryPath

    @Option(name: .long, help: "Run ID to associate with this worktree.")
    var runID: String?

    mutating func run() async throws {
        let config = CLIDatabaseConfig()
        let db = CLIDatabaseActor(config: config)
        try await db.open()
        defer { db.close() }

        let manager = CLIWorktreeManager(database: db)

        // Generate path if not provided
        let worktreePath = path ?? generateWorktreePath(repoRoot: repoRoot, branch: branch)

        print("Creating worktree for branch '\(branch)' at \(worktreePath)...")

        let lease = try await manager.createWorktree(
            repoRoot: repoRoot,
            branch: branch,
            path: worktreePath,
            runID: runID
        )

        print("✅ Worktree created with lease \(lease.leaseID)")
        print("   Path: \(lease.worktreePath)")
        print("   Branch: \(lease.branchName ?? "unknown")")
        print("   TTL: \(lease.intendedTTL)s (\(lease.intendedTTL / 3600)h)")
    }

    private func generateWorktreePath(repoRoot: String, branch: String) -> String {
        let sanitized = branch.replacingOccurrences(of: "/", with: "-")
        let timestamp = Int(Date().timeIntervalSince1970)
        return "\(repoRoot)/.anigma/worktrees/\(sanitized)-\(timestamp)"
    }
}

// MARK: - Worktree Remove

struct WorktreeRemoveCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "remove",
            abstract: "Remove a worktree (with safety checks)."
        )
    }

    @Argument(help: "Path to the worktree to remove.")
    var path: String

    @Flag(name: .long, help: "Force removal even if unmerged.")
    var force: Bool = false

    @Flag(name: .long, help: "Skip approval prompts.")
    var yes: Bool = false

    mutating func run() async throws {
        let config = CLIDatabaseConfig()
        let db = CLIDatabaseActor(config: config)
        try await db.open()
        defer { db.close() }

        let manager = CLIWorktreeManager(database: db)

        print("Removing worktree at \(path)...")

        do {
            try await manager.removeWorktree(path: path, force: force, skipApproval: yes)
            print("✅ Worktree removed successfully")
        } catch WorktreeError.worktreeLocked(let path) {
            print("❌ Cannot remove: worktree is locked (\(path))")
            print("   Use 'worktree unlock' first")
            throw ExitCode.failure
        } catch WorktreeError.unmergedChanges(let path) {
            print("⚠️  Worktree has unmerged changes: \(path)")
            print("   Use --force to remove anyway, or merge the changes first")
            throw ExitCode.failure
        } catch {
            print("❌ Failed to remove worktree: \(error)")
            throw ExitCode.failure
        }
    }
}

// MARK: - Worktree Lock

struct WorktreeLockCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "lock",
            abstract: "Lock a worktree to prevent removal."
        )
    }

    @Argument(help: "Path to the worktree to lock.")
    var path: String

    @Option(name: .long, help: "Reason for locking.")
    var reason: String = "Manual lock"

    mutating func run() async throws {
        let config = CLIDatabaseConfig()
        let db = CLIDatabaseActor(config: config)
        try await db.open()
        defer { db.close() }

        let manager = CLIWorktreeManager(database: db)

        try await manager.lockWorktree(path: path, reason: reason)
        print("🔒 Locked worktree: \(path)")
        print("   Reason: \(reason)")
    }
}

// MARK: - Worktree Unlock

struct WorktreeUnlockCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "unlock",
            abstract: "Unlock a worktree."
        )
    }

    @Argument(help: "Path to the worktree to unlock.")
    var path: String

    mutating func run() async throws {
        let config = CLIDatabaseConfig()
        let db = CLIDatabaseActor(config: config)
        try await db.open()
        defer { db.close() }

        let manager = CLIWorktreeManager(database: db)

        try await manager.unlockWorktree(path: path)
        print("🔓 Unlocked worktree: \(path)")
    }
}

// MARK: - Worktree Clean

struct WorktreeCleanCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "clean",
            abstract: "Clean up stale worktrees (housekeeping)."
        )
    }

    @Option(name: .long, help: "Repository root path.")
    var repoRoot: String = FileManager.default.currentDirectoryPath

    @Flag(name: .long, help: "Actually perform cleanup (default is dry-run).")
    var execute: Bool = false

    @Flag(name: .long, help: "Allow removal of unmerged worktrees.")
    var force: Bool = false

    mutating func run() async throws {
        let config = CLIDatabaseConfig()
        let db = CLIDatabaseActor(config: config)
        try await db.open()
        defer { db.close() }

        let manager = CLIWorktreeManager(database: db)

        let mode = execute ? "EXECUTE" : "DRY-RUN"
        print("🧹 Housekeeping (\(mode)) for \(repoRoot)...\n")

        let result = try await manager.housekeeping(
            repoRoot: repoRoot,
            dryRun: !execute,
            requireApproval: !force
        )

        if !result.removed.isEmpty {
            print("Would remove (\(result.removed.count)):")
            for path in result.removed {
                print("  ❌ \(path)")
            }
            print("")
        }

        if !result.kept.isEmpty {
            print("Keeping (\(result.kept.count)):")
            for path in result.kept {
                print("  ✅ \(path)")
            }
            print("")
        }

        if !result.errors.isEmpty {
            print("Errors (\(result.errors.count)):")
            for (path, error) in result.errors {
                print("  ⚠️  \(path): \(error)")
            }
            print("")
        }

        if result.dryRun {
            print("ℹ️  This was a dry-run. Use --execute to perform cleanup.")
        } else {
            print("✅ Housekeeping complete!")
        }
    }
}
