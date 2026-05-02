-- Schema for tamper-evidence system and retrieval auditability
-- Creates append-only evidence chain and bundle export capabilities

-- Evidence Chain: Append-only tamper-evident log
CREATE TABLE IF NOT EXISTS evidence_chain (
    sequence_number INTEGER PRIMARY KEY AUTOINCREMENT,
    event_id TEXT NOT NULL UNIQUE,
    event_type TEXT NOT NULL,
    timestamp INTEGER NOT NULL,
    timezone TEXT NOT NULL DEFAULT 'UTC',
    payload_hash TEXT NOT NULL,
    previous_hash TEXT NOT NULL,
    head_hash TEXT NOT NULL,
    payload TEXT NOT NULL,
    actor TEXT NOT NULL,
    actor_ip TEXT,
    session_id TEXT,
    bundle_ids TEXT DEFAULT '[]',
    created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
);

-- Evidence Bundles: Exportable collections for legal proceedings
CREATE TABLE IF NOT EXISTS evidence_bundles (
    id TEXT PRIMARY KEY,
    bundle_type TEXT NOT NULL,
    description TEXT NOT NULL,
    purpose TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    created_by TEXT NOT NULL,
    retention_days INTEGER NOT NULL DEFAULT 2555, -- 7 years default
    event_ids TEXT NOT NULL,
    artifact_paths TEXT NOT NULL,
    manifest_hash TEXT NOT NULL,
    head_hash_at_creation TEXT NOT NULL,
    exported_at INTEGER,
    export_format TEXT,
    export_path TEXT,
    checksum TEXT,
    integrity_check TEXT,
    access_count INTEGER DEFAULT 0,
    last_accessed INTEGER
);

-- Bundle Templates: Predefined configurations for common export scenarios
CREATE TABLE IF NOT EXISTS bundle_templates (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    template_type TEXT NOT NULL,
    event_types TEXT NOT NULL,
    time_range_hours INTEGER NOT NULL,
    default_format TEXT NOT NULL,
    default_retention_days INTEGER NOT NULL,
    created_at INTEGER NOT NULL,
    created_by TEXT NOT NULL
);

-- Timestamp Claims: Multiple time sources for verification
CREATE TABLE IF NOT EXISTS timestamp_claims (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_id TEXT NOT NULL,
    system_clock INTEGER NOT NULL,
    filesystem_mtime INTEGER,
    http_timestamp INTEGER,
    git_commit_timestamp INTEGER,
    system_timezone TEXT,
    filesystem_timezone TEXT,
    ntp_server TEXT,
    clock_drift_seconds INTEGER,
    verification_status TEXT DEFAULT 'unverified',
    FOREIGN KEY (event_id) REFERENCES evidence_chain(event_id)
);

-- Retrieval Evidence: Audit trail for semantic search operations
CREATE TABLE IF NOT EXISTS retrieval_evidence (
    query_id TEXT PRIMARY KEY,
    query_text TEXT NOT NULL,
    query_timestamp INTEGER NOT NULL,
    embedding_recipe BLOB NOT NULL,
    similarity_threshold REAL NOT NULL,
    max_results INTEGER NOT NULL,
    total_candidates INTEGER NOT NULL,
    results_json BLOB NOT NULL,
    execution_time_ms INTEGER NOT NULL,
    engine_metadata BLOB NOT NULL,
    record_hash TEXT NOT NULL,
    created_at INTEGER NOT NULL
);

-- Transmission Events: Fax/email headers and metadata capture
CREATE TABLE IF NOT EXISTS transmission_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_unit_id TEXT NOT NULL,
    transmission_type TEXT NOT NULL, -- 'fax', 'email', 'http_upload', etc.
    device_service TEXT NOT NULL,
    sender_identifier TEXT,
    recipient_identifier TEXT,
    transmission_time INTEGER,
    confirmation_time INTEGER,
    header_lines TEXT NOT NULL,
    protocol_identifiers TEXT,
    resolution INTEGER,
    page_count INTEGER,
    transmission_quality TEXT,
    error_flags TEXT,
    FOREIGN KEY (document_unit_id) REFERENCES document_units(id)
);

-- Coverage Misses: Track when agents fall back to repo scanning
CREATE TABLE IF NOT EXISTS coverage_misses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    agent_id TEXT NOT NULL,
    session_id TEXT,
    query_type TEXT NOT NULL,
    query_content TEXT NOT NULL,
    reason TEXT NOT NULL, -- 'no_embedding_coverage', 'no_fulltext_coverage', etc.
    attempted_fallback TEXT NOT NULL, -- 'repo_scan', 'file_read', etc.
    file_patterns TEXT,
    timestamp INTEGER NOT NULL,
    resolved BOOLEAN DEFAULT FALSE,
    resolution_timestamp INTEGER,
    resolution_method TEXT
);

-- Policy Violations: Track all policy breaches for audit
CREATE TABLE IF NOT EXISTS policy_violations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    violation_type TEXT NOT NULL,
    severity TEXT NOT NULL, -- 'low', 'medium', 'high', 'critical'
    actor TEXT NOT NULL,
    session_id TEXT,
    description TEXT NOT NULL,
    context_json TEXT,
    policy_reference TEXT,
    auto_detected BOOLEAN DEFAULT TRUE,
    manual_review BOOLEAN DEFAULT FALSE,
    timestamp INTEGER NOT NULL,
    resolved BOOLEAN DEFAULT FALSE,
    resolution_timestamp INTEGER,
    resolution_method TEXT,
    resolution_notes TEXT
);

-- Evidence Rings: Merkle Mountain Range peaks for efficient proofs
CREATE TABLE IF NOT EXISTS evidence_rings (
    ring_id TEXT PRIMARY KEY,
    peaks_json TEXT NOT NULL,
    root_hash TEXT NOT NULL,
    ring_size INTEGER NOT NULL,
    hashing_policy TEXT NOT NULL DEFAULT 'blake3Tier1V2',
    updated_at INTEGER NOT NULL,
    metadata_json TEXT
);

-- Indexes for evidence chain integrity
CREATE UNIQUE INDEX IF NOT EXISTS idx_evidence_chain_event_id ON evidence_chain(event_id);
CREATE INDEX IF NOT EXISTS idx_evidence_chain_timestamp ON evidence_chain(timestamp);
CREATE INDEX IF NOT EXISTS idx_evidence_chain_event_type ON evidence_chain(event_type);
CREATE INDEX IF NOT EXISTS idx_evidence_chain_actor ON evidence_chain(actor);
CREATE INDEX IF NOT EXISTS idx_evidence_chain_head_hash ON evidence_chain(head_hash);

-- Indexes for bundle management
CREATE INDEX IF NOT EXISTS idx_evidence_bundles_type ON evidence_bundles(bundle_type);
CREATE INDEX IF NOT EXISTS idx_evidence_bundles_created_at ON evidence_bundles(created_at);
CREATE INDEX IF NOT EXISTS idx_evidence_bundles_retention ON evidence_bundles(retention_days);

-- Indexes for retrieval evidence
CREATE INDEX IF NOT EXISTS idx_retrieval_evidence_timestamp ON retrieval_evidence(query_timestamp);
CREATE INDEX IF NOT EXISTS idx_retrieval_evidence_threshold ON retrieval_evidence(similarity_threshold);
CREATE INDEX IF NOT EXISTS idx_retrieval_evidence_hash ON retrieval_evidence(record_hash);

-- Indexes for coverage tracking
CREATE INDEX IF NOT EXISTS idx_coverage_misses_agent ON coverage_misses(agent_id);
CREATE INDEX IF NOT EXISTS idx_coverage_misses_timestamp ON coverage_misses(timestamp);
CREATE INDEX IF NOT EXISTS idx_coverage_misses_resolved ON coverage_misses(resolved);

-- Indexes for policy violations
CREATE INDEX IF NOT EXISTS idx_policy_violations_type ON policy_violations(violation_type);
CREATE INDEX IF NOT EXISTS idx_policy_violations_severity ON policy_violations(severity);
CREATE INDEX IF NOT EXISTS idx_policy_violations_timestamp ON policy_violations(timestamp);
CREATE INDEX IF NOT EXISTS idx_policy_violations_resolved ON policy_violations(resolved);

-- Views for common queries
CREATE VIEW IF NOT EXISTS evidence_chain_head AS
SELECT 
    event_id,
    event_type,
    timestamp,
    actor,
    head_hash,
    payload_hash
FROM evidence_chain 
ORDER BY sequence_number DESC 
LIMIT 1;

CREATE VIEW IF NOT EXISTS active_bundles AS
SELECT 
    id,
    bundle_type,
    description,
    purpose,
    created_at,
    retention_days,
    (created_at + (retention_days * 86400)) as expires_at,
    CASE 
        WHEN (created_at + (retention_days * 86400)) < strftime('%s', 'now') THEN 'expired'
        WHEN integrity_check = 'valid' THEN 'valid'
        ELSE 'suspicious'
    END as status
FROM evidence_bundles
ORDER BY created_at DESC;

CREATE VIEW IF NOT EXISTS retrieval_performance AS
SELECT 
    DATE(query_timestamp, 'unixepoch') as query_date,
    COUNT(*) as total_queries,
    AVG(execution_time_ms) as avg_execution_ms,
    AVG(similarity_threshold) as avg_threshold,
    AVG(total_candidates) as avg_candidates,
    MAX(execution_time_ms) as max_execution_ms
FROM retrieval_evidence
GROUP BY DATE(query_timestamp, 'unixepoch')
ORDER BY query_date DESC;

CREATE VIEW IF NOT EXISTS coverage_gaps AS
SELECT 
    agent_id,
    COUNT(*) as total_misses,
    COUNT(CASE WHEN resolved = FALSE THEN 1 END) as unresolved_misses,
    reason,
    MAX(timestamp) as last_miss_timestamp
FROM coverage_misses
GROUP BY agent_id, reason
ORDER BY total_misses DESC;

CREATE VIEW IF NOT EXISTS policy_compliance AS
SELECT 
    violation_type,
    severity,
    COUNT(*) as total_violations,
    COUNT(CASE WHEN resolved = FALSE THEN 1 END) as unresolved_violations,
    MAX(timestamp) as last_violation_timestamp
FROM policy_violations
GROUP BY violation_type, severity
ORDER BY unresolved_violations DESC, total_violations DESC;

-- Triggers for maintaining chain integrity
CREATE TRIGGER IF NOT EXISTS verify_head_hash_insert
BEFORE INSERT ON evidence_chain
FOR EACH ROW
BEGIN
    SELECT CASE
        WHEN NEW.previous_hash != (SELECT head_hash FROM evidence_chain ORDER BY sequence_number DESC LIMIT 1)
            AND (SELECT COUNT(*) FROM evidence_chain) > 0
        THEN RAISE(ABORT, 'Previous hash does not match chain head')
    END;
END;

-- Insert default bundle templates
INSERT OR IGNORE INTO bundle_templates VALUES 
(
    'legal_discovery',
    'Legal Discovery Bundle',
    'Complete evidence package for legal proceedings and discovery requests',
    'legal',
    'document_ingestion,embedding_generation,retrieval_operation,policy_violation',
    720, -- 30 days
    'zip',
    3650, -- 10 years
    strftime('%s', 'now'),
    'system'
),
(
    'compliance_audit',
    'Compliance Audit Bundle',
    'Evidence package for regulatory compliance audits',
    'compliance',
    'policy_violation,coverage_misses,transmission_event',
    168, -- 7 days
    'zip',
    1825, -- 5 years
    strftime('%s', 'now'),
    'system'
),
(
    'incident_response',
    'Incident Response Bundle',
    'Evidence collection for security incident investigations',
    'security',
    'policy_violation,retrieval_operation,coverage_misses',
    24, -- 1 day
    'zip',
    2555, -- 7 years
    strftime('%s', 'now'),
    'system'
),
(
    'research_export',
    'Research Data Bundle',
    ' anonymized data for research and analysis',
    'research',
    'retrieval_operation,document_ingestion',
    8760, -- 1 year
    'tar',
    3650, -- 10 years
    strftime('%s', 'now'),
    'system'
);

-- Default policy violation types
INSERT OR IGNORE INTO policy_violations (violation_type, severity, actor, description, timestamp) VALUES
('repo_scan_without_db_check', 'medium', 'system', 'Agent performed repository scan without checking database coverage first', strftime('%s', 'now')),
('metadata_stripping', 'high', 'system', 'Document metadata was stripped without explicit policy authorization', strftime('%s', 'now')),
('lossy_transformation', 'high', 'system', 'Lossy data transformation performed without provenance markers', strftime('%s', 'now')),
('evidence_chain_break', 'critical', 'system', 'Evidence chain integrity check failed', strftime('%s', 'now')),
('unauthorized_artifact_access', 'high', 'system', 'Access to artifacts without proper authorization', strftime('%s', 'now'));

-- Ensure evidence chain starts with genesis block
INSERT OR IGNORE INTO evidence_chain (
    event_id, event_type, timestamp, timezone, payload_hash,
    previous_hash, head_hash, payload, actor, bundle_ids
) VALUES (
    'genesis_' || lower(hex(randomblob(16))),
    'system_genesis',
    strftime('%s', 'now'),
    'UTC',
    lower(hex(randomblob(32))),
    '',
    lower(hex(randomblob(32))),
    '{"message": "Evidence chain initialized", "version": "1.0"}',
    'tamper_evidence_system',
    '[]'
);