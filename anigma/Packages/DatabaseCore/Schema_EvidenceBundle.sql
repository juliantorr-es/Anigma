-- Tamper-Evident Ledger and Evidence Bundle Schema
-- Makes the entire custody chain tamper-detectable and exportable

-- Immutable append-only event log for all system changes
CREATE TABLE evidence_chain (
    sequence_number INTEGER PRIMARY KEY AUTOINCREMENT,
    event_id TEXT NOT NULL UNIQUE,
    event_type TEXT NOT NULL,          -- 'document_ingest', 'embedding_generated', 'diagnostic_parsed', 'policy_violation'
    timestamp INTEGER NOT NULL,         -- Multiple clock sources captured
    timezone TEXT DEFAULT 'UTC',          -- Explicit timezone, never rewritten
    payload_hash TEXT NOT NULL,        -- SHA256 of event payload
    previous_hash TEXT,                 -- Hash of previous event for chain integrity
    head_hash TEXT NOT NULL,            -- Hash of this event (including previous)
    
    -- Serialized event payload (immutable)
    payload TEXT NOT NULL,              -- JSON event data
    
    -- Provenance
    actor TEXT NOT NULL,                -- System or user who initiated event
    actor_ip TEXT,                      -- IP address if external actor
    session_id TEXT,                    -- User session if applicable
    
    -- Evidence bundle references
    bundle_ids TEXT,                     -- Comma-separated list of bundle IDs that include this event
    
    created_at INTEGER DEFAULT (strftime('%s', 'now'))
);

-- Evidence bundles for export and archival
CREATE TABLE evidence_bundles (
    id TEXT PRIMARY KEY,
    bundle_type TEXT NOT NULL,          -- 'retrieval_query', 'diagnostic_report', 'document_lifecycle'
    description TEXT,
    
    -- Bundle metadata
    created_at INTEGER NOT NULL,
    created_by TEXT NOT NULL,          -- System component that created bundle
    purpose TEXT NOT NULL,              -- 'legal_produced', 'audit_requested', 'incident_response'
    retention_days INTEGER DEFAULT 2555,  -- 7 years default
    
    -- Bundle composition
    event_ids TEXT NOT NULL,           -- Comma-separated list of event IDs included
    artifact_paths TEXT,                -- Comma-separated list of artifact paths included
    manifest_hash TEXT NOT NULL,        -- SHA256 of bundle manifest
    
    -- Export status
    exported_at INTEGER,                -- When bundle was exported
    export_format TEXT DEFAULT 'zip',    -- 'zip', 'tar', 'directory'
    export_path TEXT,                   -- Where bundle was exported
    checksum TEXT,                       -- SHA256 of exported file/directory
    
    -- Validation
    head_hash_at_creation TEXT NOT NULL, -- Head hash when bundle was created
    integrity_check TEXT DEFAULT 'valid', -- 'valid', 'tampered', 'corrupted'
    
    created_at INTEGER DEFAULT (strftime('%s', 'now'))
);

-- Captured timestamps from multiple sources for time verification
CREATE TABLE timestamp_claims (
    id TEXT PRIMARY KEY,
    event_id TEXT NOT NULL,
    
    -- Clock sources
    system_clock INTEGER NOT NULL,    -- System clock at event time
    filesystem_mtime INTEGER,          -- File modification time (if applicable)
    http_timestamp INTEGER,             -- HTTP timestamp (if applicable)
    git_commit_timestamp INTEGER,       -- Git commit timestamp (if applicable)
    
    -- Clock metadata
    system_timezone TEXT DEFAULT 'UTC',
    filesystem_timezone TEXT,
    ntp_server TEXT,
    clock_drift_seconds INTEGER DEFAULT 0,  -- Calculated drift from reference
    
    -- Verification status
    verification_status TEXT DEFAULT 'unverified', -- 'verified', 'drift_detected', 'conflict'
    verification_details TEXT,          -- JSON with verification results
    
    created_at INTEGER DEFAULT (strftime('%s', 'now')),
    FOREIGN KEY (event_id) REFERENCES evidence_chain(event_id)
);

-- Retrieval query evidence records
CREATE TABLE retrieval_queries (
    id TEXT PRIMARY KEY,
    query_text TEXT NOT NULL,
    query_embedding_recipe_id TEXT NOT NULL,
    
    -- Query execution
    vector_hash TEXT NOT NULL,         -- SHA256 of query vector
    similarity_threshold REAL NOT NULL,
    max_results INTEGER NOT NULL,
    
    -- Results (as evidence)
    result_document_units TEXT NOT NULL,    -- Comma-separated document unit IDs
    result_similarities TEXT NOT NULL,       -- JSON array of similarity scores
    result_snippets TEXT NOT NULL,           -- JSON array of content snippets
    
    -- Performance metrics
    execution_time_ms INTEGER NOT NULL,
    vector_comparison_count INTEGER NOT NULL,
    
    -- Evidence bundle reference
    bundle_id TEXT NOT NULL,             -- Bundle that includes this query
    
    created_at INTEGER DEFAULT (strftime('%s', 'now'))
);

-- Transmission events for facsimiles (fax, email, etc.)
CREATE TABLE transmission_events (
    id TEXT PRIMARY KEY,
    document_unit_id TEXT NOT NULL,
    
    -- Transmission details
    transmission_type TEXT NOT NULL,     -- 'fax', 'email', 'http_upload', 'file_transfer'
    sender_id TEXT,                       -- Fax number, email address, IP address
    receiver_id TEXT,                     -- Recipient information
    protocol TEXT,                        -- 't38', 'smtp', 'http', 'sftp'
    
    -- Technical details
    device_id TEXT,                      -- Sending device/service identifier
    connection_details TEXT,              -- JSON with technical metadata
    page_count INTEGER,                    -- For faxes
    resolution TEXT,                       -- Image resolution if applicable
    file_size INTEGER,                    -- Original file size
    
    -- Timing
    sent_timestamp INTEGER NOT NULL,
    received_timestamp INTEGER,
    processing_timestamp INTEGER,
    
    -- Evidence
    headers_raw TEXT,                     -- Raw transmission headers
    headers_parsed TEXT,                   -- Parsed headers as JSON
    checksums TEXT,                       -- Various checksums calculated
    verification_status TEXT DEFAULT 'verified',
    
    created_at INTEGER DEFAULT (strftime('%s', 'now')),
    FOREIGN KEY (document_unit_id) REFERENCES document_units(id)
);

-- Transformation events for any content processing
CREATE TABLE transformation_events (
    id TEXT PRIMARY KEY,
    source_artifact_path TEXT NOT NULL,
    source_hash TEXT NOT NULL,
    target_artifact_path TEXT NOT NULL,
    target_hash TEXT NOT NULL,
    
    -- Transformation details
    transformation_type TEXT NOT NULL,      -- 'ocr', 'text_extraction', 'normalization', 'chunking'
    tool_id TEXT NOT NULL,                -- Tool name and version
    tool_argv TEXT,                       -- Command line arguments
    tool_env TEXT,                         -- Environment variables
    tool_config TEXT,                      -- Tool configuration JSON
    
    -- Processing parameters
    processing_time_ms INTEGER NOT NULL,
    input_size INTEGER NOT NULL,
    output_size INTEGER NOT NULL,
    quality_score REAL,                    -- Confidence score (0-1) if applicable
    
    -- Evidence bundle reference
    bundle_id TEXT,
    
    created_at INTEGER DEFAULT (strftime('%s', 'now'))
);

-- Policy violations with remediation tracking
CREATE TABLE policy_violations (
    id TEXT PRIMARY KEY,
    violation_type TEXT NOT NULL,         -- 'repo_scan_fallback', 'ingest_error', 'tamper_detected'
    severity TEXT NOT NULL,               -- 'critical', 'high', 'medium', 'low'
    
    -- Violation details
    actor TEXT NOT NULL,
    action TEXT NOT NULL,                -- What was attempted
    reason TEXT NOT NULL,                -- Why it was a violation
    context TEXT NOT NULL,               -- Additional context as JSON
    
    -- Remediation
    remediation_required BOOLEAN DEFAULT TRUE,
    remediation_action TEXT,              -- What should be done to fix
    remediation_due_date INTEGER,         -- When remediation should be complete
    remediation_status TEXT DEFAULT 'open', -- 'open', 'in_progress', 'resolved', 'waived'
    
    -- Evidence bundle reference
    bundle_id TEXT,
    
    created_at INTEGER DEFAULT (strftime('%s', 'now')),
    resolved_at INTEGER,
    resolved_by TEXT
);

-- Bundle generation templates
CREATE TABLE bundle_templates (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    template_type TEXT NOT NULL,          -- 'diagnostic_report', 'legal_produced', 'incident_response'
    
    -- Template configuration
    event_types TEXT NOT NULL,           -- Comma-separated event types to include
    time_range_hours INTEGER DEFAULT 24,   -- Time range of events to include
    include_artifacts BOOLEAN DEFAULT TRUE,
    include_timestamp_claims BOOLEAN DEFAULT TRUE,
    
    -- Export configuration
    default_format TEXT DEFAULT 'zip',
    default_retention_days INTEGER DEFAULT 2555,
    
    created_at INTEGER DEFAULT (strftime('%s', 'now')),
    created_by TEXT NOT NULL
);

-- Indexes for evidence chain integrity
CREATE UNIQUE INDEX idx_evidence_chain_head_hash ON evidence_chain(head_hash);
CREATE INDEX idx_evidence_chain_timestamp ON evidence_chain(timestamp);
CREATE INDEX idx_evidence_chain_event_type ON evidence_chain(event_type);
CREATE INDEX idx_evidence_chain_event_id ON evidence_chain(event_id);

-- Indexes for bundle management
CREATE INDEX idx_evidence_bundles_created_at ON evidence_bundles(created_at);
CREATE INDEX idx_evidence_bundles_type ON evidence_bundles(bundle_type);
CREATE INDEX idx_evidence_bundles_purpose ON evidence_bundles(purpose);

-- Full-text search for bundle discovery
CREATE VIRTUAL TABLE evidence_bundles_fts USING fts5(
    description, purpose, created_by,
    content='evidence_bundles',
    content_rowid='rowid'
);

-- Indexes for evidence queries
CREATE INDEX idx_timestamp_claims_event_id ON timestamp_claims(event_id);
CREATE INDEX idx_transmission_events_document ON transmission_events(document_unit_id);
CREATE INDEX idx_transmission_events_timestamp ON transmission_events(sent_timestamp);
CREATE INDEX idx_transformation_events_source ON transformation_events(source_hash);
CREATE INDEX idx_transformation_events_target ON transformation_events(target_hash);
CREATE INDEX idx_retrieval_queries_bundle ON retrieval_queries(bundle_id);
CREATE INDEX idx_policy_violations_severity ON policy_violations(severity);
CREATE INDEX idx_policy_violations_status ON policy_violations(remediation_status);
CREATE INDEX idx_policy_violations_type ON policy_violations(violation_type);