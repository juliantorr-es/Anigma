//
//  GrapheneSubgraph.swift
//  AnigmaCore
//
//  First-class subgraph support for Graphene.
//
//  Enables:
//  - Node grouping with exposed interface ports
//  - Reusable graph templates
//  - Hierarchical graph composition
//  - Parameter passthrough from parent to child
//

import AnigmaFoundation
import AnigmaGovernance
import AnigmaJobs
import AnigmaPrimitives
import ContractsCore
import InferenceCore
import Foundation

// MARK: - Subgraph Types

/// A subgraph that can be used as a node in another graph.
public struct SubgraphDefinition: Sendable, Codable {
    public let id: SubgraphId
    public var name: String
    public var description: String
    public var version: GraphSemanticVersion
    public var graph: NodeGraph

    /// Interface ports exposed to parent graphs.
    public var interfacePorts: SubgraphInterface

    /// Parameters exposed to parent graphs.
    public var exposedParameters: [ExposedParameter]

    /// Metadata for the subgraph.
    public var metadata: SubgraphMetadata

    public init(
        id: SubgraphId = SubgraphId(),
        name: String,
        description: String = "",
        version: GraphSemanticVersion = GraphSemanticVersion(major: 1, minor: 0, patch: 0),
        graph: NodeGraph,
        interfacePorts: SubgraphInterface = SubgraphInterface(),
        exposedParameters: [ExposedParameter] = [],
        metadata: SubgraphMetadata = SubgraphMetadata()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.version = version
        self.graph = graph
        self.interfacePorts = interfacePorts
        self.exposedParameters = exposedParameters
        self.metadata = metadata
    }
}

/// Unique identifier for a subgraph definition.
public struct SubgraphId: Hashable, Codable, Sendable {
    public let rawValue: UUID
    public init() { self.rawValue = UUID() }
    public init(rawValue: UUID) { self.rawValue = rawValue }
}

/// Semantic version for subgraph versioning.
public struct GraphSemanticVersion: Hashable, Codable, Sendable, Comparable {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public var string: String { "\(major).\(minor).\(patch)" }

    public static func < (lhs: GraphSemanticVersion, rhs: GraphSemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
}

/// Interface ports for a subgraph.
public struct SubgraphInterface: Sendable, Codable {
    /// Input ports exposed to parent graphs.
    public var inputs: [InterfacePort]

    /// Output ports exposed to parent graphs.
    public var outputs: [InterfacePort]

    public init(inputs: [InterfacePort] = [], outputs: [InterfacePort] = []) {
        self.inputs = inputs
        self.outputs = outputs
    }
}

/// A port exposed at the subgraph interface.
public struct InterfacePort: Sendable, Codable, Hashable {
    public let name: String
    public let displayName: String
    public let typeId: String
    public let internalPortId: PortId
    public let description: String

    public init(
        name: String,
        displayName: String? = nil,
        typeId: String,
        internalPortId: PortId,
        description: String = ""
    ) {
        self.name = name
        self.displayName = displayName ?? name
        self.typeId = typeId
        self.internalPortId = internalPortId
        self.description = description
    }
}

/// A parameter exposed from a subgraph to its parent.
public struct ExposedParameter: Sendable, Codable {
    public let name: String
    public let displayName: String
    public let internalNodeId: NodeInstanceId
    public let internalParameterName: String
    public let parameterType: NodeParameter.ParameterType
    public let defaultValue: ParameterValue

    public init(
        name: String,
        displayName: String? = nil,
        internalNodeId: NodeInstanceId,
        internalParameterName: String,
        parameterType: NodeParameter.ParameterType,
        defaultValue: ParameterValue
    ) {
        self.name = name
        self.displayName = displayName ?? name
        self.internalNodeId = internalNodeId
        self.internalParameterName = internalParameterName
        self.parameterType = parameterType
        self.defaultValue = defaultValue
    }
}

/// Metadata about a subgraph.
public struct SubgraphMetadata: Sendable, Codable {
    public var author: String
    public var tags: [String]
    public var category: String
    public var estimatedCost: ExecutionCost
    public var supportsStreaming: Bool
    public var isBuiltIn: Bool

    public init(
        author: String = "",
        tags: [String] = [],
        category: String = "Custom",
        estimatedCost: ExecutionCost = .medium,
        supportsStreaming: Bool = false,
        isBuiltIn: Bool = false
    ) {
        self.author = author
        self.tags = tags
        self.category = category
        self.estimatedCost = estimatedCost
        self.supportsStreaming = supportsStreaming
        self.isBuiltIn = isBuiltIn
    }
}

/// Estimated execution cost for scheduling.
public enum ExecutionCost: String, Codable, Sendable {
    case trivial    // < 1ms
    case low        // 1-10ms
    case medium     // 10-100ms
    case high       // 100ms-1s
    case veryHigh   // > 1s
}

// MARK: - Subgraph Library

/// Library of reusable subgraph definitions.
public actor SubgraphLibrary {
    public static let shared = SubgraphLibrary()

    private var subgraphs: [SubgraphId: SubgraphDefinition] = [:]
    private var byName: [String: SubgraphId] = [:]
    private var byCategory: [String: Set<SubgraphId>] = [:]

    private init() {
        // Register built-in subgraphs
        Task {
            await registerBuiltInSubgraphs()
        }
    }

    // MARK: - Registration

    /// Register a subgraph definition.
    public func register(_ subgraph: SubgraphDefinition) {
        subgraphs[subgraph.id] = subgraph
        byName[subgraph.name] = subgraph.id
        byCategory[subgraph.metadata.category, default: []].insert(subgraph.id)
    }

    /// Unregister a subgraph.
    public func unregister(_ id: SubgraphId) {
        if let subgraph = subgraphs[id] {
            byName[subgraph.name] = nil
            byCategory[subgraph.metadata.category]?.remove(id)
            subgraphs[id] = nil
        }
    }

    // MARK: - Lookup

    /// Get a subgraph by ID.
    public func get(_ id: SubgraphId) -> SubgraphDefinition? {
        subgraphs[id]
    }

    /// Get a subgraph by name.
    public func get(named name: String) -> SubgraphDefinition? {
        guard let id = byName[name] else { return nil }
        return subgraphs[id]
    }

    /// Get all subgraphs in a category.
    public func subgraphs(inCategory category: String) -> [SubgraphDefinition] {
        guard let ids = byCategory[category] else { return [] }
        return ids.compactMap { subgraphs[$0] }
    }

    /// Get all categories.
    public func allCategories() -> [String] {
        Array(byCategory.keys).sorted()
    }

    /// Search subgraphs by name or tags.
    public func search(query: String) -> [SubgraphDefinition] {
        let lowered = query.lowercased()
        return subgraphs.values.filter {
            $0.name.lowercased().contains(lowered) ||
            $0.description.lowercased().contains(lowered) ||
            $0.metadata.tags.contains { $0.lowercased().contains(lowered) }
        }
    }

    // MARK: - Built-In Subgraphs

    private func registerBuiltInSubgraphs() async {
        // Register common AI pipeline templates
        await registerSummarizeSubgraph()
        await registerRAGSubgraph()
        await registerTranscribeAndSummarizeSubgraph()
    }

    private func registerSummarizeSubgraph() async {
        // Build a summarization pipeline from primitives
        var graph = NodeGraph(name: "Summarize Pipeline")

        // Add input node
        let inputNode = NodeInstance(
            typeId: NodeTypeId(category: "IO", name: "GraphInput"),
            displayName: "Text Input",
            parameterValues: ["inputName": .text("text"), "dataType": .choice("text", options: [])]
        )
        graph.addNode(inputNode)

        // Add prompt template
        let templateNode = NodeInstance(
            typeId: NodeTypeId(category: "Text", name: "TextTemplate"),
            displayName: "Summarize Prompt",
            parameterValues: ["template": .text("Summarize the following text concisely:\n\n{text}\n\nSummary:")]
        )
        graph.addNode(templateNode)

        // Add LLM node
        let llmNode = NodeInstance(
            typeId: NodeTypeId(category: "AI/LLM", name: "TextGeneration"),
            displayName: "LLM",
            parameterValues: [
                "model": .model(identifier: "llama-3.2-3b"),
                "maxTokens": .integer(200),
                "temperature": .number(0.3)
            ]
        )
        graph.addNode(llmNode)

        // Add output node
        let outputNode = NodeInstance(
            typeId: NodeTypeId(category: "IO", name: "GraphOutput"),
            displayName: "Summary Output",
            parameterValues: ["outputName": .text("summary")]
        )
        graph.addNode(outputNode)

        // Connect nodes
        // Input -> Template variables (as JSON)
        // Template result -> LLM prompt
        // LLM response -> Output

        let subgraph = SubgraphDefinition(
            name: "Summarize",
            description: "Summarizes text using an LLM with a summarization prompt",
            graph: graph,
            interfacePorts: SubgraphInterface(
                inputs: [
                    InterfacePort(
                        name: "text",
                        typeId: TextPort.typeId,
                        internalPortId: PortId(nodeId: inputNode.id, portName: "value", isInput: false),
                        description: "Text to summarize"
                    )
                ],
                outputs: [
                    InterfacePort(
                        name: "summary",
                        typeId: TextPort.typeId,
                        internalPortId: PortId(nodeId: outputNode.id, portName: "value", isInput: true),
                        description: "Summarized text"
                    )
                ]
            ),
            exposedParameters: [
                ExposedParameter(
                    name: "model",
                    internalNodeId: llmNode.id,
                    internalParameterName: "model",
                    parameterType: .model,
                    defaultValue: .model(identifier: "llama-3.2-3b")
                ),
                ExposedParameter(
                    name: "maxLength",
                    displayName: "Max Length",
                    internalNodeId: llmNode.id,
                    internalParameterName: "maxTokens",
                    parameterType: .integer,
                    defaultValue: .integer(200)
                )
            ],
            metadata: SubgraphMetadata(
                tags: ["summarization", "llm", "text"],
                category: "AI/Text",
                estimatedCost: .high,
                supportsStreaming: true,
                isBuiltIn: true
            )
        )

        register(subgraph)
    }

    private func registerRAGSubgraph() async {
        let graph = NodeGraph(name: "RAG Pipeline")

        // This would be a more complex graph with:
        // Query Input -> Embedding -> Vector Search -> Context Builder -> LLM -> Output

        let subgraph = SubgraphDefinition(
            name: "RAG Query",
            description: "Retrieval-augmented generation pipeline for document Q&A",
            graph: graph,
            metadata: SubgraphMetadata(
                tags: ["rag", "retrieval", "qa", "documents"],
                category: "AI/RAG",
                estimatedCost: .veryHigh,
                supportsStreaming: true,
                isBuiltIn: true
            )
        )

        register(subgraph)
    }

    private func registerTranscribeAndSummarizeSubgraph() async {
        let graph = NodeGraph(name: "Transcribe and Summarize")

        // Audio -> ASR -> Summarize -> Output

        let subgraph = SubgraphDefinition(
            name: "Transcribe and Summarize",
            description: "Transcribes audio and summarizes the content",
            graph: graph,
            metadata: SubgraphMetadata(
                tags: ["audio", "transcription", "summarization"],
                category: "AI/Audio",
                estimatedCost: .veryHigh,
                supportsStreaming: false,
                isBuiltIn: true
            )
        )

        register(subgraph)
    }
}

// MARK: - Subgraph Node Executor

/// Executor that runs a subgraph as a node.
public struct SubgraphExecutor: NodeExecutor {
    private let engine: GrapheneEngine
    private let library: SubgraphLibrary

    public init(engine: GrapheneEngine, library: SubgraphLibrary = .shared) {
        self.engine = engine
        self.library = library
    }

    public func execute(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue] {
        // Get subgraph ID from instance
        guard let subgraphIdString = instance.parameterValues["subgraphId"]?.stringValue,
              let subgraphId = UUID(uuidString: subgraphIdString) else {
            throw GrapheneError.executionFailed(
                nodeId: instance.id,
                reason: "Invalid subgraph ID"
            )
        }

        guard let subgraph = await library.get(SubgraphId(rawValue: subgraphId)) else {
            throw GrapheneError.executionFailed(
                nodeId: instance.id,
                reason: "Subgraph not found"
            )
        }

        // Map external inputs to internal graph inputs
        var graphInputs: [String: AnyPortValue] = [:]
        for interfaceInput in subgraph.interfacePorts.inputs {
            if let value = inputs[interfaceInput.name] {
                graphInputs[interfaceInput.name] = value
            }
        }

        // Apply exposed parameter overrides
        var modifiedGraph = subgraph.graph
        for exposedParam in subgraph.exposedParameters {
            if let overrideValue = instance.parameterValues[exposedParam.name] {
                modifiedGraph.updateNode(exposedParam.internalNodeId) { node in
                    node.parameterValues[exposedParam.internalParameterName] = overrideValue
                }
            }
        }

        // Execute the subgraph
        let result = try await engine.execute(
            graph: modifiedGraph,
            inputs: graphInputs,
            options: ExecutionOptions.default
        )

        // Map internal outputs to external outputs
        var outputs: [String: AnyPortValue] = [:]
        for interfaceOutput in subgraph.interfacePorts.outputs {
            if let value = result.outputs[interfaceOutput.name] {
                outputs[interfaceOutput.name] = value
            }
        }

        return outputs
    }
}

// MARK: - Subgraph Builder

/// Builder for creating subgraph definitions programmatically.
public struct SubgraphBuilder {
    private var definition: SubgraphDefinition
    private var graphBuilder: GraphBuilder
    private var nodeMap: [String: NodeInstanceId] = [:]

    public init(name: String, description: String = "") async {
        self.definition = SubgraphDefinition(
            name: name,
            description: description,
            graph: NodeGraph(name: name)
        )
        self.graphBuilder = GraphBuilder(name: name)
    }

    /// Add a node to the subgraph.
    @discardableResult
    public mutating func addNode(
        _ key: String,
        type: NodeTypeId,
        displayName: String? = nil,
        parameters: [String: ParameterValue] = [:]
    ) async throws -> NodeInstanceId {
        let nodeId = try await graphBuilder.addNode(
            type: type,
            displayName: displayName,
            parameters: parameters
        )
        nodeMap[key] = nodeId
        return nodeId
    }

    /// Connect two nodes.
    @discardableResult
    public mutating func connect(
        from sourceKey: String,
        port sourcePort: String,
        to targetKey: String,
        port targetPort: String
    ) -> Bool {
        guard let sourceId = nodeMap[sourceKey],
              let targetId = nodeMap[targetKey] else {
            return false
        }
        _ = graphBuilder.connect(
            from: sourceId,
            port: sourcePort,
            to: targetId,
            port: targetPort
        )
        return true
    }

    /// Expose an input port.
    public mutating func exposeInput(
        name: String,
        displayName: String? = nil,
        typeId: String,
        nodeKey: String,
        portName: String
    ) {
        guard let nodeId = nodeMap[nodeKey] else { return }
        definition.interfacePorts.inputs.append(
            InterfacePort(
                name: name,
                displayName: displayName,
                typeId: typeId,
                internalPortId: PortId(nodeId: nodeId, portName: portName, isInput: true)
            )
        )
    }

    /// Expose an output port.
    public mutating func exposeOutput(
        name: String,
        displayName: String? = nil,
        typeId: String,
        nodeKey: String,
        portName: String
    ) {
        guard let nodeId = nodeMap[nodeKey] else { return }
        definition.interfacePorts.outputs.append(
            InterfacePort(
                name: name,
                displayName: displayName,
                typeId: typeId,
                internalPortId: PortId(nodeId: nodeId, portName: portName, isInput: false)
            )
        )
    }

    /// Expose a parameter.
    public mutating func exposeParameter(
        name: String,
        displayName: String? = nil,
        nodeKey: String,
        parameterName: String,
        type: NodeParameter.ParameterType,
        defaultValue: ParameterValue
    ) {
        guard let nodeId = nodeMap[nodeKey] else { return }
        definition.exposedParameters.append(
            ExposedParameter(
                name: name,
                displayName: displayName,
                internalNodeId: nodeId,
                internalParameterName: parameterName,
                parameterType: type,
                defaultValue: defaultValue
            )
        )
    }

    /// Set metadata.
    public mutating func setMetadata(_ metadata: SubgraphMetadata) {
        definition.metadata = metadata
    }

    /// Build the final subgraph definition.
    public func build() -> SubgraphDefinition {
        var result = definition
        result.graph = graphBuilder.build()
        return result
    }
}
