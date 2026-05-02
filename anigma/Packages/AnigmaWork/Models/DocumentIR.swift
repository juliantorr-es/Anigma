import Foundation

public struct DocumentIR: Codable, Sendable, Identifiable {
    public let id: UUID
    public var title: String
    public var blocks: [DocumentBlock]
    public var metadata: [String: String]

    public init(id: UUID = UUID(), title: String, blocks: [DocumentBlock] = [], metadata: [String: String] = [:]) {
        self.id = id
        self.title = title
        self.blocks = blocks
        self.metadata = metadata
    }
}

public enum DocumentBlock: Codable, Sendable, Identifiable {
    case paragraph(id: UUID, text: String, style: String?)
    case heading(id: UUID, text: String, level: Int)
    case list(id: UUID, items: [String], ordered: Bool)
    case table(id: UUID, rows: [[String]])
    case image(id: UUID, assetId: String, caption: String?)

    public var id: UUID {
        switch self {
        case .paragraph(let id, _, _): return id
        case .heading(let id, _, _): return id
        case .list(let id, _, _): return id
        case .table(let id, _): return id
        case .image(let id, _, _): return id
        }
    }
}
