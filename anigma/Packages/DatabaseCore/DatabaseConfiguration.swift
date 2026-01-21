//
//  DatabaseConfiguration.swift
//  DatabaseCore
//
//  Configuration for database paths and connection settings.
//  Provides a stable default database path that respects environment variables
//  and attempts to locate the repository root for consistent access.
//

import Foundation

public enum DatabaseConfiguration {
    /// Returns the default database path, resolved as an absolute path.
    /// Priority:
    /// 1. ANIGMA_DB_PATH environment variable (if set)
    /// 2. Repository‑root‑relative path (if inside a git repository)
    /// 3. Current‑directory‑relative path (expanded to absolute)
    public static func defaultDatabasePath() -> String {
        // 1. Environment variable
        if let envPath = ProcessInfo.processInfo.environment["ANIGMA_DB_PATH"],
           !envPath.isEmpty {
            return absolutePath(envPath)
        }

        // 2. Repository root detection
        if let repoRoot = findRepositoryRoot() {
            let repoPath = (repoRoot as NSString).appendingPathComponent("harmonia_harness.sqlite")
            return repoPath
        }

        // 3. Fallback to current directory
        return absolutePath("./harmonia_harness.sqlite")
    }

    /// Returns the absolute path of a given relative path.
    /// If the input is already absolute, it is returned unchanged.
    /// SQLite special names (e.g., ":memory:") are returned unchanged.
    private static func absolutePath(_ path: String) -> String {
        let fileManager = FileManager.default
        let currentDirectory = fileManager.currentDirectoryPath

        if path.hasPrefix("/") {
            return path
        }

        // SQLite special identifiers (":memory:", "file::memory:", etc.)
        if path.isEmpty || path.hasPrefix(":") {
            return path
        }

        let resolved = (currentDirectory as NSString).appendingPathComponent(path)
        // Normalize any ".." components
        return (resolved as NSString).standardizingPath
    }

    /// Walks up from the current directory looking for a `.git` directory.
    /// Returns the absolute path of the nearest git repository root, or nil.
    private static func findRepositoryRoot() -> String? {
        let fileManager = FileManager.default
        var currentDir = fileManager.currentDirectoryPath

        while true {
            let gitPath = (currentDir as NSString).appendingPathComponent(".git")
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: gitPath, isDirectory: &isDir), isDir.boolValue {
                return currentDir
            }

            let parent = (currentDir as NSString).deletingLastPathComponent
            if parent == currentDir {
                break // reached filesystem root
            }
            currentDir = parent
        }

        return nil
    }

    /// Prints the database path and detection logic to stderr (for debugging).
    public static func printDatabasePathInfo() {
        let env = ProcessInfo.processInfo.environment["ANIGMA_DB_PATH"]
        let repoRoot = findRepositoryRoot()
        let defaultPath = defaultDatabasePath()

        fputs("Database path resolution:\n", stderr)
        fputs("  ANIGMA_DB_PATH: \(env ?? "(not set)")\n", stderr)
        fputs("  Repository root: \(repoRoot ?? "(not a git repository)")\n", stderr)
        fputs("  Selected path: \(defaultPath)\n", stderr)
    }
}
