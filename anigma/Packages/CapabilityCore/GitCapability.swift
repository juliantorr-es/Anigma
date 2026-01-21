//
//  GitCapability.swift
//  CapabilityCore
//
//  [Brief description of file purpose]
//

import Foundation

/// Capability for Git operations.
public protocol GitCapability: Capability {
    /// Clones a repository to a local path.
    func clone(url: URL, to localPath: URL) async throws

    /// Fetches updates from a remote.
    func fetch(repoPath: URL) async throws

    /// Gets the current status of the workspace.
    func status(repoPath: URL) async throws -> String

    /// Commits changes to the repository.
    func commit(repoPath: URL, message: String) async throws -> String

    /// Pushes changes to a remote.
    func push(repoPath: URL) async throws
}

extension GitCapability {
    public static var capabilityId: String { CapabilityIds.git }
}
