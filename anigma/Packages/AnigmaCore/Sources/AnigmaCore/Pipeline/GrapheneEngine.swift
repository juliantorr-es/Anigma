//
//  GrapheneEngine.swift
//  AnigmaCore
//
//  The procedural runtime that executes node graphs.
//
//  Inspired by Graphite's Graphene engine:
//  - Topological execution order
//  - Output caching and memoization
//  - GPU/CPU scheduling based on node hints
//  - Progressive refinement for expensive operations
//  - Parallel execution of independent branches
//

import Foundation
import CoreGraphics

// MARK: - Execution Result

/// Result of executing a node graph.
public struct GraphExecutionResult: Sendable {
    public let graphId: NodeGraphId
    public let outputs: [String: AnyPortValue]
    public let nodeResults: [NodeInstanceId: NodeExecutionResult]
    public let executionTime: TimeInterval
    public let cacheHits: Int
    public let cacheMisses: Int

    public init(
        graphId: NodeGraphId,
        outputs: [String: AnyPortValue],
        nodeResults: [NodeInstanceId: NodeExecutionResult],
        executionTime: TimeInterval,
        cacheHits: Int,
        cacheMisses: Int
    ) {
        self.graphId = graphId
        self.outputs = outputs
        self.nodeResults = nodeResults
        self.executionTime = executionTime
        self.cacheHits = cacheHits
        self.cacheMisses = cacheMisses
    }
}

/// Result of executing a single node.
public struct NodeExecutionResult: Sendable {
    public let nodeId: NodeInstanceId
    public let outputs: [String: AnyPortValue]
    public let executionTime: TimeInterval
    public let wasCached: Bool
    public let executionHint: NodeDescriptor.ExecutionHint

    public init(
        nodeId: NodeInstanceId,
        outputs: [String: AnyPortValue],
        executionTime: TimeInterval,
        wasCached: Bool,
        executionHint: NodeDescriptor.ExecutionHint
    ) {
        self.nodeId = nodeId
        self.outputs = outputs
        self.executionTime = executionTime
        self.wasCached = wasCached
        self.executionHint = executionHint
    }
}

// MARK: - Execution Options

/// Configuration for graph execution.
public struct ExecutionOptions: Sendable {
    public var enableCaching: Bool
    public var enableParallelExecution: Bool
    public var maxParallelNodes: Int
    public var progressiveRefinement: Bool
    public var timeout: TimeInterval?
    public var preferredExecutionHint: NodeDescriptor.ExecutionHint?

    public init(
        enableCaching: Bool = true,
        enableParallelExecution: Bool = true,
        maxParallelNodes: Int = 4,
        progressiveRefinement: Bool = false,
        timeout: TimeInterval? = nil,
        preferredExecutionHint: NodeDescriptor.ExecutionHint? = nil
    ) {
        self.enableCaching = enableCaching
        self.enableParallelExecution = enableParallelExecution
        self.maxParallelNodes = maxParallelNodes
        self.progressiveRefinement = progressiveRefinement
        self.timeout = timeout
        self.preferredExecutionHint = preferredExecutionHint
    }

    public static let `default` = ExecutionOptions()
    public static let fast = ExecutionOptions(enableCaching: true, enableParallelExecution: true, progressiveRefinement: true)
    public static let accurate = ExecutionOptions(enableCaching: true, enableParallelExecution: true, progressiveRefinement: false)
}

// MARK: - Graphene Engine

/// The procedural runtime engine for executing node graphs.
public actor GrapheneEngine {
    private let registry: NodeRegistry
    private let cache: NodeCacheProtocol
    private let resourceManager: ResourceManager

    // Execution state
    private var runningGraphs: Set<NodeGraphId> = []
    private var cancellationTokens: [NodeGraphId: CancellationToken] = [:]

    // Statistics
    private var totalExecutions: Int = 0
    private var totalCacheHits: Int = 0
    private var totalCacheMisses: Int = 0

    public init(
        registry: NodeRegistry = .shared,
        cache: NodeCacheProtocol? = nil,
        resourceManager: ResourceManager? = nil
    ) {
        self.registry = registry
        self.cache = cache ?? InMemoryNodeCache()
        self.resourceManager = resourceManager ?? ResourceManager()
    }

    // MARK: - Graph Execution

    /// Execute a node graph with optional input values.
    public func execute(
        graph: NodeGraph,
        inputs: [String: AnyPortValue] = [:],
        options: ExecutionOptions = .default
    ) async throws -> GraphExecutionResult {
        let startTime = Date()

        // Check if already running
        guard !runningGraphs.contains(graph.id) else {
            throw GrapheneError.executionFailed(
                nodeId: NodeInstanceId(),
                reason: "Graph is already executing"
            )
        }

        runningGraphs.insert(graph.id)
        defer { runningGraphs.remove(graph.id) }

        // Create cancellation token
        let cancellationToken = CancellationToken()
        cancellationTokens[graph.id] = cancellationToken
        defer { cancellationTokens[graph.id] = nil }

        // Get execution order
        let executionOrder = try graph.topologicalSort()

        // Execute nodes
        var nodeOutputs: [NodeInstanceId: [String: AnyPortValue]] = [:]
        var nodeResults: [NodeInstanceId: NodeExecutionResult] = [:]
        var cacheHits = 0
        var cacheMisses = 0

        // Inject graph inputs into input nodes
        for nodeId in executionOrder {
            guard let node = graph.nodes[nodeId] else { continue }

            // Check for cancellation
            if await cancellationToken.isCancelled {
                throw GrapheneError.executionFailed(
                    nodeId: nodeId,
                    reason: "Execution cancelled"
                )
            }

            // Skip bypassed nodes
            if node.isBypassed {
                continue
            }

            // Collect inputs from upstream connections
            var nodeInputs: [String: AnyPortValue] = [:]
            for connection in graph.incomingConnections(for: nodeId) {
                if let sourceOutputs = nodeOutputs[connection.sourceNodeId],
                   let value = sourceOutputs[connection.sourcePortName] {
                    nodeInputs[connection.targetPortName] = value
                }
            }

            // For graph input nodes, inject external inputs
            if node.typeId == NodeTypeId(category: "IO", name: "GraphInput") {
                if let inputName = node.parameterValues["inputName"]?.stringValue,
                   let externalValue = inputs[inputName] {
                    nodeInputs["external"] = externalValue
                }
            }

            // Execute the node
            let result = try await executeNode(
                graph: graph,
                node: node,
                inputs: nodeInputs,
                options: options,
                cancellationToken: cancellationToken
            )

            nodeOutputs[nodeId] = result.outputs
            nodeResults[nodeId] = result

            if result.wasCached {
                cacheHits += 1
            } else {
                cacheMisses += 1
            }
        }

        // Collect graph outputs
        var graphOutputs: [String: AnyPortValue] = [:]
        for nodeId in executionOrder {
            guard let node = graph.nodes[nodeId],
                  node.typeId == NodeTypeId(category: "IO", name: "GraphOutput") else {
                continue
            }

            if let outputName = node.parameterValues["outputName"]?.stringValue,
               let inputs = nodeOutputs[nodeId], !inputs.isEmpty {
                // Graph output nodes pass through their input
                let incomingConnections = graph.incomingConnections(for: nodeId)
                for connection in incomingConnections {
                    if let sourceOutputs = nodeOutputs[connection.sourceNodeId],
                       let value = sourceOutputs[connection.sourcePortName] {
                        graphOutputs[outputName] = value
                    }
                }
            }
        }

        // Also collect from exposed outputs
        for (name, portId) in graph.exposedOutputs {
            if let outputs = nodeOutputs[portId.nodeId],
               let value = outputs[portId.portName] {
                graphOutputs[name] = value
            }
        }

        let executionTime = Date().timeIntervalSince(startTime)

        totalExecutions += 1
        totalCacheHits += cacheHits
        totalCacheMisses += cacheMisses

        return GraphExecutionResult(
            graphId: graph.id,
            outputs: graphOutputs,
            nodeResults: nodeResults,
            executionTime: executionTime,
            cacheHits: cacheHits,
            cacheMisses: cacheMisses
        )
    }

    /// Execute a single node.
    private func executeNode(
        graph: NodeGraph,
        node: NodeInstance,
        inputs: [String: AnyPortValue],
        options: ExecutionOptions,
        cancellationToken: CancellationToken
    ) async throws -> NodeExecutionResult {
        let startTime = Date()

        // Get descriptor and executor
        guard let descriptor = await registry.descriptor(for: node.typeId) else {
            throw GrapheneError.nodeTypeNotFound(node.typeId)
        }

        guard let executor = await registry.executor(for: node.typeId) else {
            throw GrapheneError.nodeTypeNotFound(node.typeId)
        }

        // Check required inputs
        for inputDef in descriptor.inputs where inputDef.isRequired {
            if inputs[inputDef.name] == nil && inputDef.defaultValue == nil {
                throw GrapheneError.missingRequiredInput(
                    nodeId: node.id,
                    portName: inputDef.name
                )
            }
        }

        // Check cache if enabled
        if options.enableCaching {
            let cacheKey = makeCacheKey(node: node, inputs: inputs)
            if let cached = await cache.get(key: cacheKey) {
                return NodeExecutionResult(
                    nodeId: node.id,
                    outputs: cached,
                    executionTime: Date().timeIntervalSince(startTime),
                    wasCached: true,
                    executionHint: descriptor.executionHint
                )
            }
        }

        // Build execution context
        let context = GrapheneExecutionContext(
            graphId: graph.id,
            nodeId: node.id,
            cache: cache,
            resourceManager: resourceManager,
            cancellationToken: cancellationToken
        )

        // Fill in default values for missing inputs
        var finalInputs = inputs
        for inputDef in descriptor.inputs {
            if finalInputs[inputDef.name] == nil, let defaultValue = inputDef.defaultValue {
                finalInputs[inputDef.name] = defaultValue
            }
        }

        // Execute
        let outputs = try await executor.execute(
            descriptor: descriptor,
            instance: node,
            inputs: finalInputs,
            context: context
        )

        // Cache result if enabled
        if options.enableCaching {
            let cacheKey = makeCacheKey(node: node, inputs: inputs)
            await cache.set(key: cacheKey, value: outputs)
        }

        return NodeExecutionResult(
            nodeId: node.id,
            outputs: outputs,
            executionTime: Date().timeIntervalSince(startTime),
            wasCached: false,
            executionHint: descriptor.executionHint
        )
    }

    /// Create a cache key for a node execution.
    private func makeCacheKey(node: NodeInstance, inputs: [String: AnyPortValue]) -> NodeCacheKey {
        var hasher = Hasher()

        // Hash inputs
        for (key, value) in inputs.sorted(by: { $0.key < $1.key }) {
            hasher.combine(key)
            hasher.combine(value.typeId)
            // Note: Proper hashing would hash the actual values
        }

        // Hash parameters
        for (key, value) in node.parameterValues.sorted(by: { $0.key < $1.key }) {
            hasher.combine(key)
            hasher.combine(value)
        }

        return NodeCacheKey(
            nodeId: node.id,
            inputHash: hasher.finalize(),
            parameterHash: node.parameterValues.hashValue
        )
    }

    // MARK: - Graph Management

    /// Cancel execution of a running graph.
    public func cancel(graphId: NodeGraphId) async {
        if let token = cancellationTokens[graphId] {
            await token.cancel()
        }
    }

    /// Check if a graph is currently executing.
    public func isExecuting(graphId: NodeGraphId) -> Bool {
        runningGraphs.contains(graphId)
    }

    /// Invalidate cache for a specific node.
    public func invalidateCache(nodeId: NodeInstanceId) async {
        await cache.invalidate(nodeId: nodeId)
    }

    /// Clear all cached data.
    public func clearCache() async {
        await cache.invalidateAll()
    }

    // MARK: - Statistics

    /// Get engine statistics.
    public func statistics() -> EngineStatistics {
        EngineStatistics(
            totalExecutions: totalExecutions,
            totalCacheHits: totalCacheHits,
            totalCacheMisses: totalCacheMisses,
            runningGraphsCount: runningGraphs.count
        )
    }
}

/// Engine statistics.
public struct EngineStatistics: Sendable {
    public let totalExecutions: Int
    public let totalCacheHits: Int
    public let totalCacheMisses: Int
    public let runningGraphsCount: Int

    public var cacheHitRate: Double {
        let total = totalCacheHits + totalCacheMisses
        guard total > 0 else { return 0 }
        return Double(totalCacheHits) / Double(total)
    }
}

// MARK: - Graph Builder DSL

/// Builder for creating node graphs programmatically.
public struct GraphBuilder {
    private var graph: NodeGraph
    private let registry: NodeRegistry

    public init(name: String = "Untitled Graph", registry: NodeRegistry = .shared) {
        self.graph = NodeGraph(name: name)
        self.registry = registry
    }

    /// Add a node to the graph.
    @discardableResult
    public mutating func addNode(
        type: NodeTypeId,
        displayName: String? = nil,
        parameters: [String: ParameterValue] = [:],
        position: CGPoint = .zero
    ) async throws -> NodeInstanceId {
        var node = try await registry.createInstance(
            typeId: type,
            displayName: displayName,
            position: position
        )

        // Override default parameters
        for (key, value) in parameters {
            node.parameterValues[key] = value
        }

        graph.addNode(node)
        return node.id
    }

    /// Connect two nodes.
    @discardableResult
    public mutating func connect(
        from sourceNode: NodeInstanceId,
        port sourcePort: String,
        to targetNode: NodeInstanceId,
        port targetPort: String
    ) -> NodeConnection {
        graph.connect(
            from: sourceNode,
            port: sourcePort,
            to: targetNode,
            port: targetPort
        )
    }

    /// Build the final graph.
    public func build() -> NodeGraph {
        graph
    }
}

// MARK: - Graph Validation

/// Validates node graphs for correctness.
public struct GraphValidator: Sendable {

    /// Validation result.
    public struct ValidationResult: Sendable {
        public let isValid: Bool
        public let errors: [ValidationError]
        public let warnings: [ValidationWarning]
    }

    public enum ValidationError: Sendable, LocalizedError {
        case cyclicDependency(path: [NodeInstanceId])
        case missingRequiredInput(nodeId: NodeInstanceId, portName: String)
        case incompatibleConnection(connectionId: UUID, sourceType: String, targetType: String)
        case unknownNodeType(nodeId: NodeInstanceId, typeId: NodeTypeId)
        case multipleConnectionsToInput(portId: PortId)

        public var errorDescription: String? {
            switch self {
            case .cyclicDependency:
                return "Cyclic dependency detected in graph"
            case .missingRequiredInput(_, let portName):
                return "Missing required input: \(portName)"
            case .incompatibleConnection(_, let sourceType, let targetType):
                return "Cannot connect \(sourceType) to \(targetType)"
            case .unknownNodeType(_, let typeId):
                return "Unknown node type: \(typeId.fullId)"
            case .multipleConnectionsToInput(let portId):
                return "Multiple connections to input port: \(portId.portName)"
            }
        }
    }

    public enum ValidationWarning: Sendable {
        case disconnectedNode(nodeId: NodeInstanceId)
        case unusedOutput(nodeId: NodeInstanceId, portName: String)
        case deprecatedNodeType(nodeId: NodeInstanceId)
    }

    private let registry: NodeRegistry

    public init(registry: NodeRegistry = .shared) {
        self.registry = registry
    }

    /// Validate a node graph.
    public func validate(_ graph: NodeGraph) async -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []

        // Check for cycles
        do {
            _ = try graph.topologicalSort()
        } catch {
            errors.append(.cyclicDependency(path: []))
        }

        // Check each node
        for (nodeId, node) in graph.nodes {
            // Check node type exists
            guard let descriptor = await registry.descriptor(for: node.typeId) else {
                errors.append(.unknownNodeType(nodeId: nodeId, typeId: node.typeId))
                continue
            }

            // Check required inputs
            let incomingConnections = graph.incomingConnections(for: nodeId)
            let connectedInputs = Set(incomingConnections.map { $0.targetPortName })

            for inputDef in descriptor.inputs where inputDef.isRequired {
                if !connectedInputs.contains(inputDef.name) && inputDef.defaultValue == nil {
                    errors.append(.missingRequiredInput(nodeId: nodeId, portName: inputDef.name))
                }
            }

            // Check for disconnected nodes
            if incomingConnections.isEmpty && graph.outgoingConnections(for: nodeId).isEmpty {
                if node.typeId != NodeTypeId(category: "IO", name: "GraphInput") &&
                   node.typeId != NodeTypeId(category: "IO", name: "GraphOutput") {
                    warnings.append(.disconnectedNode(nodeId: nodeId))
                }
            }
        }

        // Check for multiple connections to same input
        var inputConnectionCounts: [PortId: Int] = [:]
        for connection in graph.connections {
            let portId = connection.targetPort
            inputConnectionCounts[portId, default: 0] += 1
        }
        for (portId, count) in inputConnectionCounts where count > 1 {
            errors.append(.multipleConnectionsToInput(portId: portId))
        }

        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }
}
