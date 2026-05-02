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

public struct LSPMessage: Codable, Sendable {
    public let jsonrpc: String
    public let id: String?
    public let method: LSPMethod?
    public let params: AnyCodable?
    public let result: AnyCodable?
    public let error: LSPError?

    public init(
        jsonrpc: String = "2.0",
        id: String? = nil,
        method: LSPMethod? = nil,
        params: AnyCodable? = nil,
        result: AnyCodable? = nil,
        error: LSPError? = nil
    ) {
        self.jsonrpc = jsonrpc
        self.id = id
        self.method = method
        self.params = params
        self.result = result
        self.error = error
    }
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
    case requestCancelled = -32800
    case contentModified = -32801
    case unknown = -1
}

public struct LSPError: Error, Codable, Sendable {
    public let code: LSPCode
    public let message: String

    public init(code: LSPCode, message: String) {
        self.code = code
        self.message = message
    }
}

// Type-erased Codable (canonicalized to AnigmaPrimitives)
import AnigmaPrimitives

public typealias AnyCodable = AnigmaPrimitives.AnyCodable

// Helper extension for AnyCodable encoding
extension Encodable {
    func encode(to container: inout SingleValueEncodingContainer) throws {
        try container.encode(self)
    }
}


