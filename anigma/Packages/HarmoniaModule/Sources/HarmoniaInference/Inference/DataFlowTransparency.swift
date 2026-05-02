//
//  DataFlowTransparency.swift
//  HarmoniaModule
//
//  Radically Legible AI: Visualize exactly where data flows during processing.
//  Turn the black box into a visible, auditable graph.
//

@preconcurrency import Foundation
import Foundation
import HarmoniaCore
import AnigmaPrimitives
import InferenceCore
import AnigmaCore
import HarmoniaInferenceContracts

// MARK: - DataFlow Graph

/// A graph showing exactly how data moved through the system.
public struct DataFlowGraph: Sendable, Codable, Identifiable {
    public let id: String
    public let taskId: String
    public let createdAt: Date
    public let nodes: [DataFlowNode]
    public let edges: [DataFlowEdge]
    public let annotations: [DataFlowAnnotation]

    public init(
        id: String = UUID().uuidString,
        taskId: String,
        createdAt: Date = Date(),
        nodes: [DataFlowNode],
        edges: [DataFlowEdge],
        annotations: [DataFlowAnnotation] = []
    ) {
        self.id = id
        self.taskId = taskId
        self.createdAt = createdAt
        self.nodes = nodes
        self.edges = edges
        self.annotations = annotations
    }
}

// MARK: - DataFlow Node

/// A node in the data flow graph.
public struct DataFlowNode: Sendable, Codable, Identifiable, Hashable {
    public let id: String
    public let type: NodeType
    public let name: String
    public let locality: Locality
    public let securityLevel: SecurityLevel
    public let metadata: [String: String]

    public enum NodeType: String, Sendable, Codable {
        case input          // User input / document
        case preprocessor   // OCR, parsing, etc.
        case model          // LLM, embedding model, etc.
        case reasoner       // Symbolic/TRM reasoner
        case validator      // Output validation
        case output         // Final output
        case storage        // Persistence layer
        case telemetry      // Telemetry/logging
        case learning       // Institutional learning
    }

    public enum Locality: String, Sendable, Codable {
        case local          // On this machine
        case cluster        // On a trusted cluster node
        case remote         // External API
    }

    public enum SecurityLevel: String, Sendable, Codable {
        case trusted        // Full access to data
        case restricted     // Limited access / anonymized
        case auditOnly      // Metadata only
    }

    public init(
        id: String = UUID().uuidString,
        type: NodeType,
        name: String,
        locality: Locality = .local,
        securityLevel: SecurityLevel = .trusted,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.locality = locality
        self.securityLevel = securityLevel
        self.metadata = metadata
    }

    public static func == (lhs: DataFlowNode, rhs: DataFlowNode) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - DataFlow Edge

/// An edge in the data flow graph, showing data movement.
public struct DataFlowEdge: Sendable, Codable, Identifiable {
    public let id: String
    public let sourceId: String
    public let targetId: String
    public let dataType: DataType
    public let transformations: [Transformation]
    public let learningEligible: Bool

    public enum DataType: String, Sendable, Codable {
        case rawContent         // Original user content
        case processedContent   // Cleaned/parsed content
        case tokens             // Tokenized representation
        case embeddings         // Vector embeddings
        case structuredData     // Extracted structured data
        case reasoning          // Reasoning traces
        case metadata           // Non-content metadata
        case result             // Final output
    }

    public enum Transformation: String, Sendable, Codable {
        case none               // Data passed unchanged
        case anonymized         // PII removed
        case tokenized          // Converted to tokens
        case embedded           // Converted to embeddings
        case structured         // Extracted to structured form
        case summarized         // Summarized/compressed
        case encrypted          // Encrypted in transit
        case scrubbed           // Fully scrubbed (metadata only)
    }

    public init(
        id: String = UUID().uuidString,
        sourceId: String,
        targetId: String,
        dataType: DataType,
        transformations: [Transformation] = [],
        learningEligible: Bool = false
    ) {
        self.id = id
        self.sourceId = sourceId
        self.targetId = targetId
        self.dataType = dataType
        self.transformations = transformations
        self.learningEligible = learningEligible
    }
}

// MARK: - DataFlow Annotation

/// An annotation on the data flow graph.
public struct DataFlowAnnotation: Sendable, Codable {
    public let nodeOrEdgeId: String
    public let type: AnnotationType
    public let message: String

    public enum AnnotationType: String, Sendable, Codable {
        case piiScrubbed        // PII was removed here
        case learningPoint      // Data may be used for learning
        case securityBoundary   // Security boundary crossed
        case encryptionPoint    // Data encrypted here
        case noRawData          // No raw content after this point
        case blocked            // Action was blocked
    }

    public init(
        nodeOrEdgeId: String,
        type: AnnotationType,
        message: String
    ) {
        self.nodeOrEdgeId = nodeOrEdgeId
        self.type = type
        self.message = message
    }
}

// MARK: - DataFlow Builder

/// Builds data flow graphs during inference execution.
public actor DataFlowBuilder {
    private var nodes: [DataFlowNode] = []
    private var edges: [DataFlowEdge] = []
    private var annotations: [DataFlowAnnotation] = []
    private let taskId: String

    public init(taskId: String) {
        self.taskId = taskId
    }

    /// Add a node to the graph.
    public func addNode(_ node: DataFlowNode) {
        nodes.append(node)
    }

    /// Add an edge to the graph.
    public func addEdge(_ edge: DataFlowEdge) {
        edges.append(edge)
    }

    /// Add an annotation.
    public func annotate(_ nodeOrEdgeId: String, type: DataFlowAnnotation.AnnotationType, message: String) {
        annotations.append(DataFlowAnnotation(
            nodeOrEdgeId: nodeOrEdgeId,
            type: type,
            message: message
        ))
    }

    /// Build the final graph.
    public func build() -> DataFlowGraph {
        DataFlowGraph(
            taskId: taskId,
            nodes: nodes,
            edges: edges,
            annotations: annotations
        )
    }

    // MARK: - Convenience Methods

    /// Record data entering the system.
    public func recordInput(name: String, metadata: [String: String] = [:]) -> DataFlowNode {
        let node = DataFlowNode(
            type: .input,
            name: name,
            locality: .local,
            securityLevel: .trusted,
            metadata: metadata
        )
        nodes.append(node)
        return node
    }

    /// Record a model being used.
    public func recordModelUsage(
        name: String,
        modelId: String,
        isLocal: Bool,
        fromNodeId: String,
        dataType: DataFlowEdge.DataType,
        transformations: [DataFlowEdge.Transformation] = []
    ) -> DataFlowNode {
        let node = DataFlowNode(
            type: .model,
            name: name,
            locality: isLocal ? .local : .remote,
            securityLevel: isLocal ? .trusted : .restricted,
            metadata: ["modelId": modelId]
        )
        nodes.append(node)

        let edge = DataFlowEdge(
            sourceId: fromNodeId,
            targetId: node.id,
            dataType: dataType,
            transformations: transformations
        )
        edges.append(edge)

        return node
    }

    /// Record reasoning happening.
    public func recordReasoning(
        name: String,
        tier: String,
        fromNodeId: String
    ) -> DataFlowNode {
        let node = DataFlowNode(
            type: .reasoner,
            name: name,
            locality: .local,
            securityLevel: .trusted,
            metadata: ["tier": tier]
        )
        nodes.append(node)

        let edge = DataFlowEdge(
            sourceId: fromNodeId,
            targetId: node.id,
            dataType: .reasoning,
            transformations: [.structured]
        )
        edges.append(edge)

        return node
    }

    /// Record output being produced.
    public func recordOutput(name: String, fromNodeId: String) -> DataFlowNode {
        let node = DataFlowNode(
            type: .output,
            name: name,
            locality: .local,
            securityLevel: .trusted
        )
        nodes.append(node)

        let edge = DataFlowEdge(
            sourceId: fromNodeId,
            targetId: node.id,
            dataType: .result,
            transformations: []
        )
        edges.append(edge)

        return node
    }

    /// Record telemetry being generated.
    public func recordTelemetry(fromNodeId: String, scrubbed: Bool) {
        let node = DataFlowNode(
            type: .telemetry,
            name: "Telemetry",
            locality: .local,
            securityLevel: scrubbed ? .auditOnly : .restricted
        )
        nodes.append(node)

        var transformations: [DataFlowEdge.Transformation] = [.structured]
        if scrubbed {
            transformations.append(.scrubbed)
        }

        let edge = DataFlowEdge(
            sourceId: fromNodeId,
            targetId: node.id,
            dataType: .metadata,
            transformations: transformations,
            learningEligible: false
        )
        edges.append(edge)

        if scrubbed {
            annotations.append(DataFlowAnnotation(
                nodeOrEdgeId: edge.id,
                type: .piiScrubbed,
                message: "PII removed before telemetry"
            ))
        }
    }

    /// Record learning data being captured.
    public func recordLearning(fromNodeId: String, eligible: Bool, anonymous: Bool) {
        guard eligible else { return }

        let node = DataFlowNode(
            type: .learning,
            name: "Institutional Learning",
            locality: .local,
            securityLevel: anonymous ? .auditOnly : .restricted
        )
        nodes.append(node)

        var transformations: [DataFlowEdge.Transformation] = [.structured]
        if anonymous {
            transformations.append(.anonymized)
        }

        let edge = DataFlowEdge(
            sourceId: fromNodeId,
            targetId: node.id,
            dataType: .reasoning,
            transformations: transformations,
            learningEligible: true
        )
        edges.append(edge)

        annotations.append(DataFlowAnnotation(
            nodeOrEdgeId: edge.id,
            type: .learningPoint,
            message: anonymous ? "Anonymized traces used for learning" : "Traces eligible for learning"
        ))
    }
}

// MARK: - DataFlow Renderer

/// Renders data flow graphs in various formats.
public struct DataFlowRenderer {

    /// Render as ASCII art for terminal display.
    public static func renderASCII(_ graph: DataFlowGraph) -> String {
        var lines: [String] = []

        lines.append("╔═══════════════════════════════════════════════════════════╗")
        lines.append("║                     DATA FLOW GRAPH                       ║")
        lines.append("╠═══════════════════════════════════════════════════════════╣")
        lines.append("║ Task: \(graph.taskId.prefix(50))  ║")
        lines.append("╚═══════════════════════════════════════════════════════════╝")
        lines.append("")

        // Group nodes by type for vertical layout
        let nodesByType = Dictionary(grouping: graph.nodes) { $0.type }
        let typeOrder: [DataFlowNode.NodeType] = [.input, .preprocessor, .model, .reasoner, .validator, .output, .telemetry, .learning, .storage]

        for nodeType in typeOrder {
            guard let nodesOfType = nodesByType[nodeType], !nodesOfType.isEmpty else { continue }

            let typeLabel = nodeType.rawValue.uppercased()
            lines.append("  ┌─ \(typeLabel) ─────────────────────────────────────────────┐")

            for node in nodesOfType {
                let localityIcon: String
                switch node.locality {
                case .local: localityIcon = "🏠"
                case .cluster: localityIcon = "🖥️"
                case .remote: localityIcon = "🌐"
                }

                let securityIcon: String
                switch node.securityLevel {
                case .trusted: securityIcon = "🔓"
                case .restricted: securityIcon = "🔐"
                case .auditOnly: securityIcon = "📋"
                }

                lines.append("  │ \(localityIcon) \(securityIcon) \(node.name.padding(toLength: 40, withPad: " ", startingAt: 0))│")
            }

            lines.append("  └──────────────────────────────────────────────────────┘")
            lines.append("                           │")
            lines.append("                           ▼")
        }

        // Remove last arrow if present
        if lines.last == "                           ▼" {
            lines.removeLast(2)
        }

        lines.append("")

        // Annotations
        if !graph.annotations.isEmpty {
            lines.append("  ╔═ ANNOTATIONS ═══════════════════════════════════════════╗")
            for annotation in graph.annotations {
                let icon: String
                switch annotation.type {
                case .piiScrubbed: icon = "🧹"
                case .learningPoint: icon = "📚"
                case .securityBoundary: icon = "🔒"
                case .encryptionPoint: icon = "🔐"
                case .noRawData: icon = "🚫"
                case .blocked: icon = "⛔"
                }
                lines.append("  ║ \(icon) \(annotation.message.prefix(50))║")
            }
            lines.append("  ╚═══════════════════════════════════════════════════════╝")
        }

        // Legend
        lines.append("")
        lines.append("  Legend: 🏠 Local  🖥️ Cluster  🌐 Remote  |  🔓 Trusted  🔐 Restricted  📋 Audit-only")

        return lines.joined(separator: "\n")
    }

    /// Render as Mermaid diagram for documentation.
    public static func renderMermaid(_ graph: DataFlowGraph) -> String {
        var lines: [String] = []

        lines.append("```mermaid")
        lines.append("graph TD")

        // Nodes
        for node in graph.nodes {
            let shape: (String, String)
            switch node.type {
            case .input: shape = ("([", "])") // Stadium
            case .output: shape = ("([", "])") // Stadium
            case .model: shape = ("{{", "}}") // Hexagon
            case .reasoner: shape = ("[/", "/]") // Parallelogram
            case .storage: shape = ("[(", ")]") // Cylinder
            default: shape = ("[", "]") // Rectangle
            }

            let locality = node.locality == .remote ? " 🌐" : ""
            lines.append("    \(node.id)\(shape.0)\(node.name)\(locality)\(shape.1)")
        }

        lines.append("")

        // Edges
        for edge in graph.edges {
            var label = edge.dataType.rawValue
            if edge.learningEligible {
                label += " 📚"
            }
            if edge.transformations.contains(.anonymized) {
                label += " (anon)"
            }
            lines.append("    \(edge.sourceId) -->|\(label)| \(edge.targetId)")
        }

        lines.append("```")

        return lines.joined(separator: "\n")
    }

    /// Render as a simple summary.
    public static func renderSummary(_ graph: DataFlowGraph) -> String {
        let localNodes = graph.nodes.filter { $0.locality == .local }.count
        let remoteNodes = graph.nodes.filter { $0.locality == .remote }.count
        let learningEdges = graph.edges.filter { $0.learningEligible }.count
        let piiAnnotations = graph.annotations.filter { $0.type == .piiScrubbed }.count

        return """
        Data Flow Summary:
        • \(graph.nodes.count) processing nodes (\(localNodes) local, \(remoteNodes) remote)
        • \(graph.edges.count) data flows
        • \(learningEdges) edges eligible for learning
        • \(piiAnnotations) PII scrub points
        """
    }
}

// MARK: - Transparency Service

/// Central service for generating and managing transparency artifacts.
struct CompleteTrackingConfiguration: Sendable {
    let task: InferenceTask
    let result: InferenceResult
    let stages: [PipelineStage]
    let engines: [EngineUsage]
    let policy: AppliedPolicyReport
    let blockedActions: [BlockedAction]
    let reasoningExplanation: ReasoningExplanation?

    init(
        task: InferenceTask,
        result: InferenceResult,
        stages: [PipelineStage],
        engines: [EngineUsage],
        policy: AppliedPolicyReport,
        blockedActions: [BlockedAction] = [],
        reasoningExplanation: ReasoningExplanation? = nil
    ) {
        self.task = task
        self.result = result
        self.stages = stages
        self.engines = engines
        self.policy = policy
        self.blockedActions = blockedActions
        self.reasoningExplanation = reasoningExplanation
    }
}

// MARK: - Transparency Service

/// Central service for generating and managing transparency artifacts.
actor TransparencyService {
    private let receiptGenerator: ReceiptGenerator
    private var flowBuilders: [String: DataFlowBuilder] = [:]

    init() {
        self.receiptGenerator = ReceiptGenerator()
    }

    /// Start tracking a new task.
    func beginTracking(taskId: String) -> DataFlowBuilder {
        let builder = DataFlowBuilder(taskId: taskId)
        flowBuilders[taskId] = builder
        return builder
    }

    /// Complete tracking and emit transparency bundle.
    func completeTracking(
        for task: InferenceTask,
        result: InferenceResult,
        stages: [PipelineStage],
        engines: [EngineUsage],
        policy: AppliedPolicyReport,
        blockedActions: [BlockedAction],
        reasoningExplanation: ReasoningExplanation?
    ) async -> TransparencyBundle {
        let receipt = await receiptGenerator.generateReceipt(
            config: GenerateReceiptConfiguration(
                task: task,
                result: result,
                stages: stages,
                engines: engines,
                policy: policy,
                blockedActions: blockedActions,
                reasoningExplanation: reasoningExplanation
            )
        )

        let flowGraph: DataFlowGraph
        if let builder = flowBuilders[task.id] {
            flowGraph = await builder.build()
            flowBuilders.removeValue(forKey: task.id)
        } else {
            flowGraph = DataFlowGraph(taskId: task.id, nodes: [], edges: [])
        }

        return TransparencyBundle(
            receipt: receipt,
            dataFlow: flowGraph,
            generatedAt: Date()
        )
    }

    /// Get a builder for a task.
    func getBuilder(for taskId: String) -> DataFlowBuilder? {
        flowBuilders[taskId]
    }
}

// MARK: - Transparency Bundle

/// Complete transparency artifacts for an inference run.
struct TransparencyBundle: Sendable, Codable {
    let receipt: ProcessingReceipt
    let dataFlow: DataFlowGraph
    let generatedAt: Date

    /// Render all artifacts as a combined report.
    func renderFullReport() -> String {
        var lines: [String] = []

        lines.append("═══════════════════════════════════════════════════════════════")
        lines.append("              COMPLETE TRANSPARENCY REPORT")
        lines.append("═══════════════════════════════════════════════════════════════")
        lines.append("Generated: \(generatedAt)")
        lines.append("")
        lines.append(ReceiptRenderer.renderText(receipt))
        lines.append("")
        lines.append(DataFlowRenderer.renderASCII(dataFlow))

        return lines.joined(separator: "\n")
    }
}
