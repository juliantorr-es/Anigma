//  WorkspaceStore.swift
//  AnigmaAppMac
//
//  Manages repository workspaces, file selection, and change sets.
//  Extracted from AppStore for focused responsibility and testability.
//

import Foundation
import Observation
import AnigmaClientKit
import Combine

@MainActor
@Observable
final class WorkspaceStore {

    // MARK: - Properties

    /// Repository workspaces (local git repositories)
    var repoWorkspaces: [RepoWorkspace] = []

    /// Currently active workspace ID (if any)
    var activeWorkspaceID: UUID?

    /// Selected file URL within active workspace
    var selectedFileURL: URL?

    /// Change sets (staged changes) for active workspace
    var changeSets: [ChangeSet] = []

    /// Selected change set ID (for diff viewing)
    var selectedChangeSetID: UUID?

    /// Current project in workbench (if any)
    var currentProject: WorkbenchProject?

    // MARK: - Remote Workspace Properties

    /// Remote workspace summaries (from server)
    var workspaces: [WorkspaceSummary] = []

    /// Cursor for paginating remote workspaces
    private(set) var workspacesCursor: String?

    /// Whether more remote workspaces can be loaded
    var hasMoreWorkspaces: Bool = false

    /// Selected remote workspace ID (derived from sidebar selection)
    var selectedWorkspaceID: WorkspaceID? {
        // Injected from AppStore via property forwarding
        // This is a computed property that should be set by AppStore
        _selectedWorkspaceID
    }
    
    /// Backing storage for selectedWorkspaceID
    private var _selectedWorkspaceID: WorkspaceID?

    /// Artifacts cursor for pagination
    private(set) var artifactsCursor: String?

    /// Jobs cursor for pagination
    private(set) var jobsCursor: String?

    /// Whether more artifacts can be loaded
    var hasMoreArtifacts: Bool = false

    /// Whether more jobs can be loaded
    var hasMoreJobs: Bool = false

    /// Artifacts for current workspace
    var artifacts: [ArtifactSummary] = [] {
        didSet {
            onArtifactsChanged?()
        }
    }

    /// Jobs for current workspace
    var jobs: [JobSummary] = [] {
        didSet {
            onJobsChanged?()
        }
    }

    // MARK: - Computed Properties

    /// Active workspace (computed from activeWorkspaceID)
    var activeWorkspace: RepoWorkspace? {
        repoWorkspaces.first { $0.id == activeWorkspaceID }
    }

    /// Develop workbench tab (editor, search, etc.)
    var developWorkbenchTab: DevelopWorkbenchTab = .editor

    // MARK: - Dependencies (Injected)

    /// Anigma client for remote workspace operations
    var client: AnigmaClientKit.AnigmaClient?

    /// Workspace service for local repository operations
    var workspaceService: WorkspaceService = .shared

    /// Callback for showing toasts (injected from AppStore)
    var showToast: (String, String, String) -> Void = { _, _, _ in }

    /// Callback for showing errors (injected from AppStore)
    var showError: (String) -> Void = { _ in }

    /// Callback for logging network activity (injected from AppStore)
    var logNetworkActivity: (String, String, String, String) -> Void = { _, _, _, _ in }

    /// Callback when artifacts change (injected from AppStore)
    var onArtifactsChanged: (() -> Void)?

    /// Callback when jobs change (injected from AppStore)
    var onJobsChanged: (() -> Void)?

    // MARK: - Initialization

    init() {
        // Dependencies will be injected later
    }

    // MARK: - Workspace Management

    /// Open a local git repository and return the workspace
    func openLocalRepository(at url: URL) async throws -> RepoWorkspace {
        var workspace = try await workspaceService.loadWorkspace(at: url)

        // Create playground sandbox
        if let sandboxURL = try? await workspaceService.ensureSandbox(for: workspace) {
            workspace.sandboxURL = sandboxURL
        }

        repoWorkspaces.append(workspace)
        activeWorkspaceID = workspace.id
        return workspace
    }

    /// Load remote workspaces from server
    func loadWorkspaces() async {
        guard let client = client else { return }
        do {
            let page = try await client.query.listWorkspaces(cursor: nil, limit: 50)
            workspaces = page.items
            workspacesCursor = page.cursor
            hasMoreWorkspaces = page.cursor != nil
        } catch {
            print("Error loading workspaces: \(error)")
        }
    }

    /// Select a remote workspace and load its data
    func selectWorkspace(_ id: WorkspaceID) async {
        guard id != _selectedWorkspaceID else { return }
        _selectedWorkspaceID = id
        await loadWorkspaceData(id: id)
    }

    /// Create a new remote workspace
    func createWorkspace(name: String = "New Workspace") async {
        guard let client = client else { return }
        do {
            let workspaceId = try await client.command.createWorkspace(name: name)
            await loadWorkspaces()
            await selectWorkspace(workspaceId)
        } catch {
            print("Error creating workspace: \(error)")
        }
    }

    /// Update a remote workspace name
    func updateWorkspace(id: WorkspaceID, name: String) async {
        guard let client = client else { return }
        do {
            try await client.command.updateWorkspace(id: id, name: name)
            await loadWorkspaces()
        } catch {
            print("Error updating workspace: \(error)")
        }
    }

    /// Delete a remote workspace
    func deleteWorkspace(id: WorkspaceID) async {
        guard let client = client else { return }
        do {
            try await client.command.deleteWorkspace(id: id)
            await loadWorkspaces()
        } catch {
            print("Error deleting workspace: \(error)")
        }
    }

    /// Load more remote workspaces (pagination)
    func loadMoreWorkspaces() async {
        guard let client = client, let cursor = workspacesCursor else { return }
        do {
            let page = try await client.query.listWorkspaces(cursor: cursor, limit: 50)
            workspaces.append(contentsOf: page.items)
            workspacesCursor = page.cursor
            hasMoreWorkspaces = page.cursor != nil
        } catch {
            print("Error loading more workspaces: \(error)")
        }
    }

    /// Load data for a specific remote workspace (artifacts, jobs)
    private func loadWorkspaceData(id: WorkspaceID) async {
        guard let client = client else { return }
        do {
            // Load artifacts
            let artifactsPage = try await client.query.listArtifacts(workspaceID: id, cursor: nil, limit: 50)
            artifacts = artifactsPage.items
            artifactsCursor = artifactsPage.cursor
            hasMoreArtifacts = artifactsPage.cursor != nil

            // Load jobs
            let jobsPage = try await client.query.listJobs(workspaceID: id, cursor: nil, limit: 50)
            jobs = jobsPage.items
            jobsCursor = jobsPage.cursor
            hasMoreJobs = jobsPage.cursor != nil
        } catch {
            print("Error loading workspace data: \(error)")
        }
    }

    /// Refresh jobs for current workspace
    private func refreshJobs(workspaceId: WorkspaceID) async {
        guard let client = client else { return }
        do {
            _ = try await client.query.listJobs(workspaceID: workspaceId, cursor: nil, limit: 50)
            // TODO: Update jobs store
        } catch {
            print("Error refreshing jobs: \(error)")
        }
    }
}