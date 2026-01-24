//
//  MetopticonModule.swift
//  AnigmaCore
//
//  Module registration and public API for Metopticon.
//

import Foundation
import AnigmaPrimitives

public typealias GraphId = NodeGraphId

// MARK: - Global Actor

/// Global actor that ensures thread-safe access to Metopticon shared state.
@globalActor
public actor MetopticonActor {
    public static let shared = MetopticonActor()
}

// MARK: - Configuration

public struct StartWorkloadConfiguration: Sendable {
    public let graphId: GraphId
    public let templateName: String
    public let category: String
    public let ownerId: String
    public let ownerOrgUnit: String?
    public let ownerDepartment: String?
    public let deviceId: String
    public let invokingFrontend: String
    public let sessionId: String?
    
    public init(
        graphId: GraphId,
        templateName: String,
        category: String,
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

// MARK: - Module Definition

/// The Metopticon module for workload observability.
public struct MetopticonModule {
    /// Module identifier
    public static let identifier = "anigma.metopticon"

    /// Module version
    public static let version = "1.0.0"

    /// Module display name
    public static let displayName = "Metopticon Workload Observatory"

    /// Module description
    public static let description = """
        Metopticon provides ethical workload observability for AI pipelines.
        It tracks infrastructure behavior—templates, performance, errors—not content.
        """

    /// The current ethics manifest
    public static var manifest: MetopticonManifest { .current }

    /// Shared singleton components - now protected by MetopticonActor
    @MetopticonActor
    private static var _sharedStore: MetopticonWorkloadStore?

    @MetopticonActor
    private static var _sharedEnforcer: MetopticonAccessEnforcer?

    @MetopticonActor
    private static var _sharedQueryService: MetopticonQueryService?

    @MetopticonActor
    private static var _sharedDashboardService: MetopticonDashboardService?

    @MetopticonActor
    private static var _sharedRunnerAdapter: MetopticonRunnerAdapter?

    /// Error thrown when accessing uninitialized module components.
    public enum ModuleError: Error, LocalizedError {
        case notInitialized(String)

        public var errorDescription: String? {
            switch self {
            case .notInitialized(let component):
                return
                    "MetopticonModule not initialized. Call MetopticonModule.initialize() before accessing \(component)."
            }
        }
    }

    /// Initialize the module with shared components.
    @MetopticonActor
    public static func initialize(world: World? = nil) async {
        let store = MetopticonWorkloadStore()
        let enforcer = MetopticonAccessEnforcer()
        let dashboard = MetopticonDashboardService(accessEnforcer: enforcer)
        let query = MetopticonQueryService(
            store: store, accessEnforcer: enforcer, dashboardService: dashboard)
        let adapter = MetopticonRunnerAdapter(store: store, world: world)

        _sharedStore = store
        _sharedEnforcer = enforcer
        _sharedDashboardService = dashboard
        _sharedQueryService = query
        _sharedRunnerAdapter = adapter
    }

    /// Get the shared workload store.
    @MetopticonActor
    public static var sharedStore: MetopticonWorkloadStore {
        get async throws {
            guard let store = _sharedStore else {
                throw ModuleError.notInitialized("sharedStore")
            }
            return store
        }
    }

    /// Get the shared access enforcer.
    @MetopticonActor
    public static var sharedEnforcer: MetopticonAccessEnforcer {
        get async throws {
            guard let enforcer = _sharedEnforcer else {
                throw ModuleError.notInitialized("sharedEnforcer")
            }
            return enforcer
        }
    }

    /// Get the shared query service.
    @MetopticonActor
    public static var sharedQueryService: MetopticonQueryService {
        get async throws {
            guard let service = _sharedQueryService else {
                throw ModuleError.notInitialized("sharedQueryService")
            }
            return service
        }
    }

    /// Get the shared dashboard service.
    @MetopticonActor
    public static var sharedDashboardService: MetopticonDashboardService {
        get async throws {
            guard let service = _sharedDashboardService else {
                throw ModuleError.notInitialized("sharedDashboardService")
            }
            return service
        }
    }

    /// Get the shared runner adapter.
    @MetopticonActor
    public static var sharedRunnerAdapter: MetopticonRunnerAdapter {
        get async throws {
            guard let adapter = _sharedRunnerAdapter else {
                throw ModuleError.notInitialized("sharedRunnerAdapter")
            }
            return adapter
        }
    }

    // MARK: - Convenience API

    public static func startWorkload(
        graphId: GraphId,
        templateName: String,
        category: String,
        ownerId: String,
        ownerOrgUnit: String? = nil,
        ownerDepartment: String? = nil,
        deviceId: String = "local",
        invokingFrontend: String = "anigma",
        sessionId: String? = nil
    ) async throws -> WorkloadEntityId {
        let config = StartWorkloadConfiguration(
            graphId: graphId,
            templateName: templateName,
            category: category,
            ownerId: ownerId,
            ownerOrgUnit: ownerOrgUnit,
            ownerDepartment: ownerDepartment,
            deviceId: deviceId,
            invokingFrontend: invokingFrontend,
            sessionId: sessionId
        )
        return try await startWorkload(config: config)
    }
    
    public static func startWorkload(config: StartWorkloadConfiguration) async throws -> WorkloadEntityId {
        let metopticonConfig = MetopticonWorkloadConfig(
            graphId: config.graphId,
            templateName: config.templateName,
            category: WorkloadCategory(rawValue: config.category) ?? .unknown,
            ownerId: config.ownerId,
            ownerOrgUnit: config.ownerOrgUnit,
            ownerDepartment: config.ownerDepartment,
            deviceId: config.deviceId,
            invokingFrontend: config.invokingFrontend,
            sessionId: config.sessionId
        )
        return try await MetopticonModule.sharedRunnerAdapter.workloadStarted(config: metopticonConfig)
    }

    /// Update workload status.
    public static func updateStatus(_ id: WorkloadEntityId, status: WorkloadStatus) async throws {
        try await MetopticonModule.sharedRunnerAdapter.updateStatus(id, status: status)
    }

    /// Mark workload as completed.
    public static func completeWorkload(_ id: WorkloadEntityId, durationMs: Int) async throws {
        try await MetopticonModule.sharedRunnerAdapter.workloadCompleted(id, durationMs: durationMs)
    }

    /// Mark workload as failed.
    public static func failWorkload(_ id: WorkloadEntityId, error: String) async throws {
        try await MetopticonModule.sharedRunnerAdapter.workloadFailed(id, error: error)
    }

    /// Get dashboard overview for a principal.
    public static func getOverview(
        for principal: MetopticonPrincipal,
        timeWindow: TimeWindow = .lastHour()
    ) async throws -> MetopticonDashboardOverview {
        try await MetopticonModule.sharedQueryService.getOverview(
            for: principal, timeWindow: timeWindow)
    }

    /// Query workloads for a principal.
    public static func queryWorkloads(
        query: MetopticonWorkloadQuery,
        for principal: MetopticonPrincipal
    ) async throws -> MetopticonWorkloadListResult {
        try await MetopticonModule.sharedQueryService.queryWorkloads(query: query, for: principal)
    }

    /// Validate that telemetry conforms to manifest.
    public static func validateTelemetry(_ context: [String: Any]) -> [ManifestViolation] {
        let validator = MetopticonManifestValidator()
        return validator.validateTelemetryContext(context)
    }
}

// MARK: - SwiftUI Dashboard View Models

#if canImport(SwiftUI)
    import SwiftUI

    /// View model for the Metopticon dashboard overview.
    @MainActor
    public class MetopticonDashboardViewModel: ObservableObject {
        @Published public var overview: MetopticonDashboardOverview?
        @Published public var isLoading = false
        @Published public var error: Error?

        private let principal: MetopticonPrincipal

        public init(principal: MetopticonPrincipal) {
            self.principal = principal
        }

        public func refresh() async {
            isLoading = true
            error = nil

            do {
                overview = try await MetopticonModule.getOverview(for: principal)
            } catch {
                self.error = error
            }

            isLoading = false
        }
    }

    /// View model for the workload list.
    @MainActor
    public class MetopticonWorkloadListViewModel: ObservableObject {
        @Published public var result: MetopticonWorkloadListResult?
        @Published public var query: MetopticonWorkloadQuery
        @Published public var isLoading = false
        @Published public var error: Error?

        private let principal: MetopticonPrincipal

        public init(
            principal: MetopticonPrincipal,
            query: MetopticonWorkloadQuery = MetopticonWorkloadQuery()
        ) {
            self.principal = principal
            self.query = query
        }

        public func refresh() async {
            isLoading = true
            error = nil

            do {
                result = try await MetopticonModule.queryWorkloads(query: query, for: principal)
            } catch {
                self.error = error
            }

            isLoading = false
        }

        public func loadNextPage() async {
            guard let current = result, current.offset + current.limit < current.totalCount else {
                return
            }
            query.offset = current.offset + current.limit
            await refresh()
        }
    }
#endif

// MARK: - Debug Helpers

#if DEBUG
    extension MetopticonModule {
        /// Create test data for development.
        @MetopticonActor
        public static func createTestData() async throws {
            let store = try await sharedStore

            let categories: [WorkloadCategory] = [
                .altMedia, .dsps, .grading, .research, .facultyTools
            ]
            let statuses: [WorkloadStatus] = [.running, .completed, .failed, .queued]

            for i in 0..<20 {
                let category = categories[i % categories.count]
                let status = statuses[i % statuses.count]

                let component = PipelineWorkloadComponent(
                    graphId: "graph-\(i)",
                    templateName: "Test Template \(i)",
                    category: category,
                    status: status,
                    ownerId: "user-\(i % 5)",
                    ownerOrgUnit: "unit-\(i % 3)",
                    ownerDepartment: "dept-\(i % 2)",
                    deviceId: "device-\(i % 4)",
                    invokingFrontend: "test"
                )

                let entity = await store.createWorkload(component)

                // Add some metrics
                let metrics = PipelineMetricsComponent(
                    totalDurationMs: Int.random(in: 100...10000),
                    nodeCount: Int.random(in: 5...20),
                    nodesExecuted: Int.random(in: 5...20),
                    cacheHits: Int.random(in: 0...10),
                    cacheMisses: Int.random(in: 0...10),
                    errorCount: status == .failed ? Int.random(in: 1...5) : 0,
                    backendsUsed: ["cpu", "mlx"]
                )
                await store.updateMetrics(entity.id, metrics: metrics)
            }
        }
    }
#endif
