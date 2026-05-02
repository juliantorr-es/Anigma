//
//  IRService.swift
//  AnigmaCore
//
//  Service for building and querying Intermediate Representation graphs.
//  This bridges MAKER traces and state into unified IR format.
//

import AnigmaFoundation
import AnigmaGovernance
import AnigmaJobs
import AnigmaPrimitives
import InferenceCore
import Foundation
import ContractsCore
import CryptoKit

/// Actor-based service for IR graph operations
public actor IRService {

    // MARK: - Dependencies

    private let auditLog: any AuditLogging
    private let evidenceRecorder: any EvidenceRecording
    private let config: IRServiceConfig

    // MARK: - State

    private var graphs: [IRGraphId: IRGraph] = [:]
    private var graphHistory: [IRGraphId: [IRGraph]] = [:]  // version history

    // MARK: - Initialization

    public init(
        auditLog: any AuditLogging,
        evidenceRecorder: any EvidenceRecording,
        config: IRServiceConfig = .default
    ) {
        self.auditLog = auditLog
        self.evidenceRecorder = evidenceRecorder
        self.config = config
    }

    // MARK: - Public Interface

    /// Build IR graph from MAKER trace and state snapshot
    public func buildGraph(
        from trace: StepTrace,
        with stateSnapshot: StateSlice,
        graphId: IRGraphId? = nil
    ) async throws -> IRGraph {
        let id = graphId ?? IRGraphId.generate()
        let timestamp = Date()

        // Create nodes for trace components
        var nodes: [IRNode] = []

        // Add step node
        let stepNode = IRNode(
            id: IRNodeId("step_\(trace.stepId.value)"),
            kind: .step,
            type: "maker_step",
            attributes: IRAttributes([
                "stepId": .string(trace.stepId.value),
                "workflowId": .string(trace.workflowId),
                "sessionId": .string(trace.sessionId),
                "timestamp": .string(ISO8601DateFormatter().string(from: trace.timestamp)),
                "status": .string(trace.output?.status.rawValue ?? "unknown")
            ]),
            metadata: IRMetadata([
                "source": "maker_trace",
                "created_at": ISO8601DateFormatter().string(from: timestamp)
            ])
        )
        nodes.append(stepNode)

        // Add input state node
        let inputStateNode = IRNode(
            id: IRNodeId("input_state_\(trace.stepId.value)"),
            kind: .state,
            type: "state_slice",
            attributes: IRAttributes([
                "entityCount": .integer(trace.input.stateSlice.entities.count),
                "relationCount": .integer(trace.input.stateSlice.relations.count),
                "trustTier": .string(trace.input.context.trustTier.rawValue),
                "zone": .string(trace.input.context.zone.rawValue)
            ]),
            metadata: IRMetadata([
                "source": "step_input"
            ])
        )
        nodes.append(inputStateNode)

        // Add candidate nodes
        for (index, candidate) in trace.candidates.enumerated() {
            let candidateNode = IRNode(
                id: IRNodeId("candidate_\(candidate.id.value)"),
                kind: .decision,
                type: "step_candidate",
                attributes: IRAttributes([
                    "candidateId": .string(candidate.id.value),
                    "confidence": .double(candidate.confidence),
                    "reasoning": .string(candidate.reasoning),
                    "riskLevel": .string(candidate.estimatedImpact.riskLevel.rawValue),
                    "estimatedChanges": .integer(candidate.estimatedImpact.changesEstimated)
                ]),
                metadata: IRMetadata([
                    "step_id": trace.stepId.value,
                    "candidate_index": "\(index)"
                ])
            )
            nodes.append(candidateNode)

            // Add policy flag nodes for this candidate
            for (flagIndex, flag) in candidate.policyFlags.enumerated() {
                let flagNode = IRNode(
                    id: IRNodeId("flag_\(candidate.id.value)_\(flagIndex)"),
                    kind: .policy,
                    type: "policy_flag",
                    attributes: IRAttributes([
                        "policy": .string(flag.policy),
                        "severity": .string(flag.severity.rawValue),
                        "message": .string(flag.message)
                    ]),
                    metadata: IRMetadata([
                        "candidate_id": candidate.id.value,
                        "flag_index": "\(flagIndex)"
                    ])
                )
                nodes.append(flagNode)
            }
        }

        // Add decision node
        let decisionNode = IRNode(
            id: IRNodeId("decision_\(trace.stepId.value)"),
            kind: .decision,
            type: "step_decision",
            attributes: IRAttributes([
                "selectedCandidate": trace.decision.selectedCandidate.map { .string($0.value) } ?? .null,
                "rejectionReason": trace.decision.rejectionReason.map { .string($0) } ?? .null,
                "trustTierRequired": .string(trace.decision.trustTierRequired.rawValue),
                "violationCount": .integer(trace.decision.policyViolations.count)
            ]),
            metadata: IRMetadata([
                "step_id": trace.stepId.value
            ])
        )
        nodes.append(decisionNode)

        // Add output node if present
        if let output = trace.output {
            let outputNode = IRNode(
                id: IRNodeId("output_\(trace.stepId.value)"),
                kind: .artifact,
                type: "step_output",
                attributes: IRAttributes([
                    "status": .string(output.status.rawValue),
                    "duration": .double(output.metrics.duration),
                    "memoryUsed": .integer(Int(output.metrics.memoryUsed)),
                    "filesAccessed": .integer(output.metrics.filesAccessed),
                    "networkCalls": .integer(output.metrics.networkCalls),
                    "artifactCount": .integer(output.artifacts.count)
                ]),
                metadata: IRMetadata([
                    "step_id": trace.stepId.value
                ])
            )
            nodes.append(outputNode)

            // Add artifact nodes
            for (artifactIndex, artifact) in output.artifacts.enumerated() {
                let artifactNode = IRNode(
                    id: IRNodeId("artifact_\(artifact.id)"),
                    kind: .artifact,
                    type: artifact.type,
                    attributes: IRAttributes([
                        "artifactId": .string(artifact.id),
                        "type": .string(artifact.type),
                        "hash": .string(artifact.hash),
                        "location": .string(artifact.location)
                    ]),
                    metadata: IRMetadata([
                        "step_id": trace.stepId.value,
                        "artifact_index": "\(artifactIndex)"
                    ])
                )
                nodes.append(artifactNode)
            }
        }

        // Add state entities from snapshot
        for entity in stateSnapshot.entities {
            let entityNode = IRNode(
                id: IRNodeId("entity_\(entity.id)"),
                kind: .entity,
                type: entity.type,
                attributes: IRAttributes(
                    Dictionary(uniqueKeysWithValues: entity.attributes.map { key, value in
                        (key, .string(value))
                    })
                ),
                metadata: IRMetadata([
                    "source": "state_snapshot",
                    "step_id": trace.stepId.value
                ])
            )
            nodes.append(entityNode)
        }

        // Create edges
        var edges: [IREdge] = []

        // Step uses input state
        edges.append(IREdge(
            id: IREdgeId.generate(),
            from: stepNode.id,
            to: inputStateNode.id,
            kind: .uses,
            weight: 1.0,
            metadata: IRMetadata(["relationship": "step_uses_input"])
        ))

        // Step produces candidates
        for candidate in trace.candidates {
            edges.append(IREdge(
                id: IREdgeId.generate(),
                from: stepNode.id,
                to: IRNodeId("candidate_\(candidate.id.value)"),
                kind: .produces,
                weight: candidate.confidence,
                metadata: IRMetadata(["relationship": "step_produces_candidate"])
            ))
        }

        // Decision follows step
        edges.append(IREdge(
            id: IREdgeId.generate(),
            from: stepNode.id,
            to: decisionNode.id,
            kind: .follows,
            weight: 1.0,
            metadata: IRMetadata(["relationship": "decision_follows_step"])
        ))

        // Add policy violation edges
        for candidate in trace.candidates {
            for (flagIndex, _) in candidate.policyFlags.enumerated() {
                edges.append(IREdge(
                    id: IREdgeId.generate(),
                    from: IRNodeId("candidate_\(candidate.id.value)"),
                    to: IRNodeId("flag_\(candidate.id.value)_\(flagIndex)"),
                    kind: .violates,
                    weight: 1.0,
                    metadata: IRMetadata(["relationship": "candidate_violates_policy"])
                ))
            }
        }

        // Output follows decision if successful
        if let output = trace.output, output.status == .completed {
            edges.append(IREdge(
                id: IREdgeId.generate(),
                from: decisionNode.id,
                to: IRNodeId("output_\(trace.stepId.value)"),
                kind: .follows,
                weight: 1.0,
                metadata: IRMetadata(["relationship": "output_follows_decision"])
            ))
        }

        // Create graph
        let graph = IRGraph(
            id: id,
            name: "maker_trace_\(trace.workflowId)_\(trace.stepId.value)",
            version: IRVersion(major: 1, minor: 0, patch: 0, timestamp: timestamp),
            nodes: nodes,
            edges: edges,
            metadata: IRMetadata([
                "source": "maker_trace",
                "trace_id": trace.id.value,
                "workflow_id": trace.workflowId,
                "step_id": trace.stepId.value,
                "session_id": trace.sessionId,
                "created_at": ISO8601DateFormatter().string(from: timestamp)
            ]),
            indexes: buildIndexes(nodes: nodes, edges: edges)
        )

        // Validate graph contract
        let contract = IRGraphContract(graph)
        try IRGraphContract.validateInvariants(contract)

        // Store graph
        graphs[id] = graph

        // Add to history
        var history = graphHistory[id, default: []]
        history.append(graph)

        // Keep only recent versions
        let maxHistory = config.maxGraphHistory
        if history.count > maxHistory {
            history = Array(history.suffix(maxHistory))
        }
        graphHistory[id] = history

        // Persist through evidence recorder
        let irGraphData = try JSONEncoder().encode(graph)
        let irGraphHash = SHA256.hash(data: irGraphData)
        let irGraphHead = EvidenceHead(
            headId: id.value,
            headHash: irGraphHash.compactMap { String(format: "%02x", $0) }.joined(),
            timestamp: timestamp,
            lastActor: "IRService"
        )
        try await evidenceRecorder.recordEvidence(head: irGraphHead, content: irGraphData)

        // Log to audit trail
        try await auditLog.recordEvent(
            id: UUID(),
            type: ContractsCore.AuditEventType.custom,
            principal: nil,
            module: "IRService",
            description: "Built IR graph from trace \(trace.id.value)",
            metadata: [
                "traceId": trace.id.value,
                "graphId": id.value,
                "nodeCount": "\(nodes.count)",
                "edgeCount": "\(edges.count)",
                "original_event_type": "build_graph"
            ]
            )

        return graph
    }

    /// Query IR graphs with pattern matching
    public func query(_ query: IRQuery, in graphId: IRGraphId? = nil) async throws -> IRQueryResult {
        let targetGraphs = graphId.map { [$0] } ?? Array(graphs.keys)
        var allMatches: [IRMatch] = []

        for graphId in targetGraphs {
            guard let graph = graphs[graphId] else { continue }

            let matches = try queryGraph(graph, with: query)
            allMatches.append(contentsOf: matches)
        }

        // Apply pagination
        let offset = query.offset ?? 0
        let limit = query.limit ?? Int.max
        let paginatedMatches = Array(allMatches.dropFirst(offset).prefix(limit))

        return IRQueryResult(
            matches: paginatedMatches,
            total: allMatches.count,
            hasMore: offset + limit < allMatches.count
        )
    }

    /// Get stored graph by ID
    public func getGraph(_ graphId: IRGraphId) async -> IRGraph? {
        return graphs[graphId]
    }

    /// Get version history for a graph
    public func getGraphHistory(_ graphId: IRGraphId) async -> [IRGraph] {
        return graphHistory[graphId, default: []]
    }

    /// Delete old graphs based on retention policy
    public func cleanup(retentionPolicy: IRRetentionPolicy) async throws {
        let cutoffDate = Date().addingTimeInterval(-retentionPolicy.maxAge)
        var toDelete: [IRGraphId] = []

        for (graphId, graph) in graphs {
            if graph.version.timestamp < cutoffDate {
                toDelete.append(graphId)
            }
        }

        // Also check total count limit
        if graphs.count > retentionPolicy.maxGraphs {
            let sortedByDate = graphs.sorted { $0.value.version.timestamp < $1.value.version.timestamp }
            let excessCount = graphs.count - retentionPolicy.maxGraphs
            let oldestToDelete = Array(sortedByDate.prefix(excessCount)).map { $0.key }
            toDelete.append(contentsOf: oldestToDelete)
        }

        // Remove duplicates
        toDelete = Array(Set(toDelete))

        // Delete graphs
        for graphId in toDelete {
            graphs.removeValue(forKey: graphId)
            graphHistory.removeValue(forKey: graphId)
        }

        // Log cleanup
        try await auditLog.recordEvent(
            id: UUID(),
            type: ContractsCore.AuditEventType.custom,
            principal: nil,
            module: "IRService",
            description: "Removed \(toDelete.count) graphs.",
            metadata: [
                "removed_count": "\(toDelete.count)",
                "original_event_type": "cleanup"
            ]
        )
    } // Closes cleanup function

    // MARK: - Private Methods

    /// Query a single graph with pattern matching
    private func queryGraph(_ graph: IRGraph, with query: IRQuery) throws -> [IRMatch] {
        var matches: [IRMatch] = []

        switch query.pattern {
        case .node(let kind):
            let nodes = graph.nodes(ofKind: kind)
            for node in nodes {
                if matchesFilters(node, filters: query.filters) {
                    let match = IRMatch(
                        nodes: [node],
                        score: calculateNodeScore(node, filters: query.filters)
                    )
                    matches.append(match)
                }
            }

        case .edge(let kind):
            let edges = graph.edges(ofKind: kind)
            for edge in edges {
                if matchesFilters(edge, filters: query.filters) {
                    guard let fromNode = graph.node(edge.from) else {
                        fatalError("Failed to unwrap fromNode")
                    }
                    guard let toNode = graph.node(edge.to) else {
                        fatalError("Failed to unwrap toNode")
                    }
                    let match = IRMatch(
                        nodes: [fromNode, toNode],
                        edges: [edge],
                        score: calculateEdgeScore(edge, filters: query.filters)
                    )
                    matches.append(match)
                }
            }

        case .path(let edgeKinds):
            // Find all paths matching the edge kind sequence
            let paths = findPaths(in: graph, edgeKinds: edgeKinds)
            for path in paths {
                if matchesFilters(path, filters: query.filters) {
                    let match = IRMatch(
                        nodes: path.nodes,
                        edges: path.edges,
                        score: calculatePathScore(path, filters: query.filters)
                    )
                    matches.append(match)
                }
            }

        case .star:
            // Return all nodes and edges (with filters applied)
            for node in graph.nodes.values {
                if matchesFilters(node, filters: query.filters) {
                    let match = IRMatch(nodes: [node])
                    matches.append(match)
                }
            }

        case .sequence, .alternative, .conditional:
            throw IRServiceError.unsupportedPattern(query.pattern)
        }

        // Sort matches by score (descending)
        matches.sort { $0.score ?? 0 > $1.score ?? 0 }

        return matches
    }

    /// Check if node matches filters
    private func matchesFilters(_ node: IRNode, filters: [IRFilter]) -> Bool {
        return filters.allSatisfy { filter in
            guard let value = node.attributes[filter.attribute] else { return false }
            return matchesFilter(value: value, filter: filter)
        }
    }

    /// Check if edge matches filters
    private func matchesFilters(_ edge: IREdge, filters: [IRFilter]) -> Bool {
        return filters.allSatisfy { filter in
            guard let value = edge.attributes[filter.attribute] else { return false }
            return matchesFilter(value: value, filter: filter)
        }
    }

    /// Check if path matches filters
    private func matchesFilters(_ path: GraphPath, filters: [IRFilter]) -> Bool {
        // For MVP, only check node attributes
        for node in path.nodes {
            guard matchesFilters(node, filters: filters) else { return false }
        }
        return true
    }

    /// Match attribute value against filter
    private func matchesFilter(value: IRAttributeValue, filter: IRFilter) -> Bool {
        switch filter.op {
        case .equals:
            return value == filter.value
        case .notEquals:
            return value != filter.value
        case .greaterThan:
            return compareValues(value, filter.value) == .orderedAscending
        case .greaterThanOrEqual:
            let comparison = compareValues(value, filter.value)
            return comparison == .orderedAscending || comparison == .orderedSame
        case .lessThan:
            return compareValues(value, filter.value) == .orderedDescending
        case .lessThanOrEqual:
            let comparison = compareValues(value, filter.value)
            return comparison == .orderedDescending || comparison == .orderedSame
        case .contains:
            if case .array(let array) = value {
                return array.contains(filter.value)
            }
            return false
        case .notContains:
            if case .array(let array) = value {
                return !array.contains(filter.value)
            }
            return true
        case .matches:
            // Simple string matching for MVP
            if case .string(let valueStr) = value,
               case .string(let filterStr) = filter.value {
                return valueStr.range(of: filterStr, options: .regularExpression) != nil
            }
            return false
        case .notMatches:
            if case .string(let valueStr) = value,
               case .string(let filterStr) = filter.value {
                return valueStr.range(of: filterStr, options: .regularExpression) == nil
            }
            return true
        case .in:
            if case .array(let array) = filter.value {
                return array.contains(value)
            }
            return false
        case .notIn:
            if case .array(let array) = filter.value {
                return !array.contains(value)
            }
            return true
        }
    }

    /// Compare two attribute values
    private func compareValues(_ lhs: IRAttributeValue, _ rhs: IRAttributeValue) -> ComparisonResult {
        switch (lhs, rhs) {
        case (.integer(let a), .integer(let b)):
            return a < b ? .orderedAscending : a > b ? .orderedDescending : .orderedSame
        case (.double(let a), .double(let b)):
            return a < b ? .orderedAscending : a > b ? .orderedDescending : .orderedSame
        case (.string(let a), .string(let b)):
            return a < b ? .orderedAscending : a > b ? .orderedDescending : .orderedSame
        default:
            return .orderedSame  // Cannot compare different types
        }
    }

    /// Calculate score for node match
    private func calculateNodeScore(_ node: IRNode, filters: [IRFilter]) -> Double {
        // Simple scoring for MVP - count of matching attributes
        let matchingAttributes = filters.filter { filter in
            node.attributes.contains(filter.attribute)
        }.count

        return Double(matchingAttributes) / Double(max(filters.count, 1))
    }

    /// Calculate score for edge match
    private func calculateEdgeScore(_ edge: IREdge, filters: [IRFilter]) -> Double {
        // Use weight as base score, adjust for filter matches
        let baseScore = edge.weight ?? 1.0
        let filterBonus = calculateEdgeFilterScore(edge, filters: filters)
        return baseScore + filterBonus
    }

    /// Calculate filter match bonus for edge
    private func calculateEdgeFilterScore(_ edge: IREdge, filters: [IRFilter]) -> Double {
        let matchingAttributes = filters.filter { filter in
            edge.attributes.contains(filter.attribute)
        }.count

        return Double(matchingAttributes) * 0.1  // Small bonus for filter matches
    }

    /// Calculate score for path match
    private func calculatePathScore(_ path: GraphPath, filters: [IRFilter]) -> Double {
        // Average of node scores plus edge weights
        let nodeScores = path.nodes.map { calculateNodeScore($0, filters: filters) }
        let avgNodeScore = nodeScores.reduce(0, +) / Double(nodeScores.count)

        let edgeWeightSum = path.edges.compactMap { $0.weight }.reduce(0, +)

        return avgNodeScore + edgeWeightSum * 0.1
    }

    /// Find paths matching edge kind sequence
    private func findPaths(in graph: IRGraph, edgeKinds: [IREdgeKind]) -> [GraphPath] {
        guard !edgeKinds.isEmpty else { return [] }

        var paths: [GraphPath] = []

        // Start from all nodes that could be path start
        for node in graph.nodes.values {
            let path = findPathFrom(node, in: graph, edgeKinds: edgeKinds, visited: Set())
            if !path.isEmpty {
                paths.append(path)
            }
        }

        return paths
    }

    /// Find path starting from node with edge kind sequence
    private func findPathFrom(
        _ startNode: IRNode,
        in graph: IRGraph,
        edgeKinds: [IREdgeKind],
        visited: Set<IRNodeId>
    ) -> GraphPath {
        guard !edgeKinds.isEmpty else { return GraphPath(nodes: [startNode], edges: []) }

        let currentEdgeKind = edgeKinds[0]
        let remainingEdgeKinds = Array(edgeKinds.dropFirst())

        // Find outgoing edges of the right kind
        let candidateEdges = graph.outgoingEdges(from: startNode.id)
            .filter { $0.kind == currentEdgeKind }

        for edge in candidateEdges {
            guard let nextNode = graph.node(edge.to) else { continue }
            guard !visited.contains(nextNode.id) else { continue }

            let newPath = findPathFrom(
                nextNode,
                in: graph,
                edgeKinds: remainingEdgeKinds,
                visited: visited.union([nextNode.id])
            )

            if !newPath.isEmpty {
                return GraphPath(
                    nodes: [startNode] + newPath.nodes,
                    edges: [edge] + newPath.edges
                )
            }
        }

        return GraphPath(nodes: [], edges: [])
    }

    /// Build indexes for efficient querying
    private func buildIndexes(nodes: [IRNode], edges: [IREdge]) -> IRIndexes {
        var nodeKindIndex: [IRNodeKind: Set<IRNodeId>] = [:]
        var edgeKindIndex: [IREdgeKind: Set<IREdgeId>] = [:]
        var nodeTypeIndex: [String: Set<IRNodeId>] = [:]
        var adjacencyIndex: [IRNodeId: Set<IRNodeId>] = [:]

        // Build node indexes
        for node in nodes {
            nodeKindIndex[node.kind, default: []].insert(node.id)
            nodeTypeIndex[node.type, default: []].insert(node.id)
        }

        // Build edge indexes
        for edge in edges {
            edgeKindIndex[edge.kind, default: []].insert(edge.id)
            adjacencyIndex[edge.from, default: []].insert(edge.to)
        }

        return IRIndexes(
            nodeKindIndex: nodeKindIndex,
            edgeKindIndex: edgeKindIndex,
            nodeTypeIndex: nodeTypeIndex,
            adjacencyIndex: adjacencyIndex
        )
    }
}

// MARK: - Supporting Types

/// Configuration for IR service
public struct IRServiceConfig: Sendable {
    public let maxGraphHistory: Int
    public let enablePersistence: Bool
    public let maxQueryResults: Int

    public init(
        maxGraphHistory: Int = 10,
        enablePersistence: Bool = true,
        maxQueryResults: Int = 1000
    ) {
        self.maxGraphHistory = maxGraphHistory
        self.enablePersistence = enablePersistence
        self.maxQueryResults = maxQueryResults
    }

    public static let `default` = IRServiceConfig()
}

/// Retention policy for IR graphs
public struct IRRetentionPolicy: Sendable {
    public let maxAge: TimeInterval
    public let maxGraphs: Int

    public init(maxAge: TimeInterval, maxGraphs: Int) {
        self.maxAge = maxAge
        self.maxGraphs = maxGraphs
    }

    public static let `default` = IRRetentionPolicy(
        maxAge: 7 * 24 * 60 * 60,  // 7 days
        maxGraphs: 1000
    )
}

/// Path through graph
public struct GraphPath: Sendable {
    public let nodes: [IRNode]
    public let edges: [IREdge]

    public init(nodes: [IRNode], edges: [IREdge]) {
        self.nodes = nodes
        self.edges = edges
    }

    public var isEmpty: Bool {
        nodes.isEmpty && edges.isEmpty
    }
}

/// Errors specific to IR service
public enum IRServiceError: Error, Sendable {
    case graphNotFound(IRGraphId)
    case unsupportedPattern(IRPattern)
    case queryTimeout
    case invalidQuery(String)

    public var localizedDescription: String {
        switch self {
        case .graphNotFound(let id):
            return "IR graph not found: \(id.value)"
        case .unsupportedPattern(let pattern):
            return "Unsupported query pattern: \(pattern.description)"
        case .queryTimeout:
            return "Query timed out"
        case .invalidQuery(let message):
            return "Invalid query: \(message)"
        }
    }
}
