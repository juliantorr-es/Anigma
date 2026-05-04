//
//  MigrationEngine.swift
//  AnigmaCore
//
//  AnigmaCore - Schema Migration Engine
//
//  Handles database/ECS schema migrations with rollback support.
//  Migrations are versioned, reversible where possible, and fully audited.
//

import AnigmaPrimitives
import ContractsCore
import Foundation

// MARK: - Migration Status

/// Status of a migration
public enum MigrationStatus: String, Sendable, Codable {
    case pending
    case running
    case completed
    case failed
    case rolledBack
    case skipped
}

// MARK: - Migration Record

/// Record of a migration execution
public struct MigrationRecord: Sendable, Codable, Identifiable {
    public let id: String  // Migration ID
    public let version: SemanticVersion
    public let description: String
    public var status: MigrationStatus
    public let startedAt: Date?
    public let completedAt: Date?
    public let error: String?
    public let affectedEntities: Int
    public let isReversible: Bool
    public let executedBy: String?

    public init(
        id: String,
        version: SemanticVersion,
        description: String,
        status: MigrationStatus = .pending,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        error: String? = nil,
        affectedEntities: Int = 0,
        isReversible: Bool = true,
        executedBy: String? = nil
    ) {
        self.id = id
        self.version = version
        self.description = description
        self.status = status
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.error = error
        self.affectedEntities = affectedEntities
        self.isReversible = isReversible
        self.executedBy = executedBy
    }

    public var duration: TimeInterval? {
        guard let start = startedAt, let end = completedAt else { return nil }
        return end.timeIntervalSince(start)
    }
}

// MARK: - Migration Definition

/// Definition of a migration to execute
public protocol Migration: Sendable {
    var id: String { get }
    var version: SemanticVersion { get }
    var description: String { get }
    var isReversible: Bool { get }
    var affectedDomains: [String] { get }
    var preconditions: [String] { get }
    var estimatedDuration: TimeInterval { get }

    /// Execute the migration forward
    func up(context: MigrationContext) async throws -> DetailedMigrationResult

    /// Rollback the migration (if reversible)
    func down(context: MigrationContext) async throws -> DetailedMigrationResult

    /// Validate preconditions
    func validate(context: MigrationContext) async throws -> Bool
}

/// Default implementations
public extension Migration {
    var isReversible: Bool { true }
    var affectedDomains: [String] { [] }
    var preconditions: [String] { [] }
    var estimatedDuration: TimeInterval { 60 }

    func validate(context: MigrationContext) async throws -> Bool {
        return true
    }
}

// MARK: - Migration Context

/// Context provided to migrations
public struct MigrationContext: Sendable {
    public let environment: DeploymentEnvironment
    public let dryRun: Bool
    public let principalId: String
    public let timestamp: Date
    public let previousVersion: SemanticVersion?
    public let targetVersion: SemanticVersion

    public init(
        environment: DeploymentEnvironment,
        dryRun: Bool = false,
        principalId: String,
        timestamp: Date = Date(),
        previousVersion: SemanticVersion? = nil,
        targetVersion: SemanticVersion
    ) {
        self.environment = environment
        self.dryRun = dryRun
        self.principalId = principalId
        self.timestamp = timestamp
        self.previousVersion = previousVersion
        self.targetVersion = targetVersion
    }
}

// MARK: - Migration Result

/// Result of a migration execution
public struct DetailedMigrationResult: Sendable {
    public let success: Bool
    public let affectedEntities: Int
    public let warnings: [String]
    public let details: String

    public init(
        success: Bool,
        affectedEntities: Int = 0,
        warnings: [String] = [],
        details: String = ""
    ) {
        self.success = success
        self.affectedEntities = affectedEntities
        self.warnings = warnings
        self.details = details
    }

    public static func success(affected: Int = 0, details: String = "") -> DetailedMigrationResult {
        return DetailedMigrationResult(success: true, affectedEntities: affected, details: details)
    }

    public static func failure(reason: String) -> DetailedMigrationResult {
        return DetailedMigrationResult(success: false, details: reason)
    }
}

// MARK: - Migration Plan

/// Plan for executing migrations
public struct MigrationPlan: Sendable {
    public let migrations: [any Migration]
    public let fromVersion: SemanticVersion?
    public let toVersion: SemanticVersion
    public let estimatedDuration: TimeInterval
    public let requiresMaintenanceMode: Bool
    public let hasIrreversibleSteps: Bool

    public init(
        migrations: [any Migration],
        fromVersion: SemanticVersion?,
        toVersion: SemanticVersion
    ) {
        self.migrations = migrations
        self.fromVersion = fromVersion
        self.toVersion = toVersion
        self.estimatedDuration = migrations.reduce(0) { $0 + $1.estimatedDuration }
        self.requiresMaintenanceMode = migrations.count > 3 || estimatedDuration > 300
        self.hasIrreversibleSteps = migrations.contains { !$0.isReversible }
    }

    public var affectedDomains: Set<String> {
        var domains = Set<String>()
        for migration in migrations {
            domains.formUnion(migration.affectedDomains)
        }
        return domains
    }
}

// MARK: - Migration Engine

/// Engine for executing migrations
public actor MigrationEngine {
    private var registeredMigrations: [String: any Migration] = [:]
    private var executedMigrations: [String: MigrationRecord] = [:]
    private var currentVersion: SemanticVersion?

    public init(currentVersion: SemanticVersion? = nil) {
        self.currentVersion = currentVersion
    }

    // MARK: - Registration

    /// Register a migration
    public func register(_ migration: any Migration) {
        registeredMigrations[migration.id] = migration
    }

    /// Register multiple migrations
    public func register(_ migrations: [any Migration]) {
        for migration in migrations {
            register(migration)
        }
    }

    // MARK: - Planning

    /// Create migration plan to target version
    public func plan(to targetVersion: SemanticVersion) -> MigrationPlan {
        // Get migrations that need to run
        let pending = registeredMigrations.values
            .filter { migration in
                // Not already executed
                guard executedMigrations[migration.id]?.status != .completed else {
                    return false
                }
                // Version is in range
                if let current = currentVersion {
                    return migration.version > current && migration.version <= targetVersion
                }
                return migration.version <= targetVersion
            }
            .sorted { $0.version < $1.version }

        return MigrationPlan(
            migrations: pending,
            fromVersion: currentVersion,
            toVersion: targetVersion
        )
    }

    /// Create rollback plan
    public func planRollback(to targetVersion: SemanticVersion) -> MigrationPlan {
        // Get migrations to rollback (in reverse order)
        let toRollback = executedMigrations.values
            .filter { record in
                record.status == .completed &&
                record.isReversible &&
                record.version > targetVersion
            }
            .sorted { $0.version > $1.version }
            .compactMap { registeredMigrations[$0.id] }

        return MigrationPlan(
            migrations: toRollback,
            fromVersion: currentVersion,
            toVersion: targetVersion
        )
    }

    // MARK: - Execution

    /// Execute migration plan
    public func execute(
        plan: MigrationPlan,
        context: MigrationContext
    ) async -> MigrationExecutionResult {
        var results: [MigrationRecord] = []
        var success = true

        for migration in plan.migrations {
            // Validate preconditions
            do {
                let valid = try await migration.validate(context: context)
                guard valid else {
                    let record = MigrationRecord(
                        id: migration.id,
                        version: migration.version,
                        description: migration.description,
                        status: .skipped,
                        error: "Precondition validation failed",
                        isReversible: migration.isReversible,
                        executedBy: context.principalId
                    )
                    results.append(record)
                    executedMigrations[migration.id] = record
                    continue
                }
            } catch {
                let record = MigrationRecord(
                    id: migration.id,
                    version: migration.version,
                    description: migration.description,
                    status: .failed,
                    error: "Validation error: \(error.localizedDescription)",
                    isReversible: migration.isReversible,
                    executedBy: context.principalId
                )
                results.append(record)
                executedMigrations[migration.id] = record
                success = false
                break
            }

            // Execute migration
            let startTime = Date()
            do {
                let result: DetailedMigrationResult = try await migration.up(context: context)

                let record = MigrationRecord(
                    id: migration.id,
                    version: migration.version,
                    description: migration.description,
                    status: result.success ? .completed : .failed,
                    startedAt: startTime,
                    completedAt: Date(),
                    error: result.success ? nil : result.details,
                    affectedEntities: result.affectedEntities,
                    isReversible: migration.isReversible,
                    executedBy: context.principalId
                )
                results.append(record)
                executedMigrations[migration.id] = record

                if !result.success {
                    success = false
                    break
                }

                // Update current version
                currentVersion = migration.version

            } catch {
                let record = MigrationRecord(
                    id: migration.id,
                    version: migration.version,
                    description: migration.description,
                    status: .failed,
                    startedAt: startTime,
                    completedAt: Date(),
                    error: error.localizedDescription,
                    isReversible: migration.isReversible,
                    executedBy: context.principalId
                )
                results.append(record)
                executedMigrations[migration.id] = record
                success = false
                break
            }
        }

        return MigrationExecutionResult(
            success: success,
            records: results,
            finalVersion: currentVersion,
            totalDuration: results.compactMap { $0.duration }.reduce(0, +)
        )
    }

    /// Execute rollback
    public func rollback(
        plan: MigrationPlan,
        context: MigrationContext
    ) async -> MigrationExecutionResult {
        var results: [MigrationRecord] = []
        var success = true

        for migration in plan.migrations {
            guard migration.isReversible else {
                let record = MigrationRecord(
                    id: migration.id,
                    version: migration.version,
                    description: migration.description,
                    status: .skipped,
                    error: "Migration is not reversible",
                    isReversible: false,
                    executedBy: context.principalId
                )
                results.append(record)
                success = false
                break
            }

            let startTime = Date()
            do {
                let result: DetailedMigrationResult = try await migration.down(context: context)

                let record = MigrationRecord(
                    id: migration.id,
                    version: migration.version,
                    description: "Rollback: \(migration.description)",
                    status: result.success ? .rolledBack : .failed,
                    startedAt: startTime,
                    completedAt: Date(),
                    error: result.success ? nil : result.details,
                    affectedEntities: result.affectedEntities,
                    isReversible: true,
                    executedBy: context.principalId
                )
                results.append(record)

                if var existing = executedMigrations[migration.id] {
                    existing = MigrationRecord(
                        id: existing.id,
                        version: existing.version,
                        description: existing.description,
                        status: .rolledBack,
                        startedAt: existing.startedAt,
                        completedAt: Date(),
                        error: nil,
                        affectedEntities: existing.affectedEntities,
                        isReversible: existing.isReversible,
                        executedBy: context.principalId
                    )
                    executedMigrations[migration.id] = existing
                }

                if !result.success {
                    success = false
                    break
                }

            } catch {
                let record = MigrationRecord(
                    id: migration.id,
                    version: migration.version,
                    description: "Rollback failed: \(migration.description)",
                    status: .failed,
                    startedAt: startTime,
                    completedAt: Date(),
                    error: error.localizedDescription,
                    isReversible: true,
                    executedBy: context.principalId
                )
                results.append(record)
                success = false
                break
            }
        }

        // Update current version to target
        if success {
            currentVersion = plan.toVersion
        }

        return MigrationExecutionResult(
            success: success,
            records: results,
            finalVersion: currentVersion,
            totalDuration: results.compactMap { $0.duration }.reduce(0, +)
        )
    }

    // MARK: - Dry Run

    /// Execute dry run (validate only)
    public func dryRun(
        plan: MigrationPlan,
        context: MigrationContext
    ) async -> DryRunResult {
        var validations: [(String, Bool, String)] = []

        let dryContext = MigrationContext(
            environment: context.environment,
            dryRun: true,
            principalId: context.principalId,
            timestamp: context.timestamp,
            previousVersion: context.previousVersion,
            targetVersion: context.targetVersion
        )

        for migration in plan.migrations {
            do {
                let valid = try await migration.validate(context: dryContext)
                validations.append((migration.id, valid, valid ? "OK" : "Validation failed"))
            } catch {
                validations.append((migration.id, false, error.localizedDescription))
            }
        }

        let allValid = validations.allSatisfy { $0.1 }

        return DryRunResult(
            wouldSucceed: allValid,
            validations: validations,
            estimatedDuration: plan.estimatedDuration,
            affectedDomains: Array(plan.affectedDomains),
            requiresMaintenanceMode: plan.requiresMaintenanceMode,
            hasIrreversibleSteps: plan.hasIrreversibleSteps
        )
    }

    // MARK: - Status

    /// Get current version
    public func getCurrentVersion() -> SemanticVersion? {
        return currentVersion
    }

    /// Get migration history
    public func getHistory() -> [MigrationRecord] {
        return executedMigrations.values.sorted { $0.version < $1.version }
    }

    /// Get pending migrations
    public func getPending(to version: SemanticVersion) -> [any Migration] {
        return plan(to: version).migrations
    }

    /// Check if migration was executed
    public func wasExecuted(_ migrationId: String) -> Bool {
        return executedMigrations[migrationId]?.status == .completed
    }
}

// MARK: - Result Types

/// Result of migration execution
public struct MigrationExecutionResult: Sendable {
    public let success: Bool
    public let records: [MigrationRecord]
    public let finalVersion: SemanticVersion?
    public let totalDuration: TimeInterval

    public var failedMigrations: [MigrationRecord] {
        records.filter { $0.status == .failed }
    }

    public var completedMigrations: [MigrationRecord] {
        records.filter { $0.status == .completed }
    }
}

/// Result of dry run
public struct DryRunResult: Sendable {
    public let wouldSucceed: Bool
    public let validations: [(migrationId: String, valid: Bool, message: String)]
    public let estimatedDuration: TimeInterval
    public let affectedDomains: [String]
    public let requiresMaintenanceMode: Bool
    public let hasIrreversibleSteps: Bool
}

// MARK: - Common Migrations

/// Base migration for adding a new component type

/// Base migration for data transformation
public struct DataTransformMigration: Migration, Sendable {
    public let id: String
    public let version: SemanticVersion
    public let description: String
    public let affectedDomains: [String]
    public let isReversible: Bool
    public let estimatedDuration: TimeInterval

    private let transform: @Sendable (MigrationContext) async throws -> Int
    private let reverseTransform: (@Sendable (MigrationContext) async throws -> Int)?

    public init(
        id: String,
        version: SemanticVersion,
        description: String,
        domains: [String],
        estimatedDuration: TimeInterval = 120,
        transform: @escaping @Sendable (MigrationContext) async throws -> Int,
        reverseTransform: (@Sendable (MigrationContext) async throws -> Int)? = nil
    ) {
        self.id = id
        self.version = version
        self.description = description
        self.affectedDomains = domains
        self.estimatedDuration = estimatedDuration
        self.transform = transform
        self.reverseTransform = reverseTransform
        self.isReversible = reverseTransform != nil
    }

    public func up(context: MigrationContext) async throws -> DetailedMigrationResult {
        let affected = try await transform(context)
        return DetailedMigrationResult.success(affected: affected, details: "Transformed \(affected) records")
    }

    public func down(context: MigrationContext) async throws -> DetailedMigrationResult {
        guard let reverse = reverseTransform else {
            return DetailedMigrationResult.failure(reason: "Migration is not reversible")
        }
        let affected = try await reverse(context)
        return DetailedMigrationResult.success(affected: affected, details: "Reversed \(affected) records")
    }
}
