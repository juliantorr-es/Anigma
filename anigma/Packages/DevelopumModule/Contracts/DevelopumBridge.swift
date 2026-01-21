//
//  DevelopumBridge.swift
//  DevelopumModule
//
//  Bridge contract for communication between Monaco editor and Swift runtime.
//  Uses JCS (JSON Canonicalization Scheme) for deterministic evidence hashing.
//
//  All messages must follow this schema to ensure replayability and evidence integrity.
//

import Foundation
import AnigmaPrimitives

// MARK: - Bridge Protocol Version

/// Version identifier for the DevelopumBridge contract.
public enum DevelopumBridgeVersion: String, Codable, Sendable {
    case v1 = "1.0"
}

// MARK: - Message Types

/// Type of bridge message.
public enum DevelopumMessageType: String, Codable, Sendable {
    // Editor -> Swift
    case editorReady = "editorReady"
    case fileOpened = "fileOpened"
    case fileClosed = "fileClosed"
    case cursorMoved = "cursorMoved"
    case selectionChanged = "selectionChanged"
    case viewportChanged = "viewportChanged"
    case contentChanged = "contentChanged"
    case saveRequest = "saveRequest"
    case searchRequest = "searchRequest"
    case findReferencesRequest = "findReferencesRequest"
    
    // Swift -> Editor
    case openFile = "openFile"
    case closeFile = "closeFile"
    case updateContent = "updateContent"
    case showMessage = "showMessage"
    case setCursor = "setCursor"
    case setSelection = "setSelection"
    case setViewport = "setViewport"
    case searchResults = "searchResults"
    case referencesResults = "referencesResults"
    case receiptNotification = "receiptNotification"
}

// MARK: - Base Message

/// Base bridge message with common fields.
public struct DevelopumBridgeMessage: Codable, Sendable {
    /// Protocol version.
    public let version: DevelopumBridgeVersion
    
    /// Message type.
    public let type: DevelopumMessageType
    
    /// Unique message ID for correlation.
    public let messageId: String
    
    /// Session identifier.
    public let sessionId: String
    
    /// Repository session ID.
    public let repoId: String?
    
    /// Timestamp in milliseconds since epoch.
    public let timestampMs: Int64
    
    /// Message-specific payload.
    public let payload: DevelopumPayload
    
    public init(
        version: DevelopumBridgeVersion = .v1,
        type: DevelopumMessageType,
        messageId: String = UUID().uuidString,
        sessionId: String,
        repoId: String? = nil,
        timestampMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        payload: DevelopumPayload
    ) {
        self.version = version
        self.type = type
        self.messageId = messageId
        self.sessionId = sessionId
        self.repoId = repoId
        self.timestampMs = timestampMs
        self.payload = payload
    }
}

// MARK: - Payload Types

/// Union type for message payloads.
public enum DevelopumPayload: Codable, Sendable {
    case editorReady(EditorReadyPayload)
    case fileOpened(FileOpenedPayload)
    case fileClosed(FileClosedPayload)
    case cursorMoved(CursorMovedPayload)
    case selectionChanged(SelectionChangedPayload)
    case viewportChanged(ViewportChangedPayload)
    case contentChanged(ContentChangedPayload)
    case saveRequest(SaveRequestPayload)
    case searchRequest(SearchRequestPayload)
    case findReferencesRequest(FindReferencesRequestPayload)
    case openFile(OpenFilePayload)
    case closeFile(CloseFilePayload)
    case updateContent(UpdateContentPayload)
    case showMessage(ShowMessagePayload)
    case setCursor(SetCursorPayload)
    case setSelection(SetSelectionPayload)
    case setViewport(SetViewportPayload)
    case searchResults(SearchResultsPayload)
    case referencesResults(ReferencesResultsPayload)
    case receiptNotification(ReceiptNotificationPayload)
    
    // Custom Codable implementation for union type
    private enum CodingKeys: String, CodingKey {
        case type
        case payload
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(DevelopumMessageType.self, forKey: .type)
        
        switch type {
        case .editorReady:
            let payload = try container.decode(EditorReadyPayload.self, forKey: .payload)
            self = .editorReady(payload)
        case .fileOpened:
            let payload = try container.decode(FileOpenedPayload.self, forKey: .payload)
            self = .fileOpened(payload)
        case .fileClosed:
            let payload = try container.decode(FileClosedPayload.self, forKey: .payload)
            self = .fileClosed(payload)
        case .cursorMoved:
            let payload = try container.decode(CursorMovedPayload.self, forKey: .payload)
            self = .cursorMoved(payload)
        case .selectionChanged:
            let payload = try container.decode(SelectionChangedPayload.self, forKey: .payload)
            self = .selectionChanged(payload)
        case .viewportChanged:
            let payload = try container.decode(ViewportChangedPayload.self, forKey: .payload)
            self = .viewportChanged(payload)
        case .contentChanged:
            let payload = try container.decode(ContentChangedPayload.self, forKey: .payload)
            self = .contentChanged(payload)
        case .saveRequest:
            let payload = try container.decode(SaveRequestPayload.self, forKey: .payload)
            self = .saveRequest(payload)
        case .searchRequest:
            let payload = try container.decode(SearchRequestPayload.self, forKey: .payload)
            self = .searchRequest(payload)
        case .findReferencesRequest:
            let payload = try container.decode(FindReferencesRequestPayload.self, forKey: .payload)
            self = .findReferencesRequest(payload)
        case .openFile:
            let payload = try container.decode(OpenFilePayload.self, forKey: .payload)
            self = .openFile(payload)
        case .closeFile:
            let payload = try container.decode(CloseFilePayload.self, forKey: .payload)
            self = .closeFile(payload)
        case .updateContent:
            let payload = try container.decode(UpdateContentPayload.self, forKey: .payload)
            self = .updateContent(payload)
        case .showMessage:
            let payload = try container.decode(ShowMessagePayload.self, forKey: .payload)
            self = .showMessage(payload)
        case .setCursor:
            let payload = try container.decode(SetCursorPayload.self, forKey: .payload)
            self = .setCursor(payload)
        case .setSelection:
            let payload = try container.decode(SetSelectionPayload.self, forKey: .payload)
            self = .setSelection(payload)
        case .setViewport:
            let payload = try container.decode(SetViewportPayload.self, forKey: .payload)
            self = .setViewport(payload)
        case .searchResults:
            let payload = try container.decode(SearchResultsPayload.self, forKey: .payload)
            self = .searchResults(payload)
        case .referencesResults:
            let payload = try container.decode(ReferencesResultsPayload.self, forKey: .payload)
            self = .referencesResults(payload)
        case .receiptNotification:
            let payload = try container.decode(ReceiptNotificationPayload.self, forKey: .payload)
            self = .receiptNotification(payload)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .editorReady(let payload):
            try container.encode(DevelopumMessageType.editorReady, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .fileOpened(let payload):
            try container.encode(DevelopumMessageType.fileOpened, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .fileClosed(let payload):
            try container.encode(DevelopumMessageType.fileClosed, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .cursorMoved(let payload):
            try container.encode(DevelopumMessageType.cursorMoved, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .selectionChanged(let payload):
            try container.encode(DevelopumMessageType.selectionChanged, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .viewportChanged(let payload):
            try container.encode(DevelopumMessageType.viewportChanged, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .contentChanged(let payload):
            try container.encode(DevelopumMessageType.contentChanged, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .saveRequest(let payload):
            try container.encode(DevelopumMessageType.saveRequest, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .searchRequest(let payload):
            try container.encode(DevelopumMessageType.searchRequest, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .findReferencesRequest(let payload):
            try container.encode(DevelopumMessageType.findReferencesRequest, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .openFile(let payload):
            try container.encode(DevelopumMessageType.openFile, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .closeFile(let payload):
            try container.encode(DevelopumMessageType.closeFile, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .updateContent(let payload):
            try container.encode(DevelopumMessageType.updateContent, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .showMessage(let payload):
            try container.encode(DevelopumMessageType.showMessage, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .setCursor(let payload):
            try container.encode(DevelopumMessageType.setCursor, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .setSelection(let payload):
            try container.encode(DevelopumMessageType.setSelection, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .setViewport(let payload):
            try container.encode(DevelopumMessageType.setViewport, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .searchResults(let payload):
            try container.encode(DevelopumMessageType.searchResults, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .referencesResults(let payload):
            try container.encode(DevelopumMessageType.referencesResults, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .receiptNotification(let payload):
            try container.encode(DevelopumMessageType.receiptNotification, forKey: .type)
            try container.encode(payload, forKey: .payload)
        }
    }
}

// MARK: - Payload Definitions

/// Editor ready notification.
public struct EditorReadyPayload: Codable, Sendable {
    /// Editor instance ID.
    public let editorId: String
    /// Monaco editor version.
    public let editorVersion: String
    /// Supported language features.
    public let capabilities: [String]
    
    public init(editorId: String, editorVersion: String, capabilities: [String]) {
        self.editorId = editorId
        self.editorVersion = editorVersion
        self.capabilities = capabilities
    }
}

/// File opened notification.
public struct FileOpenedPayload: Codable, Sendable {
    /// Virtual file URI (anigma:// scheme).
    public let fileUri: String
    /// File path relative to repo root.
    public let filePath: String
    /// Language ID for syntax highlighting.
    public let languageId: String
    /// Initial content hash (SHA-256).
    public let contentHash: String
    
    public init(fileUri: String, filePath: String, languageId: String, contentHash: String) {
        self.fileUri = fileUri
        self.filePath = filePath
        self.languageId = languageId
        self.contentHash = contentHash
    }
}

/// File closed notification.
public struct FileClosedPayload: Codable, Sendable {
    /// Virtual file URI.
    public let fileUri: String
    /// Whether the file had unsaved changes.
    public let hadUnsavedChanges: Bool
    
    public init(fileUri: String, hadUnsavedChanges: Bool) {
        self.fileUri = fileUri
        self.hadUnsavedChanges = hadUnsavedChanges
    }
}

/// Cursor moved notification.
public struct CursorMovedPayload: Codable, Sendable {
    /// Virtual file URI.
    public let fileUri: String
    /// Cursor line (0-indexed).
    public let line: Int
    /// Cursor column (0-indexed).
    public let column: Int
    
    public init(fileUri: String, line: Int, column: Int) {
        self.fileUri = fileUri
        self.line = line
        self.column = column
    }
}

/// Selection changed notification.
public struct SelectionChangedPayload: Codable, Sendable {
    /// Virtual file URI.
    public let fileUri: String
    /// Selection start line.
    public let startLine: Int
    /// Selection start column.
    public let startColumn: Int
    /// Selection end line.
    public let endLine: Int
    /// Selection end column.
    public let endColumn: Int
    
    public init(fileUri: String, startLine: Int, startColumn: Int, endLine: Int, endColumn: Int) {
        self.fileUri = fileUri
        self.startLine = startLine
        self.startColumn = startColumn
        self.endLine = endLine
        self.endColumn = endColumn
    }
}

/// Viewport changed notification.
public struct ViewportChangedPayload: Codable, Sendable {
    /// Virtual file URI.
    public let fileUri: String
    /// Top visible line.
    public let topLine: Int
    /// Bottom visible line.
    public let bottomLine: Int
    
    public init(fileUri: String, topLine: Int, bottomLine: Int) {
        self.fileUri = fileUri
        self.topLine = topLine
        self.bottomLine = bottomLine
    }
}

/// Content changed notification (keystrokes, edits).
public struct ContentChangedPayload: Codable, Sendable {
    /// Virtual file URI.
    public let fileUri: String
    /// Change description (monaco change event serialized).
    public let changes: String
    /// New content hash after changes.
    public let contentHash: String
    /// Whether the file now has unsaved changes.
    public let hasUnsavedChanges: Bool
    
    public init(fileUri: String, changes: String, contentHash: String, hasUnsavedChanges: Bool) {
        self.fileUri = fileUri
        self.changes = changes
        self.contentHash = contentHash
        self.hasUnsavedChanges = hasUnsavedChanges
    }
}

/// Save request from editor.
public struct SaveRequestPayload: Codable, Sendable {
    /// Virtual file URI.
    public let fileUri: String
    /// Content to save.
    public let content: String
    /// Content hash (SHA-256).
    public let contentHash: String
    
    public init(fileUri: String, content: String, contentHash: String) {
        self.fileUri = fileUri
        self.content = content
        self.contentHash = contentHash
    }
}

/// Search request from editor.
public struct SearchRequestPayload: Codable, Sendable {
    /// Virtual file URI (optional, if searching within a file).
    public let fileUri: String?
    /// Search query.
    public let query: String
    /// Whether to use regex.
    public let isRegex: Bool
    /// Whether to match case.
    public let matchCase: Bool
    /// Whether to match whole word.
    public let matchWholeWord: Bool
    
    public init(fileUri: String?, query: String, isRegex: Bool, matchCase: Bool, matchWholeWord: Bool) {
        self.fileUri = fileUri
        self.query = query
        self.isRegex = isRegex
        self.matchCase = matchCase
        self.matchWholeWord = matchWholeWord
    }
}

/// Find references request.
public struct FindReferencesRequestPayload: Codable, Sendable {
    /// Virtual file URI.
    public let fileUri: String
    /// Line position.
    public let line: Int
    /// Column position.
    public let column: Int
    
    public init(fileUri: String, line: Int, column: Int) {
        self.fileUri = fileUri
        self.line = line
        self.column = column
    }
}

/// Open file command to editor.
public struct OpenFilePayload: Codable, Sendable {
    /// Virtual file URI.
    public let fileUri: String
    /// File content.
    public let content: String
    /// Language ID.
    public let languageId: String
    /// Whether to focus the editor.
    public let focus: Bool
    
    public init(fileUri: String, content: String, languageId: String, focus: Bool = true) {
        self.fileUri = fileUri
        self.content = content
        self.languageId = languageId
        self.focus = focus
    }
}

/// Close file command.
public struct CloseFilePayload: Codable, Sendable {
    /// Virtual file URI.
    public let fileUri: String
    
    public init(fileUri: String) {
        self.fileUri = fileUri
    }
}

/// Update content command.
public struct UpdateContentPayload: Codable, Sendable {
    /// Virtual file URI.
    public let fileUri: String
    /// New content.
    public let content: String
    /// Optional selection to restore.
    public let selection: SelectionRange?
    
    public init(fileUri: String, content: String, selection: SelectionRange? = nil) {
        self.fileUri = fileUri
        self.content = content
        self.selection = selection
    }
}

/// Show message to user.
public struct ShowMessagePayload: Codable, Sendable {
    /// Message severity.
    public let severity: MessageSeverity
    /// Message text.
    public let message: String
    /// Optional timeout in milliseconds.
    public let timeoutMs: Int?
    
    public init(severity: MessageSeverity, message: String, timeoutMs: Int? = nil) {
        self.severity = severity
        self.message = message
        self.timeoutMs = timeoutMs
    }
}

/// Set cursor position.
public struct SetCursorPayload: Codable, Sendable {
    /// Virtual file URI.
    public let fileUri: String
    /// Line position.
    public let line: Int
    /// Column position.
    public let column: Int
    
    public init(fileUri: String, line: Int, column: Int) {
        self.fileUri = fileUri
        self.line = line
        self.column = column
    }
}

/// Set selection range.
public struct SetSelectionPayload: Codable, Sendable {
    /// Virtual file URI.
    public let fileUri: String
    /// Selection range.
    public let selection: SelectionRange
    
    public init(fileUri: String, selection: SelectionRange) {
        self.fileUri = fileUri
        self.selection = selection
    }
}

/// Set viewport range.
public struct SetViewportPayload: Codable, Sendable {
    /// Virtual file URI.
    public let fileUri: String
    /// Viewport range.
    public let viewport: ViewportRange
    
    public init(fileUri: String, viewport: ViewportRange) {
        self.fileUri = fileUri
        self.viewport = viewport
    }
}

/// Search results.
public struct SearchResultsPayload: Codable, Sendable {
    /// Search request ID.
    public let requestId: String
    /// Search results.
    public let results: [SearchResult]
    /// Whether this is the final batch.
    public let isComplete: Bool
    
    public init(requestId: String, results: [SearchResult], isComplete: Bool) {
        self.requestId = requestId
        self.results = results
        self.isComplete = isComplete
    }
}

/// References results.
public struct ReferencesResultsPayload: Codable, Sendable {
    /// Request ID.
    public let requestId: String
    /// Reference results.
    public let results: [ReferenceResult]
    
    public init(requestId: String, results: [ReferenceResult]) {
        self.requestId = requestId
        self.results = results
    }
}

/// Receipt notification.
public struct ReceiptNotificationPayload: Codable, Sendable {
    /// Receipt ID.
    public let receiptId: String
    /// Operation type.
    public let operationType: String
    /// Status (success, failure).
    public let status: ReceiptStatus
    /// Optional message.
    public let message: String?
    
    public init(receiptId: String, operationType: String, status: ReceiptStatus, message: String? = nil) {
        self.receiptId = receiptId
        self.operationType = operationType
        self.status = status
        self.message = message
    }
}

// MARK: - Supporting Types

/// Selection range.
public struct SelectionRange: Codable, Sendable {
    public let startLine: Int
    public let startColumn: Int
    public let endLine: Int
    public let endColumn: Int
    
    public init(startLine: Int, startColumn: Int, endLine: Int, endColumn: Int) {
        self.startLine = startLine
        self.startColumn = startColumn
        self.endLine = endLine
        self.endColumn = endColumn
    }
}

/// Viewport range.
public struct ViewportRange: Codable, Sendable {
    public let topLine: Int
    public let bottomLine: Int
    
    public init(topLine: Int, bottomLine: Int) {
        self.topLine = topLine
        self.bottomLine = bottomLine
    }
}

/// Search result.
public struct SearchResult: Codable, Sendable {
    public let fileUri: String
    public let line: Int
    public let column: Int
    public let match: String
    public let lineText: String
    
    public init(fileUri: String, line: Int, column: Int, match: String, lineText: String) {
        self.fileUri = fileUri
        self.line = line
        self.column = column
        self.match = match
        self.lineText = lineText
    }
}

/// Reference result.
public struct ReferenceResult: Codable, Sendable {
    public let fileUri: String
    public let line: Int
    public let column: Int
    public let name: String
    public let kind: String
    
    public init(fileUri: String, line: Int, column: Int, name: String, kind: String) {
        self.fileUri = fileUri
        self.line = line
        self.column = column
        self.name = name
        self.kind = kind
    }
}

/// Message severity.
public enum MessageSeverity: String, Codable, Sendable {
    case info, warning, error
}

/// Receipt status.
public enum ReceiptStatus: String, Codable, Sendable {
    case success, failure, pending
}

// MARK: - JCS Canonicalization

extension DevelopumBridgeMessage {
    /// Computes the canonical JCS representation of this message.
    /// Used for deterministic evidence hashing.
    public func toCanonicalJSON() throws -> Data {
        // TODO: Implement proper JCS canonicalization
        // For now, use sorted keys and no whitespace
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }
    
    /// Computes the BLAKE3 hash of the canonical JCS representation.
    public func canonicalHash() throws -> String {
        let canonicalData = try toCanonicalJSON()
        // TODO: Use BLAKE3 hashing
        return canonicalData.base64EncodedString()
    }
}