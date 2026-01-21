import Foundation
import DatabaseCore
import GRDB

extension ContextumDatabase {
    /// Create forensics tables for Phase 4
    static func createForensicsTables(_ db: GRDB.Database) throws {
        // Forensics reports
        try db.create(table: "forensics_reports", ifNotExists: true) { t in
            t.column("reportID", .text).notNull().primaryKey()
            t.column("subjectReceiptID", .text).notNull().indexed()
            t.column("subjectRunID", .text).indexed()
            t.column("subjectWorkflowID", .text).indexed()
            t.column("investigationType", .text).notNull()
            t.column("reportArtifactHash", .text).indexed()
            t.column("created", .datetime).notNull().indexed()
        }

        // Forensic evidence references
        try db.create(table: "forensic_evidence", ifNotExists: true) { t in
            t.column("reportID", .text).notNull().indexed()
            t.column("evidenceType", .text).notNull()
            t.column("referenceID", .text).notNull()
            t.column("evidenceHash", .text)
            t.column("description", .text)

            t.foreignKey(["reportID"], references: "forensics_reports", onDelete: .cascade)
        }
        try db.create(index: "idx_forensic_evidence_report", on: "forensic_evidence", columns: ["reportID"])

        // Root cause hypotheses
        try db.create(table: "root_cause_hypotheses", ifNotExists: true) { t in
            t.column("reportID", .text).notNull().indexed()
            t.column("hypothesisID", .text).notNull().primaryKey()
            t.column("hypothesisType", .text).notNull()
            t.column("ruleID", .text).notNull()
            t.column("ruleSpecHash", .text).notNull()
            t.column("evidenceReferences", .text).notNull()  // JSON array
            t.column("confidence", .text).notNull()
            t.column("explanation", .text).notNull()

            t.foreignKey(["reportID"], references: "forensics_reports", onDelete: .cascade)
        }

        // Replay linkage
        try db.create(table: "replay_linkage", ifNotExists: true) { t in
            t.column("originalRunID", .text).notNull().indexed()
            t.column("replayRunID", .text).notNull().primaryKey()
            t.column("replayReceiptID", .text).notNull().indexed()
            t.column("reconstructionMethod", .text).notNull()
            t.column("corpusSnapshotHash", .text)
            t.column("contextSetHash", .text).notNull()
            t.column("created", .datetime).notNull()
        }
        try db.create(index: "idx_replay_original", on: "replay_linkage", columns: ["originalRunID"])
    }
}
