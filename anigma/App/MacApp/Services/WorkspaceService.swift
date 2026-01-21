import Foundation
import AnigmaClientKit

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
            // In a real app, this should be an async stream or separate actor task
            for case _ as URL in enumerator {
                fileCount += 1
                if fileCount > 5000 { break } // Cap at 5000 for initial scan
            }
            // Rough progress estimation based on file count cap
            indexingProgress = min(1.0, Double(fileCount) / 5000.0)
        }

        return RepoWorkspace(
            id: UUID(), // In a real app we might hash the path to get stable IDs
            name: name,
            rootURL: url,
            gitState: gitState,
            indexStatus: .discovery, // Placeholder
            indexingProgress: 0.0,
            includeRules: [],
            excludeRules: [],
            trustBoundary: .verify,
            sandboxURL: nil,
            networkPolicy: NetworkPolicy(stance: .offline), // Default safe
            resourceBudget: ResourceBudget()
        )
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
