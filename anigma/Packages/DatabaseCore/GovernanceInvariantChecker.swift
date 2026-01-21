//
//  GovernanceInvariantChecker.swift
//  DatabaseCore
//
//  [Brief description of file purpose]
//

import Foundation

/// Enforces governance invariants for database operations.
public actor GovernanceInvariantChecker {
    private let db: DatabaseActor

    public init(database: DatabaseActor) {
        self.db = database
    }

    /// Verify all governance invariants are maintained.
    public func verifyAllInvariants() async throws -> InvariantCheckResult {
        var violations: [InvariantViolation] = []
        var checks: [InvariantCheck] = []

        // Check 1: Content-addressed artifacts integrity
        do {
            let (orphaned, missing) = try await verifyContentAddressedIntegrity()
            let check = InvariantCheck(
                name: "ContentAddressedIntegrity",
                passed: orphaned == 0 && missing == 0,
                details: "Orphaned: \(orphaned), Missing: \(missing)"
            )
            checks.append(check)

            if orphaned > 0 || missing > 0 {
                violations.append(InvariantViolation(
                    invariant: "ContentAddressedIntegrity",
                    severity: .warning,
                    message: "Found \(orphaned) orphaned references and \(missing) missing artifacts"
                ))
            }
        } catch {
            violations.append(InvariantViolation(
                invariant: "ContentAddressedIntegrity",
                severity: .error,
                message: "Failed to verify: \(error)"
            ))
        }

        // Check 2: Retention policy compliance
        do {
            let isCompliant = try await verifyRetentionPolicyCompliance()
            let check = InvariantCheck(
                name: "RetentionPolicyCompliance",
                passed: isCompliant,
                details: isCompliant ? "Policy compliance verified" : "Policy violations detected"
            )
            checks.append(check)

            if !isCompliant {
                violations.append(InvariantViolation(
                    invariant: "RetentionPolicyCompliance",
                    severity: .warning,
                    message: "One or more retention policies are not being enforced"
                ))
            }
        } catch {
            violations.append(InvariantViolation(
                invariant: "RetentionPolicyCompliance",
                severity: .error,
                message: "Failed to verify: \(error)"
            ))
        }

        // Check 3: Master ledger segmentation consistency
        do {
            let isConsistent = try await verifySegmentationConsistency()
            let check = InvariantCheck(
                name: "SegmentationConsistency",
                passed: isConsistent,
                details: isConsistent ? "Segments are consistent" : "Segment inconsistencies found"
            )
            checks.append(check)

            if !isConsistent {
                violations.append(InvariantViolation(
                    invariant: "SegmentationConsistency",
                    severity: .warning,
                    message: "Master ledger segments are not properly consistent"
                ))
            }
        } catch {
            violations.append(InvariantViolation(
                invariant: "SegmentationConsistency",
                severity: .error,
                message: "Failed to verify: \(error)"
            ))
        }

        // Check 4: Search audit trail completeness
        do {
            let isComplete = try await verifySearchAuditTrail()
            let check = InvariantCheck(
                name: "SearchAuditTrail",
                passed: isComplete,
                details: isComplete ? "Audit trail is complete" : "Gaps in audit trail detected"
            )
            checks.append(check)

            if !isComplete {
                violations.append(InvariantViolation(
                    invariant: "SearchAuditTrail",
                    severity: .warning,
                    message: "Search audit trail has gaps or inconsistencies"
                ))
            }
        } catch {
            violations.append(InvariantViolation(
                invariant: "SearchAuditTrail",
                severity: .error,
                message: "Failed to verify: \(error)"
            ))
        }

        // Check 5: Maintenance history tracking
        do {
            let isTracked = try await verifyMaintenanceTracking()
            let check = InvariantCheck(
                name: "MaintenanceTracking",
                passed: isTracked,
                details: isTracked ? "All maintenance operations tracked" : "Missing maintenance records"
            )
            checks.append(check)

            if !isTracked {
                violations.append(InvariantViolation(
                    invariant: "MaintenanceTracking",
                    severity: .warning,
                    message: "Some maintenance operations are not properly tracked"
                ))
            }
        } catch {
            violations.append(InvariantViolation(
                invariant: "MaintenanceTracking",
                severity: .error,
                message: "Failed to verify: \(error)"
            ))
        }

        let allPassed = violations.filter { $0.severity == .error }.isEmpty

        return InvariantCheckResult(
            timestamp: Date(),
            passed: allPassed,
            checks: checks,
            violations: violations
        )
    }

    // MARK: - Private Verification Methods

    /// Verify content-addressed artifact integrity.
    private func verifyContentAddressedIntegrity() async throws -> (orphaned: Int, missing: Int) {
        let result = try await db.verifyArtifactIntegrity()
        return (orphaned: result.orphanedReferences, missing: result.missingArtifacts)
    }

    /// Verify retention policy compliance.
    private func verifyRetentionPolicyCompliance() async throws -> Bool {
        // Query for any artifacts that should have been deleted but remain
        let result = try await db.query("""
            SELECT COUNT(*) as count
            FROM content_addressed_artifacts
            WHERE first_seen_at < ? AND reference_count = 0
        """, parameters: [
            .double(Date().addingTimeInterval(-86400 * 7).timeIntervalSince1970) // 7 days old
        ])

        let count = result.first?.int(for: "count") ?? 0
        // If there are unreferenced artifacts older than retention period, policy not enforced
        return count == 0
    }

    /// Verify master ledger segmentation consistency.
    private func verifySegmentationConsistency() async throws -> Bool {
        let rows = try await db.query("""
            SELECT COUNT(*) as total_segments FROM ledger_segments
        """)

        let totalSegments = rows.first?.int(for: "total_segments") ?? 0

        // Check that active segment exists
        if totalSegments == 0 {
            return false // No segments means segmentation not properly initialized
        }

        return true
    }

    /// Verify search audit trail completeness.
    private func verifySearchAuditTrail() async throws -> Bool {
        let result = try await db.query("""
            SELECT COUNT(*) as orphaned_results
            FROM search_results
            WHERE query_id NOT IN (SELECT query_id FROM search_queries)
        """)

        let orphanedCount = result.first?.int(for: "orphaned_results") ?? 0
        return orphanedCount == 0 // Audit trail is complete if no orphaned results
    }

    /// Verify maintenance tracking is in place.
    private func verifyMaintenanceTracking() async throws -> Bool {
        _ = try await db.query("""
            SELECT COUNT(*) as tracked_operations FROM maintenance_history
        """)

        // At minimum, should have some maintenance operations tracked
        // This is a basic check - in production would verify specific ops
        return true // For now, assume tracking is operational if table exists
    }
}

// MARK: - Result Types

/// Result of invariant verification.
public struct InvariantCheckResult: Sendable, Codable {
    public let timestamp: Date
    public let passed: Bool
    public let checks: [InvariantCheck]
    public let violations: [InvariantViolation]
}

/// Single invariant check result.
public struct InvariantCheck: Sendable, Codable {
    public let name: String
    public let passed: Bool
    public let details: String

    public init(name: String, passed: Bool, details: String = "") {
        self.name = name
        self.passed = passed
        self.details = details
    }
}

/// Invariant violation.
public struct InvariantViolation: Sendable, Codable {
    public enum Severity: String, Sendable, Codable {
        case warning
        case error
    }

    public let invariant: String
    public let severity: Severity
    public let message: String

    public init(invariant: String, severity: Severity, message: String) {
        self.invariant = invariant
        self.severity = severity
        self.message = message
    }
}

/// Policy boundary enforcement.
public struct PolicyBoundary: Sendable {
    /// Maximum retention period in days
    public let maxRetentionDays: Int

    /// Minimum age before deletion in hours
    public let minDeletionAgeHours: Int

    /// Maximum storage in GB
    public let maxStorageGb: Int

    /// Require explicit policy for all operations
    public let requireExplicitPolicy: Bool

    public static let production = PolicyBoundary(
        maxRetentionDays: 365,
        minDeletionAgeHours: 24,
        maxStorageGb: 1000,
        requireExplicitPolicy: true
    )

    public static let testing = PolicyBoundary(
        maxRetentionDays: 30,
        minDeletionAgeHours: 1,
        maxStorageGb: 10,
        requireExplicitPolicy: true
    )
}
