//
//  RetentionPolicyManager.swift
//  DatabaseCore
//
//  Actor for loading, enforcing, and managing retention policies.
//

import Foundation
import AnigmaPrimitives
import FoundationContracts
import EvidenceContracts
import GovernanceContracts

/// Actor for loading, enforcing, and managing retention policies.
public actor RetentionPolicyManager {
    private let db: DatabaseActor
    private var cachedPolicy: RetentionPolicy?
    private var policyUpdateTimestamp: Date?

    public init(database: DatabaseActor) async throws {
        self.db = database
        try await setupPolicyStorage()

        // Load initial policy
        _ = try await loadPolicy()
    }

    /// Initialize storage for retention policies.
    private func setupPolicyStorage() async throws {
        try await db.executeAsync(
            """
            CREATE TABLE IF NOT EXISTS retention_policy_store (
                policy_id TEXT PRIMARY KEY,
                policy_version TEXT NOT NULL,
                policy_content BLOB NOT NULL,
                policy_hash TEXT NOT NULL,
                created_at REAL NOT NULL,
                is_active INTEGER NOT NULL DEFAULT 1
            );
            """
        )

        try await db.executeAsync(
            """
            CREATE INDEX IF NOT EXISTS idx_retention_policy_active
            ON retention_policy_store(is_active);
            """
        )
    }

    /// Load the active retention policy, using fallback if none exists.
    public func loadPolicy() async throws -> RetentionPolicy {
        if let storedPolicy = try await loadActivePolicy() {
            self.cachedPolicy = storedPolicy
            policyUpdateTimestamp = Date()
            return storedPolicy
        }

        let defaultPolicy = RetentionPolicy.production
        try await storePolicy(defaultPolicy, makeActive: true)
        self.cachedPolicy = defaultPolicy
        policyUpdateTimestamp = Date()

        return defaultPolicy
    }

    private func loadActivePolicy() async throws -> RetentionPolicy? {
        let rows = try await db.query(
            """
            SELECT policy_content, policy_hash
            FROM retention_policy_store
            WHERE is_active = 1
            """
        )

        guard let row = rows.first,
            let policyData = row.data(for: "policy_content"),
            let storedHash = row.string(for: "policy_hash")
        else {
            return nil
        }

        let decoder = JSONDecoder()
        let policy = try decoder.decode(RetentionPolicy.self, from: policyData)

        if policy.policyHash != storedHash {
            throw RetentionPolicyError.corruptedPolicy(
                storedHash: storedHash, computedHash: policy.policyHash)
        }

        return policy
    }

    public func storePolicy(_ policy: RetentionPolicy, makeActive: Bool = false) async throws {
        let encoder = JSONEncoder()
        let policyData = try encoder.encode(policy)

        try await db.executeAsync(
            """
            INSERT OR REPLACE INTO retention_policy_store
            (policy_id, policy_version, policy_content, policy_hash, created_at, is_active)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                .text(UUID().uuidString),
                .text(policy.version),
                .blob(policyData),
                .text(policy.policyHash),
                .double(Date().timeIntervalSince1970),
                .int(makeActive ? 1 : 0)
            ]
        )

        if makeActive {
            try await db.executeAsync(
                """
                UPDATE retention_policy_store
                SET is_active = 0
                WHERE policy_hash <> ?
                """,
                parameters: [.text(policy.policyHash)]
            )

            cachedPolicy = policy
            policyUpdateTimestamp = Date()
        }
    }

    public func getCurrentPolicy() -> RetentionPolicy? {
        return cachedPolicy
    }

    public func needsRefresh(olderThan: TimeInterval = 300) async throws -> Bool {
        guard let timestamp = policyUpdateTimestamp else {
            return true
        }

        let age = Date().timeIntervalSince(timestamp)
        return age >= olderThan
    }

    public func evaluateRetentionEligibility(
        artifacts: [(
            hash: String, classKey: String, artifactType: String, contentAge: TimeInterval,
            referenceCount: Int
        )],
        usingPolicy policy: RetentionPolicy? = nil
    ) async throws -> [String: RetentionEligibility] {
        let currentPolicy = policy ?? cachedPolicy ?? RetentionPolicy.production

        var results: [String: RetentionEligibility] = [:]

        for artifact in artifacts {
            let eligibility = currentPolicy.shouldRetain(
                contentHash: artifact.hash,
                policyClass: artifact.classKey,
                artifactType: artifact.artifactType,
                contentAge: artifact.contentAge,
                referenceCount: artifact.referenceCount
            )
            results[artifact.hash] = eligibility
        }

        return results
    }

    public func recordComplianceEvent(
        eventID: String,
        policyVersionHash: String,
        action: String,
        effectedArtifacts: Int = 0,
        bytesFreed: Int = 0
    ) async throws -> String {
        let now = Date()

        try await db.executeAsync(
            """
            INSERT OR REPLACE INTO policy_compliance_events
            (event_id, policy_version_hash, action, effected_artifacts, bytes_freed, created_at)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                .text(eventID),
                .text(policyVersionHash),
                .text(action),
                .int(effectedArtifacts),
                .int(bytesFreed),
                .double(now.timeIntervalSince1970)
            ]
        )

        return eventID
    }

    public func getComplianceStats(since: Date? = nil) async throws -> (
        totalEvents: Int,
        artifactsDeleted: Int,
        bytesFreed: Int
    ) {
        let whereClause = since != nil ? "WHERE created_at >= \(since!.timeIntervalSince1970)" : ""

        let rows = try await db.query(
            """
            SELECT
                COUNT(*) as total_events,
                SUM(effected_artifacts) as total_artifacts,
                SUM(bytes_freed) as total_bytes
            FROM policy_compliance_events
            \(whereClause)
            """
        )

        guard let row = rows.first else {
            return (0, 0, 0)
        }

        return (
            totalEvents: row.int(for: "total_events") ?? 0,
            artifactsDeleted: row.int(for: "total_artifacts") ?? 0,
            bytesFreed: row.int(for: "total_bytes") ?? 0
        )
    }

    public func enforcePolicyForOperation(
        operation: String,
        resource: String
    ) throws -> RetentionPolicyEnforcement {
        guard let policy = cachedPolicy else {
            throw RetentionPolicyError.noActivePolicy
        }

        // Basic enforcement - could be extended with specific rules per operation
        if operation == "delete_master_ledger" && policy.segments.maxSegmentSizeMB > 0 {
            // Allow deletion if segmentation is configured
            return .allowed(policyVersion: policy.policyHash)
        }

        if operation.starts(with: "delete_") && resource == "master_ledger" {
            // Never allow deletion of master ledger
            return .denied(reason: "Master ledger is protected by policy")
        }

        return .allowed(policyVersion: policy.policyHash)
    }
}
