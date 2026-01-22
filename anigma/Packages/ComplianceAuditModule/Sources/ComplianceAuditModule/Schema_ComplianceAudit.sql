//
//  Schema_ComplianceAudit.sql
//  ComplianceAuditModule
//
//  Database schema for comprehensive audit trail and compliance reporting
//

-- Core audit events table
CREATE TABLE IF NOT EXISTS audit_events (
    id TEXT PRIMARY KEY,
    timestamp INTEGER NOT NULL,
    event_type TEXT NOT NULL,
    user_id TEXT,
    session_id TEXT,
    principal TEXT NOT NULL,
    operation_type TEXT,
    resource_id TEXT,
    resource_type TEXT,
    action TEXT NOT NULL,
    result TEXT,
    details TEXT, -- Base64 encoded JSON
    metadata TEXT, -- Base64 encoded JSON
    ip_address TEXT,
    user_agent TEXT,
    compliance_flags TEXT, -- Base64 encoded JSON array
    retention_period INTEGER, -- Days
    created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
    FOREIGN KEY (session_id) REFERENCES session_lifecycle(session_id)
);

-- AI operation metadata table
CREATE TABLE IF NOT EXISTS ai_operation_metadata (
    audit_event_id TEXT PRIMARY KEY,
    ai_operation_type TEXT NOT NULL,
    model_id TEXT NOT NULL,
    model_version TEXT,
    input_tokens INTEGER,
    output_tokens INTEGER,
    inference_time_ms INTEGER,
    confidence REAL,
    cost TEXT, -- Decimal as string
    prompt_hash TEXT,
    response_hash TEXT,
    safety_filters TEXT, -- Base64 encoded JSON array
    content_policy_violations TEXT, -- Base64 encoded JSON array
    created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
    FOREIGN KEY (audit_event_id) REFERENCES audit_events(id) ON DELETE CASCADE
);

-- Document access metadata table
CREATE TABLE IF NOT EXISTS document_access_metadata (
    audit_event_id TEXT PRIMARY KEY,
    access_type TEXT NOT NULL,
    document_path TEXT NOT NULL,
    document_hash TEXT,
    file_size INTEGER,
    mime_type TEXT,
    permissions TEXT,
    previous_version TEXT,
    new_version TEXT,
    access_reason TEXT,
    data_classification TEXT,
    created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
    FOREIGN KEY (audit_event_id) REFERENCES audit_events(id) ON DELETE CASCADE
);

-- Governance decision metadata table
CREATE TABLE IF NOT EXISTS governance_decision_metadata (
    audit_event_id TEXT PRIMARY KEY,
    decision_type TEXT NOT NULL,
    policy_id TEXT,
    policy_version TEXT,
    rule_ids TEXT, -- Base64 encoded JSON array
    risk_score REAL,
    blocking_factors TEXT, -- Base64 encoded JSON array
    approval_chain TEXT, -- Base64 encoded JSON array
    justification TEXT,
    appeals_process TEXT,
    automated_review INTEGER,
    created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
    FOREIGN KEY (audit_event_id) REFERENCES audit_events(id) ON DELETE CASCADE
);

-- Report generation tracking
CREATE TABLE IF NOT EXISTS audit_reports (
    report_id TEXT PRIMARY KEY,
    generated_at INTEGER NOT NULL,
    generated_by TEXT NOT NULL,
    filters TEXT NOT NULL, -- JSON encoded AuditReportFilters
    summary TEXT, -- JSON encoded AuditReportSummary
    file_path_pdf TEXT,
    file_path_csv TEXT,
    file_path_json TEXT,
    file_path_xml TEXT,
    status TEXT NOT NULL DEFAULT 'pending', -- pending, generating, completed, failed
    error_message TEXT,
    expires_at INTEGER,
    created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
);

-- Compliance metrics aggregation
CREATE TABLE IF NOT EXISTS compliance_metrics (
    metric_id TEXT PRIMARY KEY,
    date TEXT NOT NULL, -- YYYY-MM-DD format
    metric_type TEXT NOT NULL, -- event_count, user_activity, security_incidents, etc.
    metric_value REAL NOT NULL,
    breakdown_data TEXT, -- JSON for detailed breakdown
    created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
    updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
);

-- PII detection and redaction logs
CREATE TABLE IF NOT EXISTS pii_detection_log (
    detection_id TEXT PRIMARY KEY,
    audit_event_id TEXT NOT NULL,
    detected_pii_types TEXT, -- JSON array of PII types detected
    redaction_applied INTEGER DEFAULT 0,
    original_content_hash TEXT,
    redacted_content_hash TEXT,
    confidence_score REAL,
    detection_method TEXT, -- regex, ml_model, pattern_match, etc.
    created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
    FOREIGN KEY (audit_event_id) REFERENCES audit_events(id) ON DELETE CASCADE
);

-- Data classification registry
CREATE TABLE IF NOT EXISTS data_classification_registry (
    classification_id TEXT PRIMARY KEY,
    classification_name TEXT NOT NULL,
    sensitivity_level INTEGER NOT NULL, -- 1-5 scale
    retention_days INTEGER NOT NULL,
    access_controls TEXT, -- JSON array of required controls
    encryption_required INTEGER DEFAULT 0,
    audit_required INTEGER DEFAULT 1,
    created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
    updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
);

-- User consent tracking for GDPR/CCPA compliance
CREATE TABLE IF NOT EXISTS user_consent_log (
    consent_id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    consent_type TEXT NOT NULL, -- data_processing, analytics, marketing, etc.
    granted INTEGER NOT NULL,
    granted_at INTEGER NOT NULL,
    withdrawn_at INTEGER,
    consent_version TEXT NOT NULL,
    legal_basis TEXT,
    audit_event_id TEXT, -- Link to the audit event that triggered this consent
    created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
    FOREIGN KEY (audit_event_id) REFERENCES audit_events(id)
);

-- Retention policy enforcement log
CREATE TABLE IF NOT EXISTS retention_enforcement_log (
    enforcement_id TEXT PRIMARY KEY,
    policy_name TEXT NOT NULL,
    policy_version TEXT NOT NULL,
    enforced_at INTEGER NOT NULL,
    events_deleted INTEGER DEFAULT 0,
    events_expired INTEGER DEFAULT 0,
    space_freed_bytes INTEGER DEFAULT 0,
    enforcement_details TEXT, -- JSON with detailed statistics
    next_run_at INTEGER,
    created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
);

-- Security incident escalation tracking
CREATE TABLE IF NOT EXISTS security_incidents (
    incident_id TEXT PRIMARY KEY,
    severity_level TEXT NOT NULL, -- low, medium, high, critical
    status TEXT NOT NULL DEFAULT 'open', -- open, investigating, resolved, false_positive
    title TEXT NOT NULL,
    description TEXT,
    detected_at INTEGER NOT NULL,
    resolved_at INTEGER,
    related_audit_events TEXT, -- JSON array of audit event IDs
    assigned_to TEXT,
    resolution_summary TEXT,
    lessons_learned TEXT,
    created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
    updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
);

-- Performance indexes for audit queries
CREATE INDEX IF NOT EXISTS idx_audit_events_timestamp ON audit_events(timestamp);
CREATE INDEX IF NOT EXISTS idx_audit_events_event_type ON audit_events(event_type);
CREATE INDEX IF NOT EXISTS idx_audit_events_user_id ON audit_events(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_events_session_id ON audit_events(session_id);
CREATE INDEX IF NOT EXISTS idx_audit_events_principal ON audit_events(principal);
CREATE INDEX IF NOT EXISTS idx_audit_events_operation_type ON audit_events(operation_type);
CREATE INDEX IF NOT EXISTS idx_audit_events_resource_type ON audit_events(resource_type);
CREATE INDEX IF NOT EXISTS idx_audit_events_compliance_flags ON audit_events(compliance_flags);
CREATE INDEX IF NOT EXISTS idx_audit_events_retention_period ON audit_events(retention_period);
CREATE INDEX IF NOT EXISTS idx_audit_events_created_at ON audit_events(created_at);

-- Composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_audit_events_timestamp_type ON audit_events(timestamp, event_type);
CREATE INDEX IF NOT EXISTS idx_audit_events_user_timestamp ON audit_events(user_id, timestamp);
CREATE INDEX IF NOT EXISTS idx_audit_events_session_timestamp ON audit_events(session_id, timestamp);
CREATE INDEX IF NOT EXISTS idx_audit_events_principal_timestamp ON audit_events(principal, timestamp);

-- Metadata table indexes
CREATE INDEX IF NOT EXISTS idx_ai_metadata_model_id ON ai_operation_metadata(model_id);
CREATE INDEX IF NOT EXISTS idx_ai_metadata_operation_type ON ai_operation_metadata(ai_operation_type);
CREATE INDEX IF NOT EXISTS idx_doc_metadata_path ON document_access_metadata(document_path);
CREATE INDEX IF NOT EXISTS idx_doc_metadata_access_type ON document_access_metadata(access_type);
CREATE INDEX IF NOT EXISTS idx_gov_metadata_decision_type ON governance_decision_metadata(decision_type);
CREATE INDEX IF NOT EXISTS idx_gov_metadata_policy_id ON governance_decision_metadata(policy_id);

-- Report and metric indexes
CREATE INDEX IF NOT EXISTS idx_audit_reports_generated_at ON audit_reports(generated_at);
CREATE INDEX IF NOT EXISTS idx_audit_reports_generated_by ON audit_reports(generated_by);
CREATE INDEX IF NOT EXISTS idx_compliance_metrics_date_type ON compliance_metrics(date, metric_type);
CREATE INDEX IF NOT EXISTS idx_pii_detection_event_id ON pii_detection_log(audit_event_id);
CREATE INDEX IF NOT EXISTS idx_user_consent_user_id ON user_consent_log(user_id);
CREATE INDEX IF NOT EXISTS idx_retention_enforcement_policy ON retention_enforcement_log(policy_name);
CREATE INDEX IF NOT EXISTS idx_security_incidents_severity ON security_incidents(severity_level);
CREATE INDEX IF NOT EXISTS idx_security_incidents_status ON security_incidents(status);

-- Triggers for automatic maintenance

-- Update compliance metrics when audit events are inserted
CREATE TRIGGER IF NOT EXISTS update_compliance_metrics
AFTER INSERT ON audit_events
BEGIN
    INSERT OR REPLACE INTO compliance_metrics (
        metric_id, date, metric_type, metric_value, breakdown_data
    ) VALUES (
        strftime('%Y%m%d%H%M', 'now') || '-' || NEW.event_type,
        strftime('%Y-%m-%d', NEW.timestamp),
        'event_count',
        1,
        json_object('event_type', NEW.event_type, 'operation_type', NEW.operation_type)
    );
END;

-- Log retention policy enforcement when events are deleted
CREATE TRIGGER IF NOT EXISTS log_retention_enforcement
AFTER DELETE ON audit_events
BEGIN
    INSERT INTO retention_enforcement_log (
        enforcement_id, policy_name, policy_version, enforced_at, 
        events_deleted, enforcement_details
    ) VALUES (
        strftime('%Y%m%d%H%M%S', 'now') || '-' || random(),
        'default_retention_policy',
        '1.0',
        strftime('%s', 'now'),
        1,
        json_object('event_id', OLD.id, 'event_type', OLD.event_type)
    );
END;

-- Views for common audit queries

-- Daily activity summary view
CREATE VIEW IF NOT EXISTS daily_audit_summary AS
SELECT 
    date(timestamp, 'unixepoch') as activity_date,
    COUNT(*) as total_events,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(DISTINCT session_id) as unique_sessions,
    COUNT(CASE WHEN event_type = 'security_event' THEN 1 END) as security_events,
    COUNT(CASE WHEN event_type = 'ai_operation' THEN 1 END) as ai_operations,
    COUNT(CASE WHEN result = 'blocked' OR result = 'failed' THEN 1 END) as blocked_operations,
    COUNT(CASE WHEN compliance_flags LIKE '%data_modification%' THEN 1 END) as data_modifications
FROM audit_events
GROUP BY date(timestamp, 'unixepoch')
ORDER BY activity_date DESC;

-- User activity pattern view
CREATE VIEW IF NOT EXISTS user_activity_patterns AS
SELECT 
    user_id,
    COUNT(*) as total_activities,
    MIN(timestamp) as first_activity,
    MAX(timestamp) as last_activity,
    COUNT(DISTINCT date(timestamp, 'unixepoch')) as active_days,
    COUNT(CASE WHEN event_type = 'ai_operation' THEN 1 END) as ai_operations,
    COUNT(CASE WHEN event_type = 'document_access' THEN 1 END) as document_accesses,
    COUNT(CASE WHEN event_type = 'governance_decision' THEN 1 END) as governance_decisions
FROM audit_events
WHERE user_id IS NOT NULL
GROUP BY user_id
ORDER BY total_activities DESC;

-- AI usage statistics view
CREATE VIEW IF NOT EXISTS ai_usage_statistics AS
SELECT 
    a.model_id,
    COUNT(*) as total_operations,
    AVG(b.inference_time_ms) as avg_inference_time,
    SUM(b.input_tokens) as total_input_tokens,
    SUM(b.output_tokens) as total_output_tokens,
    COUNT(DISTINCT a.user_id) as unique_users,
    MIN(a.timestamp) as first_use,
    MAX(a.timestamp) as last_use
FROM audit_events a
JOIN ai_operation_metadata b ON a.id = b.audit_event_id
WHERE a.event_type = 'ai_operation'
GROUP BY a.model_id
ORDER BY total_operations DESC;

-- Governance effectiveness view
CREATE VIEW IF NOT EXISTS governance_effectiveness AS
SELECT 
    DATE(b.timestamp/86400, 'unixepoch') as decision_date,
    b.decision_type,
    COUNT(*) as total_decisions,
    COUNT(CASE WHEN b.decision_type = 'blocked' THEN 1 END) as blocked_operations,
    AVG(b.risk_score) as avg_risk_score,
    COUNT(DISTINCT b.policy_id) as policies_applied
FROM audit_events a
JOIN governance_decision_metadata b ON a.id = b.audit_event_id
WHERE a.event_type = 'governance_decision'
GROUP BY decision_date, b.decision_type
ORDER BY decision_date DESC;

-- Document access patterns view
CREATE VIEW IF NOT EXISTS document_access_patterns AS
SELECT 
    b.document_path,
    b.access_type,
    COUNT(*) as access_count,
    COUNT(DISTINCT a.user_id) as unique_users,
    MAX(a.timestamp) as last_accessed,
    MIN(a.timestamp) as first_accessed,
    COUNT(CASE WHEN b.access_type IN ('write', 'delete', 'modify') THEN 1 END) as modification_count
FROM audit_events a
JOIN document_access_metadata b ON a.id = b.audit_event_id
WHERE a.event_type = 'document_access'
GROUP BY b.document_path, b.access_type
ORDER BY access_count DESC;