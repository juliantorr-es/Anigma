//
//  ClusterManager.swift
//  HarmoniaModule
//
//  Distributed inference across multiple nodes.
//  Manages node registration, health, and task distribution.
//

import AnigmaCore
import Foundation

// MARK: - Node Types

/// Identifier for a compute node.
public struct NodeId: Hashable, Sendable, Codable {
    public let value: String

    public init(_ value: String = UUID().uuidString) {
        self.value = value
    }
}

/// A compute node in the cluster.
public struct ComputeNode: Sendable, Codable, Identifiable {
    public var id: NodeId { nodeId }
    public let nodeId: NodeId
    public let name: String
    public let address: String
    public let port: Int
    public let capabilities: NodeCapabilities
    public let tenantScope: String?
    public var status: NodeStatus
    public var lastHeartbeat: Date
    public var currentLoad: NodeLoad

    public init(
        nodeId: NodeId = NodeId(),
        name: String,
        address: String,
        port: Int = 8080,
        capabilities: NodeCapabilities,
        tenantScope: String? = nil,
        status: NodeStatus = .unknown,
        lastHeartbeat: Date = Date(),
        currentLoad: NodeLoad = NodeLoad()
    ) {
        self.nodeId = nodeId
        self.name = name
        self.address = address
        self.port = port
        self.capabilities = capabilities
        self.tenantScope = tenantScope
        self.status = status
        self.lastHeartbeat = lastHeartbeat
        self.currentLoad = currentLoad
    }
}

/// Capabilities of a compute node.
public struct NodeCapabilities: Sendable, Codable {
    public let backends: Set<BackendKind>
    public let totalVRAM: Int
    public let totalRAM: Int
    public let gpuCount: Int
    public let hasANE: Bool
    public let maxConcurrentTasks: Int
    public let supportedFormats: Set<ModelFormat>
    public let dataResidency: DataResidency

    public init(
        backends: Set<BackendKind> = [.mlx, .llamaCpp],
        totalVRAM: Int = 8 * 1024 * 1024 * 1024,
        totalRAM: Int = 16 * 1024 * 1024 * 1024,
        gpuCount: Int = 1,
        hasANE: Bool = true,
        maxConcurrentTasks: Int = 4,
        supportedFormats: Set<ModelFormat> = [.mlx, .gguf],
        dataResidency: DataResidency = .local
    ) {
        self.backends = backends
        self.totalVRAM = totalVRAM
        self.totalRAM = totalRAM
        self.gpuCount = gpuCount
        self.hasANE = hasANE
        self.maxConcurrentTasks = maxConcurrentTasks
        self.supportedFormats = supportedFormats
        self.dataResidency = dataResidency
    }
}

/// Data residency classification for a node.
public enum DataResidency: String, Sendable, Codable {
    /// Local machine only.
    case local

    /// On-premises institutional network.
    case onPremise

    /// Approved cloud region.
    case approvedCloud

    /// External/untrusted.
    case external
}

/// Status of a compute node.
public enum NodeStatus: String, Sendable, Codable {
    case online
    case offline
    case degraded
    case draining
    case unknown
}

/// Current load on a node.
public struct NodeLoad: Sendable, Codable {
    public var activeTasks: Int
    public var usedVRAM: Int
    public var usedRAM: Int
    public var cpuPercent: Double
    public var gpuPercent: Double
    public var queueDepth: Int

    public init(
        activeTasks: Int = 0,
        usedVRAM: Int = 0,
        usedRAM: Int = 0,
        cpuPercent: Double = 0,
        gpuPercent: Double = 0,
        queueDepth: Int = 0
    ) {
        self.activeTasks = activeTasks
        self.usedVRAM = usedVRAM
        self.usedRAM = usedRAM
        self.cpuPercent = cpuPercent
        self.gpuPercent = gpuPercent
        self.queueDepth = queueDepth
    }

    public var loadScore: Double {
        // Weighted load score 0-1
        let taskLoad = Double(activeTasks) / 10.0
        let vramLoad = Double(usedVRAM) / Double(8 * 1024 * 1024 * 1024)
        let gpuLoad = gpuPercent / 100.0
        return min(1.0, (taskLoad * 0.4 + vramLoad * 0.4 + gpuLoad * 0.2))
    }
}

// MARK: - Cluster Manager

/// Manages distributed inference across multiple nodes.
public actor ClusterManager {
    private var nodes: [NodeId: ComputeNode] = [:]
    private var taskAssignments: [String: NodeId] = [:]
    private let heartbeatTimeout: Duration = .seconds(30)
    private let localNodeId: NodeId

    public init(localNodeId: NodeId = NodeId("local")) {
        self.localNodeId = localNodeId
    }

    // MARK: - Node Management

    /// Registers a new node in the cluster.
    public func registerNode(_ node: ComputeNode) {
        var mutableNode = node
        mutableNode.status = .online
        mutableNode.lastHeartbeat = Date()
        nodes[node.nodeId] = mutableNode
    }

    /// Updates a node's status and load.
    public func updateNode(
        _ nodeId: NodeId,
        status: NodeStatus? = nil,
        load: NodeLoad? = nil
    ) {
        guard var node = nodes[nodeId] else { return }

        if let status = status {
            node.status = status
        }
        if let load = load {
            node.currentLoad = load
        }
        node.lastHeartbeat = Date()

        nodes[nodeId] = node
    }

    /// Records a heartbeat from a node.
    public func heartbeat(from nodeId: NodeId, load: NodeLoad) {
        guard var node = nodes[nodeId] else { return }
        node.lastHeartbeat = Date()
        node.currentLoad = load
        if node.status == .unknown || node.status == .offline {
            node.status = .online
        }
        nodes[nodeId] = node
    }

    /// Removes a node from the cluster.
    public func removeNode(_ nodeId: NodeId) {
        nodes.removeValue(forKey: nodeId)
        // Reassign any tasks from this node
        taskAssignments = taskAssignments.filter { $0.value != nodeId }
    }

    /// Gets all registered nodes.
    public func allNodes() -> [ComputeNode] {
        Array(nodes.values)
    }

    /// Gets online nodes.
    public func onlineNodes() -> [ComputeNode] {
        nodes.values.filter { $0.status == .online }
    }

    // MARK: - Node Selection

    /// Selects the best node for a task.
    public func selectNode(
        for task: InferenceTask,
        model: ModelDescriptor,
        policy: NodeSelectionPolicy = .leastLoaded
    ) -> ComputeNode? {
        let candidates = onlineNodes().filter { node in
            // Check backend support
            guard node.capabilities.backends.contains(model.backend) else { return false }

            // Check format support
            guard node.capabilities.supportedFormats.contains(model.format) else { return false }

            // Check tenant scope
            if let nodeScope = node.tenantScope {
                guard nodeScope == task.context.tenantId else { return false }
            }

            // Check data residency for privacy level
            if task.constraints.privacyLevel == .restricted {
                guard
                    node.capabilities.dataResidency == .local
                        || node.capabilities.dataResidency == .onPremise
                else { return false }
            }

            // Check capacity
            guard node.currentLoad.activeTasks < node.capabilities.maxConcurrentTasks else {
                return false
            }
            let requiredVRAMBytes = Int(model.resources.vramRequired * 1024 * 1024 * 1024)
            guard node.currentLoad.usedVRAM + requiredVRAMBytes <= node.capabilities.totalVRAM
            else { return false }

            return true
        }

        guard !candidates.isEmpty else { return nil }

        switch policy {
        case .leastLoaded:
            return candidates.min { $0.currentLoad.loadScore < $1.currentLoad.loadScore }

        case .roundRobin:
            // Simple round-robin based on task count
            return candidates.min { $0.currentLoad.activeTasks < $1.currentLoad.activeTasks }

        case .locality:
            // Prefer local node
            if let local = candidates.first(where: { $0.nodeId == localNodeId }) {
                return local
            }
            return candidates.first

        case .dedicated(let nodeId):
            return candidates.first { $0.nodeId == nodeId }
        }
    }

    // MARK: - Task Distribution

    /// Assigns a task to a node.
    public func assignTask(_ taskId: String, to nodeId: NodeId) {
        taskAssignments[taskId] = nodeId

        // Update node load
        if var node = nodes[nodeId] {
            node.currentLoad.activeTasks += 1
            node.currentLoad.queueDepth += 1
            nodes[nodeId] = node
        }
    }

    /// Marks a task as completed.
    public func completeTask(_ taskId: String) {
        guard let nodeId = taskAssignments.removeValue(forKey: taskId) else { return }

        if var node = nodes[nodeId] {
            node.currentLoad.activeTasks = max(0, node.currentLoad.activeTasks - 1)
            node.currentLoad.queueDepth = max(0, node.currentLoad.queueDepth - 1)
            nodes[nodeId] = node
        }
    }

    /// Gets the node assigned to a task.
    public func nodeForTask(_ taskId: String) -> NodeId? {
        taskAssignments[taskId]
    }

    // MARK: - Batch Distribution

    /// Distributes a batch of work across nodes.
    public func distributeBatch(
        items: [String],
        task: InferenceTask,
        model: ModelDescriptor
    ) -> BatchDistribution {
        let available = onlineNodes().filter { node in
            node.capabilities.backends.contains(model.backend)
                && node.capabilities.supportedFormats.contains(model.format)
        }

        guard !available.isEmpty else {
            return BatchDistribution(assignments: [:], errors: ["No available nodes"])
        }

        var assignments: [NodeId: [String]] = [:]
        var nodeIndex = 0

        for item in items {
            let node = available[nodeIndex % available.count]
            assignments[node.nodeId, default: []].append(item)
            nodeIndex += 1
        }

        return BatchDistribution(assignments: assignments, errors: [])
    }

    // MARK: - Health Checks

    /// Runs health checks on all nodes.
    public func runHealthChecks() {
        let now = Date()

        for (nodeId, node) in nodes {
            var mutableNode = node

            // Check heartbeat timeout
            if now.timeIntervalSince(node.lastHeartbeat) > heartbeatTimeout.timeInterval {
                mutableNode.status = .offline
            }

            // Check for degraded state
            if mutableNode.status == .online && mutableNode.currentLoad.loadScore > 0.9 {
                mutableNode.status = .degraded
            }

            nodes[nodeId] = mutableNode
        }
    }

    // MARK: - Statistics

    /// Gets cluster statistics.
    public func statistics() -> ClusterStatistics {
        let allNodes = Array(nodes.values)
        let online = allNodes.filter { $0.status == .online }
        let degraded = allNodes.filter { $0.status == .degraded }
        let offline = allNodes.filter { $0.status == .offline }

        let totalCapacity = allNodes.reduce(0) { $0 + $1.capabilities.maxConcurrentTasks }
        let currentTasks = allNodes.reduce(0) { $0 + $1.currentLoad.activeTasks }
        let totalVRAM = allNodes.reduce(0) { $0 + $1.capabilities.totalVRAM }
        let usedVRAM = allNodes.reduce(0) { $0 + $1.currentLoad.usedVRAM }

        return ClusterStatistics(
            totalNodes: allNodes.count,
            onlineNodes: online.count,
            degradedNodes: degraded.count,
            offlineNodes: offline.count,
            totalCapacity: totalCapacity,
            currentTasks: currentTasks,
            utilizationPercent: totalCapacity > 0
                ? Double(currentTasks) / Double(totalCapacity) * 100 : 0,
            totalVRAM: totalVRAM,
            usedVRAM: usedVRAM,
            pendingTasks: taskAssignments.count
        )
    }
}

/// Policy for selecting nodes.
public enum NodeSelectionPolicy: Sendable {
    case leastLoaded
    case roundRobin
    case locality
    case dedicated(NodeId)
}

/// Distribution of batch items across nodes.
public struct BatchDistribution: Sendable {
    public let assignments: [NodeId: [String]]
    public let errors: [String]
}

/// Statistics about the cluster.
public struct ClusterStatistics: Sendable {
    public let totalNodes: Int
    public let onlineNodes: Int
    public let degradedNodes: Int
    public let offlineNodes: Int
    public let totalCapacity: Int
    public let currentTasks: Int
    public let utilizationPercent: Double
    public let totalVRAM: Int
    public let usedVRAM: Int
    public let pendingTasks: Int
}

// Duration extension is defined in InferenceGovernance.swift

// MARK: - Distributed Inference Service

/// High-level service for distributed inference.
public actor DistributedInferenceService {
    private let clusterManager: ClusterManager
    private let inferenceService: InferenceService
    private let registry: ModelRegistry

    public init(
        clusterManager: ClusterManager,
        inferenceService: InferenceService,
        registry: ModelRegistry
    ) {
        self.clusterManager = clusterManager
        self.inferenceService = inferenceService
        self.registry = registry
    }

    /// Runs inference with automatic node selection.
    public func run(_ task: InferenceTask) async throws -> InferenceResult {
        // Select model
        guard let model = await registry.selectBest(for: task, tenantId: task.context.tenantId)
        else {
            throw InferenceError.noSuitableModel(constraints: "No suitable model")
        }

        // Select node
        guard let node = await clusterManager.selectNode(for: task, model: model) else {
            // Fall back to local
            return try await inferenceService.run(task)
        }

        // If local node, use local service
        if node.nodeId.value == "local" {
            return try await inferenceService.run(task)
        }

        // Otherwise, would dispatch to remote node
        // For now, fall back to local
        return try await inferenceService.run(task)
    }

    /// Runs batch inference across the cluster.
    public func runBatch(
        texts: [String],
        task: InferenceTask
    ) async throws -> [InferenceResult] {
        guard let model = await registry.selectBest(for: task, tenantId: task.context.tenantId)
        else {
            throw InferenceError.noSuitableModel(constraints: "No suitable model")
        }

        let distribution = await clusterManager.distributeBatch(
            items: texts,
            task: task,
            model: model
        )

        var results: [InferenceResult] = []

        // Process each node's batch
        for (_, items) in distribution.assignments {
            for _ in items {
                let itemTask = task
                // Would create per-item task
                let result = try await inferenceService.run(itemTask)
                results.append(result)
            }
        }

        return results
    }

    /// Gets cluster health.
    public func clusterHealth() async -> ClusterStatistics {
        await clusterManager.statistics()
    }
}
