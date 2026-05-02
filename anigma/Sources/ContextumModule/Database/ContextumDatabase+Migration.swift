import Foundation
import DatabaseCore
import AnigmaCore

extension ContextumDatabase {
    public func migrate() async throws {
        try await database.open()

        _ = try await database.executeAsync("""
            CREATE TABLE IF NOT EXISTS contextum_events (
                event_id TEXT PRIMARY KEY,
                event_type TEXT NOT NULL,
                agent_id TEXT,
                job_id TEXT,
                run_id TEXT,
                receipt_id TEXT,
                timestamp BIGINT NOT NULL,
                duration_ms BIGINT,
                outcome TEXT NOT NULL,
                error_code TEXT,
                diagnostic_payload JSONB NOT NULL
            );
            """)

        _ = try await database.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_events_job_id ON contextum_events(job_id);
            """)

        _ = try await database.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_events_agent_id ON contextum_events(agent_id);
            """)

        _ = try await database.executeAsync("""
            CREATE TABLE IF NOT EXISTS contextum_sources (
                source_id TEXT PRIMARY KEY,
                source_type TEXT NOT NULL,
                source_hash TEXT NOT NULL,
                artifact_hash TEXT NOT NULL,
                uri TEXT,
                canonical_ref TEXT,
                canonical_lane_ref TEXT,
                canonical_entity_id TEXT,
                current_hash TEXT NOT NULL DEFAULT '',
                revision BIGINT NOT NULL DEFAULT 1,
                mime_type TEXT,
                document_truth_format TEXT,
                document_truth_adapter TEXT,
                document_truth_manifest_hash TEXT,
                document_truth_replay_hash TEXT,
                document_truth_section_count BIGINT,
                document_truth_page_count BIGINT,
                discovered_at BIGINT NOT NULL DEFAULT 0,
                last_seen_at BIGINT NOT NULL DEFAULT 0,
                stale_at BIGINT,
                supersedes_source_id TEXT,
                superseded_by_source_id TEXT,
                supersession_root_source_id TEXT,
                supersession_depth BIGINT NOT NULL DEFAULT 0,
                conflict_status TEXT NOT NULL DEFAULT 'none',
                reingestion_policy TEXT NOT NULL DEFAULT 'onHashChange',
                confidence_score DOUBLE PRECISION NOT NULL DEFAULT 1.0,
                ingest_receipt_id TEXT,
                receipt_id TEXT NOT NULL,
                evidence_head_hash TEXT,
                timestamp BIGINT NOT NULL,
                metadata JSONB NOT NULL,
                UNIQUE(source_hash)
            );
            """)

        _ = try await database.executeAsync("""
            CREATE TABLE IF NOT EXISTS contextum_chunks (
                chunk_id TEXT PRIMARY KEY,
                source_id TEXT NOT NULL,
                source_hash TEXT,
                content_hash TEXT NOT NULL,
                chunk_hash TEXT NOT NULL,
                chunk_index BIGINT NOT NULL,
                total_chunks BIGINT NOT NULL,
                byte_range_start BIGINT NOT NULL,
                byte_range_end BIGINT NOT NULL,
                token_count BIGINT,
                receipt_id TEXT,
                created_receipt_id TEXT,
                evidence_head_hash TEXT,
                timestamp BIGINT NOT NULL,
                chunker_version BIGINT NOT NULL DEFAULT 1,
                chunker_params JSONB,
                confidence_score DOUBLE PRECISION NOT NULL DEFAULT 1.0,
                raw_artifact_hash TEXT,
                normalization_hash TEXT,
                chunker_config_hash TEXT,
                tokenizer_policy_hash TEXT,
                sanitizer_policy_hash TEXT,
                boundary_metadata JSONB,
                parent_chunk_id TEXT,
                child_chunk_id TEXT,
                page_index BIGINT,
                page_left DOUBLE PRECISION,
                page_top DOUBLE PRECISION,
                page_right DOUBLE PRECISION,
                page_bottom DOUBLE PRECISION,
                segment_type TEXT,
                layout_confidence DOUBLE PRECISION,
                document_lineage JSONB,
                source_section_path JSONB,
                source_section_title TEXT,
                document_adapter_id TEXT,
                document_replay_hash TEXT,
                source_page_index BIGINT,
                FOREIGN KEY (source_id) REFERENCES contextum_sources(source_id)
            );
            """)

        _ = try await database.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_sources_canonical_lane
            ON contextum_sources(source_type, canonical_ref, superseded_by_source_id);
            """)

        _ = try await database.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_sources_canonical_lane_ref
            ON contextum_sources(source_type, canonical_lane_ref, superseded_by_source_id);
            """)

        _ = try await database.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_sources_canonical_entity_id
            ON contextum_sources(canonical_entity_id);
            """)

        _ = try await database.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_chunks_source_id ON contextum_chunks(source_id);
            """)

        _ = try await database.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_chunks_hash ON contextum_chunks(chunk_hash);
            """)

        _ = try await database.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_chunks_content_hash ON contextum_chunks(content_hash);
            """)

        _ = try await database.executeAsync("""
            CREATE TABLE IF NOT EXISTS fts_chunks (
                chunk_id TEXT PRIMARY KEY,
                content TEXT,
                search_vector tsvector
            );
            """)

        _ = try await database.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_fts_chunks_search_vector ON fts_chunks USING GIN(search_vector);
            """)

        _ = try await database.executeAsync("""
            CREATE OR REPLACE FUNCTION fts_chunks_tsvector_trigger() RETURNS trigger AS $$
            BEGIN
                new.search_vector := to_tsvector('english', coalesce(new.content, ''));
                RETURN new;
            END
            $$ LANGUAGE plpgsql;
            """)

        _ = try await database.executeAsync("""
            DROP TRIGGER IF EXISTS trg_fts_chunks_tsvector_update ON fts_chunks;
            """)

        _ = try await database.executeAsync("""
            CREATE TRIGGER trg_fts_chunks_tsvector_update
            BEFORE INSERT OR UPDATE ON fts_chunks
            FOR EACH ROW EXECUTE FUNCTION fts_chunks_tsvector_trigger();
            """)

        _ = try await database.executeAsync("""
            CREATE TABLE IF NOT EXISTS contextum_embeddings (
                embedding_id TEXT PRIMARY KEY,
                chunk_hash TEXT NOT NULL,
                model_hash TEXT NOT NULL,
                model_id TEXT NOT NULL,
                vector_dimensions BIGINT NOT NULL,
                vector_blob BYTEA NOT NULL,
                vector vector(384), -- pgvector support
                vector_hash TEXT,
                receipt_id TEXT NOT NULL,
                created_receipt_id TEXT,
                evidence_head_hash TEXT,
                timestamp BIGINT NOT NULL,
                embedded_at BIGINT NOT NULL DEFAULT 0
            );
            """)

        // Attempt to create pgvector index if extension exists
        _ = try? await database.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_embeddings_vector_hnsw 
            ON contextum_embeddings USING hnsw (vector vector_cosine_ops);
            """)

        _ = try await database.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_embeddings_chunk_hash ON contextum_embeddings(chunk_hash);
            """)

        _ = try await database.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_embeddings_model_hash ON contextum_embeddings(model_hash);
            """)

        _ = try await database.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_embeddings_receipt_id ON contextum_embeddings(receipt_id);
            """)

        for (table, column, type) in [
            ("contextum_sources", "source_hash", "TEXT"),
            ("contextum_sources", "evidence_head_hash", "TEXT"),
            ("contextum_sources", "uri", "TEXT"),
            ("contextum_sources", "canonical_ref", "TEXT"),
            ("contextum_sources", "canonical_lane_ref", "TEXT"),
            ("contextum_sources", "canonical_entity_id", "TEXT"),
            ("contextum_sources", "current_hash", "TEXT NOT NULL DEFAULT ''"),
            ("contextum_sources", "revision", "BIGINT NOT NULL DEFAULT 1"),
            ("contextum_sources", "mime_type", "TEXT"),
            ("contextum_sources", "document_truth_format", "TEXT"),
            ("contextum_sources", "document_truth_adapter", "TEXT"),
            ("contextum_sources", "document_truth_manifest_hash", "TEXT"),
            ("contextum_sources", "document_truth_replay_hash", "TEXT"),
            ("contextum_sources", "document_truth_section_count", "BIGINT"),
            ("contextum_sources", "document_truth_page_count", "BIGINT"),
            ("contextum_sources", "discovered_at", "BIGINT NOT NULL DEFAULT 0"),
            ("contextum_sources", "last_seen_at", "BIGINT NOT NULL DEFAULT 0"),
            ("contextum_sources", "stale_at", "BIGINT"),
            ("contextum_sources", "supersedes_source_id", "TEXT"),
            ("contextum_sources", "superseded_by_source_id", "TEXT"),
            ("contextum_sources", "supersession_root_source_id", "TEXT"),
            ("contextum_sources", "supersession_depth", "BIGINT NOT NULL DEFAULT 0"),
            ("contextum_sources", "conflict_status", "TEXT NOT NULL DEFAULT 'none'"),
            ("contextum_sources", "reingestion_policy", "TEXT NOT NULL DEFAULT 'onHashChange'"),
            ("contextum_sources", "confidence_score", "DOUBLE PRECISION NOT NULL DEFAULT 1.0"),
            ("contextum_sources", "ingest_receipt_id", "TEXT"),
            ("contextum_chunks", "source_hash", "TEXT"),
            ("contextum_chunks", "chunk_hash", "TEXT"),
            ("contextum_chunks", "receipt_id", "TEXT"),
            ("contextum_chunks", "created_receipt_id", "TEXT"),
            ("contextum_chunks", "evidence_head_hash", "TEXT"),
            ("contextum_chunks", "chunker_version", "BIGINT NOT NULL DEFAULT 1"),
            ("contextum_chunks", "chunker_params", "JSONB"),
            ("contextum_chunks", "confidence_score", "DOUBLE PRECISION NOT NULL DEFAULT 1.0"),
            ("contextum_chunks", "raw_artifact_hash", "TEXT"),
            ("contextum_chunks", "normalization_hash", "TEXT"),
            ("contextum_chunks", "chunker_config_hash", "TEXT"),
            ("contextum_chunks", "tokenizer_policy_hash", "TEXT"),
            ("contextum_chunks", "sanitizer_policy_hash", "TEXT"),
            ("contextum_chunks", "boundary_metadata", "JSONB"),
            ("contextum_chunks", "parent_chunk_id", "TEXT"),
            ("contextum_chunks", "child_chunk_id", "TEXT"),
            ("contextum_chunks", "document_lineage", "JSONB"),
            ("contextum_chunks", "source_section_path", "JSONB"),
            ("contextum_chunks", "source_section_title", "TEXT"),
            ("contextum_chunks", "document_adapter_id", "TEXT"),
            ("contextum_chunks", "document_replay_hash", "TEXT"),
            ("contextum_chunks", "source_page_index", "BIGINT"),
            ("contextum_embeddings", "receipt_id", "TEXT"),
            ("contextum_embeddings", "created_receipt_id", "TEXT"),
            ("contextum_embeddings", "evidence_head_hash", "TEXT"),
            ("contextum_embeddings", "vector_hash", "TEXT"),
            ("contextum_embeddings", "embedded_at", "BIGINT NOT NULL DEFAULT 0")
        ] {
            try await addColumnIfMissing(table: table, column: column, type: type)
        }

        _ = try await database.executeAsync("""
            UPDATE contextum_sources
            SET canonical_lane_ref = LOWER(TRIM(canonical_ref))
            WHERE canonical_lane_ref IS NULL
              AND canonical_ref IS NOT NULL
              AND LOWER(TRIM(canonical_ref)) LIKE 'person://%';
            """)

        _ = try await database.executeAsync("""
            UPDATE contextum_sources
            SET canonical_lane_ref = canonical_ref
            WHERE canonical_lane_ref IS NULL
              AND canonical_ref IS NOT NULL;
            """)

        _ = try await database.executeAsync("""
            DROP VIEW IF EXISTS context_sources CASCADE;
            """)

        _ = try await database.executeAsync("""
            CREATE VIEW context_sources AS
            SELECT
                source_id,
                source_type,
                source_hash,
                artifact_hash,
                uri,
                canonical_ref,
                canonical_lane_ref,
                canonical_entity_id,
                current_hash,
                revision,
                mime_type,
                document_truth_format,
                document_truth_adapter,
                document_truth_manifest_hash,
                document_truth_replay_hash,
                document_truth_section_count,
                document_truth_page_count,
                discovered_at,
                last_seen_at,
                stale_at,
                supersedes_source_id,
                superseded_by_source_id,
                supersession_root_source_id,
                supersession_depth,
                conflict_status,
                reingestion_policy,
                confidence_score,
                ingest_receipt_id,
                receipt_id,
                evidence_head_hash,
                timestamp,
                metadata
            FROM contextum_sources;
            """)

        _ = try await database.executeAsync("""
            DROP VIEW IF EXISTS context_source_graph CASCADE;
            """)

        _ = try await database.executeAsync("""
            CREATE VIEW context_source_graph AS
            SELECT
                s.source_id,
                s.source_type,
                s.source_hash,
                s.artifact_hash AS source_artifact_hash,
                s.uri AS source_uri,
                s.canonical_ref AS source_canonical_ref,
                s.canonical_lane_ref AS source_canonical_lane_ref,
                s.canonical_entity_id AS source_canonical_entity_id,
                s.current_hash AS source_current_hash,
                s.revision AS source_revision,
                s.mime_type AS source_mime_type,
                s.document_truth_format AS source_document_truth_format,
                s.document_truth_adapter AS source_document_truth_adapter,
                s.document_truth_manifest_hash AS source_document_truth_manifest_hash,
                s.document_truth_replay_hash AS source_document_truth_replay_hash,
                s.document_truth_section_count AS source_document_truth_section_count,
                s.document_truth_page_count AS source_document_truth_page_count,
                s.discovered_at AS source_discovered_at,
                s.last_seen_at AS source_last_seen_at,
                s.stale_at AS source_stale_at,
                s.supersedes_source_id AS source_supersedes_source_id,
                s.superseded_by_source_id AS source_superseded_by_source_id,
                s.supersession_root_source_id AS source_supersession_root_source_id,
                s.supersession_depth AS source_supersession_depth,
                s.conflict_status AS source_conflict_status,
                s.reingestion_policy AS source_reingestion_policy,
                s.confidence_score AS source_confidence_score,
                s.ingest_receipt_id AS source_ingest_receipt_id,
                s.receipt_id AS source_receipt_id,
                s.evidence_head_hash AS source_evidence_head_hash,
                c.chunk_id,
                c.chunk_hash,
                c.content_hash,
                c.chunk_index,
                c.total_chunks,
                c.chunker_version,
                c.chunker_params,
                c.confidence_score AS chunk_confidence_score,
                c.raw_artifact_hash,
                c.normalization_hash,
                c.chunker_config_hash,
                c.tokenizer_policy_hash,
                c.sanitizer_policy_hash,
                c.boundary_metadata,
                c.parent_chunk_id,
                c.child_chunk_id,
                c.document_lineage,
                c.source_section_path,
                c.source_section_title,
                c.document_adapter_id,
                c.document_replay_hash,
                c.source_page_index,
                c.receipt_id AS chunk_receipt_id,
                c.created_receipt_id AS chunk_created_receipt_id,
                c.evidence_head_hash AS chunk_evidence_head_hash,
                e.embedding_id,
                e.model_id AS embedding_model_id,
                e.model_hash,
                e.vector_hash,
                e.embedded_at,
                e.receipt_id AS embedding_receipt_id,
                e.created_receipt_id AS embedding_created_receipt_id,
                e.evidence_head_hash AS embedding_evidence_head_hash
            FROM contextum_sources s
            LEFT JOIN contextum_chunks c ON c.source_id = s.source_id
            LEFT JOIN contextum_embeddings e ON e.chunk_hash = c.chunk_hash;
            """)

        _ = try await database.executeAsync("""
            CREATE TABLE IF NOT EXISTS contextum_agent_stats (
                agent_id TEXT NOT NULL,
                task_taxonomy TEXT NOT NULL,
                total_executions BIGINT NOT NULL DEFAULT 0,
                success_count BIGINT NOT NULL DEFAULT 0,
                failure_count BIGINT NOT NULL DEFAULT 0,
                avg_duration_ms DOUBLE PRECISION NOT NULL DEFAULT 0,
                p50_duration_ms DOUBLE PRECISION NOT NULL DEFAULT 0,
                p95_duration_ms DOUBLE PRECISION NOT NULL DEFAULT 0,
                last_executed BIGINT NOT NULL,
                failure_codes JSONB NOT NULL,
                PRIMARY KEY (agent_id, task_taxonomy)
            );
            """)

        _ = try await database.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_stats_agent_id ON contextum_agent_stats(agent_id);
            """)

        _ = try await database.executeAsync("""
            CREATE TABLE IF NOT EXISTS contextum_index_status (
                source_id TEXT NOT NULL,
                index_type TEXT NOT NULL,
                status TEXT NOT NULL,
                last_updated BIGINT NOT NULL,
                document_count BIGINT NOT NULL DEFAULT 0,
                error_message TEXT,
                PRIMARY KEY (source_id, index_type)
            );
            """)

        _ = try await database.executeAsync("""
            CREATE TABLE IF NOT EXISTS contextum_artifact_commits (
                id TEXT PRIMARY KEY,
                artifact_id TEXT NOT NULL,
                content_hash TEXT NOT NULL,
                source_hash TEXT NOT NULL,
                media_type TEXT NOT NULL,
                commit_receipt_id TEXT NOT NULL,
                chunker_version BIGINT NOT NULL,
                embedding_model_id TEXT,
                indexed BIGINT NOT NULL DEFAULT 0,
                committed_at BIGINT NOT NULL
            );
            """)

        _ = try await database.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_artifact_commits_content_hash
            ON contextum_artifact_commits(content_hash);
            """)

        _ = try await database.executeAsync("""
            CREATE TABLE IF NOT EXISTS contextum_index_states (
                id TEXT PRIMARY KEY,
                state_key TEXT NOT NULL UNIQUE,
                artifact_id TEXT NOT NULL,
                content_hash TEXT NOT NULL,
                chunker_version BIGINT NOT NULL,
                embedding_model_id TEXT,
                status TEXT NOT NULL,
                chunking_needed BIGINT NOT NULL,
                embedding_needed BIGINT NOT NULL,
                plan_recorded_at BIGINT NOT NULL,
                last_updated BIGINT NOT NULL
            );
            """)

        _ = try await database.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_index_states_status
            ON contextum_index_states(status);
            """)

        _ = try await database.executeAsync("""
            CREATE TABLE IF NOT EXISTS contextum_jobs (
                id TEXT PRIMARY KEY,
                kind TEXT NOT NULL,
                status TEXT NOT NULL,
                payload JSONB NOT NULL,
                correlation_id TEXT,
                created_at BIGINT NOT NULL,
                started_at BIGINT,
                completed_at BIGINT
            );
            """)

        _ = try await database.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_jobs_status
            ON contextum_jobs(status);
            """)

        _ = try await database.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_jobs_kind
            ON contextum_jobs(kind);
            """)

        _ = try await database.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_embeddings_composite
            ON contextum_embeddings(chunk_hash, model_id, model_hash);
            """)

        _ = try await database.executeAsync("""
            CREATE TABLE IF NOT EXISTS contextum_analytics_rollups (
                id TEXT PRIMARY KEY,
                window_start BIGINT NOT NULL,
                window_end BIGINT NOT NULL,
                group_key_hash TEXT NOT NULL,
                rollup_spec_hash TEXT NOT NULL,
                event_range_start BIGINT NOT NULL,
                event_range_end BIGINT NOT NULL,
                event_count BIGINT NOT NULL,
                report_artifact_hash TEXT NOT NULL,
                receipt_id TEXT NOT NULL,
                created_at BIGINT NOT NULL,
                UNIQUE(window_start, window_end, group_key_hash, rollup_spec_hash)
            );
            """)

        _ = try await database.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_rollups_window
            ON contextum_analytics_rollups(window_start, window_end);
            """)

        _ = try await database.executeAsync("""
            CREATE TABLE IF NOT EXISTS contextum_anomalies (
                id TEXT PRIMARY KEY,
                detector_id TEXT NOT NULL,
                window_start BIGINT NOT NULL,
                window_end BIGINT NOT NULL,
                group_key_hash TEXT NOT NULL,
                anomaly_spec_hash TEXT NOT NULL,
                subject_key TEXT NOT NULL,
                severity TEXT NOT NULL,
                evidence_rollup_ids JSONB NOT NULL,
                report_artifact_hash TEXT NOT NULL,
                receipt_id TEXT NOT NULL,
                detected_at BIGINT NOT NULL
            );
            """)

        _ = try await database.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_anomalies_detector
            ON contextum_anomalies(detector_id);
            """)

        _ = try await database.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_anomalies_window
            ON contextum_anomalies(window_start, window_end);
            """)

        _ = try await database.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_anomalies_severity
            ON contextum_anomalies(severity);
            """)

        // Phase 4: Forensics tables
        _ = try await database.executeAsync("""
            CREATE TABLE IF NOT EXISTS forensics_reports (
                reportID TEXT PRIMARY KEY,
                subjectReceiptID TEXT NOT NULL,
                subjectRunID TEXT,
                subjectWorkflowID TEXT,
                investigationType TEXT NOT NULL,
                reportArtifactHash TEXT,
                created BIGINT NOT NULL
            );
            """)

        _ = try await database.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_forensics_subject
            ON forensics_reports(subjectReceiptID);
            """)

        _ = try await database.executeAsync("""
            CREATE TABLE IF NOT EXISTS forensic_evidence (
                reportID TEXT NOT NULL,
                evidenceType TEXT NOT NULL,
                referenceID TEXT NOT NULL,
                evidenceHash TEXT,
                description TEXT,
                FOREIGN KEY (reportID) REFERENCES forensics_reports(reportID) ON DELETE CASCADE
            );
            """)

        _ = try await database.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_forensic_evidence_report
            ON forensic_evidence(reportID);
            """)

        _ = try await database.executeAsync("""
            CREATE TABLE IF NOT EXISTS failure_reports (
                report_id TEXT PRIMARY KEY,
                receipt_id TEXT NOT NULL,
                run_id TEXT NOT NULL,
                report_artifact_json JSONB NOT NULL,
                created_at BIGINT NOT NULL
            );
            """)

        _ = try await database.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_failure_reports_run
            ON failure_reports(run_id);
            """)

        _ = try await database.executeAsync("""
            CREATE TABLE IF NOT EXISTS root_cause_hypotheses (
                reportID TEXT NOT NULL,
                hypothesisID TEXT PRIMARY KEY,
                hypothesisType TEXT NOT NULL,
                ruleID TEXT NOT NULL,
                ruleSpecHash TEXT NOT NULL,
                evidenceReferences JSONB NOT NULL,
                confidence TEXT NOT NULL,
                explanation TEXT NOT NULL,
                FOREIGN KEY (reportID) REFERENCES forensics_reports(reportID) ON DELETE CASCADE
            );
            """)

        _ = try await database.executeAsync("""
            CREATE TABLE IF NOT EXISTS replay_linkage (
                originalRunID TEXT NOT NULL,
                replayRunID TEXT PRIMARY KEY,
                replayReceiptID TEXT NOT NULL,
                reconstructionMethod TEXT NOT NULL,
                corpusSnapshotHash TEXT,
                contextSetHash TEXT NOT NULL,
                created BIGINT NOT NULL
            );
            """)

        _ = try await database.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_replay_original
            ON replay_linkage(originalRunID);
            """)

        _ = try await database.executeAsync("""
            CREATE TABLE IF NOT EXISTS replay_chunk_lineage_links (
                replayRunID TEXT NOT NULL,
                chunkHash TEXT NOT NULL,
                chunkID TEXT,
                sourceID TEXT,
                documentReplayHash TEXT,
                documentLineage JSONB,
                sourceSectionPath JSONB,
                sourceSectionTitle TEXT,
                sourcePageIndex BIGINT,
                linkedAt BIGINT NOT NULL,
                PRIMARY KEY (replayRunID, chunkHash),
                FOREIGN KEY (replayRunID) REFERENCES replay_linkage(replayRunID) ON DELETE CASCADE
            );
            """)

        _ = try await database.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_replay_chunk_lineage_chunk_hash
            ON replay_chunk_lineage_links(chunkHash);
            """)

        // Phase 5: Feedback and recommendations tables
        _ = try await database.executeAsync("""
            CREATE TABLE IF NOT EXISTS feedback_votes (
                voteID TEXT PRIMARY KEY,
                receiptID TEXT NOT NULL,
                runID TEXT,
                rating TEXT NOT NULL,
                actorID TEXT NOT NULL,
                surfaceID TEXT,
                timestamp BIGINT NOT NULL,
                comment TEXT
            );
            """)

        _ = try await database.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_feedback_receipt
            ON feedback_votes(receiptID);
            """)

        _ = try await database.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_feedback_timestamp
            ON feedback_votes(timestamp);
            """)

        _ = try await database.executeAsync("""
            CREATE TABLE IF NOT EXISTS agent_recommendations (
                recommendationID TEXT PRIMARY KEY,
                taxonomy TEXT NOT NULL,
                repoSizeBand TEXT,
                trustTier TEXT,
                explanation TEXT NOT NULL,
                generatedAt BIGINT NOT NULL
            );
            """)

        _ = try await database.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_recommendations_taxonomy
            ON agent_recommendations(taxonomy);
            """)

        _ = try await database.executeAsync("""
            CREATE TABLE IF NOT EXISTS embedding_drift_events (
                driftID TEXT PRIMARY KEY,
                modelFromHash TEXT NOT NULL,
                modelToHash TEXT NOT NULL,
                corpusSnapshotHash TEXT NOT NULL,
                querySetHash TEXT NOT NULL,
                driftSpecHash TEXT NOT NULL,
                detectedAt BIGINT NOT NULL,
                metrics JSONB NOT NULL
            );
            """)

        _ = try await database.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_drift_models
            ON embedding_drift_events(modelFromHash, modelToHash);
            """)

        _ = try await database.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_drift_corpus
            ON embedding_drift_events(corpusSnapshotHash);
            """)

        // Initialize profile memory schema
        try await initializeProfileMemorySchema()
    }
}
