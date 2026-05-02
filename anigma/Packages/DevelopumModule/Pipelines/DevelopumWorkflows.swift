//
//  DevelopumWorkflows.swift
//  DevelopumModule
//
//  Workflows for Develop mode job processing.
//  Connects job types to system execution sequences.
//

import AnigmaCore
import Foundation
import CryptoKit

// MARK: - Open File Workflow

/// Workflow for opening a file in the editor.
///
/// Pipeline: FileRead → ContentLoad → EditorDisplay
public struct OpenFileWorkflow: Workflow {
    public var name: String { "Open File" }
    public var jobTypeId: String { OpenFileJobType.identifier }
    public var systemNames: [String] { ["DevelopumEditorSystem"] }
    
    private let databaseService: DevelopumDatabaseService
    
    public init(databaseService: DevelopumDatabaseService) {
        self.databaseService = databaseService
    }
    
    public func prepare(job: Job, world: World) async throws {
        guard let repoIdString = job.metadata["repoId"],
              let repoId = UUID(uuidString: repoIdString),
              let repo = try? await databaseService.getRepoRecord(id: repoId) else {
            throw WorkflowError.executionFailed(
                workflow: name,
                error: "Repository session not found"
            )
        }
        
        guard let filePath = job.metadata["filePath"] else {
            throw WorkflowError.executionFailed(
                workflow: name,
                error: "Missing filePath in job metadata"
            )
        }
        
        let fullPath = "\(repo.repoPath)/\(filePath)"
        guard FileManager.default.fileExists(atPath: fullPath) else {
            throw WorkflowError.executionFailed(
                workflow: name,
                error: "File not found: \(fullPath)"
            )
        }
        
        logInfo("Opening file: \(filePath)", category: "OpenFileWorkflow")
    }
    
    public func finalize(job: Job, world: World, result: JobResult) async throws {
        guard let filePath = job.metadata["filePath"] else { return }
        
        switch result.outcome {
        case .success:
            logInfo("File opened successfully: \(filePath)", category: "OpenFileWorkflow")
        case .error:
            logError("Failed to open file: \(filePath)", category: "OpenFileWorkflow")
        default:
            break
        }
    }
}

// MARK: - Save File Workflow

/// Workflow for saving a file from the editor.
///
/// Pipeline: ContentHash → ArtifactStore → WorkingTreeMirror → CoreReceipt
public struct SaveFileWorkflow: Workflow {
    public var name: String { "Save File" }
    public var jobTypeId: String { SaveFileJobType.identifier }
    public var systemNames: [String] { ["DevelopumEditorSystem"] }
    
    private let databaseService: DevelopumDatabaseService
    
    public init(databaseService: DevelopumDatabaseService) {
        self.databaseService = databaseService
    }
    
    public func prepare(job: Job, world: World) async throws {
        guard let repoIdString = job.metadata["repoId"],
              let repoId = UUID(uuidString: repoIdString),
              let _ = try? await databaseService.getRepoRecord(id: repoId) else {
            throw WorkflowError.executionFailed(
                workflow: name,
                error: "Repository session not found"
            )
        }
        
        guard let filePath = job.metadata["filePath"] else {
            throw WorkflowError.executionFailed(
                workflow: name,
                error: "Missing filePath in job metadata"
            )
        }
        
        guard let contentHash = job.metadata["contentHash"] else {
            throw WorkflowError.executionFailed(
                workflow: name,
                error: "Missing contentHash in job metadata"
            )
        }
        
        logInfo("Preparing to save file: \(filePath) (hash: \(contentHash))", category: "SaveFileWorkflow")
    }
    
    public func finalize(job: Job, world: World, result: JobResult) async throws {
        guard let filePath = job.metadata["filePath"] else { return }
        
        switch result.outcome {
        case .success:
            logInfo("File saved successfully: \(filePath)", category: "SaveFileWorkflow")
        case .error:
            logError("Failed to save file: \(filePath)", category: "SaveFileWorkflow")
        default:
            break
        }
    }
}

// MARK: - Search Files Workflow

/// Workflow for searching files in the repository.
///
/// Pipeline: IndexQuery → ResultAggregation → Display
public struct SearchFilesWorkflow: Workflow {
    public var name: String { "Search Files" }
    public var jobTypeId: String { SearchFilesJobType.identifier }
    public var systemNames: [String] { ["DevelopumEditorSystem", "DevelopumIndexSystem"] }
    
    private let databaseService: DevelopumDatabaseService
    
    public init(databaseService: DevelopumDatabaseService) {
        self.databaseService = databaseService
    }
    
    public func prepare(job: Job, world: World) async throws {
        guard let repoIdString = job.metadata["repoId"],
              let repoId = UUID(uuidString: repoIdString),
              let _ = try? await databaseService.getRepoRecord(id: repoId) else {
            throw WorkflowError.executionFailed(
                workflow: name,
                error: "Repository session not found"
            )
        }
        
        guard let query = job.metadata["query"], !query.isEmpty else {
            throw WorkflowError.executionFailed(
                workflow: name,
                error: "Search query cannot be empty"
            )
        }
        
        logInfo("Searching for: \(query)", category: "SearchFilesWorkflow")
    }
    
    public func finalize(job: Job, world: World, result: JobResult) async throws {
        guard let query = job.metadata["query"] else { return }
        
        switch result.outcome {
        case .success:
            logInfo("Search completed: '\(query)' (\(result.actionsApplied) actions)", category: "SearchFilesWorkflow")
        case .error:
            logError("Search failed for query: \(query)", category: "SearchFilesWorkflow")
        default:
            break
        }
    }
}

// MARK: - Index File Workflow

/// Workflow for indexing a file or directory.
///
/// Pipeline: FileRead → IndexGeneration → ArtifactStore
public struct IndexFileWorkflow: Workflow {
    public var name: String { "Index File" }
    public var jobTypeId: String { IndexFileJobType.identifier }
    public var systemNames: [String] { ["DevelopumIndexSystem"] }
    
    private let databaseService: DevelopumDatabaseService
    
    public init(databaseService: DevelopumDatabaseService) {
        self.databaseService = databaseService
    }
    
    public func prepare(job: Job, world: World) async throws {
        guard let repoIdString = job.metadata["repoId"],
              let repoId = UUID(uuidString: repoIdString),
              let repo = try? await databaseService.getRepoRecord(id: repoId) else {
            throw WorkflowError.executionFailed(
                workflow: name,
                error: "Repository session not found"
            )
        }
        
        guard let filePath = job.metadata["filePath"] else {
            throw WorkflowError.executionFailed(
                workflow: name,
                error: "Missing filePath in job metadata"
            )
        }
        
        let fullPath = "\(repo.repoPath)/\(filePath)"
        guard FileManager.default.fileExists(atPath: fullPath) else {
            throw WorkflowError.executionFailed(
                workflow: name,
                error: "File not found: \(fullPath)"
            )
        }
        
        logInfo("Preparing to index: \(filePath)", category: "IndexFileWorkflow")
    }
    
    public func finalize(job: Job, world: World, result: JobResult) async throws {
        guard let filePath = job.metadata["filePath"] else { return }
        
        switch result.outcome {
        case .success:
            logInfo("Indexing completed: \(filePath)", category: "IndexFileWorkflow")
        case .error:
            logError("Indexing failed: \(filePath)", category: "IndexFileWorkflow")
        default:
            break
        }
    }
}

// MARK: - Create Repo Session Workflow

/// Workflow for creating a repository session.
///
/// Pipeline: RepoValidation → SessionCreation → DatabaseRecord
public struct CreateRepoSessionWorkflow: Workflow {
    public var name: String { "Create Repository Session" }
    public var jobTypeId: String { CreateRepoSessionJobType.identifier }
    public var systemNames: [String] { ["DevelopumEditorSystem"] }
    
    private let databaseService: DevelopumDatabaseService
    
    public init(databaseService: DevelopumDatabaseService) {
        self.databaseService = databaseService
    }
    
    public func prepare(job: Job, world: World) async throws {
        guard let repoPath = job.metadata["repoPath"] else {
            throw WorkflowError.executionFailed(
                workflow: name,
                error: "Missing repoPath in job metadata"
            )
        }
        
        guard FileManager.default.fileExists(atPath: repoPath) else {
            throw WorkflowError.executionFailed(
                workflow: name,
                error: "Repository path does not exist: \(repoPath)"
            )
        }
        
        logInfo("Creating repository session: \(repoPath)", category: "CreateRepoSessionWorkflow")
        
        let record = RepoRecord(
            repoPath: repoPath,
            remoteUrl: job.metadata["remoteUrl"],
            currentBranch: "main",
            headSha: "",
            createdAt: Date(),
            lastActivityAt: Date(),
            isActive: true,
            workspaceConfig: job.metadata["workspaceConfig"],
            metadata: job.metadata["metadata"]
        )
        
        try await databaseService.createRepoRecord(record)
    }
    
    public func finalize(job: Job, world: World, result: JobResult) async throws {
        guard let repoPath = job.metadata["repoPath"] else { return }
        
        switch result.outcome {
        case .success:
            logInfo("Repository session created: \(repoPath)", category: "CreateRepoSessionWorkflow")
        case .error:
            logError("Failed to create repository session: \(repoPath)", category: "CreateRepoSessionWorkflow")
        default:
            break
        }
    }
}

// MARK: - Close Repo Session Workflow

/// Workflow for closing a repository session.
///
/// Pipeline: SaveChanges → SessionDeactivation → StatePersistence
public struct CloseRepoSessionWorkflow: Workflow {
    public var name: String { "Close Repository Session" }
    public var jobTypeId: String { CloseRepoSessionJobType.identifier }
    public var systemNames: [String] { ["DevelopumEditorSystem"] }
    
    private let databaseService: DevelopumDatabaseService
    
    public init(databaseService: DevelopumDatabaseService) {
        self.databaseService = databaseService
    }
    
    public func prepare(job: Job, world: World) async throws {
        guard let repoIdString = job.metadata["repoId"],
              let repoId = UUID(uuidString: repoIdString) else {
            throw WorkflowError.executionFailed(
                workflow: name,
                error: "Invalid or missing repoId"
            )
        }
        
        guard let _ = try? await databaseService.getRepoRecord(id: repoId) else {
            throw WorkflowError.executionFailed(
                workflow: name,
                error: "Repository session not found"
            )
        }
        
        let saveChanges = job.metadata["saveUnsavedChanges"] == "true"
        
        logInfo("Closing repository session: \(repoId)", category: "CloseRepoSessionWorkflow")
        
        if saveChanges {
            logInfo("Saving unsaved changes before closing", category: "CloseRepoSessionWorkflow")
        }
        
        try await databaseService.deactivateRepoRecord(id: repoId)
    }
    
    public func finalize(job: Job, world: World, result: JobResult) async throws {
        guard let repoIdString = job.metadata["repoId"] else { return }
        
        switch result.outcome {
        case .success:
            logInfo("Repository session closed: \(repoIdString)", category: "CloseRepoSessionWorkflow")
        case .error:
            logError("Failed to close repository session: \(repoIdString)", category: "CloseRepoSessionWorkflow")
        default:
            break
        }
    }
}
