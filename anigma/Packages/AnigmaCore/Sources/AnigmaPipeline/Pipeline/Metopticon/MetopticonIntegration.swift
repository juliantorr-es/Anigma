import AnigmaPrimitives

import AnigmaPrimitives

//
//  MetopticonIntegration.swift
//  AnigmaCore
//
//  Integration between Metopticon and Harmonia/Anigma infrastructure.
//
//  This file bridges the pipeline execution layer with:
//  - Harmonia's ECS world state
//  - Anigma's session and identity management
//  - The Metopticon dashboard and RBAC systems
//
//  Data flow:
//  1. Front-end triggers workflow via MetopticonRunner
//  2. Runner creates/updates PipelineWorkloadComponent in ECS
//  3. Engine executes graph, profiler collects traces
//  4. MetopticonSyncSystem bridges traces to ECS components
//  5. Dashboard queries ECS through MetopticonQueryService
//  6. RBAC filters results based on principal
//

import AnigmaFoundation
import AnigmaGovernance
import AnigmaJobs
import ContractsCore
import InferenceCore
import Foundation
import AnigmaPrimitives
import AnigmaJobs

/// Integration layer for Metopticon observability.

/// Unique identifier for a workload entity.
public typealias WorkloadEntityId = EntityId

/// ECS component tracking a pipeline workload.
public struct PipelineWorkloadComponent: Component, Codable, Sendable {
    /// Unique workload identifier
    public let workloadId: WorkloadEntityId

    /// Graph/template identifier
    public let graphId: String

    /// Template name for display
    public let templateName: String

    /// Workload category
    public let category: WorkloadCategory

    /// Current status
    public var status: WorkloadStatus

    /// Owner identity (for RBAC scoping)
    public let ownerId: String

    /// Owner's org unit
    public let ownerOrgUnit: String?

    /// Owner's department
    public let ownerDepartment: String?

    /// Device/node running the workload
    public let deviceId: String

    /// Which frontend invoked this
    public let invokingFrontend: String

    /// Session ID if applicable
    public let sessionId: String?

    /// When the workload was created
    public let createdAt: Date

    /// When execution started
    public var startedAt: Date?

    /// When execution completed
    public var completedAt: Date?

    /// Last status update
    public var lastUpdatedAt: Date

    public init(
        workloadId: WorkloadEntityId = WorkloadEntityId(),
        graphId: String,
        templateName: String,
        category: WorkloadCategory,
        status: WorkloadStatus = .pending,
        ownerId: String,
        ownerOrgUnit: String? = nil,
        ownerDepartment: String? = nil,
        deviceId: String,
        invokingFrontend: String,
        sessionId: String? = nil,
        createdAt: Date = Date()
    ) {
        self.workloadId = workloadId
        self.graphId = graphId
        self.templateName = templateName
        self.category = category
        self.status = status
        self.ownerId = ownerId
        self.ownerOrgUnit = ownerOrgUnit
        self.ownerDepartment = ownerDepartment
        self.deviceId = deviceId
        self.invokingFrontend = invokingFrontend
        self.sessionId = sessionId
        self.createdAt = createdAt
        self.startedAt = nil
        self.completedAt = nil
        self.lastUpdatedAt = createdAt
    }
}

/// Workload categories for filtering.
public enum WorkloadCategory: String, Codable, Sendable, CaseIterable {
    case altMedia = "alt-media"
    case dsps = "dsps"
    case grading = "grading"
    case research = "research"
    case facultyTools = "faculty-tools"
    case infrastructure = "infrastructure"
    case personalSandbox = "personal-sandbox"
    case unknown = "unknown"

    public var displayName: String {
        switch self {
        case .altMedia: return "Alt-Media Conversion"
        case .dsps: return "DSPS/Accessibility"
        case .grading: return "Grading & Assessment"
        case .research: return "Research"
        case .facultyTools: return "Faculty Tools"
        case .infrastructure: return "Infrastructure"
        case .personalSandbox: return "Personal Sandbox"
        case .unknown: return "Unknown"
        }
    }
}

/// Workload execution status.
public enum WorkloadStatus: String, Codable, Sendable {
    case pending
    case queued
    case running
    case streaming
    case blocked
    case retrying
    case failed
    case completed
    case cancelled

    public var isTerminal: Bool {
        switch self {
        case .failed, .completed, .cancelled: return true
        default: return false
        }
    }

    public var isActive: Bool {
        switch self {
        case .running, .streaming: return true
        default: return false
        }
    }
}

/// ECS component for workload metrics.
public struct PipelineMetricsComponent: Component, Codable, Sendable {
    /// Total execution duration in milliseconds
    public var totalDurationMs: Int?

    /// Node count in the graph
    public var nodeCount: Int

    /// Nodes executed
    public var nodesExecuted: Int

    /// Cache hits
    public var cacheHits: Int

    /// Cache misses
    public var cacheMisses: Int

    /// Error count
    public var errorCount: Int

    /// Retry count
    public var retryCount: Int

    /// Backends used
    public var backendsUsed: Set<String>

    /// Peak CPU usage (0.0 - 1.0)
    public var peakCpuUsage: Double?

    /// Peak GPU usage (0.0 - 1.0)
    public var peakGpuUsage: Double?

    /// Peak memory usage in MB
    public var peakMemoryMB: Int?

    public init(
        totalDurationMs: Int? = nil,
        nodeCount: Int = 0,
        nodesExecuted: Int = 0,
        cacheHits: Int = 0,
        cacheMisses: Int = 0,
        errorCount: Int = 0,
        retryCount: Int = 0,
        backendsUsed: Set<String> = [],
        peakCpuUsage: Double? = nil,
        peakGpuUsage: Double? = nil,
        peakMemoryMB: Int? = nil
    ) {
        self.totalDurationMs = totalDurationMs
        self.nodeCount = nodeCount
        self.nodesExecuted = nodesExecuted
        self.cacheHits = cacheHits
        self.cacheMisses = cacheMisses
        self.errorCount = errorCount
        self.retryCount = retryCount
        self.backendsUsed = backendsUsed
        self.peakCpuUsage = peakCpuUsage
        self.peakGpuUsage = peakGpuUsage
        self.peakMemoryMB = peakMemoryMB
    }
}

/// ECS component for workload health.
public struct PipelineHealthComponent: Component, Codable, Sendable {
    /// Overall health status
    public var status: HealthStatus

    /// Issues detected
    public var issues: [HealthIssue]

    /// Last health check time
    public var lastCheckedAt: Date

    public enum HealthStatus: String, Codable, Sendable {
        case healthy
        case degraded
        case unhealthy
        case unknown
    }

    public struct HealthIssue: Codable, Sendable {
        public let code: String
        public let severity: Severity
        public let message: String
        public let detectedAt: Date

        public enum Severity: String, Codable, Sendable {
            case info
            case warning
            case error
            case critical
        }

        public init(code: String, severity: Severity, message: String, detectedAt: Date = Date()) {
            self.code = code
            self.severity = severity
            self.message = message
            self.detectedAt = detectedAt
        }
    }

    public init(
        status: HealthStatus = .unknown,
        issues: [HealthIssue] = [],
        lastCheckedAt: Date = Date()
    ) {
        self.status = status
        self.issues = issues
        self.lastCheckedAt = lastCheckedAt
    }
}

// MARK: - Workload Entity

/// Complete representation of a workload entity in ECS.
public struct WorkloadEntity: Sendable {
    public let id: WorkloadEntityId
    public var workload: PipelineWorkloadComponent
    public var metrics: PipelineMetricsComponent
    public var health: PipelineHealthComponent

    public init(
        id: WorkloadEntityId,
        workload: PipelineWorkloadComponent,
        metrics: PipelineMetricsComponent = PipelineMetricsComponent(),
        health: PipelineHealthComponent = PipelineHealthComponent()
    ) {
        self.id = id
        self.workload = workload
        self.metrics = metrics
        self.health = health
    }
}

// MARK: - Workload Store (In-Memory for now)

/// In-memory store for workload entities.
/// In production, this would be backed by the actual ECS world.
public actor MetopticonWorkloadStore {
    private var workloads: [WorkloadEntityId: WorkloadEntity] = [:]

    public init() {}

    /// Creates a new workload entity.
    public func createWorkload(_ workload: PipelineWorkloadComponent) -> WorkloadEntity {
        let entity = WorkloadEntity(
            id: workload.workloadId,
            workload: workload
        )
        workloads[entity.id] = entity
        return entity
    }

    /// Updates a workload's status.
    public func updateStatus(_ id: WorkloadEntityId, status: WorkloadStatus) {
        guard var entity = workloads[id] else { return }
        entity.workload.status = status
        entity.workload.lastUpdatedAt = Date()

        if status.isActive && entity.workload.startedAt == nil {
            entity.workload.startedAt = Date()
        }
        if status.isTerminal && entity.workload.completedAt == nil {
            entity.workload.completedAt = Date()
        }

        workloads[id] = entity
    }

    /// Updates a workload's metrics.
    public func updateMetrics(_ id: WorkloadEntityId, metrics: PipelineMetricsComponent) {
        guard var entity = workloads[id] else { return }
        entity.metrics = metrics
        entity.workload.lastUpdatedAt = Date()
        workloads[id] = entity
    }

    /// Updates a workload's health.
    public func updateHealth(_ id: WorkloadEntityId, health: PipelineHealthComponent) {
        guard var entity = workloads[id] else { return }
        entity.health = health
        entity.workload.lastUpdatedAt = Date()
        workloads[id] = entity
    }

    /// Gets a workload by ID.
    public func getWorkload(_ id: WorkloadEntityId) -> WorkloadEntity? {
        workloads[id]
    }

    /// Queries workloads with filters.
    public func queryWorkloads(
        statusFilter: [WorkloadStatus]? = nil,
        categoryFilter: [WorkloadCategory]? = nil,
        ownerFilter: String? = nil,
        departmentFilter: String? = nil,
        since: Date? = nil
    ) -> [WorkloadEntity] {
        workloads.values.filter { entity in
            if let statuses = statusFilter {
                guard statuses.contains(entity.workload.status) else { return false }
            }
            if let categories = categoryFilter {
                guard categories.contains(entity.workload.category) else { return false }
            }
            if let owner = ownerFilter {
                guard entity.workload.ownerId == owner else { return false }
            }
            if let dept = departmentFilter {
                guard entity.workload.ownerDepartment == dept else { return false }
            }
            if let date = since {
                guard entity.workload.createdAt >= date else { return false }
            }
            return true
        }
    }

    /// Removes completed/cancelled workloads older than retention period.
    public func cleanupOldWorkloads(olderThan: TimeInterval) {
        let cutoff = Date().addingTimeInterval(-olderThan)
        workloads = workloads.filter { _, entity in
            if entity.workload.status.isTerminal {
                return entity.workload.completedAt ?? entity.workload.createdAt > cutoff
            }
            return true
        }
    }

    /// Gets aggregate statistics.
    public func getAggregateStats() -> AggregateStats {
        let all = Array(workloads.values)

        let active = all.filter { $0.workload.status.isActive }.count
        let queued = all.filter { $0.workload.status == .queued }.count
        let failed = all.filter { $0.workload.status == .failed }.count
        let completed = all.filter { $0.workload.status == .completed }.count

        let totalWithDuration = all.compactMap { $0.metrics.totalDurationMs }
        let avgDuration = totalWithDuration.isEmpty ? 0 :
            totalWithDuration.reduce(0, +) / totalWithDuration.count

        let totalErrors = all.reduce(0) { $0 + $1.metrics.errorCount }
        let errorRate = all.isEmpty ? 0.0 : Double(failed) / Double(all.count)

        return AggregateStats(
            totalWorkloads: all.count,
            activeWorkloads: active,
            queuedWorkloads: queued,
            failedWorkloads: failed,
            completedWorkloads: completed,
            avgDurationMs: avgDuration,
            totalErrors: totalErrors,
            errorRate: errorRate
        )
    }
}

/// Aggregate statistics from the workload store.
public struct AggregateStats: Sendable {
    public let totalWorkloads: Int
    public let activeWorkloads: Int
    public let queuedWorkloads: Int
    public let failedWorkloads: Int
    public let completedWorkloads: Int
    public let avgDurationMs: Int
    public let totalErrors: Int
    public let errorRate: Double

    public init(
        totalWorkloads: Int,
        activeWorkloads: Int,
        queuedWorkloads: Int,
        failedWorkloads: Int,
        completedWorkloads: Int,
        avgDurationMs: Int,
        totalErrors: Int,
        errorRate: Double
    ) {
        self.totalWorkloads = totalWorkloads
        self.activeWorkloads = activeWorkloads
        self.queuedWorkloads = queuedWorkloads
        self.failedWorkloads = failedWorkloads
        self.completedWorkloads = completedWorkloads
        self.avgDurationMs = avgDurationMs
        self.totalErrors = totalErrors
        self.errorRate = errorRate
    }
}

// MARK: - Query Service

/// Service for querying Metopticon data with RBAC enforcement.
public actor MetopticonQueryService {
    private let store: MetopticonWorkloadStore
    private let accessEnforcer: MetopticonAccessEnforcer
    private let dashboardService: MetopticonDashboardService

    public init(
        store: MetopticonWorkloadStore,
        accessEnforcer: MetopticonAccessEnforcer = MetopticonAccessEnforcer(),
        dashboardService: MetopticonDashboardService? = nil
    ) {
        self.store = store
        self.accessEnforcer = accessEnforcer
        self.dashboardService = dashboardService ?? MetopticonDashboardService(accessEnforcer: accessEnforcer)
    }

    /// Gets the dashboard overview for a principal.
    public func getOverview(
        for principal: MetopticonPrincipal,
        timeWindow: TimeWindow = .lastHour()
    ) async throws -> MetopticonDashboardOverview {
        let stats = await store.getAggregateStats()

        // Build category breakdown
        let workloads = await store.queryWorkloads(since: timeWindow.start)
        let byCategory = Dictionary(grouping: workloads) { $0.workload.category }
        let categoryBreakdown = byCategory.map { category, entities in
            let failed = entities.filter { $0.workload.status == .failed }.count
            let errorRate = entities.isEmpty ? 0.0 : Double(failed) / Double(entities.count)
            let durations = entities.compactMap { $0.metrics.totalDurationMs }
            let avgLatency = durations.isEmpty ? 0 : durations.reduce(0, +) / durations.count

            return CategorySummary(
                category: category.rawValue,
                displayName: category.displayName,
                activeCount: entities.filter { $0.workload.status.isActive }.count,
                avgLatencyMs: avgLatency,
                errorRate: errorRate,
                health: errorRate > 0.1 ? .unhealthy : (errorRate > 0.05 ? .degraded : .healthy)
            )
        }

        return MetopticonDashboardOverview(
            activeWorkloads: stats.activeWorkloads,
            queuedWorkloads: stats.queuedWorkloads,
            streamingWorkloads: workloads.filter { $0.workload.status == .streaming }.count,
            failedWorkloads: stats.failedWorkloads,
            completedWorkloads: stats.completedWorkloads,
            errorRate: stats.errorRate,
            resourcePressure: ResourcePressure(
                cpuUtilization: 0.0,  // Would come from system metrics
                gpuUtilization: 0.0,
                memoryPressure: 0.0,
                neuralUtilization: 0.0,
                overallHealth: .healthy
            ),
            categoryBreakdown: categoryBreakdown,
            hotspots: [],
            timeWindow: timeWindow
        )
    }

    /// Queries workloads with RBAC filtering.
    public func queryWorkloads(
        query: MetopticonWorkloadQuery,
        for principal: MetopticonPrincipal
    ) async throws -> MetopticonWorkloadListResult {
        let access = principal.effectiveAccess

        // Map query filters to store query
        let statusFilter = query.statusFilter?.compactMap { WorkloadStatus(rawValue: $0) }
        let categoryFilter = query.categoryFilter?.compactMap { WorkloadCategory(rawValue: $0) }

        // Apply scope-based owner filter
        var ownerFilter: String?
        var deptFilter: String?

        switch access.scope {
        case .selfOnly:
            ownerFilter = principal.id
        case .department:
            deptFilter = principal.department
        case .directReports:
            // Would need org hierarchy lookup
            ownerFilter = principal.id
        case .institution, .categoricallyScoped:
            // No owner filter
            break
        }

        let entities = await store.queryWorkloads(
            statusFilter: statusFilter,
            categoryFilter: categoryFilter,
            ownerFilter: ownerFilter,
            departmentFilter: deptFilter,
            since: query.timeWindow?.start
        )

        // Convert to views
        let views = entities.map { entity -> MetopticonWorkloadView in
            MetopticonWorkloadView(
                workloadId: entity.id.raw.uuidString,
                templateId: entity.workload.graphId,
                templateName: entity.workload.templateName,
                category: entity.workload.category.rawValue,
                status: entity.workload.status.rawValue,
                ownerId: entity.workload.ownerId,
                ownerOrgUnit: entity.workload.ownerOrgUnit,
                ownerDepartment: entity.workload.ownerDepartment,
                startedAt: entity.workload.startedAt,
                durationMs: entity.metrics.totalDurationMs,
                resourceUsage: MetopticonWorkloadView.ResourceUsageView(
                    cpuPercent: entity.metrics.peakCpuUsage,
                    gpuPercent: entity.metrics.peakGpuUsage,
                    memoryMB: entity.metrics.peakMemoryMB
                ),
                backend: entity.metrics.backendsUsed.first,
                device: entity.workload.deviceId,
                healthStatus: entity.health.status.rawValue,
                errorCount: entity.metrics.errorCount,
                cacheHitRate: entity.metrics.cacheHits + entity.metrics.cacheMisses > 0
                    ? Double(entity.metrics.cacheHits) / Double(entity.metrics.cacheHits + entity.metrics.cacheMisses)
                    : nil
            )
        }

        // Apply RBAC filtering
        let filtered = await accessEnforcer.filterWorkloads(views, for: principal)

        // Sort
        let sorted = filtered.sorted { a, b in
            switch query.sortBy {
            case .startedAt:
                let aTime = a.startedAt ?? Date.distantPast
                let bTime = b.startedAt ?? Date.distantPast
                return query.sortDescending ? aTime > bTime : aTime < bTime
            case .duration:
                let aDur = a.durationMs ?? 0
                let bDur = b.durationMs ?? 0
                return query.sortDescending ? aDur > bDur : aDur < bDur
            case .status:
                return query.sortDescending ? a.status > b.status : a.status < b.status
            case .category:
                return query.sortDescending ? a.category > b.category : a.category < b.category
            case .errorCount:
                let aErr = a.errorCount ?? 0
                let bErr = b.errorCount ?? 0
                return query.sortDescending ? aErr > bErr : aErr < bErr
            }
        }

        // Paginate
        let start = min(query.offset, sorted.count)
        let end = min(start + query.limit, sorted.count)
        let page = Array(sorted[start..<end])

        return MetopticonWorkloadListResult(
            workloads: page,
            totalCount: sorted.count,
            offset: query.offset,
            limit: query.limit
        )
    }
}

// MARK: - Runner Integration

/// Configuration for creating a workload from a pipeline run.
public struct MetopticonWorkloadConfig: Sendable {
    public let graphId: GraphId
    public let templateName: String
    public let category: WorkloadCategory
    public let ownerId: String
    public let ownerOrgUnit: String?
    public let ownerDepartment: String?
    public let deviceId: String
    public let invokingFrontend: String
    public let sessionId: String?

    public init(
        graphId: GraphId,
        templateName: String,
        category: WorkloadCategory,
        ownerId: String,
        ownerOrgUnit: String? = nil,
        ownerDepartment: String? = nil,
        deviceId: String = "local",
        invokingFrontend: String = "anigma",
        sessionId: String? = nil
    ) {
        self.graphId = graphId
        self.templateName = templateName
        self.category = category
        self.ownerId = ownerId
        self.ownerOrgUnit = ownerOrgUnit
        self.ownerDepartment = ownerDepartment
        self.deviceId = deviceId
        self.invokingFrontend = invokingFrontend
        self.sessionId = sessionId
    }
}

/// Adapter that creates and updates workload entities from pipeline runs.
public actor MetopticonRunnerAdapter {
    private let store: MetopticonWorkloadStore
    private let world: World?

    public init(store: MetopticonWorkloadStore, world: World? = nil) {
        self.store = store
        self.world = world
    }

    private func attachWorkloadComponents(_ entity: WorkloadEntity) async {
        guard let world = world else { return }
        let entityId = entity.id
        _ = await world.createEntity(with: entityId)
        await world.addComponent(entityId, entity.workload)
        await world.addComponent(entityId, entity.metrics)
        await world.addComponent(entityId, entity.health)
    }

    /// Creates a workload entity when a pipeline run starts.
    public func workloadStarted(config: MetopticonWorkloadConfig) async -> WorkloadEntityId {
        let component = PipelineWorkloadComponent(
            graphId: config.graphId.rawValue.uuidString,
            templateName: config.templateName,
            category: config.category,
            status: .running,
            ownerId: config.ownerId,
            ownerOrgUnit: config.ownerOrgUnit,
            ownerDepartment: config.ownerDepartment,
            deviceId: config.deviceId,
            invokingFrontend: config.invokingFrontend,
            sessionId: config.sessionId
        )

        var entity = await store.createWorkload(component)
        entity.workload.startedAt = Date()
        await store.updateStatus(entity.id, status: .running)
        // Sync to ECS world if available
        if let entity = await store.getWorkload(entity.id) {
            await attachWorkloadComponents(entity)
        }

        return entity.id
    }

    private func syncWorkload(_ id: WorkloadEntityId) async {
        guard let entity = await store.getWorkload(id) else { return }
        await attachWorkloadComponents(entity)
    }

    /// Updates workload status.
    public func updateStatus(_ id: WorkloadEntityId, status: WorkloadStatus) async {
        await store.updateStatus(id, status: status)
        await syncWorkload(id)
    }

    /// Updates workload metrics from execution trace.
    public func updateFromTrace(
        _ id: WorkloadEntityId,
        nodeCount: Int,
        nodesExecuted: Int,
        cacheHits: Int,
        cacheMisses: Int,
        errorCount: Int,
        backends: Set<String>,
        durationMs: Int
    ) async {
        let metrics = PipelineMetricsComponent(
            nodeCount: nodeCount,
            nodesExecuted: nodesExecuted,
            cacheHits: cacheHits,
            cacheMisses: cacheMisses,
            errorCount: errorCount,
            retryCount: 0,
            backendsUsed: backends
        )
        await store.updateMetrics(id, metrics: metrics)
        await syncWorkload(id)
    }

    /// Marks workload as completed.
    public func workloadCompleted(_ id: WorkloadEntityId, durationMs: Int) async {
        await store.updateStatus(id, status: .completed)

        if var entity = await store.getWorkload(id) {
            entity.metrics.totalDurationMs = durationMs
            await store.updateMetrics(id, metrics: entity.metrics)
        }
        await syncWorkload(id)
    }

    /// Marks workload as failed.
    public func workloadFailed(_ id: WorkloadEntityId, error: String) async {
        await store.updateStatus(id, status: .failed)

        let health = PipelineHealthComponent(
            status: .unhealthy,
            issues: [
                PipelineHealthComponent.HealthIssue(
                    code: "EXECUTION_FAILED",
                    severity: .error,
                    message: error
                )
            ]
        )
        await store.updateHealth(id, health: health)
        await syncWorkload(id)
    }
}
