import AnigmaPrimitives

import AnigmaPrimitives

//
//  Storage.swift
//  AnigmaCore
//
//  Storage, backup, and disaster recovery infrastructure.
//  Manages storage backends, backup snapshots, recovery operations,
//  and data export for compliance.
//
//  Design principles:
//  - Storage backends are modeled as entities with health tracking
//  - Backups are governed workflows with full audit trails
//  - Recovery operations are tested and validated
//  - Export/deletion for privacy rights compliance
//

import ContractsCore
import Foundation
import AnigmaPrimitives

// MARK: - Storage Backend

/// Represents a storage backend.
public struct StorageBackendComponent: Component, Sendable, Codable {
    /// Unique backend identifier.
    public let backendId: UUID

    /// Human-readable name.
    public var name: String

    /// Type of storage.
    public var storageType: StorageType

    /// Current status.
    public var status: StorageStatus

    /// Base path or connection info (redacted in logs).
    public var endpoint: String

    /// Whether this is the primary storage.
    public var isPrimary: Bool

    /// When the backend was registered.
    public let registeredAt: Date

    /// Last health check timestamp.
    public var lastHealthCheck: Date?

    /// Last health check result.
    public var healthCheckResult: HealthCheckResult?

    /// Storage capacity in bytes.
    public var capacityBytes: Int64?

    /// Used storage in bytes.
    public var usedBytes: Int64?

    /// Encryption configuration.
    public var encryption: StorageEncryption

    /// Replication configuration.
    public var replication: StorageReplication?

    public init(
        backendId: UUID = UUID(),
        name: String,
        storageType: StorageType,
        endpoint: String,
        isPrimary: Bool = false,
        encryption: StorageEncryption = .atRest,
        replication: StorageReplication? = nil
    ) {
        self.backendId = backendId
        self.name = name
        self.storageType = storageType
        self.status = .healthy
        self.endpoint = endpoint
        self.isPrimary = isPrimary
        self.registeredAt = Date()
        self.lastHealthCheck = nil
        self.healthCheckResult = nil
        self.capacityBytes = nil
        self.usedBytes = nil
        self.encryption = encryption
        self.replication = replication
    }

    /// Usage percentage (0-100).
    public var usagePercentage: Double? {
        guard let capacity = capacityBytes, let used = usedBytes, capacity > 0 else {
            return nil
        }
        return Double(used) / Double(capacity) * 100.0
    }
}

/// Types of storage backends.
public enum StorageType: String, Sendable, Codable {
    /// Local filesystem.
    case filesystem = "filesystem"

    /// PostgreSQL database.
    case postgresql = "postgresql"

    /// Object storage (S3-compatible).
    case objectStorage = "object_storage"

    /// Network file system.
    case nfs = "nfs"

    /// Cloud storage.
    case cloud = "cloud"
}

/// Storage health status.
public enum StorageStatus: String, Sendable, Codable {
    /// Storage is healthy and operational.
    case healthy = "healthy"

    /// Storage is degraded but operational.
    case degraded = "degraded"

    /// Storage has warnings.
    case warning = "warning"

    /// Storage is offline.
    case offline = "offline"

    /// Storage failed health check.
    case failed = "failed"
}

/// Storage encryption configuration.
public enum StorageEncryption: String, Sendable, Codable {
    /// No encryption.
    case none = "none"

    /// Encryption at rest.
    case atRest = "at_rest"

    /// Encryption at rest and in transit.
    case full = "full"
}

/// Storage replication configuration.
public struct StorageReplication: Sendable, Codable {
    /// Number of replicas.
    public var replicaCount: Int

    /// Replication type.
    public var replicationType: ReplicationType

    /// Geographic distribution.
    public var geoDistributed: Bool

    public init(replicaCount: Int = 1, replicationType: ReplicationType = .synchronous, geoDistributed: Bool = false) {
        self.replicaCount = replicaCount
        self.replicationType = replicationType
        self.geoDistributed = geoDistributed
    }
}

/// Types of replication.
public enum ReplicationType: String, Sendable, Codable {
    case synchronous = "synchronous"
    case asynchronous = "asynchronous"
}

/// Health check result.
public struct HealthCheckResult: Sendable, Codable {
    public let timestamp: Date
    public let success: Bool
    public let latencyMs: Int?
    public let message: String?
    public let metrics: [String: Double]

    public init(success: Bool, latencyMs: Int? = nil, message: String? = nil, metrics: [String: Double] = [:]) {
        self.timestamp = Date()
        self.success = success
        self.latencyMs = latencyMs
        self.message = message
        self.metrics = metrics
    }
}

// MARK: - Backup Snapshot

/// A backup snapshot.
public struct BackupSnapshotComponent: Component, Sendable, Codable {
    /// Unique snapshot identifier.
    public let snapshotId: UUID

    /// The tenant this backup belongs to (nil = platform).
    public let tenantId: UUID?

    /// The environment this backup is from.
    public let environmentId: UUID?

    /// Snapshot name/label.
    public var name: String

    /// Type of backup.
    public var backupType: BackupType

    /// Current status.
    public var status: BackupStatus

    /// When the backup started.
    public let startedAt: Date

    /// When the backup completed.
    public var completedAt: Date?

    /// Who initiated the backup.
    public let initiatedBy: UUID

    /// Domains/modules included.
    public var includedDomains: Set<String>

    /// Size in bytes.
    public var sizeBytes: Int64?

    /// Storage backend where backup is stored.
    public var storageBackendId: UUID?

    /// Storage path/key.
    public var storagePath: String?

    /// Encryption key identifier (if encrypted).
    public var encryptionKeyId: String?

    /// Checksum for integrity verification.
    public var checksum: String?

    /// Expiration date (based on retention policy).
    public var expiresAt: Date?

    /// Whether backup has been verified.
    public var verified: Bool

    /// Last verification timestamp.
    public var lastVerifiedAt: Date?

    /// Legal hold preventing deletion.
    public var legalHoldId: UUID?

    public init(
        snapshotId: UUID = UUID(),
        tenantId: UUID? = nil,
        environmentId: UUID? = nil,
        name: String,
        backupType: BackupType = .full,
        initiatedBy: UUID,
        includedDomains: Set<String> = []
    ) {
        self.snapshotId = snapshotId
        self.tenantId = tenantId
        self.environmentId = environmentId
        self.name = name
        self.backupType = backupType
        self.status = .inProgress
        self.startedAt = Date()
        self.completedAt = nil
        self.initiatedBy = initiatedBy
        self.includedDomains = includedDomains
        self.sizeBytes = nil
        self.storageBackendId = nil
        self.storagePath = nil
        self.encryptionKeyId = nil
        self.checksum = nil
        self.expiresAt = nil
        self.verified = false
        self.lastVerifiedAt = nil
        self.legalHoldId = nil
    }
}

/// Types of backups.
public enum BackupType: String, Sendable, Codable {
    /// Full backup of all data.
    case full = "full"

    /// Incremental since last backup.
    case incremental = "incremental"

    /// Differential since last full backup.
    case differential = "differential"

    /// Snapshot/point-in-time.
    case snapshot = "snapshot"
}

/// Backup status.
public enum BackupStatus: String, Sendable, Codable {
    /// Backup is in progress.
    case inProgress = "in_progress"

    /// Backup completed successfully.
    case completed = "completed"

    /// Backup failed.
    case failed = "failed"

    /// Backup was cancelled.
    case cancelled = "cancelled"

    /// Backup is being verified.
    case verifying = "verifying"

    /// Backup has expired.
    case expired = "expired"

    /// Backup is being deleted.
    case deleting = "deleting"
}

// MARK: - Recovery Operation

/// A recovery/restore operation.
public struct RecoveryOperationComponent: Component, Sendable, Codable {
    /// Unique operation identifier.
    public let operationId: UUID

    /// The backup snapshot being restored.
    public let snapshotId: UUID

    /// Target tenant (if different from source).
    public let targetTenantId: UUID?

    /// Target environment.
    public let targetEnvironmentId: UUID?

    /// Type of recovery.
    public var recoveryType: RecoveryType

    /// Current status.
    public var status: RecoveryStatus

    /// When the recovery started.
    public let startedAt: Date

    /// When the recovery completed.
    public var completedAt: Date?

    /// Who initiated the recovery.
    public let initiatedBy: UUID

    /// Reason/justification for recovery.
    public let reason: String

    /// Domains being recovered.
    public var domains: Set<String>

    /// Whether this is a drill/test.
    public var isDrill: Bool

    /// Validation results.
    public var validationResults: [StorageValidationResult]

    /// Errors encountered.
    public var errors: [String]

    public init(
        operationId: UUID = UUID(),
        snapshotId: UUID,
        targetTenantId: UUID? = nil,
        targetEnvironmentId: UUID? = nil,
        recoveryType: RecoveryType = .full,
        initiatedBy: UUID,
        reason: String,
        domains: Set<String> = [],
        isDrill: Bool = false
    ) {
        self.operationId = operationId
        self.snapshotId = snapshotId
        self.targetTenantId = targetTenantId
        self.targetEnvironmentId = targetEnvironmentId
        self.recoveryType = recoveryType
        self.status = .pending
        self.startedAt = Date()
        self.completedAt = nil
        self.initiatedBy = initiatedBy
        self.reason = reason
        self.domains = domains
        self.isDrill = isDrill
        self.validationResults = []
        self.errors = []
    }
}

/// Types of recovery operations.
public enum RecoveryType: String, Sendable, Codable {
    /// Full system restore.
    case full = "full"

    /// Restore specific domains.
    case partial = "partial"

    /// Point-in-time recovery.
    case pointInTime = "point_in_time"

    /// Restore to new environment (clone).
    case clone = "clone"
}

/// Recovery status.
public enum RecoveryStatus: String, Sendable, Codable {
    /// Recovery is pending.
    case pending = "pending"

    /// Recovery is validating.
    case validating = "validating"

    /// Recovery is in progress.
    case inProgress = "in_progress"

    /// Recovery is verifying results.
    case verifying = "verifying"

    /// Recovery completed successfully.
    case completed = "completed"

    /// Recovery failed.
    case failed = "failed"

    /// Recovery was rolled back.
    case rolledBack = "rolled_back"
}

/// Storage validation result for recovery.
public struct StorageValidationResult: Sendable, Codable {
    public let domain: String
    public let checkName: String
    public let passed: Bool
    public let message: String
    public let expectedCount: Int?
    public let actualCount: Int?

    public init(domain: String, checkName: String, passed: Bool, message: String, expectedCount: Int? = nil, actualCount: Int? = nil) {
        self.domain = domain
        self.checkName = checkName
        self.passed = passed
        self.message = message
        self.expectedCount = expectedCount
        self.actualCount = actualCount
    }
}

// MARK: - Legal Hold

/// A legal hold preventing data deletion.
public struct LegalHoldComponent: Component, Sendable, Codable {
    /// Unique hold identifier.
    public let holdId: UUID

    /// Name/reference for the hold.
    public var name: String

    /// Description/reason.
    public var reason: String

    /// Who initiated the hold.
    public let initiatedBy: UUID

    /// When the hold was created.
    public let createdAt: Date

    /// When the hold expires (nil = indefinite).
    public var expiresAt: Date?

    /// Whether the hold is active.
    public var isActive: Bool

    /// Entities under hold (by entity ID).
    public var heldEntityIds: Set<UUID>

    /// Subjects under hold (by principal ID).
    public var heldSubjectIds: Set<UUID>

    /// Domains under hold.
    public var heldDomains: Set<String>

    /// Date ranges under hold.
    public var dateRangeStart: Date?
    public var dateRangeEnd: Date?

    /// Legal matter reference.
    public var legalMatterReference: String?

    public init(
        holdId: UUID = UUID(),
        name: String,
        reason: String,
        initiatedBy: UUID,
        expiresAt: Date? = nil
    ) {
        self.holdId = holdId
        self.name = name
        self.reason = reason
        self.initiatedBy = initiatedBy
        self.createdAt = Date()
        self.expiresAt = expiresAt
        self.isActive = true
        self.heldEntityIds = []
        self.heldSubjectIds = []
        self.heldDomains = []
        self.dateRangeStart = nil
        self.dateRangeEnd = nil
        self.legalMatterReference = nil
    }

    /// Checks if a specific entity is under hold.
    public func holdsEntity(_ entityId: UUID) -> Bool {
        heldEntityIds.contains(entityId)
    }

    /// Checks if a subject's data is under hold.
    public func holdsSubject(_ subjectId: UUID) -> Bool {
        heldSubjectIds.contains(subjectId)
    }

    /// Checks if a domain is under hold.
    public func holdsDomain(_ domain: String) -> Bool {
        heldDomains.contains(domain)
    }
}

// MARK: - Data Export Request

/// A request to export data (for privacy compliance).
public struct DataExportRequestComponent: Component, Sendable, Codable {
    /// Unique request identifier.
    public var requestId: UUID
    public var requestedAt: Date
    public let subjectId: UUID
    public var exportType: DataExportType = .full
    public var status: DataExportStatus = .pending
    public let requestedBy: UUID
    
    public init(subjectId: UUID, requestedBy: UUID, exportType: DataExportType = .full) {
        self.requestId = UUID()
        self.subjectId = subjectId
        self.requestedBy = requestedBy
        self.requestedAt = Date()
        self.exportType = exportType
    }

    /// When the export was completed.
    public var completedAt: Date? = nil

    /// Domains included in export.
    public var includedDomains: Set<String> = []

    /// Format for export.
    public var format: DataExportFormat = .json

    /// Output location/path.
    public var outputPath: String? = nil

    /// Size of export in bytes.
    public var sizeBytes: Int64? = nil

    /// When the export expires/should be deleted.
    public var expiresAt: Date? = nil

    /// Verification that export was delivered.
    public var deliveredAt: Date? = nil
}

/// Types of data exports.
public enum DataExportType: String, Sendable, Codable {
    /// Full data export (all subject data).
    case full = "full"

    /// Specific domains only.
    case partial = "partial"

    /// Audit trail only.
    case auditOnly = "audit_only"

    /// Portable format for transfer.
    case portable = "portable"
}

/// Data export status.
public enum DataExportStatus: String, Sendable, Codable {
    case pending = "pending"
    case inProgress = "in_progress"
    case completed = "completed"
    case failed = "failed"
    case delivered = "delivered"
    case expired = "expired"
}

/// Export formats.
public enum DataExportFormat: String, Sendable, Codable {
    case json = "json"
    case csv = "csv"
    case xml = "xml"
    case pdf = "pdf"
}

// MARK: - Backup Schedule

/// A backup schedule configuration.
public struct BackupScheduleComponent: Component, Sendable, Codable {
    /// Unique schedule identifier.
    public let scheduleId: UUID

    /// The tenant this schedule is for (nil = platform).
    public let tenantId: UUID?

    /// Schedule name.
    public var name: String

    /// Whether the schedule is enabled.
    public var isEnabled: Bool

    /// Backup type for this schedule.
    public var backupType: BackupType

    /// Cron-like schedule expression.
    public var cronExpression: String

    /// Domains to include.
    public var includedDomains: Set<String>

    /// Retention period in days.
    public var retentionDays: Int

    /// Target storage backend.
    public var targetBackendId: UUID?

    /// Last execution time.
    public var lastExecutedAt: Date?

    /// Next scheduled execution.
    public var nextExecutionAt: Date?

    public init(
        scheduleId: UUID = UUID(),
        tenantId: UUID? = nil,
        name: String,
        backupType: BackupType = .full,
        cronExpression: String = "0 2 * * *", // 2 AM daily
        includedDomains: Set<String> = [],
        retentionDays: Int = 30
    ) {
        self.scheduleId = scheduleId
        self.tenantId = tenantId
        self.name = name
        self.isEnabled = true
        self.backupType = backupType
        self.cronExpression = cronExpression
        self.includedDomains = includedDomains
        self.retentionDays = retentionDays
        self.targetBackendId = nil
        self.lastExecutedAt = nil
        self.nextExecutionAt = nil
    }
}

// MARK: - RPO/RTO Targets

/// Recovery Point Objective and Recovery Time Objective configuration.
public struct DisasterRecoveryTargets: Sendable, Codable {
    /// Maximum acceptable data loss (in minutes).
    public var rpoMinutes: Int

    /// Maximum acceptable downtime (in minutes).
    public var rtoMinutes: Int

    /// Critical domains requiring fastest recovery.
    public var criticalDomains: Set<String>

    /// Last measured actual RPO.
    public var actualRpoMinutes: Int?

    /// Last measured actual RTO (from drill).
    public var actualRtoMinutes: Int?

    /// When targets were last tested.
    public var lastTestedAt: Date?

    /// Whether targets are currently being met.
    public var targetsMetAsOf: Date?

    public init(
        rpoMinutes: Int = 60,
        rtoMinutes: Int = 240,
        criticalDomains: Set<String> = []
    ) {
        self.rpoMinutes = rpoMinutes
        self.rtoMinutes = rtoMinutes
        self.criticalDomains = criticalDomains
        self.actualRpoMinutes = nil
        self.actualRtoMinutes = nil
        self.lastTestedAt = nil
        self.targetsMetAsOf = nil
    }
}
