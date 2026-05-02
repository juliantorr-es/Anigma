//
//  LSPResultTypes.swift
//  DevelopumModule
//
//  LSP result structures and associated types.
//  Extracted from DevelopumLSPBridge.swift
//

import Foundation

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
            try container.encode(LSPResultValue(locations), forKey: .result)
        case .hover(let result):
            try container.encode(LSPResultValue(result), forKey: .result)
        case .completion(let result):
            try container.encode(LSPResultValue(result), forKey: .result)
        case .documentSymbol(let symbols):
            try container.encode(LSPResultValue(symbols), forKey: .result)
        case .completionItemResolve(let item):
            try container.encode(LSPResultValue(item), forKey: .result)
        case .none:
            try container.encode(LSPResultValue(isNull: true), forKey: .result)
        }
    }
}

// AnyEncodable and AnyDecodable removed in favor of AnyCodable from LSPMessageTypes.swift

public struct LSPResultValue: Codable, Sendable {
    public let isNull: Bool
    public let arrayValue: [AnyCodable]?
    public let dictionaryValue: [String: AnyCodable]?

    public init(isNull: Bool = false, arrayValue: [AnyCodable]? = nil, dictionaryValue: [String: AnyCodable]? = nil) {
        self.isNull = isNull
        self.arrayValue = arrayValue
        self.dictionaryValue = dictionaryValue
    }

    public init<T: Encodable>(_ value: T) {
        // Use AnyCodable
        let anyVal = AnyCodable(value)
        // To properly structure it as dictionary or array for LSPResultValue, we check the type
        let data = try! JSONEncoder().encode(anyVal)
        if let dict = try? JSONDecoder().decode([String: AnyCodable].self, from: data) {
            self.dictionaryValue = dict
            self.arrayValue = nil
            self.isNull = false
        } else if let arr = try? JSONDecoder().decode([AnyCodable].self, from: data) {
            self.dictionaryValue = nil
            self.arrayValue = arr
            self.isNull = false
        } else {
             self.dictionaryValue = nil
             self.arrayValue = nil
             self.isNull = false
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if isNull {
            try container.encodeNil()
        } else if let arrayValue = arrayValue {
            try container.encode(arrayValue)
        } else if let dictionaryValue = dictionaryValue {
            try container.encode(dictionaryValue)
        } else {
            try container.encodeNil()
        }
    }
}


public struct ServerCapabilities: Codable, Sendable {
    public let textDocumentSync: TextDocumentSyncOptions?
    public let completionProvider: CompletionOptions?
    public let hoverProvider: Bool?
    public let definitionProvider: Bool?
    public let referencesProvider: Bool?
    public let documentSymbolProvider: Bool?

    public init(
        textDocumentSync: TextDocumentSyncOptions? = nil,
        completionProvider: CompletionOptions? = nil,
        hoverProvider: Bool? = nil,
        definitionProvider: Bool? = nil,
        referencesProvider: Bool? = nil,
        documentSymbolProvider: Bool? = nil
    ) {
        self.textDocumentSync = textDocumentSync
        self.completionProvider = completionProvider
        self.hoverProvider = hoverProvider
        self.definitionProvider = definitionProvider
        self.referencesProvider = referencesProvider
        self.documentSymbolProvider = documentSymbolProvider
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

public struct ServerInfo: Codable, Sendable {
    public let name: String
    public let version: String?

    public init(name: String, version: String? = nil) {
        self.name = name
        self.version = version
    }
}

public struct InitializeResult: Codable, Sendable {
    public let capabilities: ServerCapabilities
    public let serverInfo: ServerInfo?

    public init(capabilities: ServerCapabilities, serverInfo: ServerInfo? = nil) {
        self.capabilities = capabilities
        self.serverInfo = serverInfo
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

public struct Location: Codable, Sendable {
    public let uri: String
    public let range: Range

    public init(uri: String, range: Range) {
        self.uri = uri
        self.range = range
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

// MARK: - Generic Types

// AnyEncodable/AnyDecodable removed
