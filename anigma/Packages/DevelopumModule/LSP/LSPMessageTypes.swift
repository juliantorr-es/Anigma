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

public struct AnyCodable: Codable, @unchecked Sendable {
    public let value: Any

    public init<T>(_ value: T?) {
        self.value = value ?? ()
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(String.self) { value = x }
        else if let x = try? container.decode(Int.self) { value = x }
        else if let x = try? container.decode(Double.self) { value = x }
        else if let x = try? container.decode(Bool.self) { value = x }
        else if let x = try? container.decode([String: AnyCodable].self) { value = x.mapValues { $0.value } }
        else if let x = try? container.decode([AnyCodable].self) { value = x.map { $0.value } }
        else {
            value = ()
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let x = value as? Encodable {
            try x.encode(to: &container)
        } else {
             try container.encodeNil()
        }
    }
}

// Helper extension for AnyCodable encoding
extension Encodable {
    func encode(to container: inout SingleValueEncodingContainer) throws {
        try container.encode(self)
    }
}


