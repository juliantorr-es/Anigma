//
//  VaultConfiguration.swift
//  StorageCore
//
//  Default configuration for vault root paths.
//

import Foundation

/// Configuration helpers for resolving vault storage paths.
public enum VaultConfiguration {
    /// Returns the default vault root URL.
    /// Priority:
    /// 1. ANIGMA_VAULT_ROOT environment variable (if set)
    /// 2. Application Support directory (Anigma/Vault)
    /// 3. Repository root (Artifacts/vault)
    /// 4. Current directory (Artifacts/vault)
    public static func defaultVaultRoot() -> URL {
        if let envPath = ProcessInfo.processInfo.environment["ANIGMA_VAULT_ROOT"],
           !envPath.isEmpty {
            return absoluteURL(envPath)
        }

        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            return appSupport
                .appendingPathComponent("Anigma", isDirectory: true)
                .appendingPathComponent("Vault", isDirectory: true)
        }

        if let repoRoot = findRepositoryRoot() {
            return repoRoot
                .appendingPathComponent("Artifacts", isDirectory: true)
                .appendingPathComponent("vault", isDirectory: true)
        }

        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Artifacts", isDirectory: true)
            .appendingPathComponent("vault", isDirectory: true)
    }

    private static func absoluteURL(_ path: String) -> URL {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path)
        }
        let resolved = (FileManager.default.currentDirectoryPath as NSString).appendingPathComponent(path)
        return URL(fileURLWithPath: (resolved as NSString).standardizingPath)
    }

    private static func findRepositoryRoot() -> URL? {
        let fileManager = FileManager.default
        var currentDir = fileManager.currentDirectoryPath

        while true {
            let gitPath = (currentDir as NSString).appendingPathComponent(".git")
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: gitPath, isDirectory: &isDir), isDir.boolValue {
                return URL(fileURLWithPath: currentDir)
            }

            let parent = (currentDir as NSString).deletingLastPathComponent
            if parent == currentDir {
                break
            }
            currentDir = parent
        }

        return nil
    }
}
