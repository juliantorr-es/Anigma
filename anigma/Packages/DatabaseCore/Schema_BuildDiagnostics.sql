-- Build Output and Diagnostics Schema
-- Treats build output as first-class artifacts with full provenance

-- Git state records for build context
CREATE TABLE IF NOT EXISTS git_states (
    id TEXT PRIMARY KEY,
    commit_hash TEXT NOT NULL,
    branch TEXT NOT NULL,
    is_dirty BOOLEAN DEFAULT FALSE,
    diff_hash TEXT,  -- Hash of git diff when working tree is dirty
    author_name TEXT,
    author_email TEXT,
    commit_timestamp INTEGER,
    message TEXT,
    
    created_at INTEGER DEFAULT (strftime('%s', 'now')),
    UNIQUE(commit_hash, branch, is_dirty, diff_hash)
);

-- Build sessions linking git state to toolchain execution
CREATE TABLE IF NOT EXISTS build_sessions (
    id TEXT PRIMARY KEY,
    git_state_id TEXT NOT NULL,
    
    -- Build configuration
    target TEXT NOT NULL,           -- Build target (e.g., "AnigmaCore", "ml-worker", "harmonia", "platform-spine")
    configuration TEXT NOT NULL,    -- "debug", "release", etc.
    toolchain TEXT NOT NULL,        -- "swift-5.9", "xcode-15.2", etc.
    
    -- Environment
    swift_version TEXT,
    xcode_version TEXT,
    platform TEXT,                 -- "macos", "linux", etc.
    architecture TEXT,              -- "arm64", "x86_64"
    
    -- Execution metadata
    command_line TEXT NOT NULL,    -- Full command line executed
    working_directory TEXT NOT NULL,
    start_timestamp INTEGER NOT NULL,
    end_timestamp INTEGER,
    exit_code INTEGER,
    
    -- Output artifacts
    artifact_path TEXT NOT NULL,   -- Path to build output artifact
    artifact_hash TEXT NOT NULL,   -- SHA256 of output artifact
    
    -- Incident tracking
    build_status TEXT DEFAULT 'running', -- 'running', 'failed', 'completed', 'aborted', 'incident_response'
    incident_ids TEXT DEFAULT '[]', -- JSON array of incident IDs
    
    -- Statistics
    total_errors INTEGER DEFAULT 0,
    total_warnings INTEGER DEFAULT 0,
    total_notes INTEGER DEFAULT 0,
    
    created_at INTEGER DEFAULT (strftime('%s', 'now')),
    completed_at INTEGER,
    FOREIGN KEY (git_state_id) REFERENCES git_states(id)
);

-- Parsed build diagnostics with precise location information
CREATE TABLE IF NOT EXISTS build_diagnostics (
    id TEXT PRIMARY KEY,
    build_session_id TEXT NOT NULL,
    
    -- Location information
    file_path TEXT NOT NULL,
    line_number INTEGER NOT NULL,
    column_number INTEGER,
    
    -- Diagnostic details
    severity TEXT NOT NULL,         -- "error", "warning", "note", "remark"
    category TEXT,                  -- "compiler", "linker", "linter", etc.
    tool TEXT NOT NULL,             -- "swiftc", "clang", "swift-build", etc.
    message TEXT NOT NULL,
    
    -- Code context (for display)
    code_snippet TEXT,              -- Surrounding code for context
    function_name TEXT,             -- Function/method containing diagnostic
    module_name TEXT,              -- Swift module
    
    -- Classification
    rule_id TEXT,                   -- Compiler rule identifier if available
    fixit_available BOOLEAN DEFAULT FALSE,
    
    created_at INTEGER DEFAULT (strftime('%s', 'now')),
    FOREIGN KEY (build_session_id) REFERENCES build_sessions(id)
);

-- Build output artifacts indexed for search
CREATE TABLE IF NOT EXISTS build_artifacts (
    id TEXT PRIMARY KEY,
    build_session_id TEXT NOT NULL,
    
    -- Artifact identification
    artifact_type TEXT NOT NULL,    -- "binary", "library", "object", "docs", etc.
    file_path TEXT NOT NULL,
    file_size INTEGER NOT NULL,
    file_hash TEXT NOT NULL,        -- SHA256 of file content
    
    -- Build metadata
    target TEXT NOT NULL,
    configuration TEXT NOT NULL,
    
    created_at INTEGER DEFAULT (strftime('%s', 'now')),
    FOREIGN KEY (build_session_id) REFERENCES build_sessions(id)
);

-- Full-text search indexes
CREATE VIRTUAL TABLE IF NOT EXISTS build_diagnostics_fts USING fts5(
    file_path, message, code_snippet, tool, severity,
    content='build_diagnostics',
    content_rowid='rowid'
);

CREATE VIRTUAL TABLE IF NOT EXISTS build_artifacts_fts USING fts5(
    file_path, artifact_type, target,
    content='build_artifacts',
    content_rowid='rowid'
);

-- Performance indexes
CREATE INDEX IF NOT EXISTS idx_build_diagnostics_session ON build_diagnostics(build_session_id);
CREATE INDEX IF NOT EXISTS idx_build_diagnostics_file ON build_diagnostics(file_path);
CREATE INDEX IF NOT EXISTS idx_build_diagnostics_severity ON build_diagnostics(severity);
CREATE INDEX IF NOT EXISTS idx_build_diagnostics_tool ON build_diagnostics(tool);
CREATE INDEX IF NOT EXISTS idx_build_diagnostics_line ON build_diagnostics(line_number);
CREATE INDEX IF NOT EXISTS idx_build_diagnostics_category ON build_diagnostics(category);
CREATE INDEX IF NOT EXISTS idx_build_diagnostics_created_at ON build_diagnostics(created_at);

CREATE INDEX IF NOT EXISTS idx_build_sessions_git_state ON build_sessions(git_state_id);
CREATE INDEX IF NOT EXISTS idx_build_sessions_target ON build_sessions(target);
CREATE INDEX IF NOT EXISTS idx_build_sessions_timestamp ON build_sessions(start_timestamp);

CREATE INDEX IF NOT EXISTS idx_git_states_commit ON git_states(commit_hash);
CREATE INDEX IF NOT EXISTS idx_git_states_branch ON git_states(branch);

-- Views for common queries
CREATE VIEW IF NOT EXISTS build_diagnostics_with_context AS
SELECT 
    bd.id, bd.file_path, bd.line_number, bd.column_number,
    bd.severity, bd.category, bd.tool, bd.message,
    bd.code_snippet, bd.function_name, bd.module_name,
    bd.rule_id, bd.fixit_available,
    bs.target, bs.configuration, bs.toolchain,
    gs.commit_hash, gs.branch, gs.is_dirty,
    bs.start_timestamp
FROM build_diagnostics bd
JOIN build_sessions bs ON bd.build_session_id = bs.id
JOIN git_states gs ON bs.git_state_id = gs.id;

-- Build Incident Tracking: Treat build failures as structured incidents
CREATE TABLE IF NOT EXISTS build_incidents (
    incident_id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    incident_type TEXT NOT NULL CHECK (incident_type IN ('compilation_failure', 'test_failure', 'performance_regression', 'security_incident')),
    severity TEXT NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    description TEXT NOT NULL,
    affected_files TEXT, -- JSON array of impacted file paths
    diagnostic_ids TEXT, -- JSON array of diagnostic IDs
    status TEXT DEFAULT 'open', -- 'open', 'investigating', 'resolved', 'closed'
    resolution_text TEXT,
    assigned_to TEXT,
    created_at INTEGER NOT NULL,
    resolved_at INTEGER,
    FOREIGN KEY (session_id) REFERENCES build_sessions(id)
);

-- Evidence Chain Heads: Cryptographic signatures for build session integrity
CREATE TABLE IF NOT EXISTS evidence_chain_heads (
    head_id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    
    -- Cryptographic signature
    signature_algorithm TEXT NOT NULL DEFAULT 'sha256', -- 'sha256', 'ed25519', etc.
    signature_value TEXT NOT NULL, -- Base64 encoded signature
    signing_key_id TEXT, -- Reference to key custody system
    timestamp_token TEXT, -- External TSA timestamp token
    
    -- Chain integrity
    previous_head_id TEXT, -- Previous head in chain
    chain_position INTEGER NOT NULL DEFAULT 0, -- Position in evidence chain
    
    -- Evidence bundle reference
    evidence_bundle_path TEXT, -- Path to generated evidence bundle
    
    -- Metadata
    created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
    expires_at INTEGER, -- When this evidence expires
    FOREIGN KEY (session_id) REFERENCES build_sessions(id),
    FOREIGN KEY (previous_head_id) REFERENCES evidence_chain_heads(head_id)
);

-- Indexes for evidence chain queries
CREATE INDEX IF NOT EXISTS idx_evidence_chain_heads_session ON evidence_chain_heads(session_id);
CREATE INDEX IF NOT EXISTS idx_evidence_chain_heads_position ON evidence_chain_heads(chain_position);
CREATE INDEX IF NOT EXISTS idx_evidence_chain_heads_created ON evidence_chain_heads(created_at);

-- Warning Budget Tracking: Control warning noise with budgets and thresholds
CREATE TABLE IF NOT EXISTS warning_budgets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL,
    budget_type TEXT NOT NULL CHECK (budget_type IN ('absolute', 'percentage', 'category', 'severity')),
    budget_limit INTEGER DEFAULT 0, -- Max warnings allowed
    current_warnings INTEGER DEFAULT 0,
    threshold_action TEXT DEFAULT 'warn' CHECK (threshold_action IN ('log', 'warn', 'fail', 'critical')),
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    FOREIGN KEY (session_id) REFERENCES build_sessions(id)
);

-- Incident tracking indexes
CREATE INDEX IF NOT EXISTS idx_build_incidents_session ON build_incidents(session_id);
CREATE INDEX IF NOT EXISTS idx_build_incidents_status ON build_incidents(status);
CREATE INDEX IF NOT EXISTS idx_build_incidents_severity ON build_incidents(severity);
CREATE INDEX IF NOT EXISTS idx_build_incidents_created_at ON build_incidents(created_at);

-- Warning budget tracking indexes
CREATE INDEX IF NOT EXISTS idx_warning_budgets_session ON warning_budgets(session_id);
CREATE INDEX IF NOT EXISTS idx_warning_budgets_updated_at ON warning_budgets(updated_at);

-- Recent incidents for monitoring and incident response
CREATE VIEW IF NOT EXISTS recent_incidents AS
SELECT 
    i.incident_id,
    i.session_id,
    i.incident_type,
    i.severity,
    i.status,
    i.description,
    i.affected_files,
    i.created_at
FROM build_incidents i
ORDER BY i.created_at DESC
LIMIT 50;

-- Recent build failures for immediate attention
CREATE VIEW IF NOT EXISTS recent_build_failures AS
SELECT 
    bd.id, bd.file_path, bd.message, bd.severity,
    bs.target, bs.exit_code, bs.start_timestamp,
    gs.commit_hash, gs.branch
FROM build_diagnostics bd
JOIN build_sessions bs ON bd.build_session_id = bs.id
WHERE bs.exit_code != 0
  AND bd.severity = 'error'
  AND bs.start_timestamp > (strftime('%s', 'now') - 86400)  -- Last 24 hours
ORDER BY bs.start_timestamp DESC;

-- ML Output Cache: Cache for ML acceleration with provenance
CREATE TABLE IF NOT EXISTS ml_output_cache (
    cache_key TEXT NOT NULL,
    output_type TEXT NOT NULL,           -- 'embedding', 'chat_completion', 'summarize', 'classify', etc.
    artifact_path TEXT,                  -- Path to generated artifact
    container_hash TEXT,                  -- Hash of container with artifacts
    created_at INTEGER NOT NULL,       -- Cache creation time
    expires_at INTEGER,                   -- Cache expiration time
    status TEXT DEFAULT 'pending',       -- 'pending', 'completed', 'verified', 'expired'
    
    -- Performance indexes
    PRIMARY KEY (cache_key),
    UNIQUE(cache_key, output_type)
);

-- Indexes for ML cache queries
CREATE INDEX IF NOT EXISTS idx_ml_cache_key ON ml_output_cache(cache_key);
CREATE INDEX IF NOT EXISTS idx_ml_cache_status ON ml_output_cache(status);
CREATE INDEX IF NOT EXISTS idx_ml_cache_expires ON ml_output_cache(expires_at);

-- Evidence Chain Integrity Queries
-- Get evidence chain for a specific build session
CREATE VIEW IF NOT EXISTS evidence_chain_for_session AS
SELECT
    ech.head_id, ech.session_id, ech.signature_algorithm, ech.signature_value,
    ech.created_at, ech.chain_position,
    bd.id as diagnostic_id, bd.file_path, bd.line_number, bd.severity, bd.message
FROM evidence_chain_heads ech
LEFT JOIN build_diagnostics bd ON ech.session_id = bd.build_session_id;

-- ============================================================================
-- File-Level Build Cache Schema (for smart caching with dependency tracking)
-- ============================================================================

-- Cache entries for individual source files
CREATE TABLE IF NOT EXISTS file_build_cache (
    id TEXT PRIMARY KEY,

    -- Source file identification
    file_path TEXT NOT NULL,                -- Relative path to source file (e.g., "Sources/AnigmaCore/main.swift")
    file_hash TEXT NOT NULL,                -- SHA256 hash of source file content

    -- Build context
    target TEXT NOT NULL,                   -- Build target (e.g., "AnigmaCore", "ml-worker")
    configuration TEXT NOT NULL,            -- "debug" or "release"

    -- Cached artifact
    object_artifact_id TEXT NOT NULL,       -- Reference to ArtifactStoreModule
    object_hash TEXT NOT NULL,              -- SHA256 of compiled object file
    object_size INTEGER NOT NULL,           -- Size in bytes

    -- Build environment
    git_state_id TEXT NOT NULL,             -- Link to git_states table
    compiler_version TEXT NOT NULL,         -- Swift compiler version (e.g., "swift-5.10")
    compiler_flags TEXT NOT NULL,           -- JSON array of compilation flags

    -- Dependencies
    imports TEXT NOT NULL,                  -- JSON array of imported modules (e.g., ["Foundation", "AnigmaCore"])
    dependency_hash TEXT NOT NULL,          -- Hash of transitive dependencies

    -- Cache management
    cached_at INTEGER NOT NULL,             -- Unix timestamp when cached
    last_accessed INTEGER NOT NULL,         -- Unix timestamp of last access (for LRU eviction)
    access_count INTEGER DEFAULT 1,         -- Number of times used

    -- Constraints
    UNIQUE(file_path, target, configuration, file_hash),
    FOREIGN KEY (git_state_id) REFERENCES git_states(id)
);

-- Dependency edges for transitive invalidation
CREATE TABLE IF NOT EXISTS file_dependencies (
    id TEXT PRIMARY KEY,

    -- Dependency relationship
    source_file TEXT NOT NULL,              -- File that imports (relative path)
    imported_module TEXT NOT NULL,          -- Module name imported (e.g., "Foundation", "AnigmaCore")
    imported_file TEXT,                     -- Resolved file path if local module (optional)

    -- Context
    target TEXT NOT NULL,                   -- Build target

    -- Metadata
    created_at INTEGER DEFAULT (strftime('%s', 'now')),

    -- Constraints
    UNIQUE(source_file, imported_module, target)
);

-- Build timing metrics for performance analysis
CREATE TABLE IF NOT EXISTS build_timing_metrics (
    id TEXT PRIMARY KEY,

    -- Session context
    build_session_id TEXT NOT NULL,         -- Link to build_sessions

    -- Timing information
    phase TEXT NOT NULL,                    -- "total", "compilation", "linking", "planning"
    duration_ms INTEGER NOT NULL,           -- Duration in milliseconds

    -- Metrics
    files_processed INTEGER DEFAULT 0,      -- Number of files in this phase
    cache_hit_rate REAL DEFAULT 0.0,        -- Cache effectiveness (0.0-1.0)

    -- Metadata
    recorded_at INTEGER NOT NULL,           -- Unix timestamp

    -- Constraints
    FOREIGN KEY (build_session_id) REFERENCES build_sessions(id)
);

-- ============================================================================
-- Indexes for Cache Tables
-- ============================================================================

-- file_build_cache indexes
CREATE INDEX IF NOT EXISTS idx_file_cache_path ON file_build_cache(file_path);
CREATE INDEX IF NOT EXISTS idx_file_cache_hash ON file_build_cache(file_hash);
CREATE INDEX IF NOT EXISTS idx_file_cache_target ON file_build_cache(target);
CREATE INDEX IF NOT EXISTS idx_file_cache_accessed ON file_build_cache(last_accessed);
CREATE INDEX IF NOT EXISTS idx_file_cache_git_state ON file_build_cache(git_state_id);

-- file_dependencies indexes
CREATE INDEX IF NOT EXISTS idx_deps_source ON file_dependencies(source_file);
CREATE INDEX IF NOT EXISTS idx_deps_imported ON file_dependencies(imported_module);
CREATE INDEX IF NOT EXISTS idx_deps_target ON file_dependencies(target);
CREATE INDEX IF NOT EXISTS idx_deps_created ON file_dependencies(created_at);

-- build_timing_metrics indexes
CREATE INDEX IF NOT EXISTS idx_timing_session ON build_timing_metrics(build_session_id);
CREATE INDEX IF NOT EXISTS idx_timing_phase ON build_timing_metrics(phase);
CREATE INDEX IF NOT EXISTS idx_timing_recorded ON build_timing_metrics(recorded_at);

-- ============================================================================
-- Views for Cache Analysis and Monitoring
-- ============================================================================

-- Cache effectiveness summary
CREATE VIEW IF NOT EXISTS cache_effectiveness AS
SELECT
    target,
    configuration,
    COUNT(*) as total_cached_files,
    SUM(object_size) as total_cache_size_bytes,
    AVG(access_count) as avg_accesses_per_file,
    AVG(CAST((julianday('now') - julianday(datetime(last_accessed, 'unixepoch'))) * 86400 AS REAL)) as avg_seconds_since_access
FROM file_build_cache
GROUP BY target, configuration;

-- Files with most cache pressure (frequently accessed)
CREATE VIEW IF NOT EXISTS high_value_cache_entries AS
SELECT
    id,
    file_path,
    target,
    object_size,
    access_count,
    last_accessed,
    (access_count / CAST((julianday('now') - julianday(datetime(cached_at, 'unixepoch'))) * 86400 + 1 AS REAL)) as accesses_per_day
FROM file_build_cache
ORDER BY accesses_per_day DESC
LIMIT 100;

-- Dependency graph for a target
CREATE VIEW IF NOT EXISTS target_dependency_graph AS
SELECT DISTINCT
    fd.source_file,
    fd.imported_module,
    fd.imported_file,
    fbc.object_size as source_object_size
FROM file_dependencies fd
LEFT JOIN file_build_cache fbc ON fd.source_file = fbc.file_path AND fd.target = fbc.target;

-- Build timing trends
CREATE VIEW IF NOT EXISTS build_timing_trends AS
SELECT
    bs.target,
    bs.configuration,
    btm.phase,
    COUNT(*) as num_builds,
    ROUND(AVG(btm.duration_ms)) as avg_duration_ms,
    ROUND(MIN(btm.duration_ms)) as min_duration_ms,
    ROUND(MAX(btm.duration_ms)) as max_duration_ms,
    ROUND(AVG(btm.cache_hit_rate) * 100) as avg_cache_hit_pct
FROM build_timing_metrics btm
JOIN build_sessions bs ON btm.build_session_id = bs.id
GROUP BY bs.target, bs.configuration, btm.phase
ORDER BY bs.target, bs.configuration, btm.phase;
