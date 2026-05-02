import Foundation
import AnigmaPrimitives

/// Intermediate representation of a document structure
/// Supports hierarchical document models (PDF, Markdown, HTML, etc.)
public enum DocumentIRNode: Codable, Sendable, Equatable {
    // Container nodes
    case document(Document)
    case section(Section)
    case paragraph(Paragraph)
    case list(List)
    case listItem(ListItem)
    case table(Table)
    case tableRow(TableRow)
    case tableCell(TableCell)
    case blockQuote(BlockQuote)
    case codeBlock(CodeBlock)
    
    // Inline nodes
    case text(Text)
    case emphasis(Emphasis)
    case strong(Strong)
    case code(Code)
    case link(Link)
    case image(Image)
    case lineBreak
    case hardBreak
    case softBreak
    
    /// Document root node
    public struct Document: Codable, Sendable, Equatable {
        public let id: String
        public let metadata: DocumentMetadata
        public var children: [DocumentIRNode]
        
        public init(
            id: String,
            metadata: DocumentMetadata,
            children: [DocumentIRNode] = []
        ) {
            self.id = id
            self.metadata = metadata
            self.children = children
        }
    }
    
    /// Document-level metadata
    public struct DocumentMetadata: Codable, Sendable, Equatable {
        public let title: String?
        public let author: String?
        public let createdDate: Date?
        public let modifiedDate: Date?
        public let subject: String?
        public let tags: [String]
        public let language: String?
        public let properties: [String: AnyCodable]
        
        public init(
            title: String? = nil,
            author: String? = nil,
            createdDate: Date? = nil,
            modifiedDate: Date? = nil,
            subject: String? = nil,
            tags: [String] = [],
            language: String? = nil,
            properties: [String: AnyCodable] = [:]
        ) {
            self.title = title
            self.author = author
            self.createdDate = createdDate
            self.modifiedDate = modifiedDate
            self.subject = subject
            self.tags = tags
            self.language = language
            self.properties = properties
        }
    }
    
    /// Section/heading node
    public struct Section: Codable, Sendable, Equatable {
        public let id: String
        public let level: Int // 1-6 for h1-h6
        public let title: String
        public let attributes: [String: AnyCodable]
        public var children: [DocumentIRNode]
        
        public init(
            id: String,
            level: Int,
            title: String,
            attributes: [String: AnyCodable] = [:],
            children: [DocumentIRNode] = []
        ) {
            self.id = id
            self.level = level
            self.title = title
            self.attributes = attributes
            self.children = children
        }
    }
    
    /// Paragraph node
    public struct Paragraph: Codable, Sendable, Equatable {
        public let id: String
        public let alignment: TextAlignment
        public let attributes: [String: AnyCodable]
        public var children: [DocumentIRNode]
        
        public init(
            id: String,
            alignment: TextAlignment = .left,
            attributes: [String: AnyCodable] = [:],
            children: [DocumentIRNode] = []
        ) {
            self.id = id
            self.alignment = alignment
            self.attributes = attributes
            self.children = children
        }
    }
    
    /// List node (ordered or unordered)
    public struct List: Codable, Sendable, Equatable {
        public enum ListType: String, Codable, Sendable {
            case ordered
            case unordered
            case checklist
        }
        
        public let id: String
        public let type: ListType
        public let startNumber: Int? // For ordered lists
        public var children: [DocumentIRNode]
        
        public init(
            id: String,
            type: ListType,
            startNumber: Int? = nil,
            children: [DocumentIRNode] = []
        ) {
            self.id = id
            self.type = type
            self.startNumber = startNumber
            self.children = children
        }
    }
    
    /// List item node
    public struct ListItem: Codable, Sendable, Equatable {
        public let id: String
        public let checked: Bool? // For checklists
        public let attributes: [String: AnyCodable]
        public var children: [DocumentIRNode]
        
        public init(
            id: String,
            checked: Bool? = nil,
            attributes: [String: AnyCodable] = [:],
            children: [DocumentIRNode] = []
        ) {
            self.id = id
            self.checked = checked
            self.attributes = attributes
            self.children = children
        }
    }
    
    /// Table node
    public struct Table: Codable, Sendable, Equatable {
        public let id: String
        public let caption: String?
        public let columns: Int
        public var children: [DocumentIRNode] // Rows
        
        public init(
            id: String,
            caption: String? = nil,
            columns: Int,
            children: [DocumentIRNode] = []
        ) {
            self.id = id
            self.caption = caption
            self.columns = columns
            self.children = children
        }
    }
    
    /// Table row node
    public struct TableRow: Codable, Sendable, Equatable {
        public let id: String
        public let isHeaderRow: Bool
        public var children: [DocumentIRNode] // Cells
        
        public init(
            id: String,
            isHeaderRow: Bool = false,
            children: [DocumentIRNode] = []
        ) {
            self.id = id
            self.isHeaderRow = isHeaderRow
            self.children = children
        }
    }
    
    /// Table cell node
    public struct TableCell: Codable, Sendable, Equatable {
        public let id: String
        public let columnSpan: Int
        public let rowSpan: Int
        public let attributes: [String: AnyCodable]
        public var children: [DocumentIRNode]
        
        public init(
            id: String,
            columnSpan: Int = 1,
            rowSpan: Int = 1,
            attributes: [String: AnyCodable] = [:],
            children: [DocumentIRNode] = []
        ) {
            self.id = id
            self.columnSpan = columnSpan
            self.rowSpan = rowSpan
            self.attributes = attributes
            self.children = children
        }
    }
    
    /// Block quote node
    public struct BlockQuote: Codable, Sendable, Equatable {
        public let id: String
        public let citation: String?
        public let attributes: [String: AnyCodable]
        public var children: [DocumentIRNode]
        
        public init(
            id: String,
            citation: String? = nil,
            attributes: [String: AnyCodable] = [:],
            children: [DocumentIRNode] = []
        ) {
            self.id = id
            self.citation = citation
            self.attributes = attributes
            self.children = children
        }
    }
    
    /// Code block node
    public struct CodeBlock: Codable, Sendable, Equatable {
        public let id: String
        public let language: String?
        public let code: String
        public let lineNumbers: Bool
        public let attributes: [String: AnyCodable]
        
        public init(
            id: String,
            language: String? = nil,
            code: String,
            lineNumbers: Bool = true,
            attributes: [String: AnyCodable] = [:]
        ) {
            self.id = id
            self.language = language
            self.code = code
            self.lineNumbers = lineNumbers
            self.attributes = attributes
        }
    }
    
    /// Text node (leaf node)
    public struct Text: Codable, Sendable, Equatable {
        public let content: String
        public let style: TextStyle
        
        public init(content: String, style: TextStyle = .normal) {
            self.content = content
            self.style = style
        }
    }
    
    /// Emphasis node (italic)
    public struct Emphasis: Codable, Sendable, Equatable {
        public let id: String
        public var children: [DocumentIRNode]
        
        public init(id: String, children: [DocumentIRNode] = []) {
            self.id = id
            self.children = children
        }
    }
    
    /// Strong node (bold)
    public struct Strong: Codable, Sendable, Equatable {
        public let id: String
        public var children: [DocumentIRNode]
        
        public init(id: String, children: [DocumentIRNode] = []) {
            self.id = id
            self.children = children
        }
    }
    
    /// Code node (inline)
    public struct Code: Codable, Sendable, Equatable {
        public let id: String
        public let code: String
        
        public init(id: String, code: String) {
            self.id = id
            self.code = code
        }
    }
    
    /// Link node
    public struct Link: Codable, Sendable, Equatable {
        public let id: String
        public let url: String
        public let title: String?
        public var children: [DocumentIRNode]
        
        public init(
            id: String,
            url: String,
            title: String? = nil,
            children: [DocumentIRNode] = []
        ) {
            self.id = id
            self.url = url
            self.title = title
            self.children = children
        }
    }
    
    /// Image node
    public struct Image: Codable, Sendable, Equatable {
        public let id: String
        public let source: String // URL or path
        public let altText: String?
        public let title: String?
        public let width: Double?
        public let height: Double?
        public let attributes: [String: AnyCodable]
        
        public init(
            id: String,
            source: String,
            altText: String? = nil,
            title: String? = nil,
            width: Double? = nil,
            height: Double? = nil,
            attributes: [String: AnyCodable] = [:]
        ) {
            self.id = id
            self.source = source
            self.altText = altText
            self.title = title
            self.width = width
            self.height = height
            self.attributes = attributes
        }
    }
    
    public enum TextAlignment: String, Codable, Sendable {
        case left
        case center
        case right
        case justify
    }
    
    public enum TextStyle: String, Codable, Sendable {
        case normal
        case bold
        case italic
        case strikethrough
        case underline
    }
}

import AnigmaPrimitives
