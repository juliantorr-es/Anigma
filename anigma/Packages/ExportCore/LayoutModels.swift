import Foundation

public struct LayoutIR: Sendable, Codable, Hashable {
    public let id: String
    public let blocks: [LayoutBlock]
    public let pages: [LayoutPage]

    public init(id: String, blocks: [LayoutBlock], pages: [LayoutPage]) {
        self.id = id
        self.blocks = blocks
        self.pages = pages
    }
}

public struct LayoutBlock: Sendable, Codable, Hashable {
    public let id: String
    public let type: String // "text", "image", "table"
    public let contentRef: String
    public let frame: CGRect

    public init(id: String, type: String, contentRef: String, frame: CGRect) {
        self.id = id
        self.type = type
        self.contentRef = contentRef
        self.frame = frame
    }
}

public struct LayoutPage: Sendable, Codable, Hashable {
    public let index: Int
    public let size: CGSize
    public let blockIds: [String]

    public init(index: Int, size: CGSize, blockIds: [String]) {
        self.index = index
        self.size = size
        self.blockIds = blockIds
    }
}

public struct LayoutPatch: Sendable, Codable, Hashable {
    public enum Operation: Sendable, Codable, Hashable {
        case moveBlock(id: String, to: CGPoint)
        case resizeBlock(id: String, size: CGSize)
        case changeMargin(pageIndex: Int, margin: EdgeInsets)
    }

    public let id: String
    public let baseIRId: String
    public let operations: [Operation]

    public init(id: String, baseIRId: String, operations: [Operation]) {
        self.id = id
        self.baseIRId = baseIRId
        self.operations = operations
    }
}

public struct EdgeInsets: Sendable, Codable, Hashable {
    public var top: Double
    public var leading: Double
    public var bottom: Double
    public var trailing: Double

    public init(top: Double, leading: Double, bottom: Double, trailing: Double) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }
}

// Helper for CGRect/CGSize/CGPoint codable
// Note: CoreGraphics provides Codable conformance on recent platforms.
// If building for older platforms, uncomment these.
/*
extension CGRect: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(Double.self, forKey: .x)
        let y = try container.decode(Double.self, forKey: .y)
        let width = try container.decode(Double.self, forKey: .width)
        let height = try container.decode(Double.self, forKey: .height)
        self.init(x: x, y: y, width: width, height: height)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(origin.x, forKey: .x)
        try container.encode(origin.y, forKey: .y)
        try container.encode(size.width, forKey: .width)
        try container.encode(size.height, forKey: .height)
    }
    
    enum CodingKeys: String, CodingKey {
        case x, y, width, height
    }
}

extension CGSize: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let width = try container.decode(Double.self, forKey: .width)
        let height = try container.decode(Double.self, forKey: .height)
        self.init(width: width, height: height)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
    }
    
    enum CodingKeys: String, CodingKey {
        case width, height
    }
}

extension CGPoint: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(Double.self, forKey: .x)
        let y = try container.decode(Double.self, forKey: .y)
        self.init(x: x, y: y)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
    }
    
    enum CodingKeys: String, CodingKey {
        case x, y
    }
}
*/
