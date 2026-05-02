import AnigmaPrimitives

import AnigmaPrimitives

//
//  PipelineECS.swift
//  AnigmaCore
//
//  ECS integration for Graphene pipelines.
//
//  Bridges the node graph system with Anigma's ECS architecture:
//  - Pipeline components for entity storage
//  - Pipeline systems for execution and management
//  - World observer for reactive updates
//

import AnigmaFoundation
import AnigmaGovernance
import AnigmaJobs
import ContractsCore
import InferenceCore
import AnigmaJobs
import Foundation
import AnigmaPrimitives

// MARK: - Pipeline Components

/// Component storing a node graph on an entity.
public struct NodeGraphComponent: Component, Codable {
    public let graphId: NodeGraphId
    public var name: String
    public var description: String
    public var createdAt: Date
    public var modifiedAt: Date
    public var version: Int
    public var status: GraphStatus

    public enum GraphStatus: String, Codable, Sendable {
        case draft
        case valid
        case invalid
        case executing
        case completed
        case failed
    }

    public init(
        graphId: NodeGraphId = NodeGraphId(),
        name: String = "Untitled Pipeline",
        description: String = "",
        createdAt: Date = Date(),
        status: GraphStatus = .draft
    ) {
        self.graphId = graphId
        self.name = name
        self.description = description
        self.createdAt = createdAt
        self.modifiedAt = createdAt
        self.version = 0
        self.status = status
    }
}

/// Component storing serialized graph data.
public struct NodeGraphDataComponent: Component, Codable {
    public var graphData: Data

    public init(graph: NodeGraph) throws {
        self.graphData = try JSONEncoder().encode(graph)
    }

    public func decode() throws -> NodeGraph {
        try JSONDecoder().decode(NodeGraph.self, from: graphData)
    }
}

/// Component for tracking pipeline execution state.
public struct PipelineExecutionComponent: Component, Codable {
    public let executionId: UUID
    public let graphId: NodeGraphId
    public var status: ExecutionStatus
    public var startedAt: Date
    public var completedAt: Date?
    public var progress: Double
    public var currentNodeId: NodeInstanceId?
    public var error: String?

    public enum ExecutionStatus: String, Codable, Sendable {
        case pending
        case running
        case completed
        case failed
        case cancelled
    }

    public init(
        executionId: UUID = UUID(),
        graphId: NodeGraphId
    ) {
        self.executionId = executionId
        self.graphId = graphId
        self.status = .pending
        self.startedAt = Date()
        self.progress = 0
    }
}

/// Component storing pipeline execution results.
public struct PipelineResultComponent: Component, Codable {
    public let executionId: UUID
    public let graphId: NodeGraphId
    public var outputs: [String: Data] // Serialized AnyPortValue
    public var executionTime: TimeInterval
    public var cacheHits: Int
    public var cacheMisses: Int
    public var nodeCount: Int

    public init(
        executionId: UUID,
        graphId: NodeGraphId,
        result: GraphExecutionResult
    ) throws {
        self.executionId = executionId
        self.graphId = graphId
        self.outputs = try serializeGraphOutputs(result.outputs)
        self.executionTime = result.executionTime
        self.cacheHits = result.cacheHits
        self.cacheMisses = result.cacheMisses
        self.nodeCount = result.nodeResults.count
    }
}

/// Component for pipeline templates (reusable patterns).
public struct PipelineTemplateComponent: Component, Codable {
    public let templateId: UUID
    public var name: String
    public var description: String
    public var category: String
    public var tags: [String]
    public var isPublic: Bool
    public var usageCount: Int

    public init(
        templateId: UUID = UUID(),
        name: String,
        description: String = "",
        category: String = "General",
        tags: [String] = [],
        isPublic: Bool = false
    ) {
        self.templateId = templateId
        self.name = name
        self.description = description
        self.category = category
        self.tags = tags
        self.isPublic = isPublic
        self.usageCount = 0
    }
}

/// Component for pipeline scheduling and triggers.
public struct PipelineScheduleComponent: Component, Codable {
    public let scheduleId: UUID
    public let graphId: NodeGraphId
    public var isEnabled: Bool
    public var trigger: TriggerType
    public var lastRunAt: Date?
    public var nextRunAt: Date?
    public var runCount: Int

    public enum TriggerType: Codable, Sendable {
        case manual
        case scheduled(cronExpression: String)
        case onEvent(eventType: String)
        case onFileChange(path: String)
    }

    public init(
        scheduleId: UUID = UUID(),
        graphId: NodeGraphId,
        trigger: TriggerType = .manual
    ) {
        self.scheduleId = scheduleId
        self.graphId = graphId
        self.isEnabled = true
        self.trigger = trigger
        self.runCount = 0
    }
}

// MARK: - Pipeline Systems

/// System for managing pipeline execution.
public struct PipelineExecutionSystem: System {
    public var name: String { "PipelineExecution" }

    private let engine: GrapheneEngine

    public init(engine: GrapheneEngine) {
        self.engine = engine
    }

    public func update(world: World) async {
        // Find pending executions
        let pendingExecutions = await world.query(PipelineExecutionComponent.self)
            .filter { $0.1.status == .pending }

        for (entityId, var execution) in pendingExecutions {
            // Get the graph data
            guard let graphData = await world.getComponent(entityId, NodeGraphDataComponent.self),
                  let graph = try? graphData.decode() else {
                execution.status = .failed
                execution.error = "Failed to load graph"
                await world.addComponent(entityId, execution)
                continue
            }

            // Mark as running
            execution.status = .running
            await world.addComponent(entityId, execution)

            // Execute the graph
            do {
                let result = try await engine.execute(graph: graph)

                // Store result
                let resultComponent = try PipelineResultComponent(
                    executionId: execution.executionId,
                    graphId: execution.graphId,
                    result: result
                )
                await world.addComponent(entityId, resultComponent)

                // Update execution status
                execution.status = .completed
                execution.completedAt = Date()
                execution.progress = 1.0
                await world.addComponent(entityId, execution)

            } catch {
                execution.status = .failed
                execution.error = error.localizedDescription
                execution.completedAt = Date()
                await world.addComponent(entityId, execution)
            }
        }
    }
}

/// System for validating pipeline graphs.
public struct PipelineValidationSystem: System {
    public var name: String { "PipelineValidation" }

    private let validator: GraphValidator

    public init(validator: GraphValidator = GraphValidator()) {
        self.validator = validator
    }

    public func update(world: World) async {
        // Find graphs needing validation (draft status)
        let drafts = await world.query(NodeGraphComponent.self, NodeGraphDataComponent.self)
            .filter { $0.1.status == .draft }

        for (entityId, var graphComponent, graphData) in drafts {
            guard let graph = try? graphData.decode() else {
                graphComponent.status = .invalid
                await world.addComponent(entityId, graphComponent)
                continue
            }

            let result = await validator.validate(graph)
            graphComponent.status = result.isValid ? .valid : .invalid
            graphComponent.modifiedAt = Date()
            await world.addComponent(entityId, graphComponent)
        }
    }
}

/// System for cleaning up old executions.
public struct PipelineCleanupSystem: System {
    public var name: String { "PipelineCleanup" }

    private let maxAge: TimeInterval
    private let maxExecutions: Int

    public init(maxAge: TimeInterval = 86400 * 7, maxExecutions: Int = 100) {
        self.maxAge = maxAge
        self.maxExecutions = maxExecutions
    }

    public func update(world: World) async {
        let now = Date()

        // Find old completed executions
        let executions = await world.query(PipelineExecutionComponent.self)
            .filter { $0.1.status == .completed || $0.1.status == .failed }
            .filter { now.timeIntervalSince($0.1.startedAt) > maxAge }

        // Remove old executions
        for (entityId, _) in executions.prefix(executions.count > maxExecutions ? executions.count - maxExecutions : 0) {
            await world.destroyEntity(entityId)
        }
    }
}

// MARK: - Pipeline Service

/// High-level service for managing pipelines.
public actor PipelineService {
    private let world: World
    private let engine: GrapheneEngine
    private let registry: NodeRegistry

    public init(
        world: World,
        engine: GrapheneEngine? = nil,
        registry: NodeRegistry = .shared
    ) async {
        self.world = world
        self.engine = engine ?? GrapheneEngine(registry: registry)
        self.registry = registry

        // Register systems
        await world.registerSystem(PipelineValidationSystem())
        await world.registerSystem(PipelineExecutionSystem(engine: self.engine))
        await world.registerSystem(PipelineCleanupSystem())
    }

    // MARK: - Graph Management

    /// Create a new pipeline graph.
    public func createGraph(name: String, description: String = "") async -> EntityId {
        let graph = NodeGraph(name: name, description: description)

        let entityId = await world.createEntity()

        let component = NodeGraphComponent(
            graphId: graph.id,
            name: name,
            description: description
        )
        await world.addComponent(entityId, component)

        if let dataComponent = try? NodeGraphDataComponent(graph: graph) {
            await world.addComponent(entityId, dataComponent)
        }

        return entityId
    }

    /// Get a graph by entity ID.
    public func getGraph(entityId: EntityId) async -> NodeGraph? {
        guard let dataComponent = await world.getComponent(entityId, NodeGraphDataComponent.self) else {
            return nil
        }
        return try? dataComponent.decode()
    }

    /// Update a graph.
    public func updateGraph(entityId: EntityId, graph: NodeGraph) async throws {
        let dataComponent = try NodeGraphDataComponent(graph: graph)
        await world.addComponent(entityId, dataComponent)

        // Mark as draft for re-validation
        if var component = await world.getComponent(entityId, NodeGraphComponent.self) {
            component.status = .draft
            component.modifiedAt = Date()
            component.version += 1
            await world.addComponent(entityId, component)
        }
    }

    /// Delete a graph.
    public func deleteGraph(entityId: EntityId) async {
        await world.destroyEntity(entityId)
    }

    // MARK: - Execution

    /// Execute a pipeline graph.
    public func execute(
        entityId: EntityId,
        inputs: [String: AnyPortValue] = [:]
    ) async throws -> EntityId {
        guard let graphComponent = await world.getComponent(entityId, NodeGraphComponent.self) else {
            throw GrapheneError.executionFailed(
                nodeId: NodeInstanceId(),
                reason: "Graph not found"
            )
        }

        // Create execution entity
        let executionId = await world.createEntity()
        let execution = PipelineExecutionComponent(graphId: graphComponent.graphId)
        await world.addComponent(executionId, execution)

        // Copy graph data to execution
        if let dataComponent = await world.getComponent(entityId, NodeGraphDataComponent.self) {
            await world.addComponent(executionId, dataComponent)
        }

        // The PipelineExecutionSystem will pick this up and run it
        return executionId
    }

    /// Execute a graph synchronously and wait for result.
    public func executeAndWait(
        entityId: EntityId,
        inputs: [String: AnyPortValue] = [:],
        timeout: TimeInterval = 300
    ) async throws -> GraphExecutionResult {
        guard let dataComponent = await world.getComponent(entityId, NodeGraphDataComponent.self),
              let graph = try? dataComponent.decode() else {
            throw GrapheneError.executionFailed(
                nodeId: NodeInstanceId(),
                reason: "Graph not found"
            )
        }

        return try await engine.execute(graph: graph, inputs: inputs)
    }

    // MARK: - Templates

    /// Save a graph as a template.
    public func saveAsTemplate(
        entityId: EntityId,
        name: String,
        category: String = "General",
        tags: [String] = []
    ) async throws -> EntityId {
        guard let dataComponent = await world.getComponent(entityId, NodeGraphDataComponent.self) else {
            throw GrapheneError.executionFailed(
                nodeId: NodeInstanceId(),
                reason: "Graph not found"
            )
        }

        let templateId = await world.createEntity()

        let template = PipelineTemplateComponent(
            name: name,
            category: category,
            tags: tags
        )
        await world.addComponent(templateId, template)
        await world.addComponent(templateId, dataComponent)

        return templateId
    }

    /// Create a new graph from a template.
    public func createFromTemplate(templateId: EntityId, name: String) async throws -> EntityId {
        guard let dataComponent = await world.getComponent(templateId, NodeGraphDataComponent.self),
              let graph = try? dataComponent.decode() else {
            throw GrapheneError.executionFailed(
                nodeId: NodeInstanceId(),
                reason: "Template not found"
            )
        }

        // Create new graph with fresh ID
        var newGraph = NodeGraph(id: NodeGraphId(), name: name, description: graph.description)
        let nodeIdMap = buildNodeIdMap(graph: graph)
        for node in graph.nodes.values {
            guard let newId = nodeIdMap[node.id] else { continue }
            let cloned = NodeInstance(
                id: newId,
                typeId: node.typeId,
                displayName: node.displayName,
                parameterValues: node.parameterValues,
                position: node.position,
                isCollapsed: node.isCollapsed,
                isBypassed: node.isBypassed
            )
            newGraph.addNode(cloned)
        }

        for connection in graph.connections {
            guard let newSource = nodeIdMap[connection.sourceNodeId],
                  let newTarget = nodeIdMap[connection.targetNodeId] else {
                continue
            }
            _ = newGraph.connect(
                from: newSource,
                port: connection.sourcePortName,
                to: newTarget,
                port: connection.targetPortName
            )
        }

        newGraph.exposedInputs = remapPorts(
            graph.exposedInputs,
            nodeIdMap: nodeIdMap
        )
        newGraph.exposedOutputs = remapPorts(
            graph.exposedOutputs,
            nodeIdMap: nodeIdMap
        )

        let entityId = await world.createEntity()

        let component = NodeGraphComponent(
            graphId: newGraph.id,
            name: name
        )
        await world.addComponent(entityId, component)

        let newDataComponent = try NodeGraphDataComponent(graph: newGraph)
        await world.addComponent(entityId, newDataComponent)

        // Increment template usage count
        if var template = await world.getComponent(templateId, PipelineTemplateComponent.self) {
            template.usageCount += 1
            await world.addComponent(templateId, template)
        }

        return entityId
    }

    // MARK: - Registry Access

    /// Get all available node types.
    public func availableNodeTypes() async -> [NodeDescriptor] {
        await registry.allDescriptors()
    }

    /// Get node types by category.
    public func nodeTypes(inCategory category: String) async -> [NodeDescriptor] {
        await registry.descriptors(inCategory: category)
    }

    /// Search for node types.
    public func searchNodeTypes(query: String) async -> [NodeDescriptor] {
        await registry.search(query: query)
    }
}

// MARK: - Pipeline World Observer

/// Observes pipeline-related changes in the world.
public actor PipelineWorldObserver: WorldObserver {
    private var handlers: [(WorldEvent) -> Void] = []

    public init() {}

    public func addHandler(_ handler: @escaping (WorldEvent) -> Void) {
        handlers.append(handler)
    }

    nonisolated public func entityCreated(_ entity: EntityId) async {
        // Check if it's a pipeline entity
    }

    nonisolated public func entityDestroyed(_ entity: EntityId) async {
        // Cleanup any associated resources
    }

    nonisolated public func componentAdded<C: Component>(_ entity: EntityId, component: C) async {
        if component is PipelineExecutionComponent {
            // Notify handlers about new execution
        }
    }

    nonisolated public func componentRemoved<C: Component>(_ entity: EntityId, componentType: C.Type) async {
        // Handle component removal
    }
}

// MARK: - Output Serialization

private struct PortValueEnvelope: Codable {
    let typeId: String
    let payload: Data
}

private enum PortValueSerializationError: Error {
    case unsupportedType(String)
}

private func serializeGraphOutputs(_ outputs: [String: AnyPortValue]) throws -> [String: Data] {
    var encoded: [String: Data] = [:]
    for (key, value) in outputs {
        encoded[key] = try serializePortValue(value)
    }
    return encoded
}

private func serializePortValue(_ value: AnyPortValue) throws -> Data {
    let encoder = JSONEncoder()
    if let text = value.as(TextPort.self) {
        return try encoder.encode(PortValueEnvelope(typeId: TextPort.typeId, payload: encoder.encode(text)))
    }
    if let number = value.as(NumberPort.self) {
        return try encoder.encode(PortValueEnvelope(typeId: NumberPort.typeId, payload: encoder.encode(number)))
    }
    if let bool = value.as(BoolPort.self) {
        return try encoder.encode(PortValueEnvelope(typeId: BoolPort.typeId, payload: encoder.encode(bool)))
    }
    if let image = value.as(ImagePort.self) {
        return try encoder.encode(PortValueEnvelope(typeId: ImagePort.typeId, payload: encoder.encode(image)))
    }
    if let audio = value.as(AudioPort.self) {
        return try encoder.encode(PortValueEnvelope(typeId: AudioPort.typeId, payload: encoder.encode(audio)))
    }
    if let tensor = value.as(TensorPort.self) {
        return try encoder.encode(PortValueEnvelope(typeId: TensorPort.typeId, payload: encoder.encode(tensor)))
    }
    if let json = value.as(JsonPort.self) {
        return try encoder.encode(PortValueEnvelope(typeId: JsonPort.typeId, payload: encoder.encode(json)))
    }
    throw PortValueSerializationError.unsupportedType(value.typeId)
}

private func buildNodeIdMap(graph: NodeGraph) -> [NodeInstanceId: NodeInstanceId] {
    var map: [NodeInstanceId: NodeInstanceId] = [:]
    for nodeId in graph.nodes.keys {
        map[nodeId] = NodeInstanceId()
    }
    return map
}

private func remapPorts(
    _ ports: [String: PortId],
    nodeIdMap: [NodeInstanceId: NodeInstanceId]
) -> [String: PortId] {
    var remapped: [String: PortId] = [:]
    for (name, port) in ports {
        guard let newNodeId = nodeIdMap[port.nodeId] else { continue }
        remapped[name] = PortId(
            nodeId: newNodeId,
            portName: port.portName,
            isInput: port.isInput
        )
    }
    return remapped
}
