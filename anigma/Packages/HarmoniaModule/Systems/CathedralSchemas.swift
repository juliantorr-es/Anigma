//
//  CathedralSchemas.swift
//  HarmoniaModule
//
//  ECS system implementation for HarmoniaModule.
//

import DatabaseCore
@preconcurrency import Foundation
import ContractsCore

/// Database schemas for Cathedral coordination and enforcement systems
/// Creates tables for evidence chains, violations, audit reports, and plan artifacts

public actor CathedralSchemas {
    private let dbActor: DatabaseActor

    public init(dbActor: DatabaseActor) async throws {
        self.dbActor = dbActor
        try await createSchemas()
    }

    private func createSchemas() async throws {
        // Evidence violations table
        try await dbActor.execute("""
            CREATE TABLE IF NOT EXISTS evidence_violations (
                violation_id TEXT PRIMARY KEY,
                violation_type TEXT NOT NULL,
                severity TEXT NOT NULL,
                operation TEXT NOT NULL,
                details TEXT NOT NULL,
                detected_at INTEGER NOT NULL,
                action_taken TEXT NOT NULL,
                enforcement_actor TEXT NOT NULL,
                created_at INTEGER DEFAULT (strftime('%s', 'now'))
            )
            """)

        // Evidence enforcement actions table
        try await dbActor.execute("""
            CREATE TABLE IF NOT EXISTS evidence_enforcement (
                id TEXT PRIMARY KEY,
                type TEXT NOT NULL,
                operation TEXT NOT NULL,
                evidence_level TEXT NOT NULL,
                status TEXT NOT NULL,
                timestamp INTEGER NOT NULL
            )
            """)

        // Evidence audit reports table
        try await dbActor.execute("""
            CREATE TABLE IF NOT EXISTS evidence_audit_reports (
                report_id TEXT PRIMARY KEY,
                start_time INTEGER NOT NULL,
                end_time INTEGER NOT NULL,
                total_operations INTEGER NOT NULL,
                validated_operations INTEGER NOT NULL,
                violations_found INTEGER NOT NULL,
                violations_json TEXT,
                created_at INTEGER DEFAULT (strftime('%s', 'now'))
            )
            """)

        // Plan artifacts table
        try await dbActor.execute("""
            CREATE TABLE IF NOT EXISTS plan_artifacts (
                plan_id TEXT PRIMARY KEY,
                plan_json TEXT NOT NULL,
                plan_hash TEXT NOT NULL,
                artifact_version TEXT NOT NULL,
                evidence_digest TEXT NOT NULL,
                generated_by TEXT NOT NULL,
                generated_at INTEGER NOT NULL,
                file_path TEXT NOT NULL,
                created_at INTEGER DEFAULT (strftime('%s', 'now'))
            )
            """)

        // Indexes for performance
        try await dbActor.execute("""
            CREATE INDEX IF NOT EXISTS idx_evidence_violations_timestamp
            ON evidence_violations(timestamp)
            """)

        try await dbActor.execute("""
            CREATE INDEX IF NOT EXISTS idx_evidence_enforcement_timestamp
            ON evidence_enforcement(timestamp)
            """)

        try await dbActor.execute("""
            CREATE INDEX IF NOT EXISTS idx_evidence_audit_reports_timestamp
            ON evidence_audit_reports(timestamp)
            """)

        try await dbActor.execute("""
            CREATE INDEX IF NOT EXISTS idx_plan_artifacts_hash
            ON plan_artifacts(plan_hash)
            """)
    }
}

// MARK: - Supporting Types

public enum EvidenceViolationSeverity: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}



public enum EnforcementActionType: String, CaseIterable {
    case validation = "validation"
    case monitoring = "monitoring"
    case blocking = "blocking"
}

public enum EvidenceApprovalStatus: String, CaseIterable {
    case approved = "approved"
    case blocked = "blocked"
    case unknown = "unknown"
}

// MARK: - Error Types

enum CathedralSchemasError: Error, LocalizedError {
    case schemaCreationFailed(String)
    case tableCreationFailed(String)

    var errorDescription: String? {
        switch self {
        case .schemaCreationFailed(let reason):
            return "Schema creation failed: \(reason)"
        case .tableCreationFailed(let reason):
            return "Table creation failed: \(reason)"
        }
    }
}
