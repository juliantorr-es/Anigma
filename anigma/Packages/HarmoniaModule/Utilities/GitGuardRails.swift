//
//  GitGuardRails.swift
//  HarmoniaModule
//
//  [Brief description of file purpose]
//

import DatabaseCore
//
//  GitGuardRails.swift
//  HarmoniaModule/Utilities
//
//  Git safety checks for automated code transformations.
//  Prevents running dangerous operations on dirty repos or main branches.
//

@preconcurrency import Foundation

/// Git safety checks for automated code transformations.
public struct GitGuardRails {

    /// Check if git repository is in a safe state for automated changes.
    /// - Parameter repoPath: Path to git repository (defaults to current directory)
    /// - Returns: Tuple with (isSafe: Bool, reason: String)
    public static func checkRepositorySafety(repoPath: String = FileManager.default.currentDirectoryPath) -> (isSafe: Bool, reason: String) {
        // 1. Check if we're in a git repository
        guard isGitRepository(at: repoPath) else {
            return (false, "Not a git repository: \(repoPath)")
        }

        // 2. Check if repository is dirty (has uncommitted changes)
        if let dirtyStatus = getGitStatus(repoPath: repoPath), !dirtyStatus.isEmpty {
            return (false, "Repository has uncommitted changes. Commit or stash them first.")
        }

        // 3. Check current branch
        guard let currentBranch = getCurrentBranch(repoPath: repoPath) else {
            return (false, "Could not determine current git branch")
        }

        // 4. Check if we're on a protected branch
        if isProtectedBranch(currentBranch) {
            return (false, "Cannot run automated changes on protected branch: \(currentBranch)")
        }

        // 5. Check if we're on a feature branch (contains feature/, fix/, etc.)
        if !isFeatureBranch(currentBranch) {
            return (false, "Not on a feature branch: \(currentBranch). Create a feature branch first.")
        }

        return (true, "Repository is safe for automated changes")
    }

    /// Check if path is a git repository.
    private static func isGitRepository(at path: String) -> Bool {
        let gitDir = URL(fileURLWithPath: path).appendingPathComponent(".git").path
        return FileManager.default.fileExists(atPath: gitDir)
    }

    /// Get git status output.
    private static func getGitStatus(repoPath: String) -> String? {
        return runGitCommand(["status", "--porcelain"], repoPath: repoPath)
    }

    /// Get current git branch.
    private static func getCurrentBranch(repoPath: String) -> String? {
        return runGitCommand(["branch", "--show-current"], repoPath: repoPath)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Check if branch is protected (main, master, develop, etc.)
    private static func isProtectedBranch(_ branch: String) -> Bool {
        let protectedBranches = ["main", "master", "develop", "trunk", "production"]
        return protectedBranches.contains(branch)
    }

    /// Check if branch is a feature branch.
    private static func isFeatureBranch(_ branch: String) -> Bool {
        let featurePatterns = ["feature/", "fix/", "bugfix/", "hotfix/", "refactor/", "chore/"]
        return featurePatterns.contains { branch.hasPrefix($0) }
    }

    /// Run a git command and return output.
    private static func runGitCommand(_ args: [String], repoPath: String) -> String? {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: repoPath)
        process.standardOutput = pipe
        process.standardError = Pipe() // Ignore stderr

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    /// Create a backup branch before making automated changes.
    /// - Parameters:
    ///   - baseBranch: Base branch name
    ///   - suffix: Suffix for backup branch
    ///   - repoPath: Repository path
    /// - Returns: Backup branch name if successful, nil otherwise
    public static func createBackupBranch(from baseBranch: String, suffix: String = "backup", repoPath: String = FileManager.default.currentDirectoryPath) -> String? {
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: ".", with: "-")
        let backupBranch = "\(baseBranch)-\(suffix)-\(timestamp)"

        // Create and checkout backup branch
        if runGitCommand(["checkout", "-b", backupBranch], repoPath: repoPath) != nil {
            return backupBranch
        }
        return nil
    }

    /// Get list of modified files from git status.
    public static func getModifiedFiles(repoPath: String = FileManager.default.currentDirectoryPath) -> [String] {
        guard let statusOutput = getGitStatus(repoPath: repoPath) else {
            return []
        }

        return statusOutput
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .compactMap { line in
                // Git status format: XY filename
                // Where X is staging status, Y is working tree status
                let components = line.components(separatedBy: .whitespaces)
                guard components.count >= 2 else { return nil }
                return components.last
            }
    }
}
