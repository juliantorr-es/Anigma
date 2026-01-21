//
//  IRContracts.swift
//  ContractsCore
//
//  Canonical Intermediate Representation (IR) schema for Anigma.
//  This provides a unified graph-based representation of workflows,
//  state, and traces that can be queried and analyzed.
//

import Foundation

// MARK: - Core IR Types

/// Unique identifier for IR nodes
public struct IRNodeId: Sendable, Codable, Hashable {
    public let value: String

    public init(_ value: String) {
        self.value = value
    }

    public static func generate() -> IRNodeId {
        return IRNodeId(UUID().uuidString)
    }
}

/// Unique identifier for IR edges
public struct IREdgeId: Sendable, Codable, Hashable {
    public let value: String

    public init(_ value: String) {
        self.value = value
    }

    public static func generate() -> IREdgeId {
        return IREdgeId(UUID().uuidString)
    }
}

/// Unique identifier for IR graphs
public struct IRGraphId: Sendable, Codable, Hashable {
    public let value: String

    public init(_ value: String) {
        self.value = value
    }

    public static func generate() -> IRGraphId {
        return IRGraphId(UUID().uuidString)
    }
}

// MARK: - IR Node

/// Node in the intermediate representation graph
public struct IRNode: Sendable, Codable {
    public let id: IRNodeId
    public let kind: IRNodeKind
    public let type: String
    public let attributes: IRAttributes
    public let metadata: IRMetadata

    public init(id: IRNodeId, kind: IRNodeKind, type: String, attributes: IRAttributes? = nil, metadata: IRMetadata? = nil) {
        self.id = id
        self.kind = kind
        self.type = type
        self.attributes = attributes ?? IRAttributes()
        self.metadata = metadata ?? IRMetadata()
    }
}

/// Kind of IR node with semantic meaning
public enum IRNodeKind: String, Sendable, Codable, CaseIterable {
    case entity = "entity"
    case artifact = "artifact"
    case process = "process"
    case decision = "decision"
    case state = "state"
    case event = "event"
    case constraint = "constraint"
    case policy = "policy"
    case resource = "resource"
    case session = "session"
    case workflow = "workflow"
    case step = "step"
    case trace = "trace"

    public var description: String {
        switch self {
        case .entity: return "Domain entity (user, project, file)"
        case .artifact: return "Generated artifact (output, result)"
        case .process: return "Running process or computation"
        case .decision: return "Decision point with alternatives"
        case .state: return "State snapshot or configuration"
        case .event: return "Event that occurred"
        case .constraint: return "Constraint or rule"
        case .policy: return "Governance policy"
        case .resource: return "Resource (CPU, memory, storage)"
        case .session: return "User session or interaction"
        case .workflow: return "Workflow or pipeline"
        case .step: return "Individual step in workflow"
        case .trace: return "Execution trace or log"
        }
    }
}

/// Typed attributes for IR nodes
public struct IRAttributes: Sendable, Codable {
    var storage: [String: IRAttributeValue] = [:]

    public init(_ elements: [String: IRAttributeValue] = [:]) {
        self.storage = elements
    }

    public subscript(key: String) -> IRAttributeValue? {
        get { storage[key] }
        set { storage[key] = newValue }
    }

    public func contains(_ key: String) -> Bool {
        return storage[key] != nil
    }

    public func keys() -> [String] {
        return Array(storage.keys)
    }

    public func values() -> [IRAttributeValue] {
        return Array(storage.values)
    }

    public func count() -> Int {
        return storage.count
    }
}

/// Attribute value with type safety
public enum IRAttributeValue: Sendable, Codable, Equatable {
    case string(String)
    case integer(Int)
    case double(Double)
    case boolean(Bool)
    case array([IRAttributeValue])
    case object(IRAttributes)
    case null

    public static func == (lhs: IRAttributeValue, rhs: IRAttributeValue) -> Bool {
        switch (lhs, rhs) {
        case (.string(let l), .string(let r)): return l == r
        case (.integer(let l), .integer(let r)): return l == r
        case (.double(let l), .double(let r)): return l == r
        case (.boolean(let l), .boolean(let r)): return l == r
        case (.array(let l), .array(let r)): return l == r
        case (.object(let l), .object(let r)):
            return l.storage.keys == r.storage.keys && l.storage.allSatisfy { key, value in r.storage[key] == value }
        case (.null, .null): return true
        default: return false
        }
    }

    public var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    public var integerValue: Int? {
        if case .integer(let value) = self { return value }
        return nil
    }

    public var doubleValue: Double? {
        if case .double(let value) = self { return value }
        return nil
    }

    public var booleanValue: Bool? {
        if case .boolean(let value) = self { return value }
        return nil
    }

    public var arrayValue: [IRAttributeValue]? {
        if case .array(let value) = self { return value }
        return nil
    }

    public var objectValue: IRAttributes? {
        if case .object(let value) = self { return value }
        return nil
    }
}

/// Metadata for IR nodes
public struct IRMetadata: Sendable, Codable {
    private var storage: [String: String] = [:]

    public init(_ elements: [String: String] = [:]) {
        self.storage = elements
    }

    public subscript(key: String) -> String? {
        get { storage[key] }
        set { storage[key] = newValue }
    }

    public func contains(_ key: String) -> Bool {
        return storage[key] != nil
    }

    public func keys() -> [String] {
        return Array(storage.keys)
    }

    public func count() -> Int {
        return storage.count
    }
}

// MARK: - IR Edge

/// Edge in the intermediate representation graph
public struct IREdge: Sendable, Codable {
    public let id: IREdgeId
    public let from: IRNodeId
    public let to: IRNodeId
    public let kind: IREdgeKind
    public let weight: Double?
    public let attributes: IRAttributes
    public let metadata: IRMetadata

    public init(id: IREdgeId, from: IRNodeId, to: IRNodeId, kind: IREdgeKind, weight: Double? = nil, attributes: IRAttributes? = nil, metadata: IRMetadata? = nil) {
        self.id = id
        self.from = from
        self.to = to
        self.kind = kind
        self.weight = weight
        self.attributes = attributes ?? IRAttributes()
        self.metadata = metadata ?? IRMetadata()
    }
}

/// Kind of IR edge with semantic meaning
public enum IREdgeKind: String, Sendable, Codable, CaseIterable {
    case uses = "uses"
    case produces = "produces"
    case dependsOn = "depends_on"
    case contains = "contains"
    case references = "references"
    case modifies = "modifies"
    case triggers = "triggers"
    case constrains = "constrains"
    case authorizes = "authorizes"
    case violates = "violates"
    case precedes = "precedes"
    case follows = "follows"
    case partOf = "part_of"
    case instanceOf = "instance_of"
    case implements = "implements"
    case extends = "extends"
    case overrides = "overrides"

    public var description: String {
        switch self {
        case .uses: return "Node uses another node"
        case .produces: return "Node produces another node"
        case .dependsOn: return "Node depends on another node"
        case .contains: return "Node contains another node"
        case .references: return "Node references another node"
        case .modifies: return "Node modifies another node"
        case .triggers: return "Node triggers another node"
        case .constrains: return "Node constrains another node"
        case .authorizes: return "Node authorizes another node"
        case .violates: return "Node violates another node"
        case .precedes: return "Node precedes another node in sequence"
        case .follows: return "Node follows another node in sequence"
        case .partOf: return "Node is part of another node"
        case .instanceOf: return "Node is instance of another node"
        case .implements: return "Node implements another node"
        case .extends: return "Node extends another node"
        case .overrides: return "Node overrides another node"
        }
    }
}

// MARK: - IR Graph

/// Complete intermediate representation graph
public struct IRGraph: Sendable, Codable {
    public let schemaVersion: String
    public let id: IRGraphId
    public let name: String
    public let version: IRVersion
    public let nodes: [IRNodeId: IRNode]
    public let edges: [IREdgeId: IREdge]
    public let metadata: IRMetadata
    public let indexes: IRIndexes

    public init(id: IRGraphId, name: String, version: IRVersion, nodes: [IRNode] = [], edges: [IREdge] = [], metadata: IRMetadata? = nil, indexes: IRIndexes = IRIndexes()) {
        self.id = id
        self.name = name
        self.version = version
        self.schemaVersion = "v1"
        self.metadata = metadata ?? IRMetadata()

        // Convert to dictionaries for fast lookup
        self.nodes = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        self.edges = Dictionary(uniqueKeysWithValues: edges.map { ($0.id, $0) })
        self.indexes = indexes
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, name, version, nodes, edges, metadata, indexes
    }

    /// Get node by ID
    public func node(_ id: IRNodeId) -> IRNode? {
        return nodes[id]
    }

    /// Get edge by ID
    public func edge(_ id: IREdgeId) -> IREdge? {
        return edges[id]
    }

    /// Get all nodes of a specific kind
    public func nodes(ofKind kind: IRNodeKind) -> [IRNode] {
        return nodes.values.filter { $0.kind == kind }
    }

    /// Get all edges of a specific kind
    public func edges(ofKind kind: IREdgeKind) -> [IREdge] {
        return edges.values.filter { $0.kind == kind }
    }

    /// Get outgoing edges from a node
    public func outgoingEdges(from nodeId: IRNodeId) -> [IREdge] {
        return edges.values.filter { $0.from == nodeId }
    }

    /// Get incoming edges to a node
    public func incomingEdges(to nodeId: IRNodeId) -> [IREdge] {
        return edges.values.filter { $0.to == nodeId }
    }

    /// Get nodes reachable from a specific node
    public func reachable(from nodeId: IRNodeId, edgeKinds: Set<IREdgeKind>? = nil) -> Set<IRNodeId> {
        var visited: Set<IRNodeId> = []
        var toVisit: [IRNodeId] = [nodeId]

        while !toVisit.isEmpty {
            let current = toVisit.removeFirst()
            guard !visited.contains(current) else { continue }
            visited.insert(current)

            let outgoing = outgoingEdges(from: current)
            let filtered = edgeKinds.map { kinds in
                outgoing.filter { kinds.contains($0.kind) }
            } ?? outgoing

            toVisit.append(contentsOf: filtered.map { $0.to })
        }

        return visited.subtracting([nodeId])
    }
}

/// Version information for IR graphs
public struct IRVersion: Sendable, Codable {
    public let major: Int
    public let minor: Int
    public let patch: Int
    public let timestamp: Date

    public init(major: Int, minor: Int, patch: Int, timestamp: Date = Date()) {
        self.major = major
        self.minor = minor
        self.patch = patch
        self.timestamp = timestamp
    }

    public var string: String {
        return "\(major).\(minor).\(patch)"
    }
}

/// Indexes for efficient IR graph queries
public struct IRIndexes: Sendable, Codable {
    public let nodeKindIndex: [IRNodeKind: Set<IRNodeId>]
    public let edgeKindIndex: [IREdgeKind: Set<IREdgeId>]
    public let nodeTypeIndex: [String: Set<IRNodeId>]
    public let adjacencyIndex: [IRNodeId: Set<IRNodeId>]  // outgoing adjacency

    public init(
        nodeKindIndex: [IRNodeKind: Set<IRNodeId>] = [:],
        edgeKindIndex: [IREdgeKind: Set<IREdgeId>] = [:],
        nodeTypeIndex: [String: Set<IRNodeId>] = [:],
        adjacencyIndex: [IRNodeId: Set<IRNodeId>] = [:]
    ) {
        self.nodeKindIndex = nodeKindIndex
        self.edgeKindIndex = edgeKindIndex
        self.nodeTypeIndex = nodeTypeIndex
        self.adjacencyIndex = adjacencyIndex
    }
}

// MARK: - IR Query Types

/// Query for IR graph traversal
public struct IRQuery: Sendable, Codable {
    public let pattern: IRPattern
    public let filters: [IRFilter]
    public let limit: Int?
    public let offset: Int?

    public init(pattern: IRPattern, filters: [IRFilter] = [], limit: Int? = nil, offset: Int? = nil) {
        self.pattern = pattern
        self.filters = filters
        self.limit = limit
        self.offset = offset
    }
}

/// Pattern for matching IR subgraphs
public indirect enum IRPattern: Sendable, Codable {
    case node(IRNodeKind)
    case edge(IREdgeKind)
    case path([IREdgeKind])
    case star  // Match any
    case sequence([IRPattern])
    case alternative([IRPattern])
    case conditional(IRPattern, IRFilter)

    public var description: String {
        switch self {
        case .node(let kind):
            return "node(\(kind.rawValue))"
        case .edge(let kind):
            return "edge(\(kind.rawValue))"
        case .path(let kinds):
            return "path(\(kinds.map { $0.rawValue }.joined(separator: "->")))"
        case .star:
            return "*"
        case .sequence(let patterns):
            return "sequence(\(patterns.map { $0.description }.joined(separator: ", ")))"
        case .alternative(let patterns):
            return "alternative(\(patterns.map { $0.description }.joined(separator: "|")))"
        case .conditional(let pattern, let filter):
            return "conditional(\(pattern.description), \(filter.description))"
        }
    }
}

/// Filter for IR query results
public struct IRFilter: Sendable, Codable {
    public let attribute: String
    public let op: IROperator
    public let value: IRAttributeValue

    public init(attribute: String, op: IROperator, value: IRAttributeValue) {
        self.attribute = attribute
        self.op = op
        self.value = value
    }

    public var description: String {
        return "\(attribute) \(op.rawValue) \(value)"
    }
}

/// Operator for IR filtering
public enum IROperator: String, Sendable, Codable {
    case equals = "equals"
    case notEquals = "not_equals"
    case greaterThan = "greater_than"
    case greaterThanOrEqual = "greater_than_or_equal"
    case lessThan = "less_than"
    case lessThanOrEqual = "less_than_or_equal"
    case contains = "contains"
    case notContains = "not_contains"
    case matches = "matches"
    case notMatches = "not_matches"
    case `in` = "in"
    case notIn = "not_in"

    public var description: String {
        return self.rawValue
    }
}

/// Result of IR query
public struct IRQueryResult: Sendable, Codable {
    public let matches: [IRMatch]
    public let total: Int
    public let hasMore: Bool

    public init(matches: [IRMatch], total: Int, hasMore: Bool = false) {
        self.matches = matches
        self.total = total
        self.hasMore = hasMore
    }
}

/// Match from IR query
public struct IRMatch: Sendable, Codable {
    public let nodes: [IRNodeId: IRNode]
    public let edges: [IREdgeId: IREdge]
    public let score: Double?
    public let metadata: IRMetadata

    public init(nodes: [IRNode], edges: [IREdge] = [], score: Double? = nil, metadata: IRMetadata? = nil) {
        self.nodes = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        self.edges = Dictionary(uniqueKeysWithValues: edges.map { ($0.id, $0) })
        self.score = score
        self.metadata = metadata ?? IRMetadata()
    }
}

// MARK: - IR Contracts

/// Contract for IR graph validation
public struct IRGraphContract: WorkflowContract {
    public static let id = ContractID(name: "ir.graph", major: 1, minor: 0, schemaHash: "v1.0")

    public let payload: IRGraph

    public init(_ payload: IRGraph) {
        self.payload = payload
    }

    public static func validateInvariants(_ value: IRGraphContract) throws {
        let graph = value.payload

        // Validate graph has required fields
        guard !graph.name.isEmpty else {
            throw ValidationError.invalidRequest("Graph name cannot be empty")
        }

        // Validate all edge references point to existing nodes
        for edge in graph.edges.values {
            guard graph.nodes[edge.from] != nil else {
                throw ValidationError.invalidRequest("Edge references non-existent from node: \(edge.from.value)")
            }

            guard graph.nodes[edge.to] != nil else {
                throw ValidationError.invalidRequest("Edge references non-existent to node: \(edge.to.value)")
            }
        }

        // Validate no duplicate node IDs
        let nodeIds = Set(graph.nodes.keys)
        guard nodeIds.count == graph.nodes.count else {
            throw ValidationError.invalidRequest("Graph contains duplicate node IDs")
        }

        // Validate no duplicate edge IDs
        let edgeIds = Set(graph.edges.keys)
        guard edgeIds.count == graph.edges.count else {
            throw ValidationError.invalidRequest("Graph contains duplicate edge IDs")
        }
    }
}

/// Contract for IR query validation
public struct IRQueryContract: WorkflowContract {
    public static let id = ContractID(name: "ir.query", major: 1, minor: 0, schemaHash: "v1.0")

    public let payload: IRQuery

    public init(_ payload: IRQuery) {
        self.payload = payload
    }

    public static func validateInvariants(_ value: IRQueryContract) throws {
        let query = value.payload

        // Validate limit is reasonable
        if let limit = query.limit, limit < 0 {
            throw ValidationError.invalidRequest("Query limit cannot be negative")
        }

        if let offset = query.offset, offset < 0 {
            throw ValidationError.invalidRequest("Query offset cannot be negative")
        }

        // Validate filter values are not null
        for filter in query.filters {
            switch filter.value {
            case .null:
                throw ValidationError.invalidRequest("Filter value cannot be null")
            default:
                break
            }
        }
    }
}
