//
//  ErrorService.swift
//  ObservatoriumModule
//
//  Central service for error tracking and aggregation.
//  Captures errors, groups them by fingerprint, and can promote to Pragma issues.
//

import Foundation
import AnigmaPrimitives
import AnigmaCore
import ContractsCore

extension AlertSeverity {
    init(_ errorSeverity: ErrorSeverity) {
        self = AlertSeverity(rawValue: errorSeverity.rawValue)!
    }
}

/// Central error tracking and management service.
/// Captures errors, aggregates by fingerprint, and promotes to Pragma.
public actor ErrorService {
    // MARK: - Dependencies

    private let world: World
    private let governance: GovernanceController

    // MARK: - Configuration

    /// Threshold for auto-promoting errors to Pragma issues.
    private let autoPromoteThreshold: Int

    /// Time window for counting occurrences (in seconds).
    private let aggregationWindow: TimeInterval

    // MARK: - State

    private var errorClusters: [String: ErrorCluster] = [:]  // fingerprint → cluster
    private var errorEntityIndex: [ErrorRecordId: EntityId] = [:]
    private var recentErrors: [ErrorRecordComponent] = []

    // MARK: - Statistics

    private var totalErrorsReceived: Int = 0
    private var totalClustersCreated: Int = 0
    private var totalPromotedToPragma: Int = 0

    // MARK: - Initialization

    public init(
        world: World,
        governance: GovernanceController,
        autoPromoteThreshold: Int = 10,
        aggregationWindow: TimeInterval = 3600  // 1 hour
    ) {
        self.world = world
        self.governance = governance
        self.autoPromoteThreshold = autoPromoteThreshold
        self.aggregationWindow = aggregationWindow
    }

    // MARK: - Error Recording

    /// Configuration for recording an error.
    public struct RecordErrorConfiguration: Sendable {
        public let type: String
        public let message: String
        public let severity: ErrorSeverity
        public let module: String
        public let component: String
        public let stackTrace: [String]?
        public let context: [String: String]
        public let correlationId: String?
        public let principalId: String?
        public let maySensitive: Bool
        
        public init(
            type: String,
            message: String,
            severity: ErrorSeverity,
            module: String,
            component: String,
            stackTrace: [String]? = nil,
            context: [String: String] = [:],
            correlationId: String? = nil,
            principalId: String? = nil,
            maySensitive: Bool = false
        ) {
            self.type = type
            self.message = message
            self.severity = severity
            self.module = module
            self.component = component
            self.stackTrace = stackTrace
            self.context = context
            self.correlationId = correlationId
            self.principalId = principalId
            self.maySensitive = maySensitive
        }
    }

    /// Records an error with the given configuration.
    public func recordError(config: RecordErrorConfiguration) async -> ErrorRecordComponent {
        let fingerprint = ErrorRecordComponent.createFingerprint(
            errorType: config.type,
            message: config.message,
            module: config.module,
            component: config.component
        )

        let error = ErrorRecordComponent(
            fingerprint: fingerprint,
            errorType: config.type,
            message: config.message,
            severity: AlertSeverity(config.severity),
            module: config.module,
            component: config.component,
            stackTrace: config.stackTrace,
            context: config.context,
            correlationId: config.correlationId,
            principalId: config.principalId,
            maySensitive: config.maySensitive
        )

        return await ingestError(error)
    }

    /// Records an error with individual parameters.
    public func recordError(
        type: String,
        message: String,
        severity: ErrorSeverity,
        module: String,
        component: String? = nil,
        stackTrace: [String]? = nil,
        context: [String: String] = [:],
        correlationId: String? = nil,
        principalId: String? = nil,
        maySensitive: Bool = false
    ) async -> ErrorRecordComponent {
        let config = RecordErrorConfiguration(
            type: type,
            message: message,
            severity: severity,
            module: module,
            component: component ?? "unknown",
            stackTrace: stackTrace,
            context: context,
            correlationId: correlationId,
            principalId: principalId,
            maySensitive: maySensitive
        )
        return await recordError(config: config)
    }

    /// Records an error from a Swift Error.
    public func recordSwiftError(
        _ error: Error,
        module: String,
        component: String? = nil,
        context: [String: String] = [:],
        correlationId: String? = nil,
        principalId: String? = nil
    ) async -> ErrorRecordComponent {
        let type = String(describing: Swift.type(of: error))
        let message = error.localizedDescription

        return await recordError(
            type: type,
            message: message,
            severity: .error,
            module: module,
            component: component,
            context: context,
            correlationId: correlationId,
            principalId: principalId
        )
    }

    /// Ingests an error and handles clustering.
    private func ingestError(_ error: ErrorRecordComponent) async -> ErrorRecordComponent {
        totalErrorsReceived += 1

        // Store the individual error
        let entityId = await world.createEntity()
        await world.addComponent(entityId, error)
        errorEntityIndex[error.id] = entityId
        recentErrors.append(error)

        // Trim recent errors older than window
        let cutoff = Date().addingTimeInterval(-aggregationWindow)
        recentErrors.removeAll { $0.lastSeenAt < cutoff }

        // Update or create cluster
        if var cluster = errorClusters[error.fingerprint] {
            cluster.addOccurrence(error)
            errorClusters[error.fingerprint] = cluster

            // Check for auto-promotion
            if !cluster.isPromoted && cluster.totalOccurrences >= autoPromoteThreshold {
                await autoPromoteCluster(fingerprint: error.fingerprint)
            }
        } else {
            var cluster = ErrorCluster(
                fingerprint: error.fingerprint,
                representativeError: error
            )
            if let principal = error.principalId {
                cluster.affectedPrincipals.insert(principal)
            }
            errorClusters[error.fingerprint] = cluster
            totalClustersCreated += 1
        }

        // Audit for critical errors
        if error.severity >= .critical {
            try? await governance.auditLog.record(
                eventType: ContractsCore.AuditEventType.custom,
                principal: error.principalId ?? "system",
                module: "ErrorService",
                description: "Critical error: [\(error.module)] \(error.errorType): \(error.message.prefix(100))",
                metadata: ["original_event_type": "critical_error", "fingerprint": error.fingerprint, "module": error.module, "severity": error.severity.rawValue]
            )
        }

        return error
    }

    // MARK: - Error Queries

    /// Gets an error by ID.
    public func getError(id: ErrorRecordId) async -> ErrorRecordComponent? {
        guard let entityId = errorEntityIndex[id] else { return nil }
        return await world.getComponent(entityId, ErrorRecordComponent.self)
    }

    /// Gets errors by fingerprint.
    public func getErrorsByFingerprint(_ fingerprint: String) -> [ErrorRecordComponent] {
        recentErrors.filter { $0.fingerprint == fingerprint }
    }

    /// Gets all error clusters.
    public func getClusters() -> [ErrorCluster] {
        Array(errorClusters.values).sorted { $0.totalOccurrences > $1.totalOccurrences }
    }

    /// Gets clusters by module.
    public func getClusters(module: String) -> [ErrorCluster] {
        errorClusters.values.filter { $0.representativeError.module == module }
    }

    /// Gets unresolved clusters sorted by severity and occurrence count.
    public func getUnresolvedClusters() -> [ErrorCluster] {
        errorClusters.values
            .filter { $0.representativeError.state != .resolved && $0.representativeError.state != .ignored }
            .sorted { ($0.representativeError.severity, $0.totalOccurrences) > ($1.representativeError.severity, $1.totalOccurrences) }
    }

    /// Gets recent errors.
    public func getRecentErrors(limit: Int = 50) -> [ErrorRecordComponent] {
        Array(recentErrors.suffix(limit).reversed())
    }

    /// Gets errors by severity.
    public func getErrors(severity: AlertSeverity) -> [ErrorRecordComponent] {
        recentErrors.filter { $0.severity >= severity }
    }

    // MARK: - Error Management

    /// Updates the state of an error.
    public func updateErrorState(
        id: ErrorRecordId,
        newState: ErrorState,
        principal: String
    ) async throws -> ErrorRecordComponent {
        guard let entityId = errorEntityIndex[id],
              var error = await world.getComponent(entityId, ErrorRecordComponent.self) else {
            throw ObservatoriumError.metricNotFound(id.raw.uuidString)
        }

        error.state = newState
        await world.addComponent(entityId, error)

        // Update cluster state if representative
        if var cluster = errorClusters[error.fingerprint],
           cluster.representativeError.id == id {
            cluster.representativeError.state = newState
            errorClusters[error.fingerprint] = cluster
        }

        try? await governance.auditLog.record(
            eventType: ContractsCore.AuditEventType.custom,
            principal: principal,
            module: "ErrorService",
            description: "Error state changed: \(error.fingerprint.prefix(8)) → \(newState.rawValue)",
            metadata: ["original_event_type": "error_state_changed", "fingerprint": error.fingerprint, "new_state": newState.rawValue]
        )

        return error
    }

    /// Manually promotes an error cluster to a Pragma issue.
    public func promoteCluster(
        fingerprint: String,
        pragmaIssueId: String,
        principal: String
    ) async throws {
        guard var cluster = errorClusters[fingerprint] else {
            throw ObservatoriumError.metricNotFound(fingerprint)
        }

        cluster.isPromoted = true
        cluster.pragmaIssueId = pragmaIssueId
        cluster.representativeError.pragmaIssueId = pragmaIssueId
        cluster.representativeError.state = .promoted
        errorClusters[fingerprint] = cluster

        totalPromotedToPragma += 1

        try? await governance.auditLog.record(
            eventType: ContractsCore.AuditEventType.custom,
            principal: principal,
            module: "ErrorService",
            description: "Error cluster promoted to Pragma: \(fingerprint.prefix(8)) → \(pragmaIssueId)",
            metadata: ["original_event_type": "error_promoted_to_pragma", "fingerprint": fingerprint, "pragma_issue_id": pragmaIssueId]
        )
    }

    /// Auto-promotes a cluster when threshold is exceeded.
    private func autoPromoteCluster(fingerprint: String) async {
        guard var cluster = errorClusters[fingerprint] else { return }

        // In a real implementation, this would call PragmaModule to create an issue
        // For now, just mark it as needing promotion
        cluster.isPromoted = true
        cluster.representativeError.state = .promoted
        errorClusters[fingerprint] = cluster
        totalPromotedToPragma += 1

        try? await governance.auditLog.record(
            eventType: ContractsCore.AuditEventType.custom,
            principal: "system",
            module: "ErrorService",
            description: "Error auto-promoted: \(cluster.fingerprint.prefix(8)) exceeded threshold (\(cluster.totalOccurrences) occurrences)",
            metadata: ["original_event_type": "error_auto_promoted", "fingerprint": cluster.fingerprint, "occurrences": "\(cluster.totalOccurrences)"]
        )
    }

    // MARK: - Statistics

    /// Returns error service statistics.
    public func getStatistics() -> ErrorStatistics {
        let bySeverity = Dictionary(
            grouping: recentErrors
        ) { $0.severity }.mapValues { $0.count }

        let byModule = Dictionary(
            grouping: recentErrors
        ) { $0.module }.mapValues { $0.count }

        return ErrorStatistics(
            totalErrorsReceived: totalErrorsReceived,
            recentErrorCount: recentErrors.count,
            clusterCount: errorClusters.count,
            promotedCount: totalPromotedToPragma,
            bySeverity: bySeverity,
            byModule: byModule
        )
    }
}

/// Error service statistics.
public struct ErrorStatistics: Sendable {
    public let totalErrorsReceived: Int
    public let recentErrorCount: Int
    public let clusterCount: Int
    public let promotedCount: Int
    public let bySeverity: [AlertSeverity: Int]
    public let byModule: [String: Int]
}
