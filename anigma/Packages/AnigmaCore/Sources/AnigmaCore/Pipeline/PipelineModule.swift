//
//  PipelineModule.swift
//  AnigmaCore
//
//  Module registration for the Graphene pipeline system.
//
//  This module provides:
//  - Node graph core (GrapheneCore)
//  - Node registry and built-in nodes (GrapheneRegistry)
//  - Graph execution engine (GrapheneEngine)
//  - AI/ML node types (AINodes)
//  - Primitive composable nodes (GraphenePrimitives)
//  - Subgraph support (GrapheneSubgraph)
//  - Streaming support (GrapheneStreaming)
//  - Profiling and introspection (GrapheneProfiling)
//  - Inference bridge (GrapheneInferenceBridge)
//  - ECS integration (PipelineECS)
//  - Plugin system (PluginSystem)
//

import Foundation
import ContractsCore
import DatabaseCore

// MARK: - Pipeline Module

/// Registration and configuration for the Pipeline module.
public struct PipelineModule {

    public static let moduleId = "anigma.core.pipeline"
    public static let moduleName = "Pipeline"
    public static let version = "1.1.0"

    /// Initialize the pipeline module with default configuration.
    public static func initialize(mlWorkerPath: String) async {
        // Register primitive nodes
        await PrimitiveNodeRegistrar.registerAll(registry: NodeRegistry.shared)

        // Create ML Worker Interface
        let mlWorker = MLWorkerProcessInterface(mlWorkerPath: mlWorkerPath)
        let inferencePlane = MLWorkerInferencePlane(mlWorker: mlWorker)

        // Register AI nodes with the shared registry
        await AINodeRegistrar.registerAll(
            registry: NodeRegistry.shared,
            inference: inferencePlane
        )

        // Initialize the subgraph library with built-ins
        _ = SubgraphLibrary.shared

        // Initialize the profiler
        _ = GrapheneProfiler.shared

        // Initialize the inference bridge registry
        _ = InferenceBridgeRegistry.shared
    }

    /// Get module information.
    public static var info: ModuleInfo {
        ModuleInfo(
            id: moduleId,
            name: moduleName,
            version: version,
            description: "Graphene-inspired node graph pipeline system for composable AI and media workflows",
            capabilities: [
                .nodeGraphExecution,
                .aiInference,
                .mediaProcessing,
                .pluginExtensibility,
                .subgraphComposition,
                .streamingExecution,
                .executionProfiling
            ]
        )
    }

    /// Module capabilities.
    public enum Capability: String, Sendable {
        case nodeGraphExecution = "node_graph_execution"
        case aiInference = "ai_inference"
        case mediaProcessing = "media_processing"
        case pluginExtensibility = "plugin_extensibility"
        case subgraphComposition = "subgraph_composition"
        case streamingExecution = "streaming_execution"
        case executionProfiling = "execution_profiling"
    }

    /// Module information structure.
    public struct ModuleInfo: Sendable {
        public let id: String
        public let name: String
        public let version: String
        public let description: String
        public let capabilities: [Capability]
    }
}

// MARK: - Module Pipeline Factory

/// Factory for creating pipeline-related objects.
/// Note: PipelineFactory in GrapheneVerticalSlice.swift is for creating graph templates.
public struct ModulePipelineFactory {

    /// Create a new GrapheneEngine with default configuration.
    public static func createEngine(
        cache: NodeCacheProtocol? = nil,
        resourceManager: ResourceManager? = nil
    ) -> GrapheneEngine {
        GrapheneEngine(
            registry: NodeRegistry.shared,
            cache: cache,
            resourceManager: resourceManager
        )
    }

    /// Create a new PipelineService for managing pipelines.
    public static func createService(world: World) async -> PipelineService {
        await PipelineService(world: world)
    }

    /// Create a GraphValidator for validating graphs.
    public static func createValidator() -> GraphValidator {
        GraphValidator(registry: NodeRegistry.shared)
    }

    /// Create a GraphBuilder for programmatic graph construction.
    public static func createBuilder(name: String = "Untitled Graph") -> GraphBuilder {
        GraphBuilder(name: name, registry: NodeRegistry.shared)
    }

    /// Create a PipelineRunner for high-level pipeline execution.
    /// - Parameters:
    ///   - engine: An optional GrapheneEngine. (Note: currently ignored in PipelineRunner construction for explicit dependency injection.)
    ///   - mlWorkerPath: The file path to the MLWorkerExecutable binary.
    /// - Returns: A configured PipelineRunner instance.
    /// - Throws: An error if database setup or PipelineRunner initialization fails.
    public static func createRunner(engine: GrapheneEngine? = nil, mlWorkerPath: String) async throws -> PipelineRunner {
        // --- Database Setup ---
        // Using a persistent location for the database.
        let fileManager = FileManager.default
        let appSupportDir = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let anigmaDir = appSupportDir.appendingPathComponent("Anigma")
        if !fileManager.fileExists(atPath: anigmaDir.path) {
            try fileManager.createDirectory(at: anigmaDir, withIntermediateDirectories: true, attributes: nil)
        }
        let dbPath = anigmaDir.appendingPathComponent("pipeline.sqlite").path

        let db = DatabaseActor(dbPath: dbPath)
        try await db.open()

        let jobQueue = try await ContractJobQueue(database: db) { Date() }
        let receiptStore = try await ReceiptStore(database: db)
        let artifactDB = try await DatabaseArtifactStore(database: db)
        let pipelineStore = DatabaseBackedPipelineArtifactStore(store: artifactDB, database: db)

        // --- Contract Registry Setup ---
        let registry = await makePDFPipelineRegistry() // Use existing PDF pipeline contracts

        // --- Pipeline Plan Setup ---
        // Define the standard PDF ingestion and processing pipeline graph
        let pdfPipelineGraph = PipelineGraph(edges: [
            PDFIngestContract.id.name: [PDFSegmentContract.id.name],
            PDFSegmentContract.id.name: [PDFExtractContract.id.name],
            PDFExtractContract.id.name: [PDFQACheckContract.id.name],
            PDFQACheckContract.id.name: [EmbedTextContract.id.name],
            EmbedTextContract.id.name: [IndexEmbeddingsContract.id.name],
            IndexEmbeddingsContract.id.name: [] // Terminal contract for now
        ])
        // The root artifact will be provided when the pipeline is actually run
        let pipelinePlan = PipelinePlan(sessionID: UUID().uuidString, graph: pdfPipelineGraph, rootArtifactRefs: [])

        // --- Embedding Computer Setup ---
        let embeddingComputer = MLWorkerEmbeddingComputer(mlWorkerPath: mlWorkerPath)

        // Create a GrapheneEngine instance (use provided one or create new)
        let grapheneEngine = engine ?? GrapheneEngine() // Create a new instance if not provided

        // --- PipelineRunner Instantiation ---
        // Call the comprehensive initializer with explicitly created dependencies
        let runner = try await PipelineRunner(
            plan: pipelinePlan,
            registry: registry,
            jobQueue: jobQueue,
            receiptStore: receiptStore,
            artifactStore: pipelineStore,
            defaultBudgets: ContractBudgets(maxWallTime: 5, maxRetries: 0),
            executorIdentity: "ModulePipelineFactory",
            embeddingComputer: embeddingComputer,
            grapheneEngine: grapheneEngine
        ) // Pass the created engine
            { Date() }

        return runner
    }
}

// MARK: - Quick Start Helpers

extension ModulePipelineFactory {

    /// Create a simple text processing pipeline.
    public static func createTextPipeline() async throws -> NodeGraph {
        var builder = createBuilder(name: "Text Pipeline")

        let inputNode = try await builder.addNode(
            type: NodeTypeId(category: "Text", name: "TextInput"),
            displayName: "Input Text",
            parameters: ["value": .text("Enter your text here")]
        )

        let outputNode = try await builder.addNode(
            type: NodeTypeId(category: "IO", name: "GraphOutput"),
            displayName: "Output",
            parameters: ["outputName": .text("result")]
        )

        builder.connect(from: inputNode, port: "text", to: outputNode, port: "value")

        return builder.build()
    }

    /// Create a RAG (Retrieval-Augmented Generation) pipeline.
    public static func createRAGPipeline() async throws -> NodeGraph {
        var builder = createBuilder(name: "RAG Pipeline")

        // Query input
        let queryInput = try await builder.addNode(
            type: NodeTypeId(category: "IO", name: "GraphInput"),
            displayName: "Query Input",
            parameters: ["inputName": .text("query")]
        )

        // Documents input
        let docsInput = try await builder.addNode(
            type: NodeTypeId(category: "IO", name: "GraphInput"),
            displayName: "Documents Input",
            parameters: ["inputName": .text("documents"), "dataType": .choice("json", options: ["text", "json"])]
        )

        // RAG Query node
        let ragNode = try await builder.addNode(
            type: NodeTypeId(category: "AI/RAG", name: "RAGQuery"),
            displayName: "RAG Query"
        )

        // Output
        let outputNode = try await builder.addNode(
            type: NodeTypeId(category: "IO", name: "GraphOutput"),
            displayName: "Answer Output",
            parameters: ["outputName": .text("answer")]
        )

        // Connect
        builder.connect(from: queryInput, port: "value", to: ragNode, port: "query")
        builder.connect(from: docsInput, port: "value", to: ragNode, port: "documents")
        builder.connect(from: ragNode, port: "answer", to: outputNode, port: "value")

        return builder.build()
    }

    /// Create a multimodal pipeline (image + text).
    public static func createMultimodalPipeline() async throws -> NodeGraph {
        var builder = createBuilder(name: "Multimodal Pipeline")

        // Image input (would be provided externally)
        let imageInput = try await builder.addNode(
            type: NodeTypeId(category: "IO", name: "GraphInput"),
            displayName: "Image Input",
            parameters: ["inputName": .text("image"), "dataType": .choice("image", options: ["text", "image"])]
        )

        // OCR
        let ocrNode = try await builder.addNode(
            type: NodeTypeId(category: "AI/Vision", name: "OCR"),
            displayName: "Extract Text"
        )

        // Image description
        let describeNode = try await builder.addNode(
            type: NodeTypeId(category: "AI/Vision", name: "DescribeImage"),
            displayName: "Describe Image"
        )

        // Combine text
        let concatNode = try await builder.addNode(
            type: NodeTypeId(category: "Text", name: "TextConcat"),
            displayName: "Combine",
            parameters: ["separator": .text("\n\n")]
        )

        // Output
        let outputNode = try await builder.addNode(
            type: NodeTypeId(category: "IO", name: "GraphOutput"),
            displayName: "Result",
            parameters: ["outputName": .text("combined")]
        )

        // Connect
        builder.connect(from: imageInput, port: "value", to: ocrNode, port: "image")
        builder.connect(from: imageInput, port: "value", to: describeNode, port: "image")
        builder.connect(from: ocrNode, port: "text", to: concatNode, port: "a")
        builder.connect(from: describeNode, port: "description", to: concatNode, port: "b")
        builder.connect(from: concatNode, port: "result", to: outputNode, port: "value")

        return builder.build()
    }
}

// MARK: - Convenience Extensions

extension NodeGraph {

    /// Create a duplicate of this graph with a new ID.
    public func duplicate(newName: String? = nil) -> NodeGraph {
        var copy = NodeGraph(
            id: NodeGraphId(),
            name: newName ?? "\(name) (Copy)",
            description: description
        )

        // Copy nodes with new IDs, keeping a mapping
        var idMapping: [NodeInstanceId: NodeInstanceId] = [:]

        for (oldId, node) in nodes {
            let newId = NodeInstanceId()
            idMapping[oldId] = newId

            // Note: We need to create a new node with the new ID
            // This is a simplified version; full implementation would deep-copy
            copy.addNode(NodeInstance(
                id: newId,
                typeId: node.typeId,
                displayName: node.displayName,
                parameterValues: node.parameterValues,
                position: node.position,
                isCollapsed: node.isCollapsed,
                isBypassed: node.isBypassed
            ))
        }

        // Copy connections with updated IDs
        for connection in connections {
            if let newSourceId = idMapping[connection.sourceNodeId],
               let newTargetId = idMapping[connection.targetNodeId] {
                _ = copy.connect(
                    from: newSourceId,
                    port: connection.sourcePortName,
                    to: newTargetId,
                    port: connection.targetPortName
                )
            }
        }

        return copy
    }

    /// Get a summary of the graph for display.
    public var summary: String {
        """
        Graph: \(name)
        Nodes: \(nodes.count)
        Connections: \(connections.count)
        Roots: \(rootNodes().count)
        Outputs: \(leafNodes().count)
        """
    }
}

extension GraphExecutionResult {

    /// Get a summary of the execution for display.
    public var summary: String {
        """
        Execution completed in \(String(format: "%.3f", executionTime))s
        Nodes executed: \(nodeResults.count)
        Cache hits: \(cacheHits), misses: \(cacheMisses)
        Hit rate: \(String(format: "%.1f", cacheHitRate * 100))%
        """
    }

    /// Cache hit rate as a percentage.
    public var cacheHitRate: Double {
        let total = cacheHits + cacheMisses
        guard total > 0 else { return 0 }
        return Double(cacheHits) / Double(total)
    }
}
