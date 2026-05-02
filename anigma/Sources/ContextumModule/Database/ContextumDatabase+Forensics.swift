import Foundation
import DatabaseCore
import AnigmaCore

public struct ReplayChunkLineageLinkRecord: Sendable {
    public let replayRunID: UUID
    public let chunkHash: String
    public let chunkID: String?
    public let sourceID: String?
    public let documentReplayHash: String?
    public let documentLineage: DocumentTruthLineage?
    public let sourceSectionPath: [String]
    public let sourceSectionTitle: String?
    public let sourcePageIndex: Int?
    public let linkedAt: Date
}

extension ContextumDatabase {
    public func insertFailureReport(_ report: FailureReportArtifact) async throws -> String {
        let json = (try? JSONEncoder().encode(report)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        let reportID = UUID().uuidString
        _ = try await database.executeAsync(
            """
            INSERT INTO failure_reports (
                report_id, receipt_id, run_id, report_artifact_json, created_at
            ) VALUES (?, ?, ?, ?, ?);
            """,
            parameters: [
                .text(reportID),
                .text(report.receiptID),
                .text(report.runID),
                .text(json),
                .int(Int(Date().timeIntervalSince1970))
            ]
        )
        return reportID
    }

    public func insertForensicsReport(_ component: ForensicsComponent) async throws {
        let subjectRunParam: DatabaseParameter = component.subjectRunID.map { .text($0.uuidString) } ?? .null
        let subjectWorkflowParam: DatabaseParameter = component.subjectWorkflowID.map { .text($0.uuidString) } ?? .null
        let reportHashParam: DatabaseParameter = component.reportArtifactHash.map { .text($0) } ?? .null

        _ = try await database.executeAsync(
            """
            INSERT INTO forensics_reports (
                reportID, subjectReceiptID, subjectRunID, subjectWorkflowID,
                investigationType, reportArtifactHash, created
            ) VALUES (?, ?, ?, ?, ?, ?, ?);
            """,
            parameters: [
                .text(component.reportID.uuidString),
                .text(component.subjectReceiptID),
                subjectRunParam,
                subjectWorkflowParam,
                .text(component.investigationType.rawValue),
                reportHashParam,
                .int(Int(Date().timeIntervalSince1970))
            ]
        )
    }

    public func insertReplayLinkage(
        _ linkage: ReplayLinkageComponent,
        chunkHashes: [String] = []
    ) async throws {
        _ = try await database.executeAsync(
            """
            INSERT OR REPLACE INTO replay_linkage (
                originalRunID, replayRunID, replayReceiptID, reconstructionMethod,
                corpusSnapshotHash, contextSetHash, created
            ) VALUES (?, ?, ?, ?, ?, ?, ?);
            """,
            parameters: [
                .text(linkage.originalRunID.uuidString),
                .text(linkage.replayRunID.uuidString),
                .text(linkage.replayReceiptID),
                .text(linkage.reconstructionMethod),
                linkage.corpusSnapshotHash.map { .text($0) } ?? .null,
                .text(linkage.contextSetHash),
                .int(Int(linkage.created.timeIntervalSince1970))
            ]
        )

        guard !chunkHashes.isEmpty else { return }
        let uniqueHashes = Array(Set(chunkHashes))
        let placeholders = uniqueHashes.map { _ in "?" }.joined(separator: ", ")
        let chunkRows = try await database.query(
            """
            SELECT content_hash, chunk_id, source_id, document_replay_hash,
                   document_lineage, source_section_path, source_section_title, source_page_index
            FROM contextum_chunks
            WHERE content_hash IN (\(placeholders));
            """,
            parameters: uniqueHashes.map { .text($0) }
        )

        let linkedAt = Int(Date().timeIntervalSince1970)
        for row in chunkRows {
            guard let chunkHash = row.string(for: "content_hash") else { continue }
            _ = try await database.executeAsync(
                """
                INSERT OR REPLACE INTO replay_chunk_lineage_links (
                    replayRunID, chunkHash, chunkID, sourceID, documentReplayHash,
                    documentLineage, sourceSectionPath, sourceSectionTitle, sourcePageIndex, linkedAt
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
                """,
                parameters: [
                    .text(linkage.replayRunID.uuidString),
                    .text(chunkHash),
                    row.string(for: "chunk_id").map { .text($0) } ?? .null,
                    row.string(for: "source_id").map { .text($0) } ?? .null,
                    row.string(for: "document_replay_hash").map { .text($0) } ?? .null,
                    row.string(for: "document_lineage").map { .text($0) } ?? .null,
                    row.string(for: "source_section_path").map { .text($0) } ?? .null,
                    row.string(for: "source_section_title").map { .text($0) } ?? .null,
                    row.int(for: "source_page_index").map { .int($0) } ?? .null,
                    .int(linkedAt)
                ]
            )
        }
    }

    public func queryReplayChunkLineageLinks(replayRunID: UUID) async throws -> [ReplayChunkLineageLinkRecord] {
        let rows = try await database.query(
            """
            SELECT l.replayRunID, l.chunkHash, l.chunkID, l.sourceID, l.documentReplayHash,
                   l.documentLineage, l.sourceSectionPath, l.sourceSectionTitle, l.sourcePageIndex, l.linkedAt,
                   r.originalRunID, r.reconstructionMethod, r.contextSetHash
            FROM replay_chunk_lineage_links l
            JOIN replay_linkage r ON r.replayRunID = l.replayRunID
            WHERE l.replayRunID = ?
            ORDER BY l.chunkHash ASC;
            """,
            parameters: [.text(replayRunID.uuidString)]
        )

        return rows.compactMap { row in
            guard let replayRunIDValue = row.string(for: "replayRunID"),
                  let replayRunID = UUID(uuidString: replayRunIDValue),
                  let chunkHash = row.string(for: "chunkHash") else {
                return nil
            }
            let lineage = row.string(for: "documentLineage").flatMap { Data($0.utf8) }.flatMap {
                try? JSONDecoder().decode(DocumentTruthLineage.self, from: $0)
            }
            let sectionPath = row.string(for: "sourceSectionPath").flatMap { Data($0.utf8) }.flatMap {
                try? JSONDecoder().decode([String].self, from: $0)
            } ?? []

            return ReplayChunkLineageLinkRecord(
                replayRunID: replayRunID,
                chunkHash: chunkHash,
                chunkID: row.string(for: "chunkID"),
                sourceID: row.string(for: "sourceID"),
                documentReplayHash: row.string(for: "documentReplayHash"),
                documentLineage: lineage,
                sourceSectionPath: sectionPath,
                sourceSectionTitle: row.string(for: "sourceSectionTitle"),
                sourcePageIndex: row.int(for: "sourcePageIndex"),
                linkedAt: Date(timeIntervalSince1970: TimeInterval(row.int(for: "linkedAt") ?? 0))
            )
        }
    }

    public func queryForensicsReport(receiptID: String) async throws -> ForensicsComponent? {
        let rows = try await database.query(
            "SELECT * FROM forensics_reports WHERE subjectReceiptID = ? LIMIT 1;",
            parameters: [.text(receiptID)]
        )
        guard let row = rows.first else { return nil }
        let subjectRunID = row.string(for: "subjectRunID").flatMap { UUID(uuidString: $0) }
        let subjectWorkflowID = row.string(for: "subjectWorkflowID").flatMap { UUID(uuidString: $0) }
        let investigationTypeRaw = row.string(for: "investigationType") ?? ""
        let investigationType = ForensicsComponent.InvestigationType(rawValue: investigationTypeRaw) ?? .failureReport
        let createdAt = Date(timeIntervalSince1970: TimeInterval(row.int(for: "created") ?? 0))

        return ForensicsComponent(
            reportID: UUID(uuidString: row.string(for: "reportID") ?? "") ?? UUID(),
            subjectReceiptID: row.string(for: "subjectReceiptID") ?? "",
            subjectRunID: subjectRunID,
            subjectWorkflowID: subjectWorkflowID,
            investigationType: investigationType,
            reportArtifactHash: row.string(for: "reportArtifactHash"),
            created: createdAt
        )
    }
}
