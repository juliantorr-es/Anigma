//
//  DoctrineMigrationIntegration.swift
//  HarmoniaModule
//
//  Integration between migration engine and concrete doctrine rules.
//

import AnigmaCore
import AnigmaPrimitives
import DatabaseCore
import DoctrineCore
import Foundation
import HarmoniaCore

/// Migration engine wrapper that checks doctrine compliance.
public final class DoctrineAwareMigrationEngineWrapper {
    private let baseEngine: any MigrationEngine
    private let lawComplianceScout: ConcreteLawComplianceScout
    private let violationStore: DoctrineViolationStore
    private let database: any DatabaseAuthority

    public init(
        baseEngine: any MigrationEngine,
        database: any DatabaseAuthority,
        lawComplianceScout: ConcreteLawComplianceScout = ConcreteLawComplianceScout(),
        violationStore: DoctrineViolationStore = try! DoctrineViolationStore()
    ) {
        self.baseEngine = baseEngine
        self.lawComplianceScout = lawComplianceScout
        self.violationStore = violationStore
        self.database = database
    }

    /// Process a migration task with doctrine checks.
    public func process(task: MigrationTaskRow, db: OpaquePointer?) async throws -> MigrationResult {
        let _ = db

        guard let finding = try await loadFinding(for: task) else {
            return .failed(errorDescription: "No scout finding found for task \(task.id)")
        }

        guard let filePath = finding.filePath else {
            return .skipped(reason: "No file path in finding")
        }

        let violations = try await lawComplianceScout.scan(fileAt: filePath)
        let blockingViolations = violations.filter { $0.severity == .critical }

        if !blockingViolations.isEmpty {
            for violation in violations {
                try violationStore.saveViolation(violation)
            }

            return .failed(
                errorDescription:
                    "Blocked by \(blockingViolations.count) critical doctrine violations. Fix debt tasks first."
            )
        }

        let result = try await baseEngine.process(task: task, db: nil)

        let nonBlockingViolations = violations.filter { $0.severity != .critical }
        for violation in nonBlockingViolations {
            try violationStore.saveViolation(violation)
        }

        return result
    }

    /// Load scout finding for a migration task.
    private func loadFinding(for task: MigrationTaskRow) async throws -> DoctrineScoutFinding? {
        guard let findingId = task.findingId else { return nil }

        let rows = try await database.query(
            """
            SELECT id, project_id, scout_id, title, description, problem_kind, file_path, line_number, metadata, created_at
            FROM scout_findings
            WHERE id = ?
            LIMIT 1
            """,
            parameters: [.text(findingId)]
        )

        guard let row = rows.first else {
            return nil
        }

        guard let id = row.string(for: "id"),
              let projectIdString = row.string(for: "project_id"),
              let projectId = UUID(uuidString: projectIdString) else {
            return nil
        }

        let metadataJSON = row.string(for: "metadata") ?? "{}"
        let metadata =
            (try? JSONSerialization.jsonObject(with: Data(metadataJSON.utf8), options: []))
            as? [String: Any] ?? [:]

        let createdAt = ISO8601DateFormatter().date(
            from: row.string(for: "created_at") ?? ""
        ) ?? Date()

        return DoctrineScoutFinding(
            id: id,
            projectId: projectId,
            scoutId: row.string(for: "scout_id") ?? "",
            title: row.string(for: "title") ?? "",
            description: row.string(for: "description") ?? "",
            problemKind: row.string(for: "problem_kind") ?? "",
            filePath: row.string(for: "file_path"),
            lineNumber: row.int(for: "line_number"),
            metadata: metadata,
            createdAt: createdAt
        )
    }
}

/// Factory for doctrine-aware migration engines.
public struct DoctrineAwareMigrationEngineFactory {
    public static func engine(
        for task: MigrationTaskRow,
        traceSink: MigrationTraceSink = NoopMigrationTraceSink()
    ) -> (any MigrationEngine)? {
        _ = task
        _ = traceSink
        return nil
    }
}
