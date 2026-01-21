import Foundation

// MARK: - Tabular IR

public struct TabularIR: Codable, Sendable {
    public let schema: TableSchema
    public let rowCount: Int
    public let storagePointer: String // Content hash or path
    public let parsingDiagnostics: [ParsingDiagnostic]

    public init(schema: TableSchema, rowCount: Int, storagePointer: String, parsingDiagnostics: [ParsingDiagnostic] = []) {
        self.schema = schema
        self.rowCount = rowCount
        self.storagePointer = storagePointer
        self.parsingDiagnostics = parsingDiagnostics
    }
}

public struct TableSchema: Codable, Sendable {
    public let columns: [ColumnSchema]

    public init(columns: [ColumnSchema]) {
        self.columns = columns
    }
}

public struct ColumnSchema: Codable, Sendable {
    public let name: String
    public let type: ColumnType
    public let isNullable: Bool

    public init(name: String, type: ColumnType, isNullable: Bool) {
        self.name = name
        self.type = type
        self.isNullable = isNullable
    }
}

public enum ColumnType: String, Codable, Sendable {
    case string
    case integer
    case double
    case boolean
    case date
    case unknown
}

public struct ParsingDiagnostic: Codable, Sendable {
    public let row: Int
    public let column: String?
    public let message: String
    public let severity: DiagnosticSeverity

    public init(row: Int, column: String?, message: String, severity: DiagnosticSeverity) {
        self.row = row
        self.column = column
        self.message = message
        self.severity = severity
    }
}

public enum DiagnosticSeverity: String, Codable, Sendable {
    case info
    case warning
    case error
}

// MARK: - Schema IR

public struct SchemaIR: Codable, Sendable {
    public let tables: [TableDefinition]
    public let relationships: [RelationshipDefinition]

    public init(tables: [TableDefinition], relationships: [RelationshipDefinition]) {
        self.tables = tables
        self.relationships = relationships
    }
}

public struct TableDefinition: Codable, Sendable {
    public let name: String
    public let columns: [ColumnSchema]
    public let primaryKey: [String]

    public init(name: String, columns: [ColumnSchema], primaryKey: [String]) {
        self.name = name
        self.columns = columns
        self.primaryKey = primaryKey
    }
}

public struct RelationshipDefinition: Codable, Sendable {
    public let fromTable: String
    public let fromColumn: String
    public let toTable: String
    public let toColumn: String
    public let type: RelationshipType

    public init(fromTable: String, fromColumn: String, toTable: String, toColumn: String, type: RelationshipType) {
        self.fromTable = fromTable
        self.fromColumn = fromColumn
        self.toTable = toTable
        self.toColumn = toColumn
        self.type = type
    }
}

public enum RelationshipType: String, Codable, Sendable {
    case oneToOne
    case oneToMany
    case manyToMany
}

// MARK: - Graph IR

public struct GraphIR: Codable, Sendable {
    public let nodes: [GraphNode]
    public let edges: [GraphEdge]

    public init(nodes: [GraphNode], edges: [GraphEdge]) {
        self.nodes = nodes
        self.edges = edges
    }
}

public struct GraphNode: Codable, Sendable {
    public let id: String
    public let type: String
    public let properties: [String: String]

    public init(id: String, type: String, properties: [String: String]) {
        self.id = id
        self.type = type
        self.properties = properties
    }
}

public struct GraphEdge: Codable, Sendable {
    public let source: String
    public let target: String
    public let type: String
    public let provenance: String?

    public init(source: String, target: String, type: String, provenance: String? = nil) {
        self.source = source
        self.target = target
        self.type = type
        self.provenance = provenance
    }
}

// MARK: - Timeline IR

public struct TimelineIR: Codable, Sendable {
    public let events: [TimelineEvent]

    public init(events: [TimelineEvent]) {
        self.events = events
    }
}

public struct TimelineEvent: Codable, Sendable {
    public let id: String
    public let timestamp: Date
    public let title: String
    public let description: String?
    public let sourceLink: String?
    public let confidence: Double

    public init(id: String, timestamp: Date, title: String, description: String? = nil, sourceLink: String? = nil, confidence: Double = 1.0) {
        self.id = id
        self.timestamp = timestamp
        self.title = title
        self.description = description
        self.sourceLink = sourceLink
        self.confidence = confidence
    }
}

// MARK: - Transform IR

public struct TransformIR: Codable, Sendable {
    public let id: String
    public let operations: [TransformOperation]

    public init(id: String, operations: [TransformOperation]) {
        self.id = id
        self.operations = operations
    }
}

public enum TransformOperation: Codable, Sendable {
    case renameColumn(old: String, new: String)
    case dropColumn(name: String)
    case filter(predicate: String) // Simplified for now
    case coerceType(column: String, type: ColumnType)
    // Add more as needed
}
