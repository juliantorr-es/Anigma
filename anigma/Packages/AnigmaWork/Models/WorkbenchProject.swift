import Foundation

public struct WorkbenchProject: Codable, Sendable, Identifiable {
    public let id: UUID
    public var name: String
    public var documents: [DocumentIR]
    public var sheets: [SheetIR]
    public var decks: [DeckIR]
    public var assets: [AnigmaAsset]

    public init(id: UUID = UUID(), name: String, documents: [DocumentIR] = [], sheets: [SheetIR] = [], decks: [DeckIR] = [], assets: [AnigmaAsset] = []) {
        self.id = id
        self.name = name
        self.documents = documents
        self.sheets = sheets
        self.decks = decks
        self.assets = assets
    }
}

public struct AnigmaAsset: Codable, Sendable, Identifiable {
    public let id: UUID
    public var name: String
    public var type: AssetType
    public var url: URL? // Local or remote URL
    public var provenance: String? // Description of origin

    public init(id: UUID = UUID(), name: String, type: AssetType, url: URL? = nil, provenance: String? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.url = url
        self.provenance = provenance
    }
}

public enum AssetType: String, Codable, Sendable {
    case image
    case audio
    case video
    case dataset
    case pdf
    case other
}
