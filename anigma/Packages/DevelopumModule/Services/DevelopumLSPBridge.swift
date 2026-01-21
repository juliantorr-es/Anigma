//
//  DevelopumLSPBridge.swift
//  DevelopumModule
//
//  LSP Bridge for semantic navigation in Develop mode.
//  Provides definition, references, hover, completion, and document symbols via Language Server Protocol.
//
//  Key Features:
//  - JSON-RPC over stdio or TCP for LSP communication
//  - Virtual anigma:// URI scheme for document references
//  - Content served via RPC, not URL fetching
//  - Full LSP lifecycle management (start/stop/reconnect)
//  - Evidence-backed receipts for all LSP operations
//

import AnigmaCore
import AnigmaPrimitives
import ExecutionCore
import Foundation
import TelemetryCore

// MARK: - Virtual URI Scheme

/// Virtual URI scheme for Anigma document references.
/// Content is served via RPC, not URL fetching.
public enum AnigmaVirtualURI {
    /// Scheme identifier.
    public static let scheme = "anigma"

    /// Creates a virtual URI for a document.
    public static func documentURI(repoId: UUID, filePath: String) -> String {
        let encodedPath = filePath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? filePath
        return "\(scheme)://\(repoId.uuidString)/\(encodedPath)"
    }

    /// Extracts the repo ID from a virtual URI.
    public static func repoId(from uri: String) -> UUID? {
        guard uri.hasPrefix("\(scheme)://") else { return nil }
        let withoutScheme = String(uri.dropFirst("\(scheme)://".count))
        let components = withoutScheme.split(separator: "/", maxSplits: 1)
        guard components.count >= 1 else { return nil }
        return UUID(uuidString: String(components[0]))
    }

    /// Extracts the file path from a virtual URI.
    public static func filePath(from uri: String) -> String? {
        guard uri.hasPrefix("\(scheme)://") else { return nil }
        let withoutScheme = String(uri.dropFirst("\(scheme)://".count))
        let components = withoutScheme.split(separator: "/", maxSplits: 1)
        guard components.count >= 2 else { return nil }
        let path = String(components[1])
        return path.removingPercentEncoding ?? path
    }
}

// MARK: - LSP Message Types

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

// MARK: - Base LSP Message

/// Base structure for all LSP messages.
public struct LSPMessage: Codable, Sendable {
    public let jsonrpc: String
    public let id: String?
    public let method: LSPMethod?
    public let params: LSPParams?
    public let result: LSPResult?
    public let error: LSPError?

    public init(
        jsonrpc: String = "2.0",
        id: String? = nil,
        method: LSPMethod? = nil,
        params: LSPParams? = nil,
        result: LSPResult? = nil,
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

// MARK: - LSP Parameters

/// Union type for LSP parameters.
public enum LSPParams: Codable, Sendable {
    case initialize(InitializeParams)
    case initialized(InitializedParams)
    case shutdown(ShutdownParams)
    case textDocumentDidOpen(DidOpenTextDocumentParams)
    case textDocumentDidChange(DidChangeTextDocumentParams)
    case textDocumentDidClose(DidCloseTextDocumentParams)
    case textDocumentDefinition(DefinitionParams)
    case textDocumentReferences(ReferenceParams)
    case textDocumentHover(HoverParams)
    case textDocumentCompletion(CompletionParams)
    case textDocumentDocumentSymbol(DocumentSymbolParams)
    case completionItemResolve(CompletionItemResolveParams)

    private enum CodingKeys: String, CodingKey {
        case method
        case params
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let method = try container.decodeIfPresent(String.self, forKey: .method)

        if let method = method {
            switch method {
            case "initialize":
                let params = try container.decode(InitializeParams.self, forKey: .params)
                self = .initialize(params)
            case "initialized":
                let params = try container.decode(InitializedParams.self, forKey: .params)
                self = .initialized(params)
            case "shutdown":
                self = .shutdown(ShutdownParams())
            case "textDocument/didOpen":
                let params = try container.decode(DidOpenTextDocumentParams.self, forKey: .params)
                self = .textDocumentDidOpen(params)
            case "textDocument/didChange":
                let params = try container.decode(DidChangeTextDocumentParams.self, forKey: .params)
                self = .textDocumentDidChange(params)
            case "textDocument/didClose":
                let params = try container.decode(DidCloseTextDocumentParams.self, forKey: .params)
                self = .textDocumentDidClose(params)
            case "textDocument/definition":
                let params = try container.decode(DefinitionParams.self, forKey: .params)
                self = .textDocumentDefinition(params)
            case "textDocument/references":
                let params = try container.decode(ReferenceParams.self, forKey: .params)
                self = .textDocumentReferences(params)
            case "textDocument/hover":
                let params = try container.decode(HoverParams.self, forKey: .params)
                self = .textDocumentHover(params)
            case "textDocument/completion":
                let params = try container.decode(CompletionParams.self, forKey: .params)
                self = .textDocumentCompletion(params)
            case "textDocument/documentSymbol":
                let params = try container.decode(DocumentSymbolParams.self, forKey: .params)
                self = .textDocumentDocumentSymbol(params)
            case "completionItem/resolve":
                let params = try container.decode(CompletionItemResolveParams.self, forKey: .params)
                self = .completionItemResolve(params)
            default:
                throw LSPError(code: .methodNotFound, message: "Unknown method: \(method)")
            }
        } else {
            throw LSPError(code: .invalidRequest, message: "Missing method in params")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .initialize(let params):
            try container.encode("initialize", forKey: .method)
            try container.encode(params, forKey: .params)
        case .initialized(let params):
            try container.encode("initialized", forKey: .method)
            try container.encode(params, forKey: .params)
        case .shutdown:
            try container.encode("shutdown", forKey: .method)
            try container.encode(ShutdownParams(), forKey: .params)
        case .textDocumentDidOpen(let params):
            try container.encode("textDocument/didOpen", forKey: .method)
            try container.encode(params, forKey: .params)
        case .textDocumentDidChange(let params):
            try container.encode("textDocument/didChange", forKey: .method)
            try container.encode(params, forKey: .params)
        case .textDocumentDidClose(let params):
            try container.encode("textDocument/didClose", forKey: .method)
            try container.encode(params, forKey: .params)
        case .textDocumentDefinition(let params):
            try container.encode("textDocument/definition", forKey: .method)
            try container.encode(params, forKey: .params)
        case .textDocumentReferences(let params):
            try container.encode("textDocument/references", forKey: .method)
            try container.encode(params, forKey: .params)
        case .textDocumentHover(let params):
            try container.encode("textDocument/hover", forKey: .method)
            try container.encode(params, forKey: .params)
        case .textDocumentCompletion(let params):
            try container.encode("textDocument/completion", forKey: .method)
            try container.encode(params, forKey: .params)
        case .textDocumentDocumentSymbol(let params):
            try container.encode("textDocument/documentSymbol", forKey: .method)
            try container.encode(params, forKey: .params)
        case .completionItemResolve(let params):
            try container.encode("completionItem/resolve", forKey: .method)
            try container.encode(params, forKey: .params)
        }
    }
}

// MARK: - LSP Result

/// Union type for LSP results.
public enum LSPResult: Codable, Sendable {
    case initialize(InitializeResult)
    case definition(DefinitionResult)
    case references([Location])
    case hover(HoverResult)
    case completion(CompletionResult)
    case documentSymbol([DocumentSymbol])
    case completionItemResolve(CompletionItem)
    case none

    private enum CodingKeys: String, CodingKey {
        case result
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let result = try container.decodeIfPresent(LSPResultValue.self, forKey: .result)

        if result == nil || result?.isNull == true {
            self = .none
            return
        }

        if let value = result?.arrayValue {
            let locations = try JSONDecoder().decode([Location].self, from: JSONSerialization.data(withJSONObject: value))
            self = .references(locations)
        } else if let value = result?.dictionaryValue {
            let data = try JSONSerialization.data(withJSONObject: value)
            if let symbols = try? JSONDecoder().decode([DocumentSymbol].self, from: data) {
                self = .documentSymbol(symbols)
            } else if let result = try? JSONDecoder().decode(InitializeResult.self, from: data) {
                self = .initialize(result)
            } else if let result = try? JSONDecoder().decode(DefinitionResult.self, from: data) {
                self = .definition(result)
            } else if let result = try? JSONDecoder().decode(HoverResult.self, from: data) {
                self = .hover(result)
            } else if let result = try? JSONDecoder().decode(CompletionResult.self, from: data) {
                self = .completion(result)
            } else if let item = try? JSONDecoder().decode(CompletionItem.self, from: data) {
                self = .completionItemResolve(item)
            } else {
                self = .none
            }
        } else {
            self = .none
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .initialize(let result):
            try container.encode(LSPResultValue(result), forKey: .result)
        case .definition(let result):
            try container.encode(LSPResultValue(result), forKey: .result)
        case .references(let locations):
            let locationsData = try JSONEncoder().encode(locations)
            let locationsValue = try JSONSerialization.jsonObject(with: locationsData) as? [Any]
            try container.encode(LSPResultValue(arrayValue: locationsValue), forKey: .result)
        case .hover(let result):
            try container.encode(LSPResultValue(result), forKey: .result)
        case .completion(let result):
            try container.encode(LSPResultValue(result), forKey: .result)
        case .documentSymbol(let symbols):
            let symbolsData = try JSONEncoder().encode(symbols)
            let symbolsValue = try JSONSerialization.jsonObject(with: symbolsData) as? [Any]
            try container.encode(LSPResultValue(arrayValue: symbolsValue), forKey: .result)
        case .completionItemResolve(let item):
            try container.encode(LSPResultValue(item), forKey: .result)
        case .none:
            try container.encode(LSPResultValue(isNull: true), forKey: .result)
        }
    }
}

public struct LSPResultValue: Codable, Sendable {
    public let isNull: Bool
    public let arrayValue: [Any]?
    public let dictionaryValue: [String: Any]?

    public init(isNull: Bool = false, arrayValue: [Any]? = nil, dictionaryValue: [String: Any]? = nil) {
        self.isNull = isNull
        self.arrayValue = arrayValue
        self.dictionaryValue = dictionaryValue
    }

    public init<T: Encodable>(_ value: T) {
        let data = try! JSONEncoder().encode(AnyEncodable(value))
        let decoded = try! JSONDecoder().decode([String: AnyCodable].self, from: data)
        self.dictionaryValue = decoded.mapValues { $0.value }
        self.arrayValue = nil
        self.isNull = false
    }
}

public struct AnyEncodable: Codable {
    public let value: Any

    public init<T: Encodable>(_ value: T) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([AnyDecodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyDecodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let arrayValue as [Any]:
            let encodableArray = arrayValue.map { AnyEncodable($0) }
            try container.encode(encodableArray)
        case let dictValue as [String: Any]:
            let encodableDict = dictValue.mapValues { AnyEncodable($0) }
            try container.encode(encodableDict)
        default:
            try container.encodeNil()
        }
    }
}

public struct AnyDecodable: Codable {
    public let value: Any

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([AnyDecodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyDecodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
}

// MARK: - LSP Error

/// LSP error structure.
public struct LSPError: Codable, Sendable, Error {
    public let code: LSPCode
    public let message: String
    public let data: String?

    public init(code: LSPCode, message: String, data: String? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }
}

// MARK: - LSP Parameter Types

public struct InitializeParams: Codable, Sendable {
    public let processId: Int?
    public let rootUri: String?
    public let initializationOptions: InitializationOptions?
    public let capabilities: ClientCapabilities
    public let trace: String?

    public init(
        processId: Int? = nil,
        rootUri: String? = nil,
        initializationOptions: InitializationOptions? = nil,
        capabilities: ClientCapabilities = ClientCapabilities(),
        trace: String? = nil
    ) {
        self.processId = processId
        self.rootUri = rootUri
        self.initializationOptions = initializationOptions
        self.capabilities = capabilities
        self.trace = trace
    }
}

public struct InitializationOptions: Codable, Sendable {
    public let anigmaOptions: AnigmaLSPOptions?

    public init(anigmaOptions: AnigmaLSPOptions? = nil) {
        self.anigmaOptions = anigmaOptions
    }
}

public struct AnigmaLSPOptions: Codable, Sendable {
    public let repoId: String
    public let repoPath: String

    public init(repoId: String, repoPath: String) {
        self.repoId = repoId
        self.repoPath = repoPath
    }
}

public struct ClientCapabilities: Codable, Sendable {
    public let textDocument: TextDocumentClientCapabilities?
    public let workspace: WorkspaceClientCapabilities?

    public init(
        textDocument: TextDocumentClientCapabilities? = nil,
        workspace: WorkspaceClientCapabilities? = nil
    ) {
        self.textDocument = textDocument
        self.workspace = workspace
    }
}

public struct TextDocumentClientCapabilities: Codable, Sendable {
    public let synchronization: TextDocumentSyncOptions?
    public let completion: CompletionCapabilities?
    public let hover: HoverCapabilities?
    public let definition: DefinitionCapabilities?
    public let references: ReferencesCapabilities?
    public let documentSymbol: DocumentSymbolCapabilities?

    public init(
        synchronization: TextDocumentSyncOptions? = nil,
        completion: CompletionCapabilities? = nil,
        hover: HoverCapabilities? = nil,
        definition: DefinitionCapabilities? = nil,
        references: ReferencesCapabilities? = nil,
        documentSymbol: DocumentSymbolCapabilities? = nil
    ) {
        self.synchronization = synchronization
        self.completion = completion
        self.hover = hover
        self.definition = definition
        self.references = references
        self.documentSymbol = documentSymbol
    }
}

public struct TextDocumentSyncOptions: Codable, Sendable {
    public let openClose: Bool?
    public let change: TextDocumentSyncKind?

    public init(openClose: Bool? = nil, change: TextDocumentSyncKind? = nil) {
        self.openClose = openClose
        self.change = change
    }
}

public enum TextDocumentSyncKind: Int, Codable, Sendable {
    case none = 0
    case full = 1
    case incremental = 2
}

public struct CompletionCapabilities: Codable, Sendable {
    public let dynamicRegistration: Bool?
    public let completionItem: CompletionItemCapabilities?
    public let completionList: CompletionListCapabilities?

    public init(
        dynamicRegistration: Bool? = nil,
        completionItem: CompletionItemCapabilities? = nil,
        completionList: CompletionListCapabilities? = nil
    ) {
        self.dynamicRegistration = dynamicRegistration
        self.completionItem = completionItem
        self.completionList = completionList
    }
}

public struct CompletionItemCapabilities: Codable, Sendable {
    public let snippetSupport: Bool?
    public let commitCharactersSupport: Bool?
    public let documentationFormat: [String]?

    public init(
        snippetSupport: Bool? = nil,
        commitCharactersSupport: Bool? = nil,
        documentationFormat: [String]? = nil
    ) {
        self.snippetSupport = snippetSupport
        self.commitCharactersSupport = commitCharactersSupport
        self.documentationFormat = documentationFormat
    }
}

public struct CompletionListCapabilities: Codable, Sendable {
    public let itemDefaults: [String]?

    public init(itemDefaults: [String]? = nil) {
        self.itemDefaults = itemDefaults
    }
}

public struct HoverCapabilities: Codable, Sendable {
    public let dynamicRegistration: Bool?
    public let contentFormat: [String]?

    public init(dynamicRegistration: Bool? = nil, contentFormat: [String]? = nil) {
        self.dynamicRegistration = dynamicRegistration
        self.contentFormat = contentFormat
    }
}

public struct DefinitionCapabilities: Codable, Sendable {
    public let dynamicRegistration: Bool?
    public let linkSupport: Bool?

    public init(dynamicRegistration: Bool? = nil, linkSupport: Bool? = nil) {
        self.dynamicRegistration = dynamicRegistration
        self.linkSupport = linkSupport
    }
}

public struct ReferencesCapabilities: Codable, Sendable {
    public let dynamicRegistration: Bool?

    public init(dynamicRegistration: Bool? = nil) {
        self.dynamicRegistration = dynamicRegistration
    }
}

public struct DocumentSymbolCapabilities: Codable, Sendable {
    public let dynamicRegistration: Bool?
    public let symbolKind: SymbolKindCapabilities?
    public let hierarchicalDocumentSymbolSupport: Bool?

    public init(
        dynamicRegistration: Bool? = nil,
        symbolKind: SymbolKindCapabilities? = nil,
        hierarchicalDocumentSymbolSupport: Bool? = nil
    ) {
        self.dynamicRegistration = dynamicRegistration
        self.symbolKind = symbolKind
        self.hierarchicalDocumentSymbolSupport = hierarchicalDocumentSymbolSupport
    }
}

public struct SymbolKindCapabilities: Codable, Sendable {
    public let valueSet: [SymbolKind]?

    public init(valueSet: [SymbolKind]? = nil) {
        self.valueSet = valueSet
    }
}

public struct WorkspaceClientCapabilities: Codable, Sendable {
    public let applyEdit: Bool?
    public let workspaceFolders: Bool?

    public init(applyEdit: Bool? = nil, workspaceFolders: Bool? = nil) {
        self.applyEdit = applyEdit
        self.workspaceFolders = workspaceFolders
    }
}

public struct InitializedParams: Codable, Sendable {}

public struct ShutdownParams: Codable, Sendable {}

public struct DidOpenTextDocumentParams: Codable, Sendable {
    public let textDocument: TextDocumentItem

    public init(textDocument: TextDocumentItem) {
        self.textDocument = textDocument
    }
}

public struct DidChangeTextDocumentParams: Codable, Sendable {
    public let textDocument: VersionedTextDocumentIdentifier
    public let contentChanges: [TextDocumentContentChangeEvent]

    public init(textDocument: VersionedTextDocumentIdentifier, contentChanges: [TextDocumentContentChangeEvent]) {
        self.textDocument = textDocument
        self.contentChanges = contentChanges
    }
}

public struct DidCloseTextDocumentParams: Codable, Sendable {
    public let textDocument: TextDocumentIdentifier

    public init(textDocument: TextDocumentIdentifier) {
        self.textDocument = textDocument
    }
}

public struct TextDocumentItem: Codable, Sendable {
    public let uri: String
    public let languageId: String
    public let version: Int
    public let text: String

    public init(uri: String, languageId: String, version: Int, text: String) {
        self.uri = uri
        self.languageId = languageId
        self.version = version
        self.text = text
    }
}

public struct TextDocumentIdentifier: Codable, Sendable {
    public let uri: String

    public init(uri: String) {
        self.uri = uri
    }
}

public struct VersionedTextDocumentIdentifier: Codable, Sendable {
    public let uri: String
    public let version: Int

    public init(uri: String, version: Int) {
        self.uri = uri
        self.version = version
    }
}

public struct TextDocumentContentChangeEvent: Codable, Sendable {
    public let range: Range?
    public let text: String

    public init(range: Range? = nil, text: String) {
        self.range = range
        self.text = text
    }
}

public struct Range: Codable, Sendable {
    public let start: Position
    public let end: Position

    public init(start: Position, end: Position) {
        self.start = start
        self.end = end
    }
}

public struct Position: Codable, Sendable {
    public let line: Int
    public let character: Int

    public init(line: Int, character: Int) {
        self.line = line
        self.character = character
    }
}

public struct DefinitionParams: Codable, Sendable {
    public let textDocument: TextDocumentIdentifier
    public let position: Position

    public init(textDocument: TextDocumentIdentifier, position: Position) {
        self.textDocument = textDocument
        self.position = position
    }
}

public struct ReferenceParams: Codable, Sendable {
    public let textDocument: TextDocumentIdentifier
    public let position: Position
    public let context: ReferenceContext

    public init(textDocument: TextDocumentIdentifier, position: Position, context: ReferenceContext) {
        self.textDocument = textDocument
        self.position = position
        self.context = context
    }
}

public struct ReferenceContext: Codable, Sendable {
    public let includeDeclaration: Bool

    public init(includeDeclaration: Bool) {
        self.includeDeclaration = includeDeclaration
    }
}

public struct HoverParams: Codable, Sendable {
    public let textDocument: TextDocumentIdentifier
    public let position: Position

    public init(textDocument: TextDocumentIdentifier, position: Position) {
        self.textDocument = textDocument
        self.position = position
    }
}

public struct CompletionParams: Codable, Sendable {
    public let textDocument: TextDocumentIdentifier
    public let position: Position
    public let context: CompletionContext?

    public init(textDocument: TextDocumentIdentifier, position: Position, context: CompletionContext? = nil) {
        self.textDocument = textDocument
        self.position = position
        self.context = context
    }
}

public struct CompletionContext: Codable, Sendable {
    public let triggerKind: CompletionTriggerKind
    public let triggerCharacter: String?

    public init(triggerKind: CompletionTriggerKind, triggerCharacter: String? = nil) {
        self.triggerKind = triggerKind
        self.triggerCharacter = triggerCharacter
    }
}

public enum CompletionTriggerKind: Int, Codable, Sendable {
    case invoked = 1
    case triggerCharacter = 2
    case triggerForIncompleteCompletions = 3
}

public struct DocumentSymbolParams: Codable, Sendable {
    public let textDocument: TextDocumentIdentifier

    public init(textDocument: TextDocumentIdentifier) {
        self.textDocument = textDocument
    }
}

public struct CompletionItemResolveParams: Codable, Sendable {
    public let completionItem: CompletionItem

    public init(completionItem: CompletionItem) {
        self.completionItem = completionItem
    }
}

// MARK: - LSP Result Types

public struct InitializeResult: Codable, Sendable {
    public let capabilities: ServerCapabilities
    public let serverInfo: ServerInfo?

    public init(capabilities: ServerCapabilities, serverInfo: ServerInfo? = nil) {
        self.capabilities = capabilities
        self.serverInfo = serverInfo
    }
}

public struct ServerCapabilities: Codable, Sendable {
    public let textDocumentSync: TextDocumentSyncOptions?
    public let completionProvider: CompletionOptions?
    public let hoverProvider: HoverOptions?
    public let definitionProvider: DefinitionOptions?
    public let referencesProvider: ReferencesOptions?
    public let documentSymbolProvider: DocumentSymbolOptions?

    public init(
        textDocumentSync: TextDocumentSyncOptions? = nil,
        completionProvider: CompletionOptions? = nil,
        hoverProvider: HoverOptions? = nil,
        definitionProvider: DefinitionOptions? = nil,
        referencesProvider: ReferencesOptions? = nil,
        documentSymbolProvider: DocumentSymbolOptions? = nil
    ) {
        self.textDocumentSync = textDocumentSync
        self.completionProvider = completionProvider
        self.hoverProvider = hoverProvider
        self.definitionProvider = definitionProvider
        self.referencesProvider = referencesProvider
        self.documentSymbolProvider = documentSymbolProvider
    }
}

public struct ServerInfo: Codable, Sendable {
    public let name: String
    public let version: String?

    public init(name: String, version: String? = nil) {
        self.name = name
        self.version = version
    }
}

public struct CompletionOptions: Codable, Sendable {
    public let resolveProvider: Bool?
    public let triggerCharacters: [String]?

    public init(resolveProvider: Bool? = nil, triggerCharacters: [String]? = nil) {
        self.resolveProvider = resolveProvider
        self.triggerCharacters = triggerCharacters
    }
}

public struct HoverOptions: Codable, Sendable {
    public let workDoneProgress: Bool?

    public init(workDoneProgress: Bool? = nil) {
        self.workDoneProgress = workDoneProgress
    }
}

public struct DefinitionOptions: Codable, Sendable {
    public let workDoneProgress: Bool?

    public init(workDoneProgress: Bool? = nil) {
        self.workDoneProgress = workDoneProgress
    }
}

public struct ReferencesOptions: Codable, Sendable {
    public let workDoneProgress: Bool?

    public init(workDoneProgress: Bool? = nil) {
        self.workDoneProgress = workDoneProgress
    }
}

public struct DocumentSymbolOptions: Codable, Sendable {
    public let workDoneProgress: Bool?
    public let label: String?

    public init(workDoneProgress: Bool? = nil, label: String? = nil) {
        self.workDoneProgress = workDoneProgress
        self.label = label
    }
}

public struct DefinitionResult: Codable, Sendable {
    public let locations: [Location]

    public init(locations: [Location]) {
        self.locations = locations
    }
}

public struct HoverResult: Codable, Sendable {
    public let contents: MarkedStringOrMarkupContent
    public let range: Range?

    public init(contents: MarkedStringOrMarkupContent, range: Range? = nil) {
        self.contents = contents
        self.range = range
    }
}

public enum MarkedStringOrMarkupContent: Codable, Sendable {
    case string(String)
    case markup(MarkupContent)

    private enum CodingKeys: String, CodingKey {
        case value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let markupValue = try? container.decode(MarkupContent.self) {
            self = .markup(markupValue)
        } else {
            self = .string("")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .markup(let value):
            try container.encode(value)
        }
    }
}

public struct MarkupContent: Codable, Sendable {
    public let kind: MarkupKind
    public let value: String

    public init(kind: MarkupKind, value: String) {
        self.kind = kind
        self.value = value
    }
}

public enum MarkupKind: String, Codable, Sendable {
    case plaintext = "plaintext"
    case markdown = "markdown"
}

public struct CompletionResult: Codable, Sendable {
    public let isIncomplete: Bool
    public let items: [CompletionItem]

    public init(isIncomplete: Bool, items: [CompletionItem]) {
        self.isIncomplete = isIncomplete
        self.items = items
    }
}

public struct CompletionItem: Codable, Sendable {
    public let label: String
    public let kind: CompletionItemKind?
    public let detail: String?
    public let documentation: StringOrMarkupContent?
    public let textEdit: TextEdit?
    public let insertText: String?
    public let sortText: String?
    public let filterText: String?
    public let preselect: Bool?
    public let data: String?

    public init(
        label: String,
        kind: CompletionItemKind? = nil,
        detail: String? = nil,
        documentation: StringOrMarkupContent? = nil,
        textEdit: TextEdit? = nil,
        insertText: String? = nil,
        sortText: String? = nil,
        filterText: String? = nil,
        preselect: Bool? = nil,
        data: String? = nil
    ) {
        self.label = label
        self.kind = kind
        self.detail = detail
        self.documentation = documentation
        self.textEdit = textEdit
        self.insertText = insertText
        self.sortText = sortText
        self.filterText = filterText
        self.preselect = preselect
        self.data = data
    }
}

public enum CompletionItemKind: Int, Codable, Sendable {
    case text = 1
    case method = 2
    case function = 3
    case constructor = 4
    case field = 5
    case variable = 6
    case `class` = 7
    case interface = 8
    case module = 9
    case property = 10
    case unit = 11
    case value = 12
    case enum_ = 13
    case keyword = 14
    case snippet = 15
    case color = 16
    case file = 17
    case reference = 18
    case folder = 19
    case event = 20
    case operator_ = 21
    case typeParameter = 22
}

public enum StringOrMarkupContent: Codable, Sendable {
    case string(String)
    case markup(MarkupContent)

    private enum CodingKeys: String, CodingKey {
        case value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let markupValue = try? container.decode(MarkupContent.self) {
            self = .markup(markupValue)
        } else {
            self = .string("")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .markup(let value):
            try container.encode(value)
        }
    }
}

public struct TextEdit: Codable, Sendable {
    public let range: Range
    public let newText: String

    public init(range: Range, newText: String) {
        self.range = range
        self.newText = newText
    }
}

public struct DocumentSymbol: Codable, Sendable {
    public let name: String
    public let kind: SymbolKind
    public let range: Range
    public let selectionRange: Range
    public let detail: String?
    public let children: [DocumentSymbol]?
    public let uri: String?

    public init(
        name: String,
        kind: SymbolKind,
        range: Range,
        selectionRange: Range,
        detail: String? = nil,
        children: [DocumentSymbol]? = nil,
        uri: String? = nil
    ) {
        self.name = name
        self.kind = kind
        self.range = range
        self.selectionRange = selectionRange
        self.detail = detail
        self.children = children
        self.uri = uri
    }
}

public enum SymbolKind: Int, Codable, Sendable {
    case file = 1
    case module = 2
    case namespace = 3
    case package = 4
    case `class` = 5
    case method = 6
    case property = 7
    case field = 8
    case constructor = 9
    case enum_ = 10
    case interface = 11
    case function = 12
    case variable = 13
    case constant = 14
    case string = 15
    case number = 16
    case boolean = 17
    case array = 18
    case object = 19
    case key = 20
    case null = 21
    case enumMember = 22
    case struct_ = 23
    case event = 24
    case operator_ = 25
    case typeParameter = 26
}

public struct Location: Codable, Sendable {
    public let uri: String
    public let range: Range

    public init(uri: String, range: Range) {
        self.uri = uri
        self.range = range
    }
}

// MARK: - LSP Bridge Message

/// Bridge message for Anigma ↔ LSP communication.
public struct LSPBridgeMessage: Codable, Sendable {
    public let version: DevelopumBridgeVersion
    public let type: DevelopumMessageType
    public let messageId: String
    public let sessionId: String
    public let repoId: String?
    public let timestampMs: Int64
    public let payload: LSPBridgePayload

    public init(
        version: DevelopumBridgeVersion = .v1,
        type: DevelopumMessageType,
        messageId: String = UUID().uuidString,
        sessionId: String,
        repoId: String? = nil,
        timestampMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        payload: LSPBridgePayload
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

public enum LSPBridgePayload: Codable, Sendable {
    case lspRequest(LSPRequestPayload)
    case lspResponse(LSPResponsePayload)
    case lspNotification(LSPNotificationPayload)
    case lspError(LSPErrorPayload)
    case connectionState(ConnectionStatePayload)
    case serverCapabilities(ServerCapabilitiesPayload)

    private enum CodingKeys: String, CodingKey {
        case type
        case payload
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "lspRequest":
            let payload = try container.decode(LSPRequestPayload.self, forKey: .payload)
            self = .lspRequest(payload)
        case "lspResponse":
            let payload = try container.decode(LSPResponsePayload.self, forKey: .payload)
            self = .lspResponse(payload)
        case "lspNotification":
            let payload = try container.decode(LSPNotificationPayload.self, forKey: .payload)
            self = .lspNotification(payload)
        case "lspError":
            let payload = try container.decode(LSPErrorPayload.self, forKey: .payload)
            self = .lspError(payload)
        case "connectionState":
            let payload = try container.decode(ConnectionStatePayload.self, forKey: .payload)
            self = .connectionState(payload)
        case "serverCapabilities":
            let payload = try container.decode(ServerCapabilitiesPayload.self, forKey: .payload)
            self = .serverCapabilities(payload)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown payload type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .lspRequest(let payload):
            try container.encode("lspRequest", forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .lspResponse(let payload):
            try container.encode("lspResponse", forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .lspNotification(let payload):
            try container.encode("lspNotification", forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .lspError(let payload):
            try container.encode("lspError", forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .connectionState(let payload):
            try container.encode("connectionState", forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .serverCapabilities(let payload):
            try container.encode("serverCapabilities", forKey: .type)
            try container.encode(payload, forKey: .payload)
        }
    }
}

public struct LSPRequestPayload: Codable, Sendable {
    public let lspMethod: LSPMethod
    public let lspId: String
    public let lspParams: Data

    public init(lspMethod: LSPMethod, lspId: String, lspParams: Data) {
        self.lspMethod = lspMethod
        self.lspId = lspId
        self.lspParams = lspParams
    }
}

public struct LSPResponsePayload: Codable, Sendable {
    public let lspId: String
    public let lspResult: Data?
    public let lspError: String?

    public init(lspId: String, lspResult: Data?, lspError: String? = nil) {
        self.lspId = lspId
        self.lspResult = lspResult
        self.lspError = lspError
    }
}

public struct LSPNotificationPayload: Codable, Sendable {
    public let lspMethod: LSPMethod
    public let lspParams: Data

    public init(lspMethod: LSPMethod, lspParams: Data) {
        self.lspMethod = lspMethod
        self.lspParams = lspParams
    }
}

public struct LSPErrorPayload: Codable, Sendable {
    public let code: LSPCode
    public let message: String
    public let data: String?

    public init(code: LSPCode, message: String, data: String? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }
}

public struct ConnectionStatePayload: Codable, Sendable {
    public let state: ConnectionState
    public let serverName: String?
    public let errorMessage: String?

    public init(state: ConnectionState, serverName: String? = nil, errorMessage: String? = nil) {
        self.state = state
        self.serverName = serverName
        self.errorMessage = errorMessage
    }
}

public enum ConnectionState: String, Codable, Sendable {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case error
}

public struct ServerCapabilitiesPayload: Codable, Sendable {
    public let capabilities: ServerCapabilities
    public let serverInfo: ServerInfo?

    public init(capabilities: ServerCapabilities, serverInfo: ServerInfo? = nil) {
        self.capabilities = capabilities
        self.serverInfo = serverInfo
    }
}

// MARK: - LSP Connection

/// Manages LSP server connections with lifecycle control.
public actor LSPConnection {
    private let repoId: UUID
    private let repoPath: String
    private let transportType: LSPTransportType
    private let lspServerPath: String
    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var tcpClient: TCPClient?
    private var isConnected: Bool = false
    private var reconnectAttempts: Int = 0
    private let maxReconnectAttempts: Int = 3
    private var pendingRequests: [String: (Data?) -> Void] = [:]
    private var messageIdCounter: Int = 0

    public enum LSPTransportType: String, Codable, Sendable {
        case stdio
        case tcp
    }

    public init(
        repoId: UUID,
        repoPath: String,
        transportType: LSPTransportType = .stdio,
        lspServerPath: String = "sourcekit-lsp"
    ) {
        self.repoId = repoId
        self.repoPath = repoPath
        self.transportType = transportType
        self.lspServerPath = lspServerPath
    }

    // MARK: - Connection Lifecycle

    public func connect() async throws {
        logInfo("Connecting to LSP server (\(transportType.rawValue)) for repo: \(repoId.uuidString)", category: "LSPConnection")

        switch transportType {
        case .stdio:
            try await connectStdio()
        case .tcp:
            try await connectTCP()
        }

        isConnected = true
        reconnectAttempts = 0
        startMessageReader()
    }

    public func disconnect() {
        logInfo("Disconnecting from LSP server for repo: \(repoId.uuidString)", category: "LSPConnection")

        isConnected = false

        switch transportType {
        case .stdio:
            disconnectStdio()
        case .tcp:
            disconnectTCP()
        }

        for (_, callback) in pendingRequests {
            callback(nil)
        }
        pendingRequests.removeAll()
    }

    public func reconnect() async throws {
        guard reconnectAttempts < maxReconnectAttempts else {
            throw LSPConnectionError.maxReconnectAttemptsReached
        }

        disconnect()
        reconnectAttempts += 1
        try await connect()
    }

    private func connectStdio() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: lspServerPath)
        process.arguments = []

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()

        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe

        try process.run()
        process.waitUntilExit()

        self.process = process
        self.stdinPipe = stdinPipe
        self.stdoutPipe = stdoutPipe
    }

    private func disconnectStdio() {
        process?.terminate()
        process = nil
        stdinPipe = nil
        stdoutPipe = nil
    }

    private func connectTCP() async throws {
        let client = TCPClient(host: "127.0.0.1", port: 8080)
        try await client.connect()
        self.tcpClient = client
    }

    private func disconnectTCP() {
        tcpClient?.disconnect()
        tcpClient = nil
    }

    private func startMessageReader() {
        Task {
            await readMessages()
        }
    }

    private func readMessages() async {
        while isConnected {
            do {
                let messageData: Data
                switch transportType {
                case .stdio:
                    guard let pipe = stdoutPipe else { break }
                    let data = try await readFromPipe(pipe)
                    messageData = data
                case .tcp:
                    guard let client = tcpClient else { break }
                    let data = try await client.read()
                    messageData = data
                }

                if let message = parseMessage(messageData) {
                    await handleMessage(message)
                }
            } catch {
                logError("Error reading LSP message: \(error)", category: "LSPConnection")
            }
        }
    }

    private func readFromPipe(_ pipe: Pipe) async throws -> Data {
        return Data()
    }

    private func parseMessage(_ data: Data) -> LSPMessage? {
        guard let messageString = String(data: data, encoding: .utf8) else {
            return nil
        }

        let contentLength = parseContentLength(from: messageString)
        guard let contentLengthValue = contentLength,
              let jsonStart = messageString.range(of: "\r\n\r\n") else {
            return nil
        }

        let jsonStartIndex = messageString.distance(from: messageString.startIndex, to: jsonStart.upperBound)
        let jsonString = String(messageString[messageString.index(messageString.startIndex, offsetBy: jsonStartIndex)...])

        guard let jsonData = jsonString.data(using: .utf8) else {
            return nil
        }

        return try? JSONDecoder().decode(LSPMessage.self, from: jsonData)
    }

    private func parseContentLength(from message: String) -> Int? {
        guard let range = message.range(of: "Content-Length:") else { return nil }
        let afterPrefix = message[range.upperBound...]
        let endOfLine = afterPrefix.firstIndex(of: "\r") ?? afterPrefix.endIndex
        let numberString = String(afterPrefix[..<endOfLine]).trimmingCharacters(in: .whitespaces)
        return Int(numberString)
    }

    private func handleMessage(_ message: LSPMessage) async {
        if let id = message.id {
            if let callback = pendingRequests.removeValue(forKey: id) {
                if let result = message.result {
                    callback(try? JSONEncoder().encode(result))
                } else if let error = message.error {
                    let errorData = try? JSONEncoder().encode(error)
                    callback(errorData)
                }
            }
        }

        if let method = message.method {
            await handleNotification(method: method, params: message.params)
        }
    }

    private func handleNotification(method: LSPMethod, params: LSPParams?) async {
        switch method {
        case .windowShowMessage:
            if case .some(.initialize(let result)) = params {
                logInfo("LSP server info: \(result.serverInfo?.name ?? "unknown")", category: "LSPConnection")
            }
        case .telemetryEvent:
            break
        default:
            break
        }
    }

    // MARK: - Request/Response

    @discardableResult
    public func sendRequest<T: Decodable>(
        _ method: LSPMethod,
        params: any Encodable,
        responseType: T.Type
    ) async throws -> T {
        let id = generateMessageId()
        let paramsData = try JSONEncoder().encode(params)

        let lspMessage: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id,
            "method": method.rawValue,
            "params": try JSONSerialization.jsonObject(with: paramsData) as? [String: Any] ?? [:]
        ]

        let messageData = try JSONSerialization.data(withJSONObject: lspMessage)
        try await sendMessage(messageData)

        return try await withCheckedThrowingContinuation { continuation in
            pendingRequests[id] = { resultData in
                guard let resultData = resultData else {
                    continuation.resume(throwing: LSPConnectionError.noResponse)
                    return
                }

                do {
                    let result = try JSONDecoder().decode(T.self, from: resultData)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: LSPConnectionError.responseParseError(error))
                }
            }
        }
    }

    public func sendNotification(_ method: LSPMethod, params: any Encodable) async throws {
        let paramsData = try JSONEncoder().encode(params)

        let lspMessage: [String: Any] = [
            "jsonrpc": "2.0",
            "method": method.rawValue,
            "params": try JSONSerialization.jsonObject(with: paramsData) as? [String: Any] ?? [:]
        ]

        let messageData = try JSONSerialization.data(withJSONObject: lspMessage)
        try await sendMessage(messageData)
    }

    private func sendMessage(_ data: Data) async throws {
        let contentLength = data.count
        let header = "Content-Length: \(contentLength)\r\n\r\n"
        let headerData = header.data(using: .utf8)!
        var fullMessage = headerData
        fullMessage.append(data)

        switch transportType {
        case .stdio:
            guard let pipe = stdinPipe else {
                throw LSPConnectionError.notConnected
            }
            pipe.fileHandleForWriting.write(fullMessage)
        case .tcp:
            guard let client = tcpClient else {
                throw LSPConnectionError.notConnected
            }
            try await client.send(fullMessage)
        }
    }

    private func generateMessageId() -> String {
        messageIdCounter += 1
        return String(messageIdCounter)
    }
}

// MARK: - TCP Client

public actor TCPClient {
    private let host: String
    private let port: Int
    private var socket: Int32 = -1
    private var isConnected: Bool = false
    private var receiveTask: Task<Void, Never>?

    public init(host: String, port: Int) {
        self.host = host
        self.port = port
    }

    public func connect() async throws {
        socket = Darwin.socket(Darwin.AF_INET, Darwin.SOCK_STREAM, 0)
        guard socket >= 0 else {
            throw TCPClientError.socketCreationFailed
        }

        var hints = addrinfo()
        hints.ai_family = Darwin.AF_INET
        hints.ai_socktype = Darwin.SOCK_STREAM
        hints.ai_protocol = Darwin.IPPROTO_TCP

        var result: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, String(port), &hints, &result) == 0 else {
            throw TCPClientError.dnsResolutionFailed
        }
        defer { freeaddrinfo(result) }

        let sockaddr = result.pointee
        guard Darwin.connect(socket, sockaddr.pointee.ai_addr, sockaddr.pointee.ai_addrlen) == 0 else {
            throw TCPClientError.connectionFailed
        }

        isConnected = true
        receiveTask = Task {
            await receiveLoop()
        }
    }

    public func disconnect() {
        isConnected = false
        receiveTask?.cancel()
        receiveTask = nil
        if socket >= 0 {
            Darwin.close(socket)
            socket = -1
        }
    }

    public func send(_ data: Data) async throws {
        guard isConnected, socket >= 0 else {
            throw TCPClientError.notConnected
        }

        var bytesSent = 0
        let totalBytes = data.count
        let buffer = [UInt8](data)

        while bytesSent < totalBytes {
            let result = Darwin.send(socket, buffer + bytesSent, totalBytes - bytesSent, 0)
            guard result > 0 else {
                throw TCPClientError.sendFailed
            }
            bytesSent += result
        }
    }

    public func read() async throws -> Data {
        guard isConnected, socket >= 0 else {
            throw TCPClientError.notConnected
        }

        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = Darwin.read(socket, &buffer, 4096)

        guard bytesRead > 0 else {
            throw TCPClientError.readFailed
        }

        return Data(buffer[0..<bytesRead])
    }

    private func receiveLoop() async {
        while isConnected {
            do {
                _ = try await read()
            } catch {
                break
            }
        }
    }
}

public enum TCPClientError: Error, LocalizedError {
    case socketCreationFailed
    case dnsResolutionFailed
    case connectionFailed
    case notConnected
    case sendFailed
    case readFailed

    public var errorDescription: String? {
        switch self {
        case .socketCreationFailed:
            return "Failed to create socket"
        case .dnsResolutionFailed:
            return "DNS resolution failed"
        case .connectionFailed:
            return "Connection failed"
        case .notConnected:
            return "Not connected"
        case .sendFailed:
            return "Send failed"
        case .readFailed:
            return "Read failed"
        }
    }
}

// MARK: - LSP Connection Errors

public enum LSPConnectionError: Error, LocalizedError {
    case notConnected
    case maxReconnectAttemptsReached
    case noResponse
    case responseParseError(Error)
    case serverError(LSPCode, String)

    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "LSP server not connected"
        case .maxReconnectAttemptsReached:
            return "Maximum reconnect attempts reached"
        case .noResponse:
            return "No response from LSP server"
        case .responseParseError(let error):
            return "Failed to parse LSP response: \(error)"
        case .serverError(let code, let message):
            return "LSP server error (\(code.rawValue)): \(message)"
        }
    }
}

// MARK: - DevelopumLSPBridge

/// Main LSP Bridge service for semantic navigation in Develop mode.
public actor DevelopumLSPBridge {
    private let databaseService: DevelopumDatabaseService
    private let receiptService: DevelopumReceiptService?
    private let connections: [UUID: LSPConnection]
    private let defaultLSPPath: String
    private let telemetryClient: TelemetryClient?

    public init(
        databaseService: DevelopumDatabaseService,
        receiptService: DevelopumReceiptService? = nil,
        defaultLSPPath: String = "sourcekit-lsp",
        telemetryClient: TelemetryClient? = nil
    ) {
        self.databaseService = databaseService
        self.receiptService = receiptService
        self.connections = [:]
        self.defaultLSPPath = defaultLSPPath
        self.telemetryClient = telemetryClient
    }

    // MARK: - Connection Management

    public func initialize(
        repoId: UUID,
        repoPath: String,
        transportType: LSPConnection.LSPTransportType = .stdio
    ) async throws -> ServerCapabilities {
        logInfo("Initializing LSP bridge for repo: \(repoId.uuidString)", category: "DevelopumLSPBridge")

        let connection = LSPConnection(
            repoId: repoId,
            repoPath: repoPath,
            transportType: transportType,
            lspServerPath: defaultLSPPath
        )

        try await connection.connect()

        let params = InitializeParams(
            processId: ProcessInfo.processInfo.processIdentifier,
            rootUri: AnigmaVirtualURI.documentURI(repoId: repoId, filePath: repoPath),
            initializationOptions: InitializationOptions(
                anigmaOptions: AnigmaLSPOptions(
                    repoId: repoId.uuidString,
                    repoPath: repoPath
                )
            ),
            capabilities: ClientCapabilities(
                textDocument: TextDocumentClientCapabilities(
                    synchronization: TextDocumentSyncOptions(openClose: true, change: .incremental),
                    completion: CompletionCapabilities(
                        dynamicRegistration: true,
                        completionItem: CompletionItemCapabilities(snippetSupport: true)
                    ),
                    hover: HoverCapabilities(dynamicRegistration: true),
                    definition: DefinitionCapabilities(dynamicRegistration: true, linkSupport: true),
                    references: ReferencesCapabilities(dynamicRegistration: true),
                    documentSymbol: DocumentSymbolCapabilities(
                        dynamicRegistration: true,
                        hierarchicalDocumentSymbolSupport: true
                    )
                ),
                workspace: WorkspaceClientCapabilities(applyEdit: true, workspaceFolders: true)
            )
        )

        let result: InitializeResult = try await connection.sendRequest(
            .initialize,
            params: params,
            responseType: InitializeResult.self
        )

        try await connection.sendNotification(.initialized, params: InitializedParams())

        if let receiptService = receiptService {
            let inputs = [
                "repoId": .string(repoId.uuidString),
                "repoPath": .string(repoPath),
                "transportType": .string(transportType.rawValue),
                "serverName": .string(result.serverInfo?.name ?? "unknown")
            ]
            let inputsHash = TelemetryHash.compute(from: inputs)
            let _ = ReceiptWire.create(
                actionName: "developum.lsp.initialize",
                authority: "DevelopumModule",
                decision: .allowed,
                reasonCode: "initialized",
                timestampMs: Int64(Date().timeIntervalSince1970 * 1000),
                inputsHash: inputsHash,
                outputsHash: nil,
                previousReceiptHash: nil,
                metadata: inputs
            )
        }

        logInfo("LSP bridge initialized for repo: \(repoId.uuidString)", category: "DevelopumLSPBridge")

        return result.capabilities
    }

    public func shutdown(repoId: UUID) async throws {
        logInfo("Shutting down LSP bridge for repo: \(repoId.uuidString)", category: "DevelopumLSPBridge")

        guard let connection = connections[repoId] else {
            return
        }

        try await connection.sendRequest(
            .shutdown,
            params: ShutdownParams(),
            responseType: Void.self
        )

        await connection.disconnect()

        if let receiptService = receiptService {
            let inputs = ["repoId": .string(repoId.uuidString)]
            let inputsHash = TelemetryHash.compute(from: inputs)
            let _ = ReceiptWire.create(
                actionName: "developum.lsp.shutdown",
                authority: "DevelopumModule",
                decision: .allowed,
                reasonCode: "shutdown",
                timestampMs: Int64(Date().timeIntervalSince1970 * 1000),
                inputsHash: inputsHash,
                outputsHash: nil,
                previousReceiptHash: nil,
                metadata: inputs
            )
        }
    }

    private func getConnection(for repoId: UUID) throws -> LSPConnection {
        guard let connection = connections[repoId] else {
            throw LSPConnectionError.notConnected
        }
        return connection
    }

    // MARK: - Document Operations

    public func openDocument(
        repoId: UUID,
        filePath: String,
        content: String,
        languageId: String
    ) async throws {
        logInfo("Opening document: \(filePath)", category: "DevelopumLSPBridge")

        guard let connection = connections[repoId] else {
            throw LSPConnectionError.notConnected
        }

        let uri = AnigmaVirtualURI.documentURI(repoId: repoId, filePath: filePath)
        let textDocument = TextDocumentItem(
            uri: uri,
            languageId: languageId,
            version: 1,
            text: content
        )

        try await connection.sendNotification(
            .textDocumentDidOpen,
            params: DidOpenTextDocumentParams(textDocument: textDocument)
        )

        if let receiptService = receiptService {
            let inputs = [
                "repoId": .string(repoId.uuidString),
                "filePath": .string(filePath),
                "languageId": .string(languageId),
                "uri": .string(uri)
            ]
            let inputsHash = TelemetryHash.compute(from: inputs)
            let _ = ReceiptWire.create(
                actionName: "developum.lsp.openDocument",
                authority: "DevelopumModule",
                decision: .allowed,
                reasonCode: "opened",
                timestampMs: Int64(Date().timeIntervalSince1970 * 1000),
                inputsHash: inputsHash,
                outputsHash: nil,
                previousReceiptHash: nil,
                metadata: inputs
            )
        }
    }

    public func closeDocument(repoId: UUID, filePath: String) async throws {
        logInfo("Closing document: \(filePath)", category: "DevelopumLSPBridge")

        guard let connection = connections[repoId] else {
            throw LSPConnectionError.notConnected
        }

        let uri = AnigmaVirtualURI.documentURI(repoId: repoId, filePath: filePath)

        try await connection.sendNotification(
            .textDocumentDidClose,
            params: DidCloseTextDocumentParams(
                textDocument: TextDocumentIdentifier(uri: uri)
            )
        )

        if let receiptService = receiptService {
            let inputs = [
                "repoId": .string(repoId.uuidString),
                "filePath": .string(filePath),
                "uri": .string(uri)
            ]
            let inputsHash = TelemetryHash.compute(from: inputs)
            let _ = ReceiptWire.create(
                actionName: "developum.lsp.closeDocument",
                authority: "DevelopumModule",
                decision: .allowed,
                reasonCode: "closed",
                timestampMs: Int64(Date().timeIntervalSince1970 * 1000),
                inputsHash: inputsHash,
                outputsHash: nil,
                previousReceiptHash: nil,
                metadata: inputs
            )
        }
    }

    // MARK: - Semantic Navigation

    public func definition(
        repoId: UUID,
        filePath: String,
        line: Int,
        column: Int
    ) async throws -> [Location] {
        logInfo("Getting definition for \(filePath):\(line):\(column)", category: "DevelopumLSPBridge")

        guard let connection = connections[repoId] else {
            throw LSPConnectionError.notConnected
        }

        let uri = AnigmaVirtualURI.documentURI(repoId: repoId, filePath: filePath)
        let params = DefinitionParams(
            textDocument: TextDocumentIdentifier(uri: uri),
            position: Position(line: line, character: column)
        )

        let result: DefinitionResult = try await connection.sendRequest(
            .textDocumentDefinition,
            params: params,
            responseType: DefinitionResult.self
        )

        if let receiptService = receiptService {
            let inputs = [
                "repoId": .string(repoId.uuidString),
                "filePath": .string(filePath),
                "line": .int(line),
                "column": .int(column),
                "resultCount": .int(result.locations.count)
            ]
            let inputsHash = TelemetryHash.compute(from: inputs)
            let _ = ReceiptWire.create(
                actionName: "developum.lsp.definition",
                authority: "DevelopumModule",
                decision: .allowed,
                reasonCode: "found",
                timestampMs: Int64(Date().timeIntervalSince1970 * 1000),
                inputsHash: inputsHash,
                outputsHash: nil,
                previousReceiptHash: nil,
                metadata: inputs
            )
        }

        return result.locations
    }

    public func references(
        repoId: UUID,
        filePath: String,
        line: Int,
        column: Int,
        includeDeclaration: Bool = true
    ) async throws -> [Location] {
        logInfo("Getting references for \(filePath):\(line):\(column)", category: "DevelopumLSPBridge")

        guard let connection = connections[repoId] else {
            throw LSPConnectionError.notConnected
        }

        let uri = AnigmaVirtualURI.documentURI(repoId: repoId, filePath: filePath)
        let params = ReferenceParams(
            textDocument: TextDocumentIdentifier(uri: uri),
            position: Position(line: line, character: column),
            context: ReferenceContext(includeDeclaration: includeDeclaration)
        )

        let locations: [Location] = try await connection.sendRequest(
            .textDocumentReferences,
            params: params,
            responseType: [Location].self
        )

        if let receiptService = receiptService {
            let inputs = [
                "repoId": .string(repoId.uuidString),
                "filePath": .string(filePath),
                "line": .int(line),
                "column": .int(column),
                "includeDeclaration": .bool(includeDeclaration),
                "resultCount": .int(locations.count)
            ]
            let inputsHash = TelemetryHash.compute(from: inputs)
            let _ = ReceiptWire.create(
                actionName: "developum.lsp.references",
                authority: "DevelopumModule",
                decision: .allowed,
                reasonCode: "found",
                timestampMs: Int64(Date().timeIntervalSince1970 * 1000),
                inputsHash: inputsHash,
                outputsHash: nil,
                previousReceiptHash: nil,
                metadata: inputs
            )
        }

        return locations
    }

    public func hover(
        repoId: UUID,
        filePath: String,
        line: Int,
        column: Int
    ) async throws -> HoverResult? {
        logInfo("Getting hover for \(filePath):\(line):\(column)", category: "DevelopumLSPBridge")

        guard let connection = connections[repoId] else {
            throw LSPConnectionError.notConnected
        }

        let uri = AnigmaVirtualURI.documentURI(repoId: repoId, filePath: filePath)
        let params = HoverParams(
            textDocument: TextDocumentIdentifier(uri: uri),
            position: Position(line: line, character: column)
        )

        let result: HoverResult? = try await connection.sendRequest(
            .textDocumentHover,
            params: params,
            responseType: HoverResult?.self
        )

        if let receiptService = receiptService {
            let inputs = [
                "repoId": .string(repoId.uuidString),
                "filePath": .string(filePath),
                "line": .int(line),
                "column": .int(column),
                "hasContent": .bool(result != nil)
            ]
            let inputsHash = TelemetryHash.compute(from: inputs)
            let _ = ReceiptWire.create(
                actionName: "developum.lsp.hover",
                authority: "DevelopumModule",
                decision: .allowed,
                reasonCode: "queried",
                timestampMs: Int64(Date().timeIntervalSince1970 * 1000),
                inputsHash: inputsHash,
                outputsHash: nil,
                previousReceiptHash: nil,
                metadata: inputs
            )
        }

        return result
    }

    public func completion(
        repoId: UUID,
        filePath: String,
        line: Int,
        column: Int,
        triggerCharacter: String? = nil,
        triggerKind: CompletionTriggerKind = .invoked
    ) async throws -> CompletionResult {
        logInfo("Getting completion for \(filePath):\(line):\(column)", category: "DevelopumLSPBridge")

        guard let connection = connections[repoId] else {
            throw LSPConnectionError.notConnected
        }

        let uri = AnigmaVirtualURI.documentURI(repoId: repoId, filePath: filePath)
        let context = triggerCharacter != nil
            ? CompletionContext(triggerKind: triggerKind, triggerCharacter: triggerCharacter)
            : nil
        let params = CompletionParams(
            textDocument: TextDocumentIdentifier(uri: uri),
            position: Position(line: line, character: column),
            context: context
        )

        let result: CompletionResult = try await connection.sendRequest(
            .textDocumentCompletion,
            params: params,
            responseType: CompletionResult.self
        )

        if let receiptService = receiptService {
            let inputs = [
                "repoId": .string(repoId.uuidString),
                "filePath": .string(filePath),
                "line": .int(line),
                "column": .int(column),
                "itemCount": .int(result.items.count)
            ]
            let inputsHash = TelemetryHash.compute(from: inputs)
            let _ = ReceiptWire.create(
                actionName: "developum.lsp.completion",
                authority: "DevelopumModule",
                decision: .allowed,
                reasonCode: "provided",
                timestampMs: Int64(Date().timeIntervalSince1970 * 1000),
                inputsHash: inputsHash,
                outputsHash: nil,
                previousReceiptHash: nil,
                metadata: inputs
            )
        }

        return result
    }

    public func documentSymbols(repoId: UUID, filePath: String) async throws -> [DocumentSymbol] {
        logInfo("Getting document symbols for \(filePath)", category: "DevelopumLSPBridge")

        guard let connection = connections[repoId] else {
            throw LSPConnectionError.notConnected
        }

        let uri = AnigmaVirtualURI.documentURI(repoId: repoId, filePath: filePath)
        let params = DocumentSymbolParams(
            textDocument: TextDocumentIdentifier(uri: uri)
        )

        let symbols: [DocumentSymbol] = try await connection.sendRequest(
            .textDocumentDocumentSymbol,
            params: params,
            responseType: [DocumentSymbol].self
        )

        if let receiptService = receiptService {
            let inputs = [
                "repoId": .string(repoId.uuidString),
                "filePath": .string(filePath),
                "symbolCount": .int(symbols.count)
            ]
            let inputsHash = TelemetryHash.compute(from: inputs)
            let _ = ReceiptWire.create(
                actionName: "developum.lsp.documentSymbols",
                authority: "DevelopumModule",
                decision: .allowed,
                reasonCode: "queried",
                timestampMs: Int64(Date().timeIntervalSince1970 * 1000),
                inputsHash: inputsHash,
                outputsHash: nil,
                previousReceiptHash: nil,
                metadata: inputs
            )
        }

        return symbols
    }

    // MARK: - Bridge Message Generation

    public func createBridgeMessage(
        sessionId: String,
        repoId: UUID,
        type: DevelopumMessageType,
        payload: LSPBridgePayload
    ) -> LSPBridgeMessage {
        return LSPBridgeMessage(
            type: type,
            sessionId: sessionId,
            repoId: repoId.uuidString,
            payload: payload
        )
    }
}
