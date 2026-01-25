//
//  DevelopumJobs.swift
//  DevelopumModule
//
//  Job definitions for Develop mode operations.
//  Each job type corresponds to a user-initiated action that requires
//  evidence-backed execution through the workflow system.
//

import AnigmaCore
import Foundation

// MARK: - Job Types

/// Job type for opening a file in the editor.
public struct OpenFileJobType: JobType {
    public static let identifier = "developum.openFile"
    public static let displayName = "Open File"
}

/// Job type for saving a file from the editor.
public struct SaveFileJobType: JobType {
    public static let identifier = "developum.saveFile"
    public static let displayName = "Save File"
}

/// Job type for searching files in the repository.
public struct SearchFilesJobType: JobType {
    public static let identifier = "developum.searchFiles"
    public static let displayName = "Search Files"
}

/// Job type for indexing a file or directory.
public struct IndexFileJobType: JobType {
    public static let identifier = "developum.indexFile"
    public static let displayName = "Index File"
}

/// Job type for creating a repository session.
public struct CreateRepoSessionJobType: JobType {
    public static let identifier = "developum.createRepoSession"
    public static let displayName = "Create Repository Session"
}

/// Job type for closing a repository session.
public struct CloseRepoSessionJobType: JobType {
    public static let identifier = "developum.closeRepoSession"
    public static let displayName = "Close Repository Session"
}

/// Job type for updating workspace state (cursor, selection, viewport).
public struct UpdateWorkspaceStateJobType: JobType {
    public static let identifier = "developum.updateWorkspaceState"
    public static let displayName = "Update Workspace State"
}

/// Job type for processing bridge messages.
public struct ProcessBridgeMessageJobType: JobType {
    public static let identifier = "developum.processBridgeMessage"
    public static let displayName = "Process Bridge Message"
}

// MARK: - Job Parameters

/// Parameters for opening a file.
public struct OpenFileParams: Codable, Sendable {
    /// Repository session ID.
    public let repoId: String
    /// File path relative to repository root.
    public let filePath: String
    /// Optional line to scroll to.
    public let line: Int?
    /// Optional column to position cursor.
    public let column: Int?
    /// Whether to focus the editor on this file.
    public let focus: Bool
    
    public init(repoId: String, filePath: String, line: Int? = nil, column: Int? = nil, focus: Bool = true) {
        self.repoId = repoId
        self.filePath = filePath
        self.line = line
        self.column = column
        self.focus = focus
    }
}

/// Parameters for saving a file.
public struct SaveFileParams: Codable, Sendable {
    /// Repository session ID.
    public let repoId: String
    /// File path relative to repository root.
    public let filePath: String
    /// Content to save.
    public let content: String
    /// Whether to create an artifact (always true for evidence).
    public let createArtifact: Bool
    /// Whether to mirror to working tree.
    public let mirrorToWorkingTree: Bool
    
    public init(
        repoId: String,
        filePath: String,
        content: String,
        createArtifact: Bool = true,
        mirrorToWorkingTree: Bool = true
    ) {
        self.repoId = repoId
        self.filePath = filePath
        self.content = content
        self.createArtifact = createArtifact
        self.mirrorToWorkingTree = mirrorToWorkingTree
    }
}

/// Parameters for searching files.
public struct SearchFilesParams: Codable, Sendable {
    /// Repository session ID.
    public let repoId: String
    /// Search query.
    public let query: String
    /// Whether to use regex.
    public let isRegex: Bool
    /// Whether to match case.
    public let matchCase: Bool
    /// Whether to match whole word.
    public let matchWholeWord: Bool
    /// Optional file path pattern to limit search.
    public let filePattern: String?
    /// Maximum number of results.
    public let maxResults: Int
    
    public init(
        repoId: String,
        query: String,
        isRegex: Bool = false,
        matchCase: Bool = false,
        matchWholeWord: Bool = false,
        filePattern: String? = nil,
        maxResults: Int = 100
    ) {
        self.repoId = repoId
        self.query = query
        self.isRegex = isRegex
        self.matchCase = matchCase
        self.matchWholeWord = matchWholeWord
        self.filePattern = filePattern
        self.maxResults = maxResults
    }
}

/// Parameters for indexing a file.
public struct IndexFileParams: Codable, Sendable {
    /// Repository session ID.
    public let repoId: String
    /// File path relative to repository root.
    public let filePath: String
    /// Whether to force re-indexing.
    public let force: Bool
    
    public init(repoId: String, filePath: String, force: Bool = false) {
        self.repoId = repoId
        self.filePath = filePath
        self.force = force
    }
}

/// Parameters for creating a repository session.
public struct CreateRepoSessionParams: Codable, Sendable {
    /// Local filesystem path to repository root.
    public let repoPath: String
    /// Optional remote URL.
    public let remoteUrl: String?
    /// Workspace configuration as JSON.
    public let workspaceConfig: String?
    /// Metadata about the session.
    public let metadata: String?
    
    public init(
        repoPath: String,
        remoteUrl: String? = nil,
        workspaceConfig: String? = nil,
        metadata: String? = nil
    ) {
        self.repoPath = repoPath
        self.remoteUrl = remoteUrl
        self.workspaceConfig = workspaceConfig
        self.metadata = metadata
    }
}

/// Parameters for closing a repository session.
public struct CloseRepoSessionParams: Codable, Sendable {
    /// Repository session ID.
    public let repoId: String
    /// Whether to save unsaved changes.
    public let saveUnsavedChanges: Bool
    /// Whether to archive the session for later restoration.
    public let archive: Bool
    
    public init(repoId: String, saveUnsavedChanges: Bool = true, archive: Bool = false) {
        self.repoId = repoId
        self.saveUnsavedChanges = saveUnsavedChanges
        self.archive = archive
    }
}

/// Parameters for updating workspace state.
public struct UpdateWorkspaceStateParams: Codable, Sendable {
    /// Repository session ID.
    public let repoId: String
    /// File path relative to repository root.
    public let filePath: String
    /// Cursor line.
    public let cursorLine: Int?
    /// Cursor column.
    public let cursorColumn: Int?
    /// Selection start line.
    public let selectionStartLine: Int?
    /// Selection start column.
    public let selectionStartColumn: Int?
    /// Selection end line.
    public let selectionEndLine: Int?
    /// Selection end column.
    public let selectionEndColumn: Int?
    /// Viewport top line.
    public let viewportTopLine: Int?
    /// Viewport bottom line.
    public let viewportBottomLine: Int?
    /// Whether the file is open.
    public let isOpen: Bool?
    /// Whether the file has unsaved changes.
    public let hasUnsavedChanges: Bool?
    
    public init(
        repoId: String,
        filePath: String,
        cursorLine: Int? = nil,
        cursorColumn: Int? = nil,
        selectionStartLine: Int? = nil,
        selectionStartColumn: Int? = nil,
        selectionEndLine: Int? = nil,
        selectionEndColumn: Int? = nil,
        viewportTopLine: Int? = nil,
        viewportBottomLine: Int? = nil,
        isOpen: Bool? = nil,
        hasUnsavedChanges: Bool? = nil
    ) {
        self.repoId = repoId
        self.filePath = filePath
        self.cursorLine = cursorLine
        self.cursorColumn = cursorColumn
        self.selectionStartLine = selectionStartLine
        self.selectionStartColumn = selectionStartColumn
        self.selectionEndLine = selectionEndLine
        self.selectionEndColumn = selectionEndColumn
        self.viewportTopLine = viewportTopLine
        self.viewportBottomLine = viewportBottomLine
        self.isOpen = isOpen
        self.hasUnsavedChanges = hasUnsavedChanges
    }
}

/// Parameters for processing a bridge message.
public struct ProcessBridgeMessageParams: Codable, Sendable {
    /// Bridge message in canonical JCS format.
    public let messageJson: String
    /// Message hash (BLAKE3 of JCS).
    public let messageHash: String
    
    public init(messageJson: String, messageHash: String) {
        self.messageJson = messageJson
        self.messageHash = messageHash
    }
}

// MARK: - Job Extensions

extension Job {
    /// Convenience method to create an OpenFile job.
    public static func openFile(
        repoId: String,
        filePath: String,
        line: Int? = nil,
        column: Int? = nil,
        focus: Bool = true,
        priority: JobPriority = .normal
    ) -> Job {
        let params = OpenFileParams(
            repoId: repoId,
            filePath: filePath,
            line: line,
            column: column,
            focus: focus
        )
        return Job(
            typeId: OpenFileJobType.identifier,
            metadata: [
                "repoId": repoId,
                "filePath": filePath,
                "line": line.map { String($0) } ?? "",
                "column": column.map { String($0) } ?? "",
                "focus": String(focus)
            ],
            priority: priority
        )
    }
    
    /// Convenience method to create a SaveFile job.
    public static func saveFile(
        repoId: String,
        filePath: String,
        content: String,
        createArtifact: Bool = true,
        mirrorToWorkingTree: Bool = true,
        priority: JobPriority = .normal
    ) -> Job {
        return Job(
            typeId: SaveFileJobType.identifier,
            metadata: [
                "repoId": repoId,
                "filePath": filePath,
                "content": content,
                "createArtifact": String(createArtifact),
                "mirrorToWorkingTree": String(mirrorToWorkingTree)
            ],
            priority: priority
        )
    }
    
    /// Convenience method to create a SearchFiles job.
    public static func searchFiles(
        repoId: String,
        query: String,
        isRegex: Bool = false,
        matchCase: Bool = false,
        matchWholeWord: Bool = false,
        filePattern: String? = nil,
        maxResults: Int = 100,
        priority: JobPriority = .normal
    ) -> Job {
        return Job(
            typeId: SearchFilesJobType.identifier,
            metadata: [
                "repoId": repoId,
                "query": query,
                "isRegex": String(isRegex),
                "matchCase": String(matchCase),
                "matchWholeWord": String(matchWholeWord),
                "filePattern": filePattern ?? "",
                "maxResults": String(maxResults)
            ],
            priority: priority
        )
    }
}