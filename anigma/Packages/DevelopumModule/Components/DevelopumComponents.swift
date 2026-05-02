import AnigmaPrimitives

import AnigmaPrimitives

//
//  DevelopumComponents.swift
//  DevelopumModule
//
//  ECS components for Develop mode editor state.
//

import AnigmaCore
import Foundation

// MARK: - Repo Session Component

/// Repository session component tracking active develop mode session.
public struct RepoSessionComponent: Component, Codable, Sendable {
    /// Repository session ID.
    public let id: UUID
    
    /// Repository path.
    public let repoPath: String
    
    /// Current branch.
    public var currentBranch: String
    
    /// HEAD commit SHA.
    public var headSha: String
    
    /// Session start timestamp.
    public let startedAt: Date
    
    /// Whether session is active.
    public var isActive: Bool
    
    public init(
        id: UUID = UUID(),
        repoPath: String,
        currentBranch: String = "main",
        headSha: String = "",
        startedAt: Date = Date(),
        isActive: Bool = true
    ) {
        self.id = id
        self.repoPath = repoPath
        self.currentBranch = currentBranch
        self.headSha = headSha
        self.startedAt = startedAt
        self.isActive = isActive
    }
}

// MARK: - Open File Component

/// Tracks an open file in the editor.
public struct OpenFileComponent: Component, Codable, Sendable {
    /// Virtual file URI (anigma:// scheme).
    public let fileUri: String
    
    /// File path relative to repo root.
    public let filePath: String
    
    /// Language ID for syntax highlighting.
    public let languageId: String
    
    /// Current content hash.
    public var contentHash: String
    
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
    
    /// Viewport top line.
    public var viewportTopLine: Int?
    
    /// Viewport bottom line.
    public var viewportBottomLine: Int?
    
    /// Whether file has unsaved changes.
    public var hasUnsavedChanges: Bool
    
    /// Last activity timestamp.
    public var lastActivityAt: Date
    
    public init(
        fileUri: String,
        filePath: String,
        languageId: String = "plaintext",
        contentHash: String,
        cursorLine: Int = 0,
        cursorColumn: Int = 0,
        selectionStartLine: Int? = nil,
        selectionStartColumn: Int? = nil,
        selectionEndLine: Int? = nil,
        selectionEndColumn: Int? = nil,
        viewportTopLine: Int? = nil,
        viewportBottomLine: Int? = nil,
        hasUnsavedChanges: Bool = false,
        lastActivityAt: Date = Date()
    ) {
        self.fileUri = fileUri
        self.filePath = filePath
        self.languageId = languageId
        self.contentHash = contentHash
        self.cursorLine = cursorLine
        self.cursorColumn = cursorColumn
        self.selectionStartLine = selectionStartLine
        self.selectionStartColumn = selectionStartColumn
        self.selectionEndLine = selectionEndLine
        self.selectionEndColumn = selectionEndColumn
        self.viewportTopLine = viewportTopLine
        self.viewportBottomLine = viewportBottomLine
        self.hasUnsavedChanges = hasUnsavedChanges
        self.lastActivityAt = lastActivityAt
    }
}

// MARK: - Bridge Message Component

/// Tracks a bridge message for processing.
public struct BridgeMessageComponent: Component, Codable, Sendable {
    /// Bridge message type.
    public let messageType: DevelopumMessageType
    
    /// Message ID for correlation.
    public let messageId: String
    
    /// Session ID.
    public let sessionId: String
    
    /// Message payload as JSON string.
    public let payloadJson: String
    
    /// Message timestamp.
    public let timestamp: Date
    
    /// Processing status.
    public var status: BridgeMessageStatus
    
    public init(
        messageType: DevelopumMessageType,
        messageId: String = UUID().uuidString,
        sessionId: String,
        payloadJson: String,
        timestamp: Date = Date(),
        status: BridgeMessageStatus = .pending
    ) {
        self.messageType = messageType
        self.messageId = messageId
        self.sessionId = sessionId
        self.payloadJson = payloadJson
        self.timestamp = timestamp
        self.status = status
    }
}

/// Status of a bridge message.
public enum BridgeMessageStatus: String, Codable, Sendable {
    case pending
    case processing
    case completed
    case failed
}

// MARK: - Index Job Component

/// Tracks an indexing job for a file.
public struct IndexJobComponent: Component, Codable, Sendable {
    /// Job ID.
    public let jobId: String
    
    /// File path to index.
    public let filePath: String
    
    /// Whether to force re-indexing.
    public let force: Bool
    
    /// Job status.
    public var status: IndexJobStatus
    
    /// Job started timestamp.
    public var startedAt: Date?
    
    /// Job completed timestamp.
    public var completedAt: Date?
    
    /// Indexing duration in milliseconds.
    public var durationMs: Int?
    
    /// Error message if failed.
    public var errorMessage: String?
    
    public init(
        jobId: String = UUID().uuidString,
        filePath: String,
        force: Bool = false,
        status: IndexJobStatus = .pending
    ) {
        self.jobId = jobId
        self.filePath = filePath
        self.force = force
        self.status = status
        self.startedAt = nil
        self.completedAt = nil
        self.durationMs = nil
        self.errorMessage = nil
    }
}

/// Status of an indexing job.
public enum IndexJobStatus: String, Codable, Sendable {
    case pending
    case running
    case completed
    case failed
    case cancelled
}

// MARK: - Search Result Component

/// Stores search results for display.
public struct SearchResultComponent: Component, Codable, Sendable {
    /// Search query.
    public let query: String
    
    /// Search results.
    public var results: [SearchResult]
    
    /// Whether search is complete.
    public var isComplete: Bool
    
    /// Search started timestamp.
    public let startedAt: Date
    
    /// Search completed timestamp.
    public var completedAt: Date?
    
    public init(
        query: String,
        results: [SearchResult] = [],
        isComplete: Bool = false,
        startedAt: Date = Date()
    ) {
        self.query = query
        self.results = results
        self.isComplete = isComplete
        self.startedAt = startedAt
        self.completedAt = nil
    }
}