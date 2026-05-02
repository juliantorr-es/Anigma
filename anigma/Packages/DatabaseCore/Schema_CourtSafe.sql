-- Enhanced Evidence Schema with Security, Timestamping, and Redaction
-- Complete court-safe evidence infrastructure

-- Previous evidence tables (from Schema_Evidence.sql)...

-- Digital Signatures for authenticity
CREATE TABLE IF NOT EXISTS evidence_signatures (
    signature_id TEXT PRIMARY KEY,
    evidence_head_hash TEXT NOT NULL,
    signer_identity TEXT NOT NULL,
    signer_role TEXT NOT NULL,
    signing_timestamp INTEGER NOT NULL,
    authorization_reference TEXT,
    hardware_attestation TEXT,
    key_fingerprint TEXT NOT NULL,
    signature_data BLOB NOT NULL,
    verification_status TEXT NOT NULL DEFAULT 'valid',
    created_at INTEGER NOT NULL,
    FOREIGN KEY (evidence_head_hash) REFERENCES evidence_chain(head_hash)
);

CREATE TABLE IF NOT EXISTS bundle_signatures (
    signature_id TEXT PRIMARY KEY,
    bundle_id TEXT NOT NULL,
    manifest_hash TEXT NOT NULL,
    signer_identity TEXT NOT NULL,
    signer_role TEXT NOT NULL,
    export_purpose TEXT NOT NULL,
    signing_timestamp INTEGER NOT NULL,
    key_fingerprint TEXT NOT NULL,
    signature_data BLOB NOT NULL,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (bundle_id) REFERENCES evidence_bundles(id)
);

-- Key Management for cryptographic signing
CREATE TABLE IF NOT EXISTS signing_keys (
    fingerprint TEXT PRIMARY KEY,
    algorithm TEXT NOT NULL,
    public_key BLOB NOT NULL,
    created INTEGER NOT NULL,
    created_by TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'active',
    deprecated_at INTEGER,
    deprecation_reason TEXT,
    revoked_at INTEGER,
    revocation_reason TEXT,
    incident_reference TEXT,
    last_rotation_at INTEGER,
    rotation_reason TEXT
);

CREATE TABLE IF NOT EXISTS key_management_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    operation TEXT NOT NULL, -- 'create', 'rotate', 'revoke', 'deactivate'
    key_fingerprint TEXT NOT NULL,
    reason TEXT NOT NULL,
    authorized_by TEXT NOT NULL,
    incident_reference TEXT,
    previous_fingerprint TEXT,
    metadata_json TEXT,
    timestamp INTEGER NOT NULL,
    FOREIGN KEY (key_fingerprint) REFERENCES signing_keys(fingerprint),
    FOREIGN KEY (previous_fingerprint) REFERENCES signing_keys(fingerprint)
);

-- Enhanced Timestamp Claims with multiple time sources
CREATE TABLE IF NOT EXISTS timestamp_claims (
    claim_id TEXT PRIMARY KEY,
    target_hash TEXT NOT NULL,
    target_type TEXT NOT NULL, -- 'evidence_head', 'bundle', 'document', 'embedding'
    master_timestamp INTEGER NOT NULL,
    monotonic_value INTEGER NOT NULL,
    time_source_claims BLOB NOT NULL, -- JSON array of TimeSourceClaim objects
    timestamping_level TEXT NOT NULL DEFAULT 'standard', -- 'basic', 'standard', 'enhanced', 'legal', 'blockchain'
    requested_by TEXT NOT NULL,
    authorized_by TEXT,
    verification_status TEXT DEFAULT 'unverified',
    external_verifications BLOB, -- JSON array of external service responses
    claim_data BLOB NOT NULL, -- Complete TimestampClaim object
    created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS bundle_timestamp_claims (
    claim_id TEXT PRIMARY KEY,
    bundle_id TEXT NOT NULL,
    bundle_hash TEXT NOT NULL,
    master_timestamp INTEGER NOT NULL,
    monotonic_value INTEGER NOT NULL,
    time_source_claims BLOB NOT NULL,
    timestamping_level TEXT NOT NULL,
    legal_hold_reference TEXT,
    retention_period INTEGER,
    export_path TEXT NOT NULL,
    file_size INTEGER,
    file_hash TEXT,
    verification_status TEXT DEFAULT 'unverified',
    claim_data BLOB NOT NULL,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (bundle_id) REFERENCES evidence_bundles(id)
);

-- Time Source Claims for multi-source timestamping
CREATE TABLE IF NOT EXISTS time_source_claims (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    claim_id TEXT NOT NULL,
    source TEXT NOT NULL, -- 'system_clock', 'filesystem_mtime', 'ntp_server', 'rfc3161_tsa', 'nist_beacon', 'blockchain'
    timestamp INTEGER NOT NULL,
    timezone TEXT NOT NULL,
    confidence REAL NOT NULL CHECK (confidence >= 0.0 AND confidence <= 1.0),
    acceptable_drift_seconds INTEGER DEFAULT 300,
    metadata_json TEXT, -- Source-specific metadata
    verification_status TEXT DEFAULT 'pending',
    verified_at INTEGER,
    FOREIGN KEY (claim_id) REFERENCES timestamp_claims(claim_id)
);

-- Redaction System for legal discovery
CREATE TABLE IF NOT EXISTS redaction_sessions (
    session_id TEXT PRIMARY KEY,
    original_bundle_id TEXT NOT NULL,
    redaction_plan BLOB NOT NULL, -- Complete RedactionPlan object
    requested_by TEXT NOT NULL,
    authorized_by TEXT NOT NULL,
    legal_hold_reference TEXT,
    status TEXT DEFAULT 'in_progress', -- 'in_progress', 'completed', 'verified', 'rejected'
    total_targets INTEGER DEFAULT 0,
    completed_targets INTEGER DEFAULT 0,
    created_at INTEGER NOT NULL,
    completed_at INTEGER,
    FOREIGN KEY (original_bundle_id) REFERENCES evidence_bundles(id)
);

CREATE TABLE IF NOT EXISTS redacted_bundles (
    original_bundle_id TEXT NOT NULL,
    redacted_bundle_id TEXT PRIMARY KEY,
    redaction_session_id TEXT NOT NULL,
    redacted_manifest BLOB NOT NULL, -- RedactedBundleManifest object
    bundle_signature_id TEXT,
    verification_status TEXT DEFAULT 'pending',
    total_redactions INTEGER DEFAULT 0,
    total_components INTEGER DEFAULT 0,
    redaction_percentage REAL DEFAULT 0.0,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (original_bundle_id) REFERENCES evidence_bundles(id),
    FOREIGN KEY (redaction_session_id) REFERENCES redaction_sessions(session_id),
    FOREIGN KEY (bundle_signature_id) REFERENCES bundle_signatures(signature_id)
);

CREATE TABLE IF NOT EXISTS redaction_results (
    result_id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    document_unit_id TEXT NOT NULL,
    original_content TEXT NOT NULL,
    redacted_content TEXT NOT NULL,
    applied_redactions BLOB NOT NULL, -- JSON array of AppliedRedaction objects
    redaction_metrics BLOB NOT NULL, -- RedactionMetrics object
    applied_by TEXT NOT NULL,
    applied_at INTEGER NOT NULL,
    FOREIGN KEY (session_id) REFERENCES redaction_sessions(session_id),
    FOREIGN KEY (document_unit_id) REFERENCES document_units(id)
);

CREATE TABLE IF NOT EXISTS privilege_logs (
    log_id TEXT PRIMARY KEY,
    bundle_id TEXT NOT NULL,
    session_id TEXT NOT NULL,
    entries BLOB NOT NULL, -- JSON array of PrivilegeLogEntry objects
    generated_at INTEGER NOT NULL,
    total_redactions INTEGER DEFAULT 0,
    challenged_redactions INTEGER DEFAULT 0,
    status TEXT DEFAULT 'active',
    FOREIGN KEY (bundle_id) REFERENCES evidence_bundles(id),
    FOREIGN KEY (session_id) REFERENCES redaction_sessions(session_id)
);

-- Enhanced Storage Security
CREATE TABLE IF NOT EXISTS storage_checkpoints (
    checkpoint_id TEXT PRIMARY KEY,
    evidence_head_hash TEXT NOT NULL,
    checkpoint_timestamp INTEGER NOT NULL,
    checkpoint_data_hash TEXT NOT NULL,
    checkpoint_signature BLOB,
    storage_location TEXT NOT NULL,
    storage_type TEXT NOT NULL, -- 'local', 's3', 'azure', 'gcs', 'worm_storage'
    retention_until INTEGER NOT NULL,
    access_count INTEGER DEFAULT 0,
    last_accessed INTEGER,
    integrity_verified BOOLEAN DEFAULT FALSE,
    verification_timestamp INTEGER,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (evidence_head_hash) REFERENCES evidence_chain(head_hash)
);

CREATE TABLE IF NOT EXISTS storage_access_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    checkpoint_id TEXT NOT NULL,
    access_type TEXT NOT NULL, -- 'read', 'write', 'verify', 'export'
    actor_identity TEXT NOT NULL,
    actor_role TEXT NOT NULL,
    access_timestamp INTEGER NOT NULL,
    access_reason TEXT,
    ip_address TEXT,
    user_agent TEXT,
    success BOOLEAN NOT NULL,
    error_message TEXT,
    FOREIGN KEY (checkpoint_id) REFERENCES storage_checkpoints(checkpoint_id)
);

-- Environment Capture with restraint
CREATE TABLE IF NOT EXISTS environment_snapshots (
    snapshot_id TEXT PRIMARY KEY,
    evidence_event_id TEXT,
    snapshot_timestamp INTEGER NOT NULL,
    os_name TEXT,
    os_version TEXT,
    architecture TEXT,
    hostname TEXT,
    username TEXT,
    toolchain_ids TEXT, -- JSON array of tool versions
    container_runtime TEXT,
    container_image_id TEXT,
    hardware_identity TEXT, -- Limited hardware fingerprinting
    security_context TEXT, -- SELinux/AppArmor context
    environment_variables BLOB, -- Only allowlisted variables
    working_directory TEXT,
    process_id INTEGER,
    parent_process_id INTEGER,
    command_line TEXT,
    restricted BOOLEAN DEFAULT TRUE, -- Whether snapshot was taken with restrictions
    created_at INTEGER NOT NULL,
    FOREIGN KEY (evidence_event_id) REFERENCES evidence_chain(event_id)
);

-- Allowed Environment Variables (for security)
CREATE TABLE IF NOT EXISTS allowed_env_vars (
    variable_name TEXT PRIMARY KEY,
    category TEXT NOT NULL, -- 'ml_config', 'system', 'security', 'diagnostic'
    description TEXT,
    required BOOLEAN DEFAULT FALSE,
    sensitive BOOLEAN DEFAULT FALSE, -- Contains potentially sensitive data
    approved_by TEXT,
    approved_at INTEGER,
    created_at INTEGER NOT NULL
);

-- Evidence Chain Integrity Monitoring
CREATE TABLE IF NOT EXISTS integrity_checks (
    check_id TEXT PRIMARY KEY,
    evidence_head_hash TEXT NOT NULL,
    check_type TEXT NOT NULL, -- 'full_chain', 'hash_verification', 'signature_verification'
    check_status TEXT NOT NULL, -- 'passed', 'failed', 'warning'
    violations_found INTEGER DEFAULT 0,
    violations_details BLOB, -- JSON array of ChainViolation objects
    check_duration_ms INTEGER,
    checked_by TEXT NOT NULL,
    check_timestamp INTEGER NOT NULL,
    check_data BLOB, -- Complete integrity report
    FOREIGN KEY (evidence_head_hash) REFERENCES evidence_chain(head_hash)
);

-- Enhanced Policy Violations with Severity
ALTER TABLE policy_violations ADD COLUMN severity_level TEXT DEFAULT 'medium'; -- 'low', 'medium', 'high', 'critical'
ALTER TABLE policy_violations ADD COLUMN remediation_required BOOLEAN DEFAULT FALSE;
ALTER TABLE policy_violations ADD COLUMN remediation_status TEXT DEFAULT 'pending'; -- 'pending', 'in_progress', 'resolved'
ALTER TABLE policy_violations ADD COLUMN impact_assessment TEXT;

-- Enhanced Coverage Misses with Impact Analysis
ALTER TABLE coverage_misses ADD COLUMN estimated_impact TEXT DEFAULT 'medium'; -- 'low', 'medium', 'high'
ALTER TABLE coverage_misses ADD COLUMN automated_fix_available BOOLEAN DEFAULT FALSE;
ALTER TABLE coverage_misses ADD COLUMN fix_attempt_count INTEGER DEFAULT 0;

-- Indexes for Enhanced Security Schema
CREATE UNIQUE INDEX IF NOT EXISTS idx_evidence_signatures_hash ON evidence_signatures(evidence_head_hash);
CREATE INDEX IF NOT EXISTS idx_evidence_signatures_signer ON evidence_signatures(signer_identity);
CREATE INDEX IF NOT EXISTS idx_evidence_signatures_timestamp ON evidence_signatures(signing_timestamp);

CREATE UNIQUE INDEX IF NOT EXISTS idx_bundle_signatures_bundle ON bundle_signatures(bundle_id);
CREATE INDEX IF NOT EXISTS idx_bundle_signatures_signer ON bundle_signatures(signer_identity);

CREATE INDEX IF NOT EXISTS idx_signing_keys_status ON signing_keys(status);
CREATE INDEX IF NOT EXISTS idx_signing_keys_created ON signing_keys(created);

CREATE INDEX IF NOT EXISTS idx_key_events_operation ON key_management_events(operation);
CREATE INDEX IF NOT EXISTS idx_key_events_timestamp ON key_management_events(timestamp);

CREATE INDEX IF NOT EXISTS idx_timestamp_claims_target ON timestamp_claims(target_hash, target_type);
CREATE INDEX IF NOT EXISTS idx_timestamp_claims_level ON timestamp_claims(timestamping_level);
CREATE INDEX IF NOT EXISTS idx_timestamp_claims_monotonic ON timestamp_claims(monotonic_value);

CREATE INDEX IF NOT EXISTS idx_time_source_claims_source ON time_source_claims(source);
CREATE INDEX IF NOT EXISTS idx_time_source_claims_confidence ON time_source_claims(confidence);

CREATE INDEX IF NOT EXISTS idx_redaction_sessions_original ON redaction_sessions(original_bundle_id);
CREATE INDEX IF NOT EXISTS idx_redaction_sessions_status ON redaction_sessions(status);

CREATE INDEX IF NOT EXISTS idx_redacted_bundles_original ON redacted_bundles(original_bundle_id);
CREATE INDEX IF NOT EXISTS idx_redacted_bundles_session ON redacted_bundles(redaction_session_id);

CREATE INDEX IF NOT EXISTS idx_redaction_results_session ON redaction_results(session_id);
CREATE INDEX IF NOT EXISTS idx_redaction_results_document ON redaction_results(document_unit_id);

CREATE INDEX IF NOT EXISTS idx_privilege_logs_bundle ON privilege_logs(bundle_id);
CREATE INDEX IF NOT EXISTS idx_privilege_logs_session ON privilege_logs(session_id);

CREATE INDEX IF NOT EXISTS idx_storage_checkpoints_head ON storage_checkpoints(evidence_head_hash);
CREATE INDEX IF NOT EXISTS idx_storage_checkpoints_type ON storage_checkpoints(storage_type);

CREATE INDEX IF NOT EXISTS idx_storage_access_checkpoint ON storage_access_log(checkpoint_id);
CREATE INDEX IF NOT EXISTS idx_storage_access_timestamp ON storage_access_log(access_timestamp);

CREATE INDEX IF NOT EXISTS idx_environment_snapshots_event ON environment_snapshots(evidence_event_id);
CREATE INDEX IF NOT EXISTS idx_environment_snapshots_timestamp ON environment_snapshots(snapshot_timestamp);

CREATE INDEX IF NOT EXISTS idx_integrity_checks_head ON integrity_checks(evidence_head_hash);
CREATE INDEX IF NOT EXISTS idx_integrity_checks_status ON integrity_checks(check_status);

-- Views for Enhanced Monitoring
CREATE VIEW IF NOT EXISTS evidence_chain_status AS
SELECT 
    ec.event_id,
    ec.head_hash,
    ec.timestamp,
    es.signer_identity,
    es.signing_timestamp as signature_timestamp,
    tc.master_timestamp,
    tc.timestamping_level,
    ic.check_status as integrity_status,
    ic.check_timestamp
FROM evidence_chain ec
LEFT JOIN evidence_signatures es ON ec.head_hash = es.evidence_head_hash
LEFT JOIN timestamp_claims tc ON ec.head_hash = tc.target_hash
LEFT JOIN integrity_checks ic ON ec.head_hash = ic.evidence_head_hash
ORDER BY ec.sequence_number DESC;

CREATE VIEW IF NOT EXISTS bundle_export_status AS
SELECT 
    eb.id as bundle_id,
    eb.bundle_type,
    eb.description,
    eb.created_at,
    bs.signer_identity,
    bs.signing_timestamp,
    btc.master_timestamp as bundle_timestamp,
    btc.timestamping_level,
    rb.redacted_bundle_id,
    rb.verification_status as redaction_status,
    eb.integrity_check
FROM evidence_bundles eb
LEFT JOIN bundle_signatures bs ON eb.id = bs.bundle_id
LEFT JOIN bundle_timestamp_claims btc ON eb.id = btc.bundle_id
LEFT JOIN redacted_bundles rb ON eb.id = rb.original_bundle_id
ORDER BY eb.created_at DESC;

CREATE VIEW IF NOT EXISTS redactivity_metrics AS
SELECT 
    DATE(rs.created_at, 'unixepoch') as redaction_date,
    COUNT(*) as total_sessions,
    COUNT(CASE WHEN rs.status = 'completed' THEN 1 END) as completed_sessions,
    COUNT(rb.redacted_bundle_id) as total_redacted_bundles,
    AVG(rb.redaction_percentage) as avg_redaction_percentage,
    SUM(rb.total_redactions) as total_redactions
FROM redaction_sessions rs
LEFT JOIN redacted_bundles rb ON rs.session_id = rb.redaction_session_id
GROUP BY DATE(rs.created_at, 'unixepoch')
ORDER BY redaction_date DESC;

CREATE VIEW IF NOT EXISTS security_metrics AS
SELECT 
    'signing_keys' as metric_type,
    COUNT(*) as total_count,
    COUNT(CASE WHEN sk.status = 'active' THEN 1 END) as active_count,
    COUNT(CASE WHEN sk.status = 'revoked' THEN 1 END) as revoked_count
FROM signing_keys sk

UNION ALL

SELECT 
    'evidence_signatures' as metric_type,
    COUNT(*) as total_count,
    COUNT(CASE WHEN es.verification_status = 'valid' THEN 1 END) as active_count,
    COUNT(CASE WHEN es.verification_status != 'valid' THEN 1 END) as revoked_count
FROM evidence_signatures es

UNION ALL

SELECT 
    'integrity_checks' as metric_type,
    COUNT(*) as total_count,
    COUNT(CASE WHEN ic.check_status = 'passed' THEN 1 END) as active_count,
    COUNT(CASE WHEN ic.check_status = 'failed' THEN 1 END) as revoked_count
FROM integrity_checks ic;

-- Triggers for Security Enforcement
CREATE TRIGGER IF NOT EXISTS enforce_signature_on_export
BEFORE UPDATE ON evidence_bundles
WHEN NEW.exported_at IS NOT NULL AND OLD.exported_at IS NULL
BEGIN
    SELECT CASE
        WHEN NOT EXISTS (
            SELECT 1 FROM bundle_signatures 
            WHERE bundle_id = NEW.id
        ) THEN RAISE(ABORT, 'Bundle must be signed before export')
    END;
END;

CREATE TRIGGER IF NOT EXISTS log_storage_access
AFTER INSERT ON storage_access_log
BEGIN
    UPDATE storage_checkpoints 
    SET access_count = access_count + 1,
        last_accessed = NEW.access_timestamp
    WHERE checkpoint_id = NEW.checkpoint_id;
END;

CREATE TRIGGER IF NOT EXISTS verify_redaction_completion
AFTER UPDATE ON redaction_sessions
WHEN NEW.status = 'completed'
BEGIN
    UPDATE redaction_sessions 
    SET completed_at = strftime('%s', 'now')
    WHERE session_id = NEW.session_id;
END;

-- Insert default allowed environment variables
INSERT OR IGNORE INTO allowed_env_vars VALUES
('MLX_MODEL_PATH', 'ml_config', 'Path to MLX model files', TRUE, FALSE, 'ml_admin', strftime('%s', 'now'), strftime('%s', 'now')),
('LLAMA_MODEL_PATH', 'ml_config', 'Path to Llama model files', TRUE, FALSE, 'ml_admin', strftime('%s', 'now'), strftime('%s', 'now')),
('ML_WORKER_MOCK_MODE', 'ml_config', 'Enable mock mode for testing', FALSE, FALSE, 'ml_admin', strftime('%s', 'now'), strftime('%s', 'now')),
('ML_WORKER_MAX_MEMORY', 'ml_config', 'Maximum memory limit for ML worker', FALSE, FALSE, 'ml_admin', strftime('%s', 'now'), strftime('%s', 'now')),
('ML_WORKER_TIMEOUT', 'ml_config', 'Timeout for ML worker operations', FALSE, FALSE, 'ml_admin', strftime('%s', 'now'), strftime('%s', 'now')),
('ANIGMA_ENVIRONMENT', 'system', 'Anigma environment identifier', TRUE, FALSE, 'system_admin', strftime('%s', 'now'), strftime('%s', 'now')),
('HARMONIA_MODE', 'system', 'Harmonia operation mode', TRUE, FALSE, 'harmonia_admin', strftime('%s', 'now'), strftime('%s', 'now')),
('ACCESSUM_ARTIFACTS_PATH', 'system', 'Path to Accessum artifacts directory', TRUE, FALSE, 'system_admin', strftime('%s', 'now'), strftime('%s', 'now')),
('TZ', 'system', 'System timezone', FALSE, FALSE, 'system_admin', strftime('%s', 'now'), strftime('%s', 'now')),
('LANG', 'system', 'System language locale', FALSE, FALSE, 'system_admin', strftime('%s', 'now'), strftime('%s', 'now'));

-- Create initial signing key record
INSERT OR IGNORE INTO signing_keys VALUES
(
    lower(hex(randomblob(32))), -- fingerprint placeholder
    'P256', -- algorithm
    randomblob(65), -- public key placeholder
    strftime('%s', 'now'), -- created
    'system', -- created_by
    'active', -- status
    NULL, -- deprecated_at
    NULL, -- deprecation_reason
    NULL, -- revoked_at
    NULL, -- revocation_reason
    NULL, -- incident_reference
    strftime('%s', 'now'), -- last_rotation_at
    'initial_key' -- rotation_reason
);