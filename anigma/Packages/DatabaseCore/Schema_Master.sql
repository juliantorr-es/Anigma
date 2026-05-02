//
//  DatabaseSchema.sql
//  DatabaseCore
//
//  Schema for master + session database architecture.
//  Supports append-only facts + recomputed views.
//

-- Master database schema (append-only source of truth)

-- Session lifecycle tracking
CREATE TABLE IF NOT EXISTS session_lifecycle (
    session_id TEXT PRIMARY KEY,
    agent_id TEXT NOT NULL,
    start_time INTEGER NOT NULL,
    end_time INTEGER,
    status TEXT NOT NULL DEFAULT 'active',
    permissions TEXT,
    metadata TEXT,
    termination_reason TEXT
);

-- Evidence chain (append-only)
CREATE TABLE IF NOT EXISTS evidence_chain (
    evidence_id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    agent_id TEXT NOT NULL,
    tool_name TEXT NOT NULL,
    request_id TEXT NOT NULL,
    parameters TEXT,
    file_path TEXT,
    content_hash TEXT,
    start_time INTEGER NOT NULL,
    end_time INTEGER,
    status TEXT NOT NULL DEFAULT 'started',
    result TEXT,
    error TEXT,
    error_details TEXT,
    FOREIGN KEY (session_id) REFERENCES session_lifecycle(session_id)
);

-- Tool-specific results tables

-- Edit results
CREATE TABLE IF NOT EXISTS edit_results (
    evidence_id TEXT PRIMARY KEY,
    success BOOLEAN NOT NULL,
    changes_count INTEGER NOT NULL DEFAULT 0,
    new_file_hash TEXT,
    applied_diff TEXT,
    FOREIGN KEY (evidence_id) REFERENCES evidence_chain(evidence_id)
);

-- File changes (detailed tracking)
CREATE TABLE IF NOT EXISTS file_changes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    evidence_id TEXT NOT NULL,
    change_index INTEGER NOT NULL,
    change_type TEXT NOT NULL,
    start_offset INTEGER NOT NULL,
    end_offset INTEGER NOT NULL,
    old_content TEXT,
    new_content TEXT,
    FOREIGN KEY (evidence_id) REFERENCES evidence_chain(evidence_id)
);

-- Read results
CREATE TABLE IF NOT EXISTS read_results (
    evidence_id TEXT PRIMARY KEY,
    file_size INTEGER NOT NULL,
    file_hash TEXT,
    last_modified INTEGER NOT NULL,
    permissions_readable BOOLEAN,
    permissions_writable BOOLEAN,
    permissions_executable BOOLEAN,
    FOREIGN KEY (evidence_id) REFERENCES evidence_chain(evidence_id)
);

-- Build results
CREATE TABLE IF NOT EXISTS build_results (
    evidence_id TEXT PRIMARY KEY,
    target TEXT NOT NULL,
    configuration TEXT NOT NULL,
    exit_code INTEGER,
    duration_ms INTEGER,
    artifact_path TEXT,
    errors_count INTEGER DEFAULT 0,
    warnings_count INTEGER DEFAULT 0,
    FOREIGN KEY (evidence_id) REFERENCES evidence_chain(evidence_id)
);

-- Test results
CREATE TABLE IF NOT EXISTS test_results (
    evidence_id TEXT PRIMARY KEY,
    test_suite TEXT NOT NULL,
    tests_run INTEGER DEFAULT 0,
    tests_passed INTEGER DEFAULT 0,
    tests_failed INTEGER DEFAULT 0,
    tests_skipped INTEGER DEFAULT 0,
    duration_ms INTEGER,
    FOREIGN KEY (evidence_id) REFERENCES evidence_chain(evidence_id)
);

-- Content-addressed artifact store for deduplication
CREATE TABLE IF NOT EXISTS artifacts (
    artifact_hash TEXT PRIMARY KEY,
    algorithm TEXT NOT NULL DEFAULT 'sha256',
    version INTEGER NOT NULL DEFAULT 1,
    byte_length INTEGER NOT NULL,
    compression_type TEXT,
    compressed_length INTEGER,
    stored_at INTEGER NOT NULL,
    last_referenced_at INTEGER,
    reference_count INTEGER DEFAULT 0,
    payload BLOB,
    CHECK (byte_length > 0),
    CHECK (compressed_length IS NULL OR compressed_length > 0)
);

-- Evidence to artifact references (many-to-many)
CREATE TABLE IF NOT EXISTS evidence_artifacts (
    evidence_id TEXT NOT NULL,
    artifact_hash TEXT NOT NULL,
    reference_type TEXT NOT NULL, -- 'result', 'parameter', 'diff', etc.
    created_at INTEGER NOT NULL,
    PRIMARY KEY (evidence_id, artifact_hash),
    FOREIGN KEY (evidence_id) REFERENCES evidence_chain(evidence_id),
    FOREIGN KEY (artifact_hash) REFERENCES artifacts(artifact_hash)
);

-- Source graph for assistant context
CREATE TABLE IF NOT EXISTS context_sources (
    source_id TEXT PRIMARY KEY,
    source_type TEXT NOT NULL,
    source_hash TEXT NOT NULL UNIQUE,
    artifact_hash TEXT NOT NULL,
    uri TEXT,
    canonical_ref TEXT,
    current_hash TEXT NOT NULL DEFAULT '',
    revision INTEGER NOT NULL DEFAULT 1,
    mime_type TEXT,
    discovered_at INTEGER NOT NULL DEFAULT 0,
    last_seen_at INTEGER NOT NULL DEFAULT 0,
    stale_at INTEGER,
    confidence_score REAL NOT NULL DEFAULT 1.0,
    ingest_receipt_id TEXT,
    receipt_id TEXT NOT NULL,
    evidence_head_hash TEXT,
    timestamp INTEGER NOT NULL,
    metadata TEXT
);

-- Retention events (append-only audit trail)
CREATE TABLE IF NOT EXISTS retention_events (
    event_id TEXT PRIMARY KEY,
    policy_hash TEXT NOT NULL,
    policy_version TEXT NOT NULL,
    event_type TEXT NOT NULL, -- 'gc_run', 'session_cleanup', 'policy_expiry'
    started_at INTEGER NOT NULL,
    completed_at INTEGER NOT NULL,
    artifacts_deleted INTEGER DEFAULT 0,
    artifacts_freed_bytes INTEGER DEFAULT 0,
    sessions_deleted INTEGER DEFAULT 0,
    affected_artifact_hashes TEXT, -- JSON array of deleted artifact hashes
    retention_summary TEXT, -- JSON summary of what was cleaned up
    created_by TEXT NOT NULL DEFAULT 'harmonia-gc'
);

-- Derived views (recomputed, not merged)

-- Session status view
CREATE TABLE IF NOT EXISTS session_status_view (
    session_id TEXT PRIMARY KEY,
    last_activity INTEGER NOT NULL,
    tool_calls INTEGER DEFAULT 0,
    errors INTEGER DEFAULT 0,
    success_rate REAL DEFAULT 0.0
);

-- Document chunks for FTS indexing
CREATE TABLE IF NOT EXISTS document_chunks (
    chunk_id TEXT PRIMARY KEY,
    source_id TEXT,
    source_hash TEXT,
    document_path TEXT NOT NULL,
    chunk_index INTEGER NOT NULL,
    chunk_text TEXT NOT NULL,
    chunk_hash TEXT NOT NULL,
    chunker_version INTEGER NOT NULL DEFAULT 1,
    chunker_params TEXT,
    confidence_score REAL NOT NULL DEFAULT 1.0,
    created_receipt_id TEXT,
    created_at INTEGER NOT NULL,
    section_title TEXT,
    section_level INTEGER,
    character_offset INTEGER,
    byte_offset INTEGER,
    byte_length INTEGER NOT NULL,
    FOREIGN KEY (source_id) REFERENCES context_sources(source_id),
    FOREIGN KEY (chunk_hash) REFERENCES artifacts(artifact_hash)
);

-- Embeddings table keyed by chunk
CREATE TABLE IF NOT EXISTS embeddings (
    embedding_id TEXT PRIMARY KEY,
    chunk_id TEXT NOT NULL,
    model_id TEXT NOT NULL,
    vector BLOB NOT NULL,
    dimension_count INTEGER NOT NULL,
    vector_hash TEXT,
    embedded_at INTEGER NOT NULL DEFAULT 0,
    created_receipt_id TEXT,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (chunk_id) REFERENCES document_chunks(chunk_id)
);

CREATE INDEX IF NOT EXISTS idx_context_sources_hash ON context_sources(source_hash);
CREATE INDEX IF NOT EXISTS idx_document_chunks_source ON document_chunks(source_id);
CREATE INDEX IF NOT EXISTS idx_document_chunks_hash ON document_chunks(chunk_hash);
CREATE INDEX IF NOT EXISTS idx_embeddings_chunk_model ON embeddings(chunk_id, model_id);

-- FTS5 virtual table for lexical search
CREATE VIRTUAL TABLE IF NOT EXISTS document_chunks_fts USING fts5(
    chunk_text,
    section_title,
    content='document_chunks',
    tokenize='porter unicode61'
);

-- Tool usage statistics
CREATE TABLE IF NOT EXISTS tool_usage_stats (
    tool_name TEXT PRIMARY KEY,
    total_calls INTEGER DEFAULT 0,
    successful_calls INTEGER DEFAULT 0,
    failed_calls INTEGER DEFAULT 0,
    blocked_calls INTEGER DEFAULT 0,
    avg_duration_ms REAL DEFAULT 0.0,
    last_used INTEGER
);

-- Session database schema (temporary, mergeable)

-- Local tool calls (session-specific)
CREATE TABLE IF NOT EXISTS local_tool_calls (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tool_name TEXT NOT NULL,
    request_id TEXT NOT NULL,
    parameters TEXT,
    result TEXT,
    error TEXT,
    timestamp INTEGER NOT NULL,
    merged_to_master BOOLEAN DEFAULT FALSE,
    merged_at INTEGER
);

-- Working state (session-specific)
CREATE TABLE IF NOT EXISTS working_state (
    key TEXT PRIMARY KEY,
    value TEXT,
    updated_at INTEGER NOT NULL
);

-- Scratch buffer (session-specific)
CREATE TABLE IF NOT EXISTS scratch_buffer (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    data_type TEXT NOT NULL,
    content TEXT,
    timestamp INTEGER NOT NULL
);

-- Content-addressed artifact store for deduplication
CREATE TABLE IF NOT EXISTS artifacts (
    artifact_hash TEXT PRIMARY KEY,
    algorithm TEXT NOT NULL DEFAULT 'sha256',
    version INTEGER NOT NULL DEFAULT 1,
    byte_length INTEGER NOT NULL,
    compression_type TEXT,
    compressed_length INTEGER,
    stored_at INTEGER NOT NULL,
    last_referenced_at INTEGER,
    reference_count INTEGER DEFAULT 0,
    payload BLOB,
    CHECK (byte_length > 0),
    CHECK (compressed_length IS NULL OR compressed_length > 0)
);

-- Evidence to artifact references (many-to-many)
CREATE TABLE IF NOT EXISTS evidence_artifacts (
    evidence_id TEXT NOT NULL,
    artifact_hash TEXT NOT NULL,
    reference_type TEXT NOT NULL, -- 'result', 'parameter', 'diff', etc.
    created_at INTEGER NOT NULL,
    PRIMARY KEY (evidence_id, artifact_hash),
    FOREIGN KEY (evidence_id) REFERENCES evidence_chain(evidence_id),
    FOREIGN KEY (artifact_hash) REFERENCES artifacts(artifact_hash)
);

-- Retention events (append-only audit trail)
CREATE TABLE IF NOT EXISTS retention_events (
    event_id TEXT PRIMARY KEY,
    policy_hash TEXT NOT NULL,
    policy_version TEXT NOT NULL,
    event_type TEXT NOT NULL, -- 'gc_run', 'session_cleanup', 'policy_expiry'
    started_at INTEGER NOT NULL,
    completed_at INTEGER NOT NULL,
    artifacts_deleted INTEGER DEFAULT 0,
    artifacts_freed_bytes INTEGER DEFAULT 0,
    sessions_deleted INTEGER DEFAULT 0,
    affected_artifact_hashes TEXT, -- JSON array of deleted artifact hashes
    retention_summary TEXT, -- JSON summary of what was cleaned up
    created_by TEXT NOT NULL DEFAULT 'harmonia-gc'
);

-- Indexes for performance

CREATE INDEX IF NOT EXISTS idx_evidence_chain_session_id ON evidence_chain(session_id);
CREATE INDEX IF NOT EXISTS idx_evidence_chain_tool_name ON evidence_chain(tool_name);
CREATE INDEX IF NOT EXISTS idx_evidence_chain_timestamp ON evidence_chain(start_time);
CREATE INDEX IF NOT EXISTS idx_file_changes_evidence_id ON file_changes(evidence_id);
CREATE INDEX IF NOT EXISTS idx_local_tool_calls_timestamp ON local_tool_calls(timestamp);
CREATE INDEX IF NOT EXISTS idx_working_state_updated_at ON working_state(updated_at);

-- New indexes for GC efficiency
CREATE INDEX IF NOT EXISTS idx_artifacts_last_referenced ON artifacts(last_referenced_at);
CREATE INDEX IF NOT EXISTS idx_artifacts_stored_at ON artifacts(stored_at);
CREATE INDEX IF NOT EXISTS idx_artifacts_reference_count ON artifacts(reference_count);
CREATE INDEX IF NOT EXISTS idx_evidence_artifacts_evidence_id ON evidence_artifacts(evidence_id);

-- Vault-backed artifact index (filesystem storage)
CREATE TABLE IF NOT EXISTS vault_artifacts (
    sha256_hex TEXT PRIMARY KEY,
    byte_len INTEGER NOT NULL,
    mime TEXT NOT NULL,
    kind TEXT NOT NULL,
    created_at REAL NOT NULL,
    key_id TEXT NOT NULL,
    object_relpath TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS vault_edges (
    parent_sha256_hex TEXT NOT NULL,
    child_sha256_hex TEXT NOT NULL,
    relation TEXT NOT NULL,
    run_id TEXT,
    step_id TEXT,
    PRIMARY KEY (parent_sha256_hex, child_sha256_hex, relation)
);

CREATE TABLE IF NOT EXISTS vault_access_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    at_utc REAL NOT NULL,
    actor_id TEXT,
    action TEXT NOT NULL,
    sha256_hex TEXT NOT NULL,
    decision TEXT NOT NULL,
    reason TEXT
);

CREATE INDEX IF NOT EXISTS idx_vault_artifacts_kind ON vault_artifacts(kind);
CREATE INDEX IF NOT EXISTS idx_vault_edges_parent ON vault_edges(parent_sha256_hex);
CREATE INDEX IF NOT EXISTS idx_vault_access_log_hash ON vault_access_log(sha256_hex);
CREATE INDEX IF NOT EXISTS idx_retention_events_completed_at ON retention_events(completed_at);

-- Triggers for maintaining derived views

-- Update session status when evidence changes
CREATE TRIGGER IF NOT EXISTS update_session_stats
AFTER INSERT ON evidence_chain
BEGIN
    DELETE FROM session_status_view WHERE session_id = NEW.session_id;
    INSERT INTO session_status_view (session_id, last_activity, tool_calls, errors)
    SELECT 
        NEW.session_id,
        NEW.start_time,
        COUNT(*),
        SUM(CASE WHEN NEW.status = 'failed' THEN 1 ELSE 0 END)
    FROM evidence_chain 
    WHERE session_id = NEW.session_id;
END;

-- Update tool usage statistics
CREATE TRIGGER IF NOT EXISTS update_tool_stats
AFTER INSERT ON evidence_chain
BEGIN
    INSERT OR REPLACE INTO tool_usage_stats (tool_name, total_calls, successful_calls, failed_calls, last_used)
    SELECT 
        NEW.tool_name,
        COALESCE(t.total_calls, 0) + 1,
        COALESCE(t.successful_calls, 0) + CASE WHEN NEW.status = 'success' THEN 1 ELSE 0 END,
        COALESCE(t.failed_calls, 0) + CASE WHEN NEW.status = 'failed' THEN 1 ELSE 0 END,
        NEW.start_time
    FROM tool_usage_stats t
    WHERE t.tool_name = NEW.tool_name;
END;
