//
//  LSPMessageTypes.swift
//  DevelopumModule
//
//  LSP message types for requests and responses.
//  Extracted from DevelopumLSPBridge.swift
//

import Foundation

/// LSP message types for requests and responses.
public enum LSPMessageType: String, Codable, Sendable {
    case request
    case response
    case notification
}

/// LSP request methods.
public enum LSPMethod: String, Codable, Sendable {
    case initialize
    case initialized
    case shutdown
    case exit
    case textDocumentDidOpen = "textDocument/didOpen"
    case textDocumentDidChange = "textDocument/didChange"
    case textDocumentDidClose = "textDocument/didClose"
    case textDocumentDefinition = "textDocument/definition"
    case textDocumentReferences = "textDocument/references"
    case textDocumentHover = "textDocument/hover"
    case textDocumentCompletion = "textDocument/completion"
    case textDocumentDocumentSymbol = "textDocument/documentSymbol"
    case completionItemResolve = "completionItem/resolve"
    case windowShowMessage = "window/showMessage"
    case telemetryEvent = "telemetry/event"
}

/// LSP error codes.
public enum LSPCode: Int, Codable, Sendable {
    case parseError = -32700
    case invalidRequest = -32600
    case methodNotFound = -32601
    case invalidParams = -32602
    case internalError = -32603
    case serverNotInitialized = -32002
    case unknownErrorCode = -32001
}
