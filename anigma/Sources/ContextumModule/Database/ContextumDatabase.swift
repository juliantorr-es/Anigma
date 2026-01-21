import Foundation
import DatabaseCore
import AnigmaCore
import CryptoKit

/// Configuration for inserting embeddings
public struct InsertEmbeddingConfiguration: Sendable {
    let embeddingId: String
    let chunkHash: String
    let modelHash: String
    let modelId: String
    let vectorDimensions: Int
    let vector: [Float]
    let receiptId: String
}

/// Configuration for inserting analytics rollups
public struct InsertAnalyticsRollupConfiguration: Sendable {
    let windowStart: Int64
    let windowEnd: Int64
    let groupKeyHash: String
    let rollupSpecHash: String
    let eventRangeStart: Int64
    let eventRangeEnd: Int64
    let eventCount: Int
    let reportArtifactHash: String
    let receiptID: String
}

/// Configuration for inserting anomalies
public struct InsertAnomalyConfiguration: Sendable {
    let detectorID: String
    let windowStart: Date
    let windowEnd: Date
    let groupKeyHash: String
    let anomalySpecHash: String
    let subjectKey: String
    let severity: Int
    let evidenceRollupIDs: [String]
    let reportArtifactHash: String
    let receiptID: String

    init(
        detectorID: String,
        windowStart: Date,
        windowEnd: Date,
        groupKeyHash: String,
        anomalySpecHash: String,
        subjectKey: String,
        severity: Int,
        evidenceRollupIDs: [String],
        reportArtifactHash: String,
        receiptID: String
    ) {
        self.detectorID = detectorID
        self.windowStart = windowStart
        self.windowEnd = windowEnd
        self.groupKeyHash = groupKeyHash
        self.anomalySpecHash = anomalySpecHash
        self.subjectKey = subjectKey
        self.severity = severity
        self.evidenceRollupIDs = evidenceRollupIDs
        self.reportArtifactHash = reportArtifactHash
        self.receiptID = receiptID
    }
}

public enum ContextumDatabaseError: Error {
    case missingEmbeddingParameters
    case invalidChunkData
    case embeddingDimensionMismatch
}

public actor ContextumDatabase {
    internal let dbActor: DatabaseAuthorityAdapter
    private let migrationVersion = 1
    internal var databasePath: String?  // Store path for size calculations (internal for CompactionSystem)

    internal let artifactAuthority: (any ArtifactAuthority)?
    
    public init(dbActor: DatabaseAuthorityAdapter) {
        self.dbActor = dbActor
        self.artifactAuthority = nil
    }
    
    public init(dbActor: DatabaseAuthorityAdapter, artifactAuthority: (any ArtifactAuthority)?) {
        self.dbActor = dbActor
        self.artifactAuthority = artifactAuthority
    }

    /// Set the database path for size calculations
    public func setDatabasePath(_ path: String) {
        self.databasePath = path
    }

    func storeContentAsArtifact(_ data: Data, mimeType: String = "text/plain", tags: [String] = [], metadata: [String: String] = [:]) async throws -> String {
        guard let authority = artifactAuthority else {
            // No artifact authority configured, skip artifact storage
            return ""
        }
        let hash = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
        let artifactId = ArtifactID(hash: hash)
        // Check if artifact already exists (optional optimization)
        // Create artifact object
        let artifact = Artifact(
            id: artifactId,
            mimeType: mimeType,
            size: Int64(data.count),
            createdAt: Date(),
            tags: tags,
            metadata: metadata,
            content: data
        )
        let systemContext = ExecutionContext(principal: .system)
        let (_, receipt) = try await authority.store(artifact, context: systemContext)
        // We can log receipt if needed
        return hash
    }
    
    public func migrate() async throws {
        try await dbActor.open()

        _ = try await dbActor.executeAsync("""
            CREATE TABLE IF NOT EXISTS contextum_events (
                event_id TEXT PRIMARY KEY,
                event_type TEXT NOT NULL,
                agent_id TEXT,
                job_id TEXT,
                run_id TEXT,
                receipt_id TEXT,
                timestamp INTEGER NOT NULL,
                duration_ms INTEGER,
                outcome TEXT NOT NULL,
                error_code TEXT,
                diagnostic_payload TEXT NOT NULL
            );
            """)

        _ = try await dbActor.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_events_job_id ON contextum_events(job_id);
            """)

        _ = try await dbActor.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_events_agent_id ON contextum_events(agent_id);
            """)

        _ = try await dbActor.executeAsync("""
            CREATE TABLE IF NOT EXISTS contextum_sources (
                source_id TEXT PRIMARY KEY,
                source_type TEXT NOT NULL,
                artifact_hash TEXT NOT NULL,
                receipt_id TEXT NOT NULL,
                timestamp INTEGER NOT NULL,
                metadata TEXT NOT NULL
            );
            """)

        _ = try await dbActor.executeAsync("""
            CREATE TABLE IF NOT EXISTS contextum_chunks (
                chunk_id TEXT PRIMARY KEY,
                source_id TEXT NOT NULL,
                content_hash TEXT NOT NULL,
                chunk_index INTEGER NOT NULL,
                total_chunks INTEGER NOT NULL,
                byte_range_start INTEGER NOT NULL,
                byte_range_end INTEGER NOT NULL,
                token_count INTEGER,
                timestamp INTEGER NOT NULL,
                page_index INTEGER,
                page_left REAL,
                page_top REAL,
                page_right REAL,
                page_bottom REAL,
                segment_type TEXT,
                layout_confidence REAL,
                FOREIGN KEY (source_id) REFERENCES contextum_sources(source_id)
            );
            """)

        _ = try await dbActor.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_chunks_source_id ON contextum_chunks(source_id);
            """)

        _ = try await dbActor.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_chunks_content_hash ON contextum_chunks(content_hash);
            """)

        _ = try await dbActor.executeAsync("""
            CREATE VIRTUAL TABLE IF NOT EXISTS fts_chunks USING fts5(
                chunk_id UNINDEXED,
                content
            );
            """)

        _ = try await dbActor.executeAsync("""
            CREATE TABLE IF NOT EXISTS contextum_embeddings (
                embedding_id TEXT PRIMARY KEY,
                chunk_hash TEXT NOT NULL,
                model_hash TEXT NOT NULL,
                model_id TEXT NOT NULL,
                vector_dimensions INTEGER NOT NULL,
                vector_blob BLOB NOT NULL,
                receipt_id TEXT NOT NULL,
                timestamp INTEGER NOT NULL
            );
            """)

        _ = try await dbActor.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_embeddings_chunk_hash ON contextum_embeddings(chunk_hash);
            """)

        _ = try await dbActor.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_embeddings_model_hash ON contextum_embeddings(model_hash);
            """)

        _ = try await dbActor.executeAsync("""
            CREATE TABLE IF NOT EXISTS contextum_agent_stats (
                agent_id TEXT NOT NULL,
                task_taxonomy TEXT NOT NULL,
                total_executions INTEGER NOT NULL DEFAULT 0,
                success_count INTEGER NOT NULL DEFAULT 0,
                failure_count INTEGER NOT NULL DEFAULT 0,
                avg_duration_ms REAL NOT NULL DEFAULT 0,
                p50_duration_ms REAL NOT NULL DEFAULT 0,
                p95_duration_ms REAL NOT NULL DEFAULT 0,
                last_executed INTEGER NOT NULL,
                failure_codes TEXT NOT NULL,
                PRIMARY KEY (agent_id, task_taxonomy)
            );
            """)

        _ = try await dbActor.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_stats_agent_id ON contextum_agent_stats(agent_id);
            """)

        _ = try await dbActor.executeAsync("""
            CREATE TABLE IF NOT EXISTS contextum_index_status (
                source_id TEXT NOT NULL,
                index_type TEXT NOT NULL,
                status TEXT NOT NULL,
                last_updated INTEGER NOT NULL,
                document_count INTEGER NOT NULL DEFAULT 0,
                error_message TEXT,
                PRIMARY KEY (source_id, index_type)
            );
            """)

        _ = try await dbActor.executeAsync("""
            CREATE TABLE IF NOT EXISTS contextum_artifact_commits (
                id TEXT PRIMARY KEY,
                artifact_id TEXT NOT NULL,
                content_hash TEXT NOT NULL,
                source_hash TEXT NOT NULL,
                media_type TEXT NOT NULL,
                commit_receipt_id TEXT NOT NULL,
                chunker_version INTEGER NOT NULL,
                embedding_model_id TEXT,
                indexed INTEGER NOT NULL DEFAULT 0,
                committed_at INTEGER NOT NULL
            );
            """)

        _ = try await dbActor.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_artifact_commits_content_hash
            ON contextum_artifact_commits(content_hash);
            """)

        _ = try await dbActor.executeAsync("""
            CREATE TABLE IF NOT EXISTS contextum_index_states (
                id TEXT PRIMARY KEY,
                state_key TEXT NOT NULL UNIQUE,
                artifact_id TEXT NOT NULL,
                content_hash TEXT NOT NULL,
                chunker_version INTEGER NOT NULL,
                embedding_model_id TEXT,
                status TEXT NOT NULL,
                chunking_needed INTEGER NOT NULL,
                embedding_needed INTEGER NOT NULL,
                plan_recorded_at INTEGER NOT NULL,
                last_updated INTEGER NOT NULL
            );
            """)

        _ = try await dbActor.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_index_states_status
            ON contextum_index_states(status);
            """)

        _ = try await dbActor.executeAsync("""
            CREATE TABLE IF NOT EXISTS contextum_jobs (
                id TEXT PRIMARY KEY,
                kind TEXT NOT NULL,
                status TEXT NOT NULL,
                payload TEXT NOT NULL,
                correlation_id TEXT,
                created_at INTEGER NOT NULL,
                started_at INTEGER,
                completed_at INTEGER
            );
            """)

        _ = try await dbActor.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_jobs_status
            ON contextum_jobs(status);
            """)

        _ = try await dbActor.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_jobs_kind
            ON contextum_jobs(kind);
            """)

        // Check if column exists before adding
        let tableInfo = try await dbActor.query("PRAGMA table_info(contextum_embeddings);")
        if !tableInfo.contains(where: { $0.string(for: "name") == "evidence_head_hash" }) {
            _ = try await dbActor.executeAsync("ALTER TABLE contextum_embeddings ADD COLUMN evidence_head_hash TEXT;")
        }

        _ = try await dbActor.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_embeddings_composite
            ON contextum_embeddings(chunk_hash, model_id, model_hash);
            """)

        _ = try await dbActor.executeAsync("""
            CREATE TABLE IF NOT EXISTS contextum_analytics_rollups (
                id TEXT PRIMARY KEY,
                window_start INTEGER NOT NULL,
                window_end INTEGER NOT NULL,
                group_key_hash TEXT NOT NULL,
                rollup_spec_hash TEXT NOT NULL,
                event_range_start INTEGER NOT NULL,
                event_range_end INTEGER NOT NULL,
                event_count INTEGER NOT NULL,
                report_artifact_hash TEXT NOT NULL,
                receipt_id TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                UNIQUE(window_start, window_end, group_key_hash, rollup_spec_hash)
            );
            """)

        _ = try await dbActor.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_rollups_window
            ON contextum_analytics_rollups(window_start, window_end);
            """)

        _ = try await dbActor.executeAsync("""
            CREATE TABLE IF NOT EXISTS contextum_anomalies (
                id TEXT PRIMARY KEY,
                detector_id TEXT NOT NULL,
                window_start INTEGER NOT NULL,
                window_end INTEGER NOT NULL,
                group_key_hash TEXT NOT NULL,
                anomaly_spec_hash TEXT NOT NULL,
                subject_key TEXT NOT NULL,
                severity TEXT NOT NULL,
                evidence_rollup_ids TEXT NOT NULL,
                report_artifact_hash TEXT NOT NULL,
                receipt_id TEXT NOT NULL,
                detected_at INTEGER NOT NULL
            );
            """)

        _ = try await dbActor.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_anomalies_detector
            ON contextum_anomalies(detector_id);
            """)

        _ = try await dbActor.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_anomalies_window
            ON contextum_anomalies(window_start, window_end);
            """)

        _ = try await dbActor.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_anomalies_severity
            ON contextum_anomalies(severity);
            """)

        // Phase 4: Forensics tables
        _ = try await dbActor.executeAsync("""
            CREATE TABLE IF NOT EXISTS forensics_reports (
                reportID TEXT PRIMARY KEY,
                subjectReceiptID TEXT NOT NULL,
                subjectRunID TEXT,
                subjectWorkflowID TEXT,
                investigationType TEXT NOT NULL,
                reportArtifactHash TEXT,
                created INTEGER NOT NULL
            );
            """)

        _ = try await dbActor.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_forensics_subject
            ON forensics_reports(subjectReceiptID);
            """)

        _ = try await dbActor.executeAsync("""
            CREATE TABLE IF NOT EXISTS forensic_evidence (
                reportID TEXT NOT NULL,
                evidenceType TEXT NOT NULL,
                referenceID TEXT NOT NULL,
                evidenceHash TEXT,
                description TEXT,
                FOREIGN KEY (reportID) REFERENCES forensics_reports(reportID) ON DELETE CASCADE
            );
            """)

        _ = try await dbActor.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_forensic_evidence_report
            ON forensic_evidence(reportID);
            """)

        _ = try await dbActor.executeAsync("""
            CREATE TABLE IF NOT EXISTS failure_reports (
                report_id TEXT PRIMARY KEY,
                receipt_id TEXT NOT NULL,
                run_id TEXT NOT NULL,
                report_artifact_json TEXT NOT NULL,
                created_at INTEGER NOT NULL
            );
            """)

        _ = try await dbActor.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_failure_reports_run
            ON failure_reports(run_id);
            """)

        _ = try await dbActor.executeAsync("""
            CREATE TABLE IF NOT EXISTS root_cause_hypotheses (
                reportID TEXT NOT NULL,
                hypothesisID TEXT PRIMARY KEY,
                hypothesisType TEXT NOT NULL,
                ruleID TEXT NOT NULL,
                ruleSpecHash TEXT NOT NULL,
                evidenceReferences TEXT NOT NULL,
                confidence TEXT NOT NULL,
                explanation TEXT NOT NULL,
                FOREIGN KEY (reportID) REFERENCES forensics_reports(reportID) ON DELETE CASCADE
            );
            """)

        _ = try await dbActor.executeAsync("""
            CREATE TABLE IF NOT EXISTS replay_linkage (
                originalRunID TEXT NOT NULL,
                replayRunID TEXT PRIMARY KEY,
                replayReceiptID TEXT NOT NULL,
                reconstructionMethod TEXT NOT NULL,
                corpusSnapshotHash TEXT,
                contextSetHash TEXT NOT NULL,
                created INTEGER NOT NULL
            );
            """)

        _ = try await dbActor.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_replay_original
            ON replay_linkage(originalRunID);
            """)

        // Phase 5: Feedback and recommendations tables
        _ = try await dbActor.executeAsync("""
            CREATE TABLE IF NOT EXISTS feedback_votes (
                voteID TEXT PRIMARY KEY,
                receiptID TEXT NOT NULL,
                runID TEXT,
                rating TEXT NOT NULL,
                actorID TEXT NOT NULL,
                surfaceID TEXT,
                timestamp INTEGER NOT NULL,
                comment TEXT
            );
            """)

        _ = try await dbActor.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_feedback_receipt
            ON feedback_votes(receiptID);
            """)

        _ = try await dbActor.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_feedback_timestamp
            ON feedback_votes(timestamp);
            """)

        _ = try await dbActor.executeAsync("""
            CREATE TABLE IF NOT EXISTS agent_recommendations (
                recommendationID TEXT PRIMARY KEY,
                taxonomy TEXT NOT NULL,
                repoSizeBand TEXT,
                trustTier TEXT,
                explanation TEXT NOT NULL,
                generatedAt INTEGER NOT NULL
            );
            """)

        _ = try await dbActor.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_recommendations_taxonomy
            ON agent_recommendations(taxonomy);
            """)

        _ = try await dbActor.executeAsync("""
            CREATE TABLE IF NOT EXISTS embedding_drift_events (
                driftID TEXT PRIMARY KEY,
                modelFromHash TEXT NOT NULL,
                modelToHash TEXT NOT NULL,
                corpusSnapshotHash TEXT NOT NULL,
                querySetHash TEXT NOT NULL,
                driftSpecHash TEXT NOT NULL,
                detectedAt INTEGER NOT NULL,
                metrics TEXT NOT NULL
            );
            """)

        _ = try await dbActor.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_drift_models
            ON embedding_drift_events(modelFromHash, modelToHash);
            """)

        _ = try await dbActor.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_drift_corpus
            ON embedding_drift_events(corpusSnapshotHash);
            """)
    }

    public func insertEvent(_ event: TelemetryEventComponent) async throws {
        let diagnosticJSON = try JSONEncoder().encode(event.diagnosticPayload)
        let diagnosticString = String(data: diagnosticJSON, encoding: .utf8) ?? "{}"

        let agentParam: DatabaseParameter = event.agentId.map { .text($0) } ?? .null
        let jobParam: DatabaseParameter = event.jobId.map { .text($0) } ?? .null
        let runParam: DatabaseParameter = event.runId.map { .text($0) } ?? .null
        let receiptParam: DatabaseParameter = event.receiptId.map { .text($0) } ?? .null
        let durationParam: DatabaseParameter = event.durationMs.map { .int(Int($0)) } ?? .null
        let errorParam: DatabaseParameter = event.errorCode.map { .text($0) } ?? .null

        _ = try await dbActor.executeAsync(
            """
            INSERT INTO contextum_events (
                event_id, event_type, agent_id, job_id, run_id, receipt_id,
                timestamp, duration_ms, outcome, error_code, diagnostic_payload
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """,
            parameters: [
                .text(event.eventId),
                .text(event.eventType.rawValue),
                agentParam,
                jobParam,
                runParam,
                receiptParam,
                .int(Int(event.timestamp.timeIntervalSince1970)),
                durationParam,
                .text(event.outcome.rawValue),
                errorParam,
                .text(diagnosticString)
            ]
        )
    }

    public func insertChunk(_ chunk: ChunkComponent, content: String, layoutMetadata: ChunkLayoutMetadata? = nil) async throws {
        let tokenParam: DatabaseParameter = chunk.tokenCount.map { .int(Int($0)) } ?? .null

        _ = try await dbActor.executeAsync(
            """
            INSERT INTO contextum_chunks (
                chunk_id, source_id, content_hash, chunk_index, total_chunks,
                byte_range_start, byte_range_end, token_count, timestamp,
                page_index, page_left, page_top, page_right, page_bottom,
                segment_type, layout_confidence
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """,
            parameters: [
                .text(chunk.chunkId),
                .text(chunk.sourceId),
                .text(chunk.contentHash),
                .int(Int(chunk.chunkIndex)),
                .int(Int(chunk.totalChunks)),
                .int(Int(chunk.byteRange.lowerBound)),
                .int(Int(chunk.byteRange.upperBound)),
                tokenParam,
                .int(Int(chunk.timestamp.timeIntervalSince1970)),
                layoutMetadata.map { .int($0.pageIndex) } ?? .null,
                layoutMetadata.map { .double($0.boundingBox[0]) } ?? .null,
                layoutMetadata.map { .double($0.boundingBox[1]) } ?? .null,
                layoutMetadata.map { .double($0.boundingBox[2]) } ?? .null,
                layoutMetadata.map { .double($0.boundingBox[3]) } ?? .null,
                layoutMetadata.map { .text($0.segmentType) } ?? .null,
                layoutMetadata.map { .double($0.confidence) } ?? .null
            ]
        )

        // Store chunk content as artifact via ArtifactAuthority if configured
        let contentData = Data(content.utf8)
        _ = try? await storeContentAsArtifact(contentData, mimeType: "text/plain", tags: ["chunk"], metadata: ["chunkId": chunk.chunkId, "sourceId": chunk.sourceId])

        _ = try await dbActor.executeAsync(
            "INSERT INTO fts_chunks (chunk_id, content) VALUES (?, ?);",
            parameters: [
                .text(chunk.chunkId),
                .text(content)
            ]
        )
    }

    public func insertEmbedding(config: InsertEmbeddingConfiguration) async throws {
        let vectorData = Data(bytes: config.vector, count: config.vector.count * MemoryLayout<Float>.size)

        _ = try await dbActor.executeAsync(
            """
            INSERT OR REPLACE INTO contextum_embeddings (
                embedding_id, chunk_hash, model_hash, model_id,
                vector_dimensions, vector_blob, receipt_id, timestamp
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
            """,
            parameters: [
                .text(config.embeddingId),
                .text(config.chunkHash),
                .text(config.modelHash),
                .text(config.modelId),
                .int(config.vector.count),
                .blob(vectorData),
                .text(config.receiptId),
                .int(Int(Date().timeIntervalSince1970))
            ]
        )
    }

    public func searchFullText(query: String, limit: Int = 20) async throws -> [String] {
        let rows = try await dbActor.query(
            "SELECT chunk_id FROM fts_chunks WHERE content MATCH ? LIMIT ?;",
            parameters: [
                .text(query),
                .int(Int(limit))
            ]
        )

        return rows.compactMap { $0.string(for: "chunk_id") }
    }

    public func getChunkContent(chunkIds: [String]) async throws -> [HybridSearchSystem.SearchResultChunk] {
        guard !chunkIds.isEmpty else { return [] }

        let placeholders = chunkIds.map { _ in "?" }.joined(separator: ", ")
        let query = """
            SELECT c.chunk_id, c.source_id, f.content
            FROM contextum_chunks c
            JOIN fts_chunks f ON c.chunk_id = f.chunk_id
            WHERE c.chunk_id IN (\(placeholders));
            """

        let rows = try await dbActor.query(
            query,
            parameters: chunkIds.map { .text($0) }
        )

        return rows.compactMap { row in
            guard let chunkId = row.string(for: "chunk_id"),
                  let sourceId = row.string(for: "source_id"),
                  let content = row.string(for: "content") else {
                return nil
            }
            return HybridSearchSystem.SearchResultChunk(
                chunkId: chunkId,
                content: content,
                sourceId: sourceId,
                score: nil
            )
        }
    }

    public func getAgentStats(agentId: String, taskTaxonomy: String) async throws -> AgentStatsComponent? {
        let rows = try await dbActor.query(
            """
            SELECT total_executions, success_count, failure_count,
                   avg_duration_ms, p50_duration_ms, p95_duration_ms,
                   last_executed, failure_codes
            FROM contextum_agent_stats
            WHERE agent_id = ? AND task_taxonomy = ?;
            """,
            parameters: [
                .text(agentId),
                .text(taskTaxonomy)
            ]
        )

        guard let row = rows.first else { return nil }

        let totalExec = row.int(for: "total_executions") ?? 0
        let successCount = row.int(for: "success_count") ?? 0
        let failureCount = row.int(for: "failure_count") ?? 0
        let avgDur = row.double(for: "avg_duration_ms") ?? 0
        let p50 = row.double(for: "p50_duration_ms") ?? 0
        let p95 = row.double(for: "p95_duration_ms") ?? 0
        let lastExec = row.int64(for: "last_executed") ?? 0
        let codesJSON = row.string(for: "failure_codes") ?? "{}"

        // Decode failure codes with error logging
        let codes: [String: Int]
        do {
            codes = try JSONDecoder().decode([String: Int].self, from: Data(codesJSON.utf8))
        } catch {
            print("⚠️ [ContextumDB] Failed to decode failure codes for agent '\(agentId)': \(error)")
            codes = [:]
        }

        return AgentStatsComponent(
            agentId: agentId,
            taskTaxonomy: taskTaxonomy,
            totalExecutions: totalExec,
            successCount: successCount,
            failureCount: failureCount,
            avgDurationMs: avgDur,
            p50DurationMs: p50,
            p95DurationMs: p95,
            lastExecuted: Date(timeIntervalSince1970: TimeInterval(lastExec)),
            failureCodes: codes
        )
    }

    public func getChunkContentByHash(chunkHashes: [String]) async throws -> [(chunkId: String, chunkHash: String, content: String, sourceId: String)] {
        guard !chunkHashes.isEmpty else { return [] }

        let placeholders = chunkHashes.map { _ in "?" }.joined(separator: ", ")
        let query = """
            SELECT c.chunk_id, c.content_hash, c.source_id, f.content
            FROM contextum_chunks c
            JOIN fts_chunks f ON c.chunk_id = f.chunk_id
            WHERE c.content_hash IN (\(placeholders));
            """

        let rows = try await dbActor.query(
            query,
            parameters: chunkHashes.map { .text($0) }
        )

        return rows.compactMap { row in
            guard let chunkId = row.string(for: "chunk_id"),
                  let chunkHash = row.string(for: "content_hash"),
                  let sourceId = row.string(for: "source_id"),
                  let content = row.string(for: "content") else {
                return nil
            }
            return (chunkId, chunkHash, content, sourceId)
        }
    }

    public func getChunkHashToIdMap(chunkHashes: [String]) async throws -> [String: String] {
        guard !chunkHashes.isEmpty else { return [:] }

        let placeholders = chunkHashes.map { _ in "?" }.joined(separator: ", ")
        let query = """
            SELECT chunk_id, content_hash
            FROM contextum_chunks
            WHERE content_hash IN (\(placeholders));
            """

        let rows = try await dbActor.query(
            query,
            parameters: chunkHashes.map { .text($0) }
        )

        var mapping: [String: String] = [:]
        for row in rows {
            if let chunkId = row.string(for: "chunk_id"),
               let chunkHash = row.string(for: "content_hash") {
                mapping[chunkHash] = chunkId
            }
        }
        return mapping
    }

    public func searchSpatialWithScore(
        pageIndex: Int?,
        boundingBox: (left: Double, top: Double, right: Double, bottom: Double)?,
        limit: Int
    ) async throws -> [(chunkId: String, score: Double)] {
        var query = "SELECT chunk_id, 1.0 as score FROM contextum_chunks WHERE 1=1"
        var parameters: [DatabaseParameter] = []
        
        if let pageIndex = pageIndex {
            query += " AND page_index = ?"
            parameters.append(.int(pageIndex))
        }
        
        if let bbox = boundingBox {
            query += " AND page_left >= ? AND page_top >= ? AND page_right <= ? AND page_bottom <= ?"
            parameters.append(.double(bbox.left))
            parameters.append(.double(bbox.top))
            parameters.append(.double(bbox.right))
            parameters.append(.double(bbox.bottom))
        }
        
        query += " ORDER BY score DESC LIMIT ?"
        parameters.append(.int(limit))
        
        let rows = try await dbActor.query(query, parameters: parameters)
        
        return rows.compactMap { row in
            guard let chunkId = row.string(for: "chunk_id"),
                  let score = row.double(for: "score") else {
                return nil
            }
            return (chunkId: chunkId, score: score)
        }
    }

    // MARK: - Missing Methods for Workflows and Ingestion

    public func insertArtifactCommit(_ commit: ArtifactCommitComponent) async throws {
        let sql = """
            INSERT INTO contextum_artifact_commits (
                id, artifact_id, content_hash, source_hash, media_type,
                commit_receipt_id, chunker_version, embedding_model_id,
                indexed, committed_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
        
        let id = DatabaseParameter.text(commit.commitReceiptID)
        let artifact_id = DatabaseParameter.text(commit.artifactID)
        let content_hash = DatabaseParameter.text(commit.contentHash)
        let source_hash = DatabaseParameter.text(commit.sourceHash)
        let media_type = DatabaseParameter.text(commit.mediaType)
        let commit_receipt_id = DatabaseParameter.text(commit.commitReceiptID)
        let chunker_version = DatabaseParameter.int(Int(commit.chunkerVersion))
        let embedding_model_id = commit.embeddingModelID.map { DatabaseParameter.text($0) } ?? .null
        let indexed = DatabaseParameter.int(commit.indexed ? 1 : 0)
        let committed_at = DatabaseParameter.int(Int(commit.committedAt.timeIntervalSince1970))
        
        let parameters: [DatabaseParameter] = [
            id, artifact_id, content_hash, source_hash, media_type,
            commit_receipt_id, chunker_version, embedding_model_id,
            indexed, committed_at
        ]
        
        _ = try await dbActor.executeAsync(sql, parameters: parameters)
    }

    public func getSource(artifactHash: String) async throws -> ContextSourceComponent? {
        let rows = try await dbActor.query(
            "SELECT * FROM contextum_sources WHERE artifact_hash = ? LIMIT 1;",
            parameters: [.text(artifactHash)]
        )
        guard let row = rows.first else { return nil }
        
        let metadataJSON = row.string(for: "metadata") ?? "{}"
        let metadata = (try? JSONDecoder().decode([String: String].self, from: Data(metadataJSON.utf8))) ?? [:]
        
        return ContextSourceComponent(
            sourceId: row.string(for: "source_id") ?? "",
            sourceType: ContextSourceComponent.SourceType(rawValue: row.string(for: "source_type") ?? "") ?? .document,
            artifactHash: row.string(for: "artifact_hash") ?? "",
            receiptId: row.string(for: "receipt_id") ?? "",
            timestamp: Date(timeIntervalSince1970: TimeInterval(row.int(for: "timestamp") ?? 0)),
            metadata: metadata
        )
    }

    public func insertSource(_ source: ContextSourceComponent) async throws {
        let metadataJSON = (try? JSONEncoder().encode(source.metadata)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        
        _ = try await dbActor.executeAsync(
            """
            INSERT INTO contextum_sources (
                source_id, source_type, artifact_hash, receipt_id, timestamp, metadata
            ) VALUES (?, ?, ?, ?, ?, ?);
            """,
            parameters: [
                .text(source.sourceId),
                .text(source.sourceType.rawValue),
                .text(source.artifactHash),
                .text(source.receiptId),
                .int(Int(source.timestamp.timeIntervalSince1970)),
                .text(metadataJSON)
            ]
        )
    }

    public func getChunksByContentHash(contentHash: String) async throws -> [ChunkComponent] {
        let rows = try await dbActor.query(
            "SELECT * FROM contextum_chunks WHERE content_hash = ?;",
            parameters: [.text(contentHash)]
        )
        return rows.compactMap { row in
            guard let chunkId = row.string(for: "chunk_id") else { return nil }
            return ChunkComponent(
                chunkId: chunkId,
                sourceId: row.string(for: "source_id") ?? "",
                contentHash: row.string(for: "content_hash") ?? "",
                chunkIndex: row.int(for: "chunk_index") ?? 0,
                totalChunks: row.int(for: "total_chunks") ?? 0,
                byteRange: (row.int(for: "byte_range_start") ?? 0)..<(row.int(for: "byte_range_end") ?? 0),
                tokenCount: row.int(for: "token_count"),
                timestamp: Date(timeIntervalSince1970: TimeInterval(row.int(for: "timestamp") ?? 0))
            )
        }
    }

    public func insertIndexStatus(_ status: IndexStatusComponent) async throws {
        _ = try await dbActor.executeAsync(
            """
            INSERT OR REPLACE INTO contextum_index_status (
                source_id, index_type, status, last_updated, document_count, error_message
            ) VALUES (?, ?, ?, ?, ?, ?);
            """,
            parameters: [
                .text(status.sourceId),
                .text(status.indexType.rawValue),
                .text(status.status.rawValue),
                .int(Int(status.lastUpdated.timeIntervalSince1970)),
                .int(Int(status.documentCount)),
                status.errorMessage.map { .text($0) } ?? .null
            ]
        )
    }

    public func searchFullTextWithSpatial(
        query: String,
        pageIndex: Int?,
        boundingBox: (left: Double, top: Double, right: Double, bottom: Double)?,
        limit: Int
    ) async throws -> [String] {
        // Simple implementation merging FTS and spatial if possible
        // Real implementation would use more complex joins or vector-spatial extensions
        let ftsIds = try await searchFullText(query: query, limit: limit * 2)
        if ftsIds.isEmpty { return [] }
        
        let placeholders = ftsIds.map { _ in "?" }.joined(separator: ", ")
        var sql = "SELECT chunk_id FROM contextum_chunks WHERE chunk_id IN (\(placeholders))"
        var params = ftsIds.map { DatabaseParameter.text($0) }
        
        if let pageIndex = pageIndex {
            sql += " AND page_index = ?"
            params.append(.int(pageIndex))
        }

        if let bbox = boundingBox {
            sql += " AND page_left >= ? AND page_top >= ? AND page_right <= ? AND page_bottom <= ?"
            params.append(.double(bbox.left))
            params.append(.double(bbox.top))
            params.append(.double(bbox.right))
            params.append(.double(bbox.bottom))
        }
        
        sql += " LIMIT ?;"
        params.append(.int(limit))
        
        let rows = try await dbActor.query(sql, parameters: params)
        return rows.compactMap { row in row.string(for: "chunk_id") }
    }

    public func filterChunksBySpatial(
        chunkIds: [String],
        pageIndex: Int?,
        boundingBox: (left: Double, top: Double, right: Double, bottom: Double)?,
        limit: Int? = nil
    ) async throws -> [String] {
        if chunkIds.isEmpty { return [] }
        
        let placeholders = chunkIds.map { _ in "?" }.joined(separator: ", ")
        var sql = "SELECT chunk_id FROM contextum_chunks WHERE chunk_id IN (\(placeholders))"
        var params = chunkIds.map { DatabaseParameter.text($0) }
        
        if let pageIndex = pageIndex {
            sql += " AND page_index = ?"
            params.append(.int(pageIndex))
        }

        if let bbox = boundingBox {
            sql += " AND page_left >= ? AND page_top >= ? AND page_right <= ? AND page_bottom <= ?"
            params.append(.double(bbox.left))
            params.append(.double(bbox.top))
            params.append(.double(bbox.right))
            params.append(.double(bbox.bottom))
        }

        if let limit = limit {
            sql += " LIMIT ?;"
            params.append(.int(limit))
        }
        
        let rows = try await dbActor.query(sql, parameters: params)
        return rows.compactMap { row in row.string(for: "chunk_id") }
    }

    public func queryEventsByRunID(runID: String) async throws -> [TelemetryEventComponent] {
        let rows = try await dbActor.query(
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
        let rows = try await dbActor.query(
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

    public func insertFailureReport(_ report: FailureReportArtifact) async throws -> String {
        let json = (try? JSONEncoder().encode(report)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        let reportID = UUID().uuidString
        _ = try await dbActor.executeAsync(
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

        _ = try await dbActor.executeAsync(
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

    public func insertReplayLinkage(_ linkage: ReplayLinkageComponent) async throws {
        _ = try await dbActor.executeAsync(
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
    }

    public func queryForensicsReport(receiptID: String) async throws -> ForensicsComponent? {
        let rows = try await dbActor.query(
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

    public func getChunksByHash(chunkHashes: [String]) async throws -> [ChunkComponent] {
        if chunkHashes.isEmpty { return [] }
        let placeholders = chunkHashes.map { _ in "?" }.joined(separator: ", ")
        let rows = try await dbActor.query(
            "SELECT * FROM contextum_chunks WHERE content_hash IN (\(placeholders));",
            parameters: chunkHashes.map { .text($0) }
        )
        return rows.compactMap { row in
            guard let chunkId = row.string(for: "chunk_id") else { return nil }
            return ChunkComponent(
                chunkId: chunkId,
                sourceId: row.string(for: "source_id") ?? "",
                contentHash: row.string(for: "content_hash") ?? "",
                chunkIndex: row.int(for: "chunk_index") ?? 0,
                totalChunks: row.int(for: "total_chunks") ?? 0,
                byteRange: (row.int(for: "byte_range_start") ?? 0)..<(row.int(for: "byte_range_end") ?? 0),
                tokenCount: row.int(for: "token_count"),
                timestamp: Date(timeIntervalSince1970: TimeInterval(row.int(for: "timestamp") ?? 0))
            )
        }
    }
}
