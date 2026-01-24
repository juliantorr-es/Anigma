//
//  MetopticonDashboard.swift
//  AnigmaCore
//
//  Dashboard data models and query service for workload visibility.
//
//  The dashboard provides three main views:
//  1. Overview: Campus-wide workload map with aggregates
//  2. Workload List: Filtered list of individual workloads
//  3. Workload Detail: Deep dive into a specific workload's execution
//
//  All data is filtered through MetopticonAccessEnforcer based on principal.
//

import Foundation

// MARK: - Dashboard Overview

/// High-level summary for the main dashboard view.
public struct MetopticonDashboardOverview: Codable, Sendable {
    /// Total active workloads right now
    public let activeWorkloads: Int

    /// Workloads currently queued
    public let queuedWorkloads: Int

    /// Workloads currently streaming
    public let streamingWorkloads: Int

    /// Failed workloads in the time window
    public let failedWorkloads: Int

    /// Completed workloads in the time window
    public let completedWorkloads: Int

    /// Overall error rate (0.0 - 1.0)
    public let errorRate: Double

    /// Resource pressure indicators
    public let resourcePressure: ResourcePressure

    /// Per-category breakdown
    public let categoryBreakdown: [CategorySummary]

    /// Hot spots flagged by performance advisor
    public let hotspots: [Hotspot]

    /// Time window for this snapshot
    public let timeWindow: TimeWindow

    /// When this snapshot was generated
    public let generatedAt: Date

    public init(
        activeWorkloads: Int,
        queuedWorkloads: Int,
        streamingWorkloads: Int,
        failedWorkloads: Int,
        completedWorkloads: Int,
        errorRate: Double,
        resourcePressure: ResourcePressure,
        categoryBreakdown: [CategorySummary],
        hotspots: [Hotspot],
        timeWindow: TimeWindow,
        generatedAt: Date = Date()
    ) {
        self.activeWorkloads = activeWorkloads
        self.queuedWorkloads = queuedWorkloads
        self.streamingWorkloads = streamingWorkloads
        self.failedWorkloads = failedWorkloads
        self.completedWorkloads = completedWorkloads
        self.errorRate = errorRate
        self.resourcePressure = resourcePressure
        self.categoryBreakdown = categoryBreakdown
        self.hotspots = hotspots
        self.timeWindow = timeWindow
        self.generatedAt = generatedAt
    }
}

// MARK: - Supporting Types

/// Resource pressure indicators.
public struct ResourcePressure: Codable, Sendable {
    /// CPU utilization (0.0 - 1.0)
    public let cpuUtilization: Double

    /// GPU utilization (0.0 - 1.0)
    public let gpuUtilization: Double

    /// Memory pressure (0.0 - 1.0)
    public let memoryPressure: Double

    /// ANE/Neural engine utilization (0.0 - 1.0)
    public let neuralUtilization: Double

    /// Overall health assessment
    public let overallHealth: HealthLevel

    public enum HealthLevel: String, Codable, Sendable {
        case healthy
        case elevated
        case stressed
        case critical
    }

    public init(
        cpuUtilization: Double,
        gpuUtilization: Double,
        memoryPressure: Double,
        neuralUtilization: Double,
        overallHealth: HealthLevel
    ) {
        self.cpuUtilization = cpuUtilization
        self.gpuUtilization = gpuUtilization
        self.memoryPressure = memoryPressure
        self.neuralUtilization = neuralUtilization
        self.overallHealth = overallHealth
    }
}

/// Summary for a workload category.
public struct CategorySummary: Codable, Sendable, Identifiable {
    public var id: String { category }

    /// Category identifier
    public let category: String

    /// Human-readable name
    public let displayName: String

    /// Number of active workloads
    public let activeCount: Int

    /// Average latency in milliseconds
    public let avgLatencyMs: Int

    /// Error rate (0.0 - 1.0)
    public let errorRate: Double

    /// Health status for this category
    public let health: HealthStatus

    public enum HealthStatus: String, Codable, Sendable {
        case healthy
        case degraded
        case unhealthy
    }

    public init(
        category: String,
        displayName: String,
        activeCount: Int,
        avgLatencyMs: Int,
        errorRate: Double,
        health: HealthStatus
    ) {
        self.category = category
        self.displayName = displayName
        self.activeCount = activeCount
        self.avgLatencyMs = avgLatencyMs
        self.errorRate = errorRate
        self.health = health
    }
}

/// A detected performance hotspot.
public struct Hotspot: Codable, Sendable, Identifiable {
    public let id: String

    /// Type of hotspot
    public let type: HotspotType

    /// Affected entity (template, node, device)
    public let affectedEntity: String

    /// Severity level
    public let severity: Severity

    /// Human-readable description
    public let description: String

    /// Recommended action
    public let recommendation: String?

    /// First detected
    public let firstDetected: Date

    public enum HotspotType: String, Codable, Sendable {
        case highErrorRate
        case highLatency
        case resourceContention
        case frequentRetries
        case stuckWorkloads
        case cacheInefficiency
    }

    public enum Severity: String, Codable, Sendable {
        case info
        case warning
        case critical
    }

    public init(
        id: String = UUID().uuidString,
        type: HotspotType,
        affectedEntity: String,
        severity: Severity,
        description: String,
        recommendation: String? = nil,
        firstDetected: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.affectedEntity = affectedEntity
        self.severity = severity
        self.description = description
        self.recommendation = recommendation
        self.firstDetected = firstDetected
    }
}

/// Time window for queries.
public struct TimeWindow: Codable, Sendable {
    public let start: Date
    public let end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }

    public static func lastHour() -> TimeWindow {
        let now = Date()
        return TimeWindow(start: now.addingTimeInterval(-3600), end: now)
    }

    public static func lastDay() -> TimeWindow {
        let now = Date()
        return TimeWindow(start: now.addingTimeInterval(-86400), end: now)
    }

    public static func lastWeek() -> TimeWindow {
        let now = Date()
        return TimeWindow(start: now.addingTimeInterval(-604800), end: now)
    }
}

// MARK: - Workload List

/// Query parameters for workload list.
public struct MetopticonWorkloadQuery: Codable, Sendable {
    /// Filter by status
    public var statusFilter: [String]?

    /// Filter by category
    public var categoryFilter: [String]?

    /// Filter by org unit
    public var orgUnitFilter: String?

    /// Filter by template ID
    public var templateFilter: String?

    /// Filter by device
    public var deviceFilter: String?

    /// Time window
    public var timeWindow: TimeWindow?

    /// Sort field
    public var sortBy: SortField

    /// Sort direction
    public var sortDescending: Bool

    /// Pagination offset
    public var offset: Int

    /// Page size
    public var limit: Int

    public enum SortField: String, Codable, Sendable {
        case startedAt
        case duration
        case status
        case category
        case errorCount
    }

    public init(
        statusFilter: [String]? = nil,
        categoryFilter: [String]? = nil,
        orgUnitFilter: String? = nil,
        templateFilter: String? = nil,
        deviceFilter: String? = nil,
        timeWindow: TimeWindow? = nil,
        sortBy: SortField = .startedAt,
        sortDescending: Bool = true,
        offset: Int = 0,
        limit: Int = 50
    ) {
        self.statusFilter = statusFilter
        self.categoryFilter = categoryFilter
        self.orgUnitFilter = orgUnitFilter
        self.templateFilter = templateFilter
        self.deviceFilter = deviceFilter
        self.timeWindow = timeWindow
        self.sortBy = sortBy
        self.sortDescending = sortDescending
        self.offset = offset
        self.limit = limit
    }
}

/// Result of workload list query.
public struct MetopticonWorkloadListResult: Codable, Sendable {
    /// The filtered workloads
    public let workloads: [MetopticonWorkloadView]

    /// Total count (before pagination)
    public let totalCount: Int

    /// Offset used
    public let offset: Int

    /// Limit used
    public let limit: Int

    public init(
        workloads: [MetopticonWorkloadView],
        totalCount: Int,
        offset: Int,
        limit: Int
    ) {
        self.workloads = workloads
        self.totalCount = totalCount
        self.offset = offset
        self.limit = limit
    }
}

// MARK: - Workload Detail

/// Detailed view of a single workload for drill-down.
public struct MetopticonWorkloadDetail: Codable, Sendable {
    /// Basic workload info
    public let workload: MetopticonWorkloadView

    /// Timeline of execution phases
    public let phases: [ExecutionPhase]

    /// Per-node metrics (if trace-level access)
    public let nodeMetrics: [NodeMetric]?

    /// Device and backend info
    public let executionContext: MetopticonExecutionContext

    /// Error information if applicable
    public let errors: [WorkloadError]

    /// Cache statistics
    public let cacheStats: CacheStats?

    public init(
        workload: MetopticonWorkloadView,
        phases: [ExecutionPhase],
        nodeMetrics: [NodeMetric]? = nil,
        executionContext: MetopticonExecutionContext,
        errors: [WorkloadError] = [],
        cacheStats: CacheStats? = nil
    ) {
        self.workload = workload
        self.phases = phases
        self.nodeMetrics = nodeMetrics
        self.executionContext = executionContext
        self.errors = errors
        self.cacheStats = cacheStats
    }
}

/// An execution phase in the timeline.
public struct ExecutionPhase: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let startOffset: TimeInterval
    public let duration: TimeInterval
    public let status: String

    public init(
        id: String = UUID().uuidString,
        name: String,
        startOffset: TimeInterval,
        duration: TimeInterval,
        status: String
    ) {
        self.id = id
        self.name = name
        self.startOffset = startOffset
        self.duration = duration
        self.status = status
    }
}

/// Per-node metrics (only for trace-level access).
public struct NodeMetric: Codable, Sendable, Identifiable {
    public let id: String
    public let nodeTypeId: String
    public let nodeName: String
    public let executionCount: Int
    public let totalDurationMs: Int
    public let avgDurationMs: Int
    public let cacheHits: Int
    public let cacheMisses: Int
    public let retryCount: Int
    public let errorCount: Int
    public let backend: String

    public init(
        id: String = UUID().uuidString,
        nodeTypeId: String,
        nodeName: String,
        executionCount: Int,
        totalDurationMs: Int,
        avgDurationMs: Int,
        cacheHits: Int,
        cacheMisses: Int,
        retryCount: Int,
        errorCount: Int,
        backend: String
    ) {
        self.id = id
        self.nodeTypeId = nodeTypeId
        self.nodeName = nodeName
        self.executionCount = executionCount
        self.totalDurationMs = totalDurationMs
        self.avgDurationMs = avgDurationMs
        self.cacheHits = cacheHits
        self.cacheMisses = cacheMisses
        self.retryCount = retryCount
        self.errorCount = errorCount
        self.backend = backend
    }
}

/// Execution context information for Metopticon dashboard.
public struct MetopticonExecutionContext: Codable, Sendable {
    public let deviceId: String
    public let deviceName: String
    public let backends: [String]
    public let modelVersions: [String: String]
    public let invokingFrontend: String
    public let sessionId: String?

    public init(
        deviceId: String,
        deviceName: String,
        backends: [String],
        modelVersions: [String: String],
        invokingFrontend: String,
        sessionId: String? = nil
    ) {
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.backends = backends
        self.modelVersions = modelVersions
        self.invokingFrontend = invokingFrontend
        self.sessionId = sessionId
    }
}

/// Error information for a workload.
public struct WorkloadError: Codable, Sendable, Identifiable {
    public let id: String
    public let code: String
    public let message: String
    public let nodeId: String?
    public let occurredAt: Date
    public let isRecoverable: Bool

    public init(
        id: String = UUID().uuidString,
        code: String,
        message: String,
        nodeId: String? = nil,
        occurredAt: Date = Date(),
        isRecoverable: Bool = false
    ) {
        self.id = id
        self.code = code
        self.message = message
        self.nodeId = nodeId
        self.occurredAt = occurredAt
        self.isRecoverable = isRecoverable
    }
}

/// Cache statistics.
public struct CacheStats: Codable, Sendable {
    public let totalHits: Int
    public let totalMisses: Int
    public let hitRate: Double
    public let estimatedSavingsMs: Int

    public init(
        totalHits: Int,
        totalMisses: Int,
        hitRate: Double,
        estimatedSavingsMs: Int
    ) {
        self.totalHits = totalHits
        self.totalMisses = totalMisses
        self.hitRate = hitRate
        self.estimatedSavingsMs = estimatedSavingsMs
    }
}

// MARK: - Template Analytics

/// Analytics for a specific template/subgraph.
public struct MetopticonTemplateAnalytics: Codable, Sendable {
    public let templateId: String
    public let templateName: String
    public let category: String

    /// Total executions in time window
    public let totalExecutions: Int

    /// Average runtime in milliseconds
    public let avgRuntimeMs: Int

    /// Median runtime in milliseconds
    public let medianRuntimeMs: Int

    /// P95 runtime in milliseconds
    public let p95RuntimeMs: Int

    /// Error rate (0.0 - 1.0)
    public let errorRate: Double

    /// Most common error codes
    public let topErrors: [String: Int]

    /// Usage by org unit
    public let usageByOrgUnit: [String: Int]

    /// Time window
    public let timeWindow: TimeWindow

    public init(
        templateId: String,
        templateName: String,
        category: String,
        totalExecutions: Int,
        avgRuntimeMs: Int,
        medianRuntimeMs: Int,
        p95RuntimeMs: Int,
        errorRate: Double,
        topErrors: [String: Int],
        usageByOrgUnit: [String: Int],
        timeWindow: TimeWindow
    ) {
        self.templateId = templateId
        self.templateName = templateName
        self.category = category
        self.totalExecutions = totalExecutions
        self.avgRuntimeMs = avgRuntimeMs
        self.medianRuntimeMs = medianRuntimeMs
        self.p95RuntimeMs = p95RuntimeMs
        self.errorRate = errorRate
        self.topErrors = topErrors
        self.usageByOrgUnit = usageByOrgUnit
        self.timeWindow = timeWindow
    }
}

// MARK: - Dashboard Service

/// Service for querying dashboard data with RBAC enforcement.
public actor MetopticonDashboardService {
    private let accessEnforcer: MetopticonAccessEnforcer

    public init(accessEnforcer: MetopticonAccessEnforcer = MetopticonAccessEnforcer()) {
        self.accessEnforcer = accessEnforcer
    }

    /// Gets the dashboard overview for a principal.
    public func getOverview(
        for principal: MetopticonPrincipal,
        timeWindow: TimeWindow = .lastHour()
    ) async throws -> MetopticonDashboardOverview {
        // In real implementation, this would query ECS state
        // and aggregate based on principal's access scope

        // Placeholder implementation
        return MetopticonDashboardOverview(
            activeWorkloads: 0,
            queuedWorkloads: 0,
            streamingWorkloads: 0,
            failedWorkloads: 0,
            completedWorkloads: 0,
            errorRate: 0.0,
            resourcePressure: ResourcePressure(
                cpuUtilization: 0.0,
                gpuUtilization: 0.0,
                memoryPressure: 0.0,
                neuralUtilization: 0.0,
                overallHealth: .healthy
            ),
            categoryBreakdown: [],
            hotspots: [],
            timeWindow: timeWindow
        )
    }

    /// Queries workload list with filtering and pagination.
    public func queryWorkloads(
        query: MetopticonWorkloadQuery,
        for principal: MetopticonPrincipal
    ) async throws -> MetopticonWorkloadListResult {
        // In real implementation, this would:
        // 1. Query ECS for workload entities
        // 2. Apply query filters
        // 3. Apply RBAC filtering via accessEnforcer
        // 4. Paginate and return

        return MetopticonWorkloadListResult(
            workloads: [],
            totalCount: 0,
            offset: query.offset,
            limit: query.limit
        )
    }

    /// Gets detailed view of a specific workload.
    public func getWorkloadDetail(
        workloadId: String,
        for principal: MetopticonPrincipal
    ) async throws -> MetopticonWorkloadDetail? {
        let access = principal.effectiveAccess

        // Check if principal can access trace-level data
        _ = access.granularity >= .traceLevel

        // In real implementation, this would:
        // 1. Fetch workload from ECS
        // 2. Verify scope access
        // 3. Fetch execution traces if allowed
        // 4. Redact fields based on access

        return nil
    }

    /// Gets analytics for a template.
    public func getTemplateAnalytics(
        templateId: String,
        for principal: MetopticonPrincipal,
        timeWindow: TimeWindow = .lastWeek()
    ) async throws -> MetopticonTemplateAnalytics? {
        // In real implementation, this would aggregate
        // metrics for the specified template

        return nil
    }
}
