//
//  IRSchema.swift
//  HarmoniaModule
//
//  Phase 8.5.4: Minimum IR Schema for Phase 9
//  Defines core entities/relations/metrics needed to power trace normalization
//  and step evaluation, avoiding representation learning/architecture search.
//

@preconcurrency import Foundation
import AnigmaPrimitives

// MARK: - Deterministic helpers

private enum IRDeterminism {
    static func hexDigest(for fields: [String]) -> String {
        let joined = fields.joined(separator: "|")
        let data = joined.data(using: .utf8) ?? Data()
        return BLAKE3Digest.hex(of: data)
    }

    static func stableId(prefix: String, fields: [String]) -> String {
        let digest = hexDigest(for: fields)
        return "\(prefix)-\(digest.prefix(16))"
    }

    static func stableDate(fields: [String]) -> Date {
        let digest = hexDigest(for: fields)
        let seconds = TimeInterval(UInt32(digest.prefix(8), radix: 16) ?? 0)
        return Date(timeIntervalSince1970: seconds)
    }
}

// MARK: - Core IR Entities

/// Project entity representing a bounded improvement/work target.
public struct IRProject: Codable, Sendable {
    public let projectId: String
    public let name: String
    public let scope: String // "core", "module", "cross-module"
    public let createdAt: Date
    public let status: String // "active", "completed", "paused"

    public init(name: String, scope: String, status: String = "active") {
        let projectId = IRDeterminism.stableId(prefix: "project", fields: [name, scope, status])
        self.projectId = projectId
        self.name = name
        self.scope = scope
        self.status = status
        self.createdAt = IRDeterminism.stableDate(fields: [projectId, name, scope, status])
    }
}

/// Component entity representing a logical unit of code/configuration.
public struct IRComponent: Codable, Sendable {
    public let componentId: String
    public let name: String
    public let type: String // "module", "type", "function", "config"
    public let projectId: String
    public let filePath: String?
    public let hash: String?

    public init(name: String, type: String, projectId: String, filePath: String? = nil, hash: String? = nil) {
        let componentId = IRDeterminism.stableId(
            prefix: "component",
            fields: [name, type, projectId, filePath ?? "", hash ?? ""]
        )
        self.componentId = componentId
        self.name = name
        self.type = type
        self.projectId = projectId
        self.filePath = filePath
        self.hash = hash
    }
}

/// Session entity representing a bounded execution context.
public struct IRSession: Codable, Sendable {
    public let sessionId: String
    public let agentId: String
    public let projectId: String
    public let startedAt: Date
    public let endedAt: Date?
    public let status: String // "active", "completed", "failed"
    public let toolsUsed: [String]

    public init(sessionId: String, agentId: String, projectId: String, toolsUsed: [String] = []) {
        self.sessionId = sessionId
        self.agentId = agentId
        self.projectId = projectId
        self.startedAt = IRDeterminism.stableDate(fields: [sessionId, agentId, projectId])
        self.endedAt = nil
        self.status = "active"
        self.toolsUsed = toolsUsed
    }
}

/// Tool entity representing a callable operation.
public struct IRTool: Codable, Sendable {
    public let toolId: String
    public let name: String
    public let category: String // "read", "write", "build", "test", "analyze"
    public let inputTypes: [String]
    public let outputTypes: [String]
    public let governanceLevel: String // "open", "restricted", "gated"

    public init(name: String, category: String, inputTypes: [String] = [], outputTypes: [String] = [], governanceLevel: String = "gated") {
        let toolId = IRDeterminism.stableId(prefix: "tool", fields: [name, category, inputTypes.joined(separator: ","), outputTypes.joined(separator: ","), governanceLevel])
        self.toolId = toolId
        self.name = name
        self.category = category
        self.inputTypes = inputTypes
        self.outputTypes = outputTypes
        self.governanceLevel = governanceLevel
    }
}

/// Policy entity representing governance rules.
public struct IRPolicy: Codable, Sendable {
    public let policyId: String
    public let name: String
    public let rule: String // Natural language or structured rule
    public let appliesTo: [String] // Tool names, component types, etc.
    public let severity: String // "info", "warning", "error", "critical"

    public init(name: String, rule: String, appliesTo: [String] = [], severity: String = "warning") {
        let policyId = IRDeterminism.stableId(prefix: "policy", fields: [name, rule, appliesTo.joined(separator: ","), severity])
        self.policyId = policyId
        self.name = name
        self.rule = rule
        self.appliesTo = appliesTo
        self.severity = severity
    }
}

/// Trace entity representing an observable action/decision.
public struct IRTrace: Codable, Sendable {
    public let traceId: String
    public let sessionId: String
    public let eventType: String // "tool_invoked", "policy_evaluated", "state_changed"
    public let sourceEntity: String // Entity ID that triggered the trace
    public let details: [String: String]
    public let timestamp: Date
    public let duration: TimeInterval?

    public init(sessionId: String, eventType: String, sourceEntity: String, details: [String: String] = [:], duration: TimeInterval? = nil) {
        let sortedDetails = details.keys.sorted().map { key in
            "\(key)=\(details[key] ?? "")"
        }.joined(separator: "|")
        let traceId = IRDeterminism.stableId(
            prefix: "trace",
            fields: [sessionId, eventType, sourceEntity, sortedDetails, duration.map { String(describing: $0) } ?? ""]
        )
        self.traceId = traceId
        self.sessionId = sessionId
        self.eventType = eventType
        self.sourceEntity = sourceEntity
        self.details = details
        self.timestamp = IRDeterminism.stableDate(fields: [traceId, sessionId, eventType, sourceEntity])
        self.duration = duration
    }
}

// MARK: - IR Relations

/// Relationship between IR entities.
public struct IRRelation: Codable, Sendable {
    public let relationId: String
    public let sourceId: String
    public let targetId: String
    public let relationshipType: String // "uses", "depends_on", "governed_by", "violates", "improves"
    public let weight: Double // 0.0 to 1.0 for importance/confidence

    public init(sourceId: String, targetId: String, relationshipType: String, weight: Double = 0.5) {
        let relationId = IRDeterminism.stableId(prefix: "relation", fields: [sourceId, targetId, relationshipType, String(weight)])
        self.relationId = relationId
        self.sourceId = sourceId
        self.targetId = targetId
        self.relationshipType = relationshipType
        self.weight = weight
    }
}

// MARK: - IR Metrics

/// Metrics for entities and system health.
public struct IRMetrics: Codable, Sendable {
    public let metricId: String
    public let entityId: String
    public let metricType: String // "success_rate", "error_rate", "latency", "policy_violations"
    public let value: Double
    public let windowStart: Date
    public let windowEnd: Date
    public let sampleCount: Int

    public init(entityId: String, metricType: String, value: Double, sampleCount: Int = 1) {
        let metricId = IRDeterminism.stableId(prefix: "metric", fields: [entityId, metricType, String(value), String(sampleCount)])
        self.metricId = metricId
        self.entityId = entityId
        self.metricType = metricType
        self.value = value
        self.windowStart = IRDeterminism.stableDate(fields: [metricId, "start"])
        self.windowEnd = IRDeterminism.stableDate(fields: [metricId, "end"])
        self.sampleCount = sampleCount
    }
}

// MARK: - IR Store

/// In-memory IR store for Phase 9 query and analysis.
public actor IRStore {
    private var projects: [String: IRProject] = [:]
    private var components: [String: IRComponent] = [:]
    private var sessions: [String: IRSession] = [:]
    private var tools: [String: IRTool] = [:]
    private var policies: [String: IRPolicy] = [:]
    private var traces: [String: IRTrace] = [:]
    private var relations: [String: IRRelation] = [:]
    private var metrics: [String: IRMetrics] = [:]

    // MARK: - Project Operations

    public func addProject(_ project: IRProject) {
        projects[project.projectId] = project
    }

    public func getProject(_ projectId: String) -> IRProject? {
        return projects[projectId]
    }

    public func listProjects() -> [IRProject] {
        return Array(projects.values)
    }

    // MARK: - Component Operations

    public func addComponent(_ component: IRComponent) {
        components[component.componentId] = component
    }

    public func getComponentsForProject(_ projectId: String) -> [IRComponent] {
        return components.values.filter { $0.projectId == projectId }
    }

    // MARK: - Session Operations

    public func addSession(_ session: IRSession) {
        sessions[session.sessionId] = session
    }

    public func getSession(_ sessionId: String) -> IRSession? {
        return sessions[sessionId]
    }

    public func getSessionsForProject(_ projectId: String) -> [IRSession] {
        return sessions.values.filter { $0.projectId == projectId }
    }

    // MARK: - Tool Operations

    public func registerTool(_ tool: IRTool) {
        tools[tool.toolId] = tool
    }

    public func getTool(_ toolId: String) -> IRTool? {
        return tools[toolId]
    }

    public func getToolsByCategory(_ category: String) -> [IRTool] {
        return tools.values.filter { $0.category == category }
    }

    // MARK: - Policy Operations

    public func addPolicy(_ policy: IRPolicy) {
        policies[policy.policyId] = policy
    }

    public func getPoliciesForTool(_ toolName: String) -> [IRPolicy] {
        return policies.values.filter { $0.appliesTo.contains(toolName) }
    }

    // MARK: - Trace Operations

    public func recordTrace(_ trace: IRTrace) {
        traces[trace.traceId] = trace
    }

    public func getTracesForSession(_ sessionId: String) -> [IRTrace] {
        return traces.values.filter { $0.sessionId == sessionId }.sorted { $0.timestamp < $1.timestamp }
    }

    public func getTracesByEventType(_ eventType: String) -> [IRTrace] {
        return traces.values.filter { $0.eventType == eventType }
    }

    // MARK: - Relation Operations

    public func addRelation(_ relation: IRRelation) {
        relations[relation.relationId] = relation
    }

    public func getRelationsFrom(_ entityId: String) -> [IRRelation] {
        return relations.values.filter { $0.sourceId == entityId }
    }

    public func getRelationsTo(_ entityId: String) -> [IRRelation] {
        return relations.values.filter { $0.targetId == entityId }
    }

    // MARK: - Metric Operations

    public func recordMetric(_ metric: IRMetrics) {
        metrics[metric.metricId] = metric
    }

    public func getMetricsForEntity(_ entityId: String) -> [IRMetrics] {
        return metrics.values.filter { $0.entityId == entityId }
    }

    public func getAverageMetric(_ entityId: String, metricType: String) -> Double? {
        let relevantMetrics = metrics.values.filter { $0.entityId == entityId && $0.metricType == metricType }
        guard !relevantMetrics.isEmpty else { return nil }

        let sum = relevantMetrics.reduce(0.0) { $0 + $1.value }
        return sum / Double(relevantMetrics.count)
    }

    // MARK: - Store Summary

    public func getSummary() -> IRStoreSummary {
        return IRStoreSummary(
            projectCount: projects.count,
            componentCount: components.count,
            sessionCount: sessions.count,
            toolCount: tools.count,
            policyCount: policies.count,
            traceCount: traces.count,
            relationCount: relations.count,
            metricCount: metrics.count
        )
    }
}

/// Summary of IR store contents.
public struct IRStoreSummary: Codable, Sendable {
    public let projectCount: Int
    public let componentCount: Int
    public let sessionCount: Int
    public let toolCount: Int
    public let policyCount: Int
    public let traceCount: Int
    public let relationCount: Int
    public let metricCount: Int
}
