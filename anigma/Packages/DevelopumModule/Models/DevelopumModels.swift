//
//  DevelopumModels.swift
//  DevelopumModule
//
//  Core data models for Develop mode.
//
//  Models follow GRDB patterns for persistence and are designed to be
//  reconstructable from database evidence (no hidden state).
//

import Foundation
import GRDB

// MARK: - RepoRecord

/// Record of a repository session for Develop mode.
/// Tracks the working tree, open files, cursor positions, and editor state.
public struct RepoRecord: Codable, Sendable, TableRecord, FetchableRecord, PersistableRecord {
    /// Unique identifier for the repository session.
    public var id: UUID
    
    /// Local filesystem path to the repository root.
    public var repoPath: String
    
    /// Git remote URL (optional).
    public var remoteUrl: String?
    
    /// Current branch name.
    public var currentBranch: String
    
    /// SHA of the current HEAD commit.
    public var headSha: String
    
    /// Timestamp when the session was created.
    public var createdAt: Date
    
    /// Timestamp of the last activity in this session.
    public var lastActivityAt: Date
    
    /// Whether the session is currently active.
    public var isActive: Bool
    
    /// Workspace configuration as JSON (editor settings, excluded paths, etc.)
    public var workspaceConfig: String?
    
    /// Metadata about the session (user-agent, tool versions, etc.)
    public var metadata: String?
    
    public init(
        id: UUID = UUID(),
        repoPath: String,
        remoteUrl: String? = nil,
        currentBranch: String = "main",
        headSha: String = "",
        createdAt: Date = Date(),
        lastActivityAt: Date = Date(),
        isActive: Bool = true,
        workspaceConfig: String? = nil,
        metadata: String? = nil
    ) {
        self.id = id
        self.repoPath = repoPath
        self.remoteUrl = remoteUrl
        self.currentBranch = currentBranch
        self.headSha = headSha
        self.createdAt = createdAt
        self.lastActivityAt = lastActivityAt
        self.isActive = isActive
        self.workspaceConfig = workspaceConfig
        self.metadata = metadata
    }
    
    // MARK: - GRDB Table Configuration
    
    public static var databaseTableName: String { "developum_repos" }
    
    /// Database columns definition.
    public enum Columns {
        public static let id = Column("id")
        public static let repoPath = Column("repo_path")
        public static let remoteUrl = Column("remote_url")
        public static let currentBranch = Column("current_branch")
        public static let headSha = Column("head_sha")
        public static let createdAt = Column("created_at")
        public static let lastActivityAt = Column("last_activity_at")
        public static let isActive = Column("is_active")
        public static let workspaceConfig = Column("workspace_config")
        public static let metadata = Column("metadata")
    }
}

// MARK: - WorkspaceState

/// State of a workspace within a repository session.
/// Tracks open files, cursor positions, selections, and viewport state.
public struct WorkspaceState: Codable, Sendable, TableRecord, FetchableRecord, PersistableRecord {
    /// Unique identifier for the workspace state.
    public var id: UUID
    
    /// Foreign key to the repository session.
    public var repoId: UUID
    
    /// Virtual file path within the repository (relative to repo root).
    public var filePath: String
    
    /// Cursor line position (0-indexed).
    public var cursorLine: Int
    
    /// Cursor column position (0-indexed).
    public var cursorColumn: Int
    
    /// Selection start line (0-indexed).
    public var selectionStartLine: Int?
    
    /// Selection start column (0-indexed).
    public var selectionStartColumn: Int?
    
    /// Selection end line (0-indexed).
    public var selectionEndLine: Int?
    
    /// Selection end column (0-indexed).
    public var selectionEndColumn: Int?
    
    /// Viewport top line (0-indexed).
    public var viewportTopLine: Int?
    
    /// Viewport bottom line (0-indexed).
    public var viewportBottomLine: Int?
    
    /// Whether the file is currently open in the editor.
    public var isOpen: Bool
    
    /// Whether the file has unsaved changes.
    public var hasUnsavedChanges: Bool
    
    /// Timestamp of the last modification to this workspace state.
    public var updatedAt: Date
    
    /// Editor-specific state as JSON (folded regions, breakpoints, etc.)
    public var editorState: String?
    
    public init(
        id: UUID = UUID(),
        repoId: UUID,
        filePath: String,
        cursorLine: Int = 0,
        cursorColumn: Int = 0,
        selectionStartLine: Int? = nil,
        selectionStartColumn: Int? = nil,
        selectionEndLine: Int? = nil,
        selectionEndColumn: Int? = nil,
        viewportTopLine: Int? = nil,
        viewportBottomLine: Int? = nil,
        isOpen: Bool = true,
        hasUnsavedChanges: Bool = false,
        updatedAt: Date = Date(),
        editorState: String? = nil
    ) {
        self.id = id
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
        self.updatedAt = updatedAt
        self.editorState = editorState
    }
    
    // MARK: - GRDB Table Configuration
    
    public static var databaseTableName: String { "developum_workspace_states" }
    
    /// Database columns definition.
    public enum Columns {
        public static let id = Column("id")
        public static let repoId = Column("repo_id")
        public static let filePath = Column("file_path")
        public static let cursorLine = Column("cursor_line")
        public static let cursorColumn = Column("cursor_column")
        public static let selectionStartLine = Column("selection_start_line")
        public static let selectionStartColumn = Column("selection_start_column")
        public static let selectionEndLine = Column("selection_end_line")
        public static let selectionEndColumn = Column("selection_end_column")
        public static let viewportTopLine = Column("viewport_top_line")
        public static let viewportBottomLine = Column("viewport_bottom_line")
        public static let isOpen = Column("is_open")
        public static let hasUnsavedChanges = Column("has_unsaved_changes")
        public static let updatedAt = Column("updated_at")
        public static let editorState = Column("editor_state")
    }
}

// MARK: - IndexArtifactRecord

/// Record of an index artifact created by IndexCapsule.
/// Used for fast file/text search without LSP dependencies.
public struct IndexArtifactRecord: Codable, Sendable, TableRecord, FetchableRecord, PersistableRecord {
    /// Unique identifier for the index artifact.
    public var id: UUID
    
    /// Foreign key to the repository session.
    public var repoId: UUID
    
    /// Artifact hash (SHA-256) of the indexed content.
    public var artifactHash: String
    
    /// File path relative to repository root.
    public var filePath: String
    
    /// MIME type of the file.
    public var mimeType: String
    
    /// Language identifier for syntax highlighting.
    public var languageId: String?
    
    /// File size in bytes.
    public var fileSize: Int64
    
    /// Last modified timestamp of the file when indexed.
    public var fileModifiedAt: Date
    
    /// Indexing timestamp.
    public var indexedAt: Date
    
    /// Index content as compressed JSON (file structure, symbols, text tokens).
    public var indexContent: Data
    
    /// Whether this index entry is current (not stale).
    public var isCurrent: Bool
    
    public init(
        id: UUID = UUID(),
        repoId: UUID,
        artifactHash: String,
        filePath: String,
        mimeType: String = "text/plain",
        languageId: String? = nil,
        fileSize: Int64 = 0,
        fileModifiedAt: Date = Date(),
        indexedAt: Date = Date(),
        indexContent: Data = Data(),
        isCurrent: Bool = true
    ) {
        self.id = id
        self.repoId = repoId
        self.artifactHash = artifactHash
        self.filePath = filePath
        self.mimeType = mimeType
        self.languageId = languageId
        self.fileSize = fileSize
        self.fileModifiedAt = fileModifiedAt
        self.indexedAt = indexedAt
        self.indexContent = indexContent
        self.isCurrent = isCurrent
    }
    
    // MARK: - GRDB Table Configuration
    
    public static var databaseTableName: String { "developum_index_artifacts" }
    
    /// Database columns definition.
    public enum Columns {
        public static let id = Column("id")
        public static let repoId = Column("repo_id")
        public static let artifactHash = Column("artifact_hash")
        public static let filePath = Column("file_path")
        public static let mimeType = Column("mime_type")
        public static let languageId = Column("language_id")
        public static let fileSize = Column("file_size")
        public static let fileModifiedAt = Column("file_modified_at")
        public static let indexedAt = Column("indexed_at")
        public static let indexContent = Column("index_content")
        public static let isCurrent = Column("is_current")
    }
}

// MARK: - Enums

/// Status of a repository session.
public enum RepoSessionStatus: String, Codable, Sendable, DatabaseValueConvertible {
    case active
    case paused
    case closed
    case archived
}

/// Type of index artifact.
public enum IndexArtifactType: String, Codable, Sendable, DatabaseValueConvertible {
    case fileStructure
    case symbolTable
    case textTokens
    case fullText
}