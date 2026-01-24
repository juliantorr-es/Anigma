//
//  LSPParameterTypes.swift
//  DevelopumModule
//
//  LSP parameter structures and associated types.
//  Extracted from DevelopumLSPBridge.swift
//

import Foundation

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
