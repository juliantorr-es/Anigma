import Foundation
import DatabaseCore
import AnigmaCore

extension ContextumDatabase {
    public func queryEventsByRunID(runID: String) async throws -> [TelemetryEventComponent] {
        let rows = try await database.query(
            "SELECT * FROM contextum_events WHERE run_id = ? ORDER BY timestamp ASC;",
            parameters: [.text(runID)]
        )
        return rows.compactMap { row in
            guard let eventId = row.string(for: "event_id") else { return nil }
            let payloadJSON = row.string(for: "diagnostic_payload") ?? "{}"
            let payload = (try? JSONDecoder().decode([String: String].self, from: Data(payloadJSON.utf8))) ?? [:]

            return TelemetryEventComponent(
                eventId: eventId,
                eventType: TelemetryEventComponent.EventType(rawValue: row.string(for: "event_type") ?? "") ?? .system,
                agentId: row.string(for: "agent_id"),
                jobId: row.string(for: "job_id"),
                runId: row.string(for: "run_id"),
                receiptId: row.string(for: "receipt_id"),
                timestamp: Date(timeIntervalSince1970: TimeInterval(row.int(for: "timestamp") ?? 0)),
                durationMs: row.int(for: "duration_ms"),
                outcome: TelemetryEventComponent.Outcome(rawValue: row.string(for: "outcome") ?? "") ?? .success,
                errorCode: row.string(for: "error_code"),
                diagnosticPayload: payload
            )
        }
    }

    public func queryRollups(
        taxonomy: String,
        repoSizeBand: String?,
        since: Date
    ) async throws -> [AnalyticsRollupComponent] {
        let rows = try await database.query(
            """
            SELECT window_start, window_end, group_key_hash, rollup_spec_hash,
                   event_range_start, event_range_end, event_count, report_artifact_hash, receipt_id
            FROM contextum_analytics_rollups
            WHERE window_start >= ?
            ORDER BY window_start DESC;
            """,
            parameters: [.int(Int(since.timeIntervalSince1970))]
        )

        return rows.compactMap { row in
            guard let windowStart = row.int(for: "window_start"),
                  let windowEnd = row.int(for: "window_end"),
                  let groupKeyHash = row.string(for: "group_key_hash"),
                  let rollupSpecHash = row.string(for: "rollup_spec_hash"),
                  let eventRangeStart = row.int(for: "event_range_start"),
                  let eventRangeEnd = row.int(for: "event_range_end"),
                  let eventCount = row.int(for: "event_count"),
                  let reportArtifactHash = row.string(for: "report_artifact_hash"),
                  let receiptID = row.string(for: "receipt_id") else {
                return nil
            }

            return AnalyticsRollupComponent(
                windowStart: Date(timeIntervalSince1970: TimeInterval(windowStart)),
                windowEnd: Date(timeIntervalSince1970: TimeInterval(windowEnd)),
                groupKeyHash: groupKeyHash,
                rollupSpecHash: rollupSpecHash,
                eventRangeStart: Int64(eventRangeStart),
                eventRangeEnd: Int64(eventRangeEnd),
                eventCount: eventCount,
                reportArtifactHash: reportArtifactHash,
                receiptID: receiptID,
                agentID: nil,
                taxonomy: taxonomy,
                repoSizeBand: repoSizeBand
            )
        }
    }
}
