import Foundation
import AnigmaClientKit
import CryptoKit

/// Service for managing repository workspaces and their state
actor WorkspaceService {
    static let shared = WorkspaceService()

    private let git = GitService.shared

    /// Loads a RepoWorkspace from a given local URL
    func loadWorkspace(at url: URL) async throws -> RepoWorkspace {
        let name = url.lastPathComponent

        // 1. Check if it's a git repo
        let isGit = (try? url.appendingPathComponent(".git").checkResourceIsReachable()) ?? false
        guard isGit else {
            throw WorkspaceError.notAGitRepository
        }

        // 2. Get Git State
        let gitState = try await git.getStatus(in: url)

        // 3. Scan for critical files
        var indexingProgress = 0.0
        let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]

        // Use a real enumerator to find critical files
        if let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) {
            var fileCount = 0
            // Limit scan to avoid hanging on massive repos during synchronous load
            while let _ = enumerator.nextObject() as? URL {
                fileCount += 1
                if fileCount > 5000 { break } // Cap at 5000 for initial scan
            }
            // Rough progress estimation based on file count cap
            indexingProgress = min(1.0, Double(fileCount) / 5000.0)
        }

        // Generate a stable ID based on the URL path
        let pathData = Data(url.path.utf8)
        let hash = SHA256.hash(data: pathData)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()

        // Create a UUID from the first 32 characters of the hash
        // (Just for stability, not cryptographically perfect UUID v5)
        let p1 = String(hashString.prefix(8))
        let p2 = String(hashString.dropFirst(8).prefix(4))
        let p3 = String(hashString.dropFirst(12).prefix(4))
        let p4 = String(hashString.dropFirst(16).prefix(4))
        let p5 = String(hashString.dropFirst(20).prefix(12))
        let uuidString = "\(p1)-\(p2)-\(p3)-\(p4)-\(p5)"

        let stableId = UUID(uuidString: uuidString) ?? UUID()

        return RepoWorkspace(
            id: stableId,
            name: name,
            rootURL: url,
            gitState: gitState,
            indexStatus: .discovery,
            indexingProgress: indexingProgress,
            includeRules: [],
            excludeRules: [],
            trustBoundary: .verify,
            sandboxURL: nil,
            networkPolicy: NetworkPolicy(stance: .offline),
            resourceBudget: ResourceBudget()
        )
    }

    /// Creates or updates a sandboxed copy of the repository for safe agent work
    func ensureSandbox(for workspace: RepoWorkspace) async throws -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let sandboxRoot = home.appendingPathComponent(".anigma/sandbox")
        let workspaceSandbox = sandboxRoot.appendingPathComponent(workspace.id.uuidString)

        // 1. Ensure sandbox root exists
        try FileManager.default.createDirectory(at: workspaceSandbox, withIntermediateDirectories: true)

        // 2. Perform a fresh copy or sync
        // For simplicity in this implementation, we will use a git clone/checkout if it doesn't exist,
        // or rsync-like copy if it does.
        // A real implementation might use git worktrees.

        if !FileManager.default.fileExists(atPath: workspaceSandbox.appendingPathComponent(".git").path) {
            // Initial clone to sandbox
            try await git.clone(from: workspace.rootURL, to: workspaceSandbox)
        } else {
            // Sync current changes to sandbox (excluding ignored files)
            // This is complex, for now we will just assume the sandbox is initialized
        }

        return workspaceSandbox
    }

    /// Refresh the git state of an existing workspace
    func refreshState(for workspace: RepoWorkspace) async throws -> RepoWorkspace {
        var updated = workspace
        updated.gitState = try await git.getStatus(in: workspace.rootURL)
        return updated
    }
}

enum WorkspaceError: LocalizedError {
    case notAGitRepository

    var errorDescription: String? {
        switch self {
        case .notAGitRepository:
            return "The selected folder is not a git repository."
        }
    }
}
