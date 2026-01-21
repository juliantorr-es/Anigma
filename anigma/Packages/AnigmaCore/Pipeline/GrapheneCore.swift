//
//  GrapheneCore.swift
//  AnigmaCore
//
//  Graphene-inspired procedural node graph runtime for Anigma.
//
//  Adapted from Graphite's architecture:
//  - Node graph as DAG of composable operations
//  - Type-safe connections via Swift generics
//  - GPU/CPU execution paths via Metal/CoreML
//  - Caching and memoization for performance
//  - Plugin extensibility via node registry
//
//  Key concepts:
//  - NodeDescriptor: Definition of a node type (inputs, outputs, operation)
//  - NodeInstance: A placed node in a graph with parameter values
//  - NodeGraph: DAG of connected node instances
//  - GrapheneEngine: Executes graphs with caching and scheduling
//

import Foundation
import CoreGraphics

// MARK: - Node Port Types

/// Describes a data type that can flow through node connections.
public protocol PortType: Sendable {
    /// Unique identifier for this port type.
    static var typeId: String { get }

    /// Human-readable display name.
    static var displayName: String { get }

    /// Whether this type is compatible with another type for connection.
    static func isCompatible(with other: any PortType.Type) -> Bool
}

extension PortType {
    public static var typeId: String { String(describing: Self.self) }
    public static var displayName: String { String(describing: Self.self) }

    public static func isCompatible(with other: any PortType.Type) -> Bool {
        typeId == other.typeId
    }
}

// MARK: - Standard Port Types

/// Text data flowing through the graph.
public struct TextPort: PortType, Codable, Hashable {
    public let value: String
    public init(_ value: String) { self.value = value }
}

/// Numeric data flowing through the graph.
public struct NumberPort: PortType, Codable, Hashable {
    public let value: Double
    public init(_ value: Double) { self.value = value }
}

/// Boolean data flowing through the graph.
public struct BoolPort: PortType, Codable, Hashable {
    public let value: Bool
    public init(_ value: Bool) { self.value = value }
}

/// Image data reference flowing through the graph.
public struct ImagePort: PortType, Codable, Hashable {
    public let width: Int
    public let height: Int
    public let format: String
    public let storageKey: String

    public init(width: Int, height: Int, format: String, storageKey: String) {
        self.width = width
        self.height = height
        self.format = format
        self.storageKey = storageKey
    }
}

/// Audio data reference flowing through the graph.
public struct AudioPort: PortType, Codable, Hashable {
    public let duration: TimeInterval
    public let sampleRate: Int
    public let channels: Int
    public let storageKey: String

    public init(duration: TimeInterval, sampleRate: Int, channels: Int, storageKey: String) {
        self.duration = duration
        self.sampleRate = sampleRate
        self.channels = channels
        self.storageKey = storageKey
    }
}

/// Tensor/embedding data for ML operations.
public struct TensorPort: PortType, Codable, Hashable {
    public let shape: [Int]
    public let dtype: String
    public let storageKey: String

    public init(shape: [Int], dtype: String, storageKey: String) {
        self.shape = shape
        self.dtype = dtype
        self.storageKey = storageKey
    }
}

/// Generic JSON/dictionary data.
public struct JsonPort: PortType, Codable, Hashable {
    public let data: Data

    public init(_ dict: [String: Any]) throws {
        self.data = try JSONSerialization.data(withJSONObject: dict)
    }

    public init(data: Data) {
        self.data = data
    }

    public func dictionary() throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
}

// MARK: - Type-Erased Port Value

/// Type-erased wrapper for any port value.
public struct AnyPortValue: Sendable {
    public let typeId: String
    private let _value: any PortType

    public init<P: PortType>(_ value: P) {
        self.typeId = P.typeId
        self._value = value
    }

    public func `as`<P: PortType>(_ type: P.Type) -> P? {
        _value as? P
    }
}

// MARK: - Port Definitions

/// Unique identifier for a port on a node.
public struct PortId: Hashable, Codable, Sendable {
    public let nodeId: NodeInstanceId
    public let portName: String
    public let isInput: Bool

    public init(nodeId: NodeInstanceId, portName: String, isInput: Bool) {
        self.nodeId = nodeId
        self.portName = portName
        self.isInput = isInput
    }
}

/// Definition of an input port on a node type.
public struct InputPortDef: Sendable {
    public let name: String
    public let typeId: String
    public let displayName: String
    public let isRequired: Bool
    public let defaultValue: AnyPortValue?

    public init<P: PortType>(
        name: String,
        type: P.Type,
        displayName: String? = nil,
        isRequired: Bool = true,
        defaultValue: P? = nil
    ) {
        self.name = name
        self.typeId = P.typeId
        self.displayName = displayName ?? name
        self.isRequired = isRequired
        self.defaultValue = defaultValue.map { AnyPortValue($0) }
    }
}

/// Definition of an output port on a node type.
public struct OutputPortDef: Sendable {
    public let name: String
    public let typeId: String
    public let displayName: String

    public init<P: PortType>(
        name: String,
        type: P.Type,
        displayName: String? = nil
    ) {
        self.name = name
        self.typeId = P.typeId
        self.displayName = displayName ?? name
    }
}

// MARK: - Node Parameters

/// A configurable parameter on a node (not connected via port).
public struct NodeParameter: Sendable, Codable {
    public let name: String
    public let displayName: String
    public let parameterType: ParameterType
    public let defaultValue: ParameterValue

    public enum ParameterType: String, Codable, Sendable {
        case text
        case number
        case integer
        case boolean
        case choice
        case color
        case file
        case model
    }

    public init(
        name: String,
        displayName: String? = nil,
        type: ParameterType,
        defaultValue: ParameterValue
    ) {
        self.name = name
        self.displayName = displayName ?? name
        self.parameterType = type
        self.defaultValue = defaultValue
    }
}

/// Value of a node parameter.
public enum ParameterValue: Sendable, Codable, Hashable {
    case text(String)
    case number(Double)
    case integer(Int)
    case boolean(Bool)
    case choice(String, options: [String])
    case color(r: Double, g: Double, b: Double, a: Double)
    case file(path: String)
    case model(identifier: String)
    case null

    public var stringValue: String? {
        if case .text(let s) = self { return s }
        return nil
    }

    public var doubleValue: Double? {
        if case .number(let n) = self { return n }
        return nil
    }

    public var intValue: Int? {
        if case .integer(let i) = self { return i }
        return nil
    }

    public var boolValue: Bool? {
        if case .boolean(let b) = self { return b }
        return nil
    }

    public var modelIdentifier: String? {
        if case .model(let identifier) = self { return identifier }
        return nil
    }

    // Renamed from doubleValue to numberValue for consistency with common usage
    public var numberValue: Double? {
        if case .number(let n) = self { return n }
        return nil
    }
}

// MARK: - Node Descriptor

/// Unique identifier for a node type in the registry.
public struct NodeTypeId: Hashable, Codable, Sendable {
    public let category: String
    public let name: String

    public init(category: String, name: String) {
        self.category = category
        self.name = name
    }

    public var fullId: String { "\(category)/\(name)" }
}

/// Describes a type of node that can be instantiated in a graph.
public struct NodeDescriptor: Sendable {
    public let typeId: NodeTypeId
    public let displayName: String
    public let description: String
    public let category: String
    public let inputs: [InputPortDef]
    public let outputs: [OutputPortDef]
    public let parameters: [NodeParameter]
    public let executionHint: ExecutionHint
    public let isSubgraph: Bool

    public enum ExecutionHint: String, Sendable {
        case cpu           // CPU-only execution
        case gpu           // Prefer GPU via Metal
        case neural        // Use ANE via CoreML
        case hybrid        // Engine decides
        case subgraph      // Contains child graph
    }

    public init(
        typeId: NodeTypeId,
        displayName: String,
        description: String = "",
        category: String = "General",
        inputs: [InputPortDef] = [],
        outputs: [OutputPortDef] = [],
        parameters: [NodeParameter] = [],
        executionHint: ExecutionHint = .cpu,
        isSubgraph: Bool = false
    ) {
        self.typeId = typeId
        self.displayName = displayName
        self.description = description
        self.category = category
        self.inputs = inputs
        self.outputs = outputs
        self.parameters = parameters
        self.executionHint = executionHint
        self.isSubgraph = isSubgraph
    }
}

// MARK: - Node Instance

/// Unique identifier for a node instance in a graph.
public struct NodeInstanceId: Hashable, Codable, Sendable {
    public let rawValue: UUID
    public init() { self.rawValue = UUID() }
    public init(rawValue: UUID) { self.rawValue = rawValue }
}

/// A placed instance of a node type in a graph.
public struct NodeInstance: Sendable, Codable {
    public let id: NodeInstanceId
    public let typeId: NodeTypeId
    public var displayName: String
    public var parameterValues: [String: ParameterValue]
    public var position: CGPoint
    public var isCollapsed: Bool
    public var isBypassed: Bool

    public init(
        id: NodeInstanceId = NodeInstanceId(),
        typeId: NodeTypeId,
        displayName: String? = nil,
        parameterValues: [String: ParameterValue] = [:],
        position: CGPoint = .zero,
        isCollapsed: Bool = false,
        isBypassed: Bool = false
    ) {
        self.id = id
        self.typeId = typeId
        self.displayName = displayName ?? typeId.name
        self.parameterValues = parameterValues
        self.position = position
        self.isCollapsed = isCollapsed
        self.isBypassed = isBypassed
    }
}

// MARK: - Node Connections

/// A connection between two ports in the graph.
public struct NodeConnection: Hashable, Codable, Sendable {
    public let id: UUID
    public let sourceNodeId: NodeInstanceId
    public let sourcePortName: String
    public let targetNodeId: NodeInstanceId
    public let targetPortName: String

    public init(
        id: UUID = UUID(),
        sourceNodeId: NodeInstanceId,
        sourcePortName: String,
        targetNodeId: NodeInstanceId,
        targetPortName: String
    ) {
        self.id = id
        self.sourceNodeId = sourceNodeId
        self.sourcePortName = sourcePortName
        self.targetNodeId = targetNodeId
        self.targetPortName = targetPortName
    }

    public var sourcePort: PortId {
        PortId(nodeId: sourceNodeId, portName: sourcePortName, isInput: false)
    }

    public var targetPort: PortId {
        PortId(nodeId: targetNodeId, portName: targetPortName, isInput: true)
    }
}

// MARK: - Node Graph

/// Unique identifier for a node graph.
public struct NodeGraphId: Hashable, Codable, Sendable {
    public let rawValue: UUID
    public init() { self.rawValue = UUID() }
    public init(rawValue: UUID) { self.rawValue = rawValue }
}

/// A directed acyclic graph of connected nodes.
public struct NodeGraph: Sendable, Codable {
    public let id: NodeGraphId
    public var name: String
    public var description: String
    public private(set) var nodes: [NodeInstanceId: NodeInstance]
    public private(set) var connections: Set<NodeConnection>

    /// Exposed inputs that can be connected from parent graphs.
    public var exposedInputs: [String: PortId]

    /// Exposed outputs that can be connected to parent graphs.
    public var exposedOutputs: [String: PortId]

    /// Version for change tracking.
    public private(set) var version: Int

    public init(
        id: NodeGraphId = NodeGraphId(),
        name: String = "Untitled Graph",
        description: String = ""
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.nodes = [:]
        self.connections = []
        self.exposedInputs = [:]
        self.exposedOutputs = [:]
        self.version = 0
    }

    // MARK: - Node Operations

    public mutating func addNode(_ node: NodeInstance) {
        nodes[node.id] = node
        version += 1
    }

    public mutating func removeNode(_ nodeId: NodeInstanceId) {
        nodes[nodeId] = nil
        // Remove all connections involving this node
        connections = connections.filter {
            $0.sourceNodeId != nodeId && $0.targetNodeId != nodeId
        }
        version += 1
    }

    public mutating func updateNode(_ nodeId: NodeInstanceId, _ update: (inout NodeInstance) -> Void) {
        guard var node = nodes[nodeId] else { return }
        update(&node)
        nodes[nodeId] = node
        version += 1
    }

    // MARK: - Connection Operations

    public mutating func connect(
        from sourceNodeId: NodeInstanceId,
        port sourcePort: String,
        to targetNodeId: NodeInstanceId,
        port targetPort: String
    ) -> NodeConnection {
        let connection = NodeConnection(
            sourceNodeId: sourceNodeId,
            sourcePortName: sourcePort,
            targetNodeId: targetNodeId,
            targetPortName: targetPort
        )
        connections.insert(connection)
        version += 1
        return connection
    }

    public mutating func disconnect(_ connectionId: UUID) {
        connections = connections.filter { $0.id != connectionId }
        version += 1
    }

    public mutating func disconnectPort(_ portId: PortId) {
        if portId.isInput {
            connections = connections.filter {
                !($0.targetNodeId == portId.nodeId && $0.targetPortName == portId.portName)
            }
        } else {
            connections = connections.filter {
                !($0.sourceNodeId == portId.nodeId && $0.sourcePortName == portId.portName)
            }
        }
        version += 1
    }

    // MARK: - Graph Analysis

    /// Returns connections feeding into a node's inputs.
    public func incomingConnections(for nodeId: NodeInstanceId) -> [NodeConnection] {
        connections.filter { $0.targetNodeId == nodeId }
    }

    /// Returns connections flowing out of a node's outputs.
    public func outgoingConnections(for nodeId: NodeInstanceId) -> [NodeConnection] {
        connections.filter { $0.sourceNodeId == nodeId }
    }

    /// Returns nodes that have no incoming connections (entry points).
    public func rootNodes() -> [NodeInstanceId] {
        let nodesWithInputs = Set(connections.map { $0.targetNodeId })
        return nodes.keys.filter { !nodesWithInputs.contains($0) }
    }

    /// Returns nodes that have no outgoing connections (outputs).
    public func leafNodes() -> [NodeInstanceId] {
        let nodesWithOutputs = Set(connections.map { $0.sourceNodeId })
        return nodes.keys.filter { !nodesWithOutputs.contains($0) }
    }

    /// Performs topological sort for execution order.
    public func topologicalSort() throws -> [NodeInstanceId] {
        var visited = Set<NodeInstanceId>()
        var visiting = Set<NodeInstanceId>()
        var order: [NodeInstanceId] = []

        func visit(_ nodeId: NodeInstanceId) throws {
            if visited.contains(nodeId) { return }
            if visiting.contains(nodeId) {
                throw GrapheneError.cyclicGraph(nodeId: nodeId)
            }

            visiting.insert(nodeId)

            // Visit all nodes that feed into this node
            for connection in incomingConnections(for: nodeId) {
                try visit(connection.sourceNodeId)
            }

            visiting.remove(nodeId)
            visited.insert(nodeId)
            order.append(nodeId)
        }

        for nodeId in nodes.keys {
            try visit(nodeId)
        }

        return order
    }
}

// MARK: - Graphene Errors

public enum GrapheneError: Error, LocalizedError {
    case nodeTypeNotFound(NodeTypeId)
    case portNotFound(nodeId: NodeInstanceId, portName: String)
    case incompatiblePortTypes(source: String, target: String)
    case cyclicGraph(nodeId: NodeInstanceId)
    case executionFailed(nodeId: NodeInstanceId, reason: String)
    case missingRequiredInput(nodeId: NodeInstanceId, portName: String)
    case cacheError(reason: String)
    case registryError(reason: String)

    public var errorDescription: String? {
        switch self {
        case .nodeTypeNotFound(let typeId):
            return "Node type not found: \(typeId.fullId)"
        case .portNotFound(let nodeId, let portName):
            return "Port '\(portName)' not found on node \(nodeId.rawValue)"
        case .incompatiblePortTypes(let source, let target):
            return "Cannot connect \(source) to \(target)"
        case .cyclicGraph(let nodeId):
            return "Cycle detected involving node \(nodeId.rawValue)"
        case .executionFailed(let nodeId, let reason):
            return "Execution failed for node \(nodeId.rawValue): \(reason)"
        case .missingRequiredInput(let nodeId, let portName):
            return "Missing required input '\(portName)' on node \(nodeId.rawValue)"
        case .cacheError(let reason):
            return "Cache error: \(reason)"
        case .registryError(let reason):
            return "Registry error: \(reason)"
        }
    }
}
