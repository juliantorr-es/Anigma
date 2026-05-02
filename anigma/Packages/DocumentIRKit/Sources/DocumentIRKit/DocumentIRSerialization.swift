import Foundation
import AnigmaPrimitives

/// Serialization and deserialization for DocumentIR
public enum DocumentIRSerialization {
    
    // MARK: - JSON Serialization
    
    /// Encode node to JSON data
    public static func encodeToJSON(_ node: DocumentIRNode) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(node)
    }
    
    /// Decode node from JSON data
    public static func decodeFromJSON(_ data: Data) throws -> DocumentIRNode {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(DocumentIRNode.self, from: data)
    }
    
    /// Encode node to JSON string
    public static func encodeToJSONString(_ node: DocumentIRNode) throws -> String {
        let data = try encodeToJSON(node)
        guard let string = String(data: data, encoding: .utf8) else {
            throw SerializationError.encodingFailed("Failed to convert JSON data to string")
        }
        return string
    }
    
    /// Decode node from JSON string
    public static func decodeFromJSONString(_ string: String) throws -> DocumentIRNode {
        guard let data = string.data(using: .utf8) else {
            throw SerializationError.decodingFailed("Failed to convert JSON string to data")
        }
        return try decodeFromJSON(data)
    }
    
    // MARK: - Document Traversal
    
    /// Get all text content from document
    public static func extractText(_ node: DocumentIRNode) -> String {
        let visitor = TextCollectionVisitor()
        let traversal = DocumentIRTraversal(visitor: visitor)
        traversal.traverseDepthFirst(node)
        return visitor.getAllText()
    }
    
    /// Get all images from document
    public static func extractImages(_ node: DocumentIRNode) -> [DocumentIRNode.Image] {
        let visitor = ImageCollectionVisitor()
        let traversal = DocumentIRTraversal(visitor: visitor)
        traversal.traverseDepthFirst(node)
        return visitor.getImages()
    }
    
    /// Get all links from document
    public static func extractLinks(_ node: DocumentIRNode) -> [DocumentIRNode.Link] {
        let visitor = LinkCollectionVisitor()
        let traversal = DocumentIRTraversal(visitor: visitor)
        traversal.traverseDepthFirst(node)
        return visitor.getLinks()
    }
    
    /// Get all code blocks from document
    public static func extractCodeBlocks(_ node: DocumentIRNode) -> [DocumentIRNode.CodeBlock] {
        let visitor = CodeCollectionVisitor()
        let traversal = DocumentIRTraversal(visitor: visitor)
        traversal.traverseDepthFirst(node)
        return visitor.getCodeBlocks()
    }
    
    /// Count node types in document
    public static func countNodeTypes(_ node: DocumentIRNode) -> [String: Int] {
        let visitor = NodeCountingVisitor()
        let traversal = DocumentIRTraversal(visitor: visitor)
        traversal.traverseDepthFirst(node)
        return visitor.getCounts()
    }
}

// MARK: - Serialization Errors

public enum SerializationError: LocalizedError, Sendable {
    case encodingFailed(String)
    case decodingFailed(String)
    case invalidFormat(String)
    
    public var errorDescription: String? {
        switch self {
        case .encodingFailed(let msg):
            return "Encoding failed: \(msg)"
        case .decodingFailed(let msg):
            return "Decoding failed: \(msg)"
        case .invalidFormat(let msg):
            return "Invalid format: \(msg)"
        }
    }
}

// MARK: - IR Builder Helpers

/// Fluent builder for DocumentIR nodes
public struct DocumentIRBuilder {
    
    /// Create a new document with fluent interface
    public static func document(id: String, title: String? = nil, author: String? = nil) -> DocumentBuilder {
        let metadata = DocumentIRNode.DocumentMetadata(
            title: title,
            author: author
        )
        return DocumentBuilder(
            id: id,
            metadata: metadata,
            children: []
        )
    }
    
    public struct DocumentBuilder {
        private var document: DocumentIRNode.Document
        
        fileprivate init(id: String, metadata: DocumentIRNode.DocumentMetadata, children: [DocumentIRNode]) {
            self.document = DocumentIRNode.Document(
                id: id,
                metadata: metadata,
                children: children
            )
        }
        
        public mutating func addChild(_ node: DocumentIRNode) -> Self {
            document.children.append(node)
            return self
        }
        
        public mutating func addChildren(_ nodes: [DocumentIRNode]) -> Self {
            document.children.append(contentsOf: nodes)
            return self
        }
        
        public func build() -> DocumentIRNode {
            return .document(document)
        }
    }
    
    /// Create a paragraph
    public static func paragraph(id: String) -> ParagraphBuilder {
        return ParagraphBuilder(
            id: id,
            alignment: .left,
            attributes: [:],
            children: []
        )
    }
    
    public struct ParagraphBuilder {
        private var paragraph: DocumentIRNode.Paragraph
        
        fileprivate init(
            id: String,
            alignment: DocumentIRNode.TextAlignment,
            attributes: [String: AnyCodable],
            children: [DocumentIRNode]
        ) {
            self.paragraph = DocumentIRNode.Paragraph(
                id: id,
                alignment: alignment,
                attributes: attributes,
                children: children
            )
        }
        
        public mutating func addChild(_ node: DocumentIRNode) -> Self {
            paragraph.children.append(node)
            return self
        }
        
        public func build() -> DocumentIRNode {
            return .paragraph(paragraph)
        }
    }
    
    /// Create a section
    public static func section(id: String, level: Int, title: String) -> SectionBuilder {
        return SectionBuilder(
            id: id,
            level: level,
            title: title,
            attributes: [:],
            children: []
        )
    }
    
    public struct SectionBuilder {
        private var section: DocumentIRNode.Section
        
        fileprivate init(
            id: String,
            level: Int,
            title: String,
            attributes: [String: AnyCodable],
            children: [DocumentIRNode]
        ) {
            self.section = DocumentIRNode.Section(
                id: id,
                level: level,
                title: title,
                attributes: attributes,
                children: children
            )
        }
        
        public mutating func addChild(_ node: DocumentIRNode) -> Self {
            section.children.append(node)
            return self
        }
        
        public func build() -> DocumentIRNode {
            return .section(section)
        }
    }
    
    /// Create a list
    public static func list(
        id: String,
        type: DocumentIRNode.List.ListType
    ) -> ListBuilder {
        return ListBuilder(
            id: id,
            type: type,
            startNumber: nil,
            children: []
        )
    }
    
    public struct ListBuilder {
        private var list: DocumentIRNode.List
        
        fileprivate init(
            id: String,
            type: DocumentIRNode.List.ListType,
            startNumber: Int?,
            children: [DocumentIRNode]
        ) {
            self.list = DocumentIRNode.List(
                id: id,
                type: type,
                startNumber: startNumber,
                children: children
            )
        }
        
        public mutating func addItem(_ node: DocumentIRNode) -> Self {
            list.children.append(node)
            return self
        }
        
        public func build() -> DocumentIRNode {
            return .list(list)
        }
    }
    
    /// Create a list item
    public static func listItem(id: String) -> ListItemBuilder {
        return ListItemBuilder(
            id: id,
            checked: nil,
            attributes: [:],
            children: []
        )
    }
    
    public struct ListItemBuilder {
        private var item: DocumentIRNode.ListItem
        
        fileprivate init(
            id: String,
            checked: Bool?,
            attributes: [String: AnyCodable],
            children: [DocumentIRNode]
        ) {
            self.item = DocumentIRNode.ListItem(
                id: id,
                checked: checked,
                attributes: attributes,
                children: children
            )
        }
        
        public mutating func addChild(_ node: DocumentIRNode) -> Self {
            item.children.append(node)
            return self
        }
        
        public func build() -> DocumentIRNode {
            return .listItem(item)
        }
    }
    
    /// Create inline text
    public static func text(_ content: String) -> DocumentIRNode {
        return .text(DocumentIRNode.Text(content: content))
    }
    
    /// Create emphasis (italic)
    public static func emphasis(id: String, children: [DocumentIRNode] = []) -> DocumentIRNode {
        return .emphasis(DocumentIRNode.Emphasis(id: id, children: children))
    }
    
    /// Create strong (bold)
    public static func strong(id: String, children: [DocumentIRNode] = []) -> DocumentIRNode {
        return .strong(DocumentIRNode.Strong(id: id, children: children))
    }
    
    /// Create code block
    public static func codeBlock(
        id: String,
        language: String? = nil,
        code: String
    ) -> DocumentIRNode {
        return .codeBlock(
            DocumentIRNode.CodeBlock(
                id: id,
                language: language,
                code: code
            )
        )
    }
    
    /// Create inline code
    public static func code(id: String, code: String) -> DocumentIRNode {
        return .code(DocumentIRNode.Code(id: id, code: code))
    }
    
    /// Create link
    public static func link(id: String, url: String, title: String? = nil) -> DocumentIRNode {
        return .link(
            DocumentIRNode.Link(
                id: id,
                url: url,
                title: title
            )
        )
    }
    
    /// Create image
    public static func image(
        id: String,
        source: String,
        altText: String? = nil,
        title: String? = nil
    ) -> DocumentIRNode {
        return .image(
            DocumentIRNode.Image(
                id: id,
                source: source,
                altText: altText,
                title: title
            )
        )
    }
}
