--
-- PostgreSQL Schema for Tiered Truth Storage Substrate (Truth Tier)
-- Canonical DDL with RLS policies, job queues, and memory budget tracking
--
-- Status: DRAFT for review
-- Created: 2026-04-21
--

-- ============================================================================
-- EXTENSIONS
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pgvector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS citext;  -- Case-insensitive text

-- ============================================================================
-- CORE SCHEMA: Artifacts and Content Addressing
-- ============================================================================

CREATE TABLE artifacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Content-addressed identifier (permanent)
    content_hash VARCHAR(64) NOT NULL UNIQUE,  -- SHA-256 hex
    
    -- Artifact metadata
    artifact_type VARCHAR(32) NOT NULL,  -- e.g., "pdf", "markdown", "json"
    source_url TEXT,
    size_bytes BIGINT NOT NULL DEFAULT 0,
    
    -- Cold tier reference (CAS store path or blob ID)
    cold_storage_key TEXT UNIQUE,
    
    -- Ingestion timestamp
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    last_accessed_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    
    INDEX idx_artifacts_content_hash ON artifacts(content_hash),
    INDEX idx_artifacts_type ON artifacts(artifact_type),
    INDEX idx_artifacts_created_at ON artifacts(created_at DESC)
);

-- ============================================================================
-- MEMORY BUDGETS AND RESIDENCY
-- ============================================================================

CREATE TABLE memory_budgets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Budget owner (e.g., "refinement-pass-v1", "retrieval-service")
    owner_name VARCHAR(128) NOT NULL UNIQUE,
    
    -- Budget allocations in bytes
    hot_ecs_budget_bytes BIGINT NOT NULL DEFAULT 536870912,       -- 512 MB default
    retrieval_budget_bytes BIGINT NOT NULL DEFAULT 268435456,     -- 256 MB
    agent_context_budget_bytes BIGINT NOT NULL DEFAULT 134217728, -- 128 MB
    trace_budget_bytes BIGINT NOT NULL DEFAULT 67108864,          -- 64 MB
    projection_budget_bytes BIGINT NOT NULL DEFAULT 134217728,    -- 128 MB
    model_cache_budget_bytes BIGINT NOT NULL DEFAULT 268435456,   -- 256 MB
    refinement_budget_bytes BIGINT NOT NULL DEFAULT 536870912,    -- 512 MB
    concurrent_load_budget_bytes BIGINT NOT NULL DEFAULT 1073741824, -- 1 GB
    
    -- Pressure thresholds (percentage)
    soft_pressure_threshold INT DEFAULT 80,  -- 80%: trigger eviction
    hard_pressure_threshold INT DEFAULT 95,  -- 95%: reject new loads
    
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    
    INDEX idx_budgets_owner ON memory_budgets(owner_name)
);

-- Track current memory usage against budgets
CREATE TABLE memory_usage_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    budget_id UUID NOT NULL REFERENCES memory_budgets(id) ON DELETE CASCADE,
    
    -- Current usage in bytes per category
    hot_ecs_bytes BIGINT NOT NULL DEFAULT 0,
    retrieval_bytes BIGINT NOT NULL DEFAULT 0,
    agent_context_bytes BIGINT NOT NULL DEFAULT 0,
    trace_bytes BIGINT NOT NULL DEFAULT 0,
    projection_bytes BIGINT NOT NULL DEFAULT 0,
    model_cache_bytes BIGINT NOT NULL DEFAULT 0,
    refinement_bytes BIGINT NOT NULL DEFAULT 0,
    concurrent_load_bytes BIGINT NOT NULL DEFAULT 0,
    
    -- Pressure state at snapshot time
    pressure_state VARCHAR(16) NOT NULL DEFAULT 'normal',  -- normal, soft, hard, critical
    
    recorded_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    
    INDEX idx_snapshots_budget_id ON memory_usage_snapshots(budget_id, recorded_at DESC),
    INDEX idx_snapshots_pressure ON memory_usage_snapshots(pressure_state, recorded_at DESC)
);

-- ============================================================================
-- PAYLOAD RESIDENCY
-- ============================================================================

CREATE TYPE residency_state AS ENUM (
    'evicted',
    'loaded',
    'pinned'
);

CREATE TABLE residency_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    artifact_id UUID NOT NULL REFERENCES artifacts(id) ON DELETE CASCADE,
    budget_id UUID NOT NULL REFERENCES memory_budgets(id) ON DELETE CASCADE,
    
    -- Residency state
    state residency_state NOT NULL DEFAULT 'evicted',
    pin_count INT NOT NULL DEFAULT 0,  -- Active pins on this payload
    
    -- Atlas location (if loaded)
    atlas_name VARCHAR(128),            -- e.g., "hot-ecs-atlas"
    atlas_offset BIGINT,                -- Byte offset in atlas
    atlas_size BIGINT,                  -- Size in atlas
    
    -- Access tracking
    load_timestamp TIMESTAMP WITH TIME ZONE,
    last_pin_timestamp TIMESTAMP WITH TIME ZONE,
    unpin_timestamp TIMESTAMP WITH TIME ZONE,
    evict_timestamp TIMESTAMP WITH TIME ZONE,
    
    -- Integrity tracking
    content_checksum VARCHAR(64),       -- SHA-256 of materialized payload
    
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    
    INDEX idx_residency_artifact ON residency_records(artifact_id),
    INDEX idx_residency_budget ON residency_records(budget_id),
    INDEX idx_residency_state ON residency_records(state),
    INDEX idx_residency_pin_count ON residency_records(pin_count) WHERE pin_count > 0
);

-- ============================================================================
-- JOB QUEUE (using SKIP LOCKED for atomic dequeue)
-- ============================================================================

CREATE TYPE job_status AS ENUM (
    'pending',
    'claimed',
    'processing',
    'completed',
    'failed',
    'cancelled'
);

CREATE TYPE refinement_pass AS ENUM (
    'pass_1_hash_index',      -- Hash, index, extract text
    'pass_2_compute',         -- ANE/Metal embeddings and analysis
    'pass_3_logic',           -- Entity resolution and contradiction checking
    'pass_4_package'          -- Summary and predigesting
);

CREATE TABLE refinement_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    artifact_id UUID NOT NULL REFERENCES artifacts(id) ON DELETE CASCADE,
    budget_id UUID NOT NULL REFERENCES memory_budgets(id) ON DELETE CASCADE,
    
    -- Job definition
    pass refinement_pass NOT NULL,
    priority INT NOT NULL DEFAULT 50,  -- 0-100 (higher = more urgent)
    
    -- Status tracking
    status job_status NOT NULL DEFAULT 'pending',
    claimed_by VARCHAR(128),           -- Worker identifier when claimed
    
    -- Attempt tracking
    attempt_count INT NOT NULL DEFAULT 0,
    max_attempts INT NOT NULL DEFAULT 3,
    
    -- Results storage (JSONB for flexibility)
    result_metadata JSONB,
    error_message TEXT,
    
    -- Lifecycle timestamps
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    claimed_at TIMESTAMP WITH TIME ZONE,
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    
    -- Budget tracking
    estimated_cpu_ms INT,
    estimated_memory_bytes BIGINT,
    
    INDEX idx_jobs_status ON refinement_jobs(status) WHERE status IN ('pending', 'claimed', 'processing'),
    INDEX idx_jobs_artifact ON refinement_jobs(artifact_id),
    INDEX idx_jobs_priority ON refinement_jobs(priority DESC, created_at ASC) WHERE status = 'pending',
    INDEX idx_jobs_claimed_by ON refinement_jobs(claimed_by) WHERE status IN ('claimed', 'processing')
);

-- ============================================================================
-- DERIVED KNOWLEDGE (Warm Tier Outputs)
-- ============================================================================

CREATE TABLE extracted_text (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    artifact_id UUID NOT NULL REFERENCES artifacts(id) ON DELETE CASCADE,
    
    -- Raw text extracted from artifact
    text_content TEXT NOT NULL,
    
    -- Full-text search index
    text_vector TSVECTOR,
    
    -- Metadata
    character_count INT NOT NULL DEFAULT 0,
    language_code VARCHAR(5),
    
    -- Pipeline version for staleness detection
    pipeline_version VARCHAR(32),
    
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    
    INDEX idx_extracted_text_artifact ON extracted_text(artifact_id),
    INDEX idx_extracted_text_ts ON extracted_text USING GIN(text_vector)
);

-- Trigger to maintain full-text search vector
CREATE OR REPLACE FUNCTION update_extracted_text_vector()
RETURNS TRIGGER AS $$
BEGIN
    NEW.text_vector := to_tsvector('english', NEW.text_content);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER extracted_text_vector_update
BEFORE INSERT OR UPDATE ON extracted_text
FOR EACH ROW
EXECUTE FUNCTION update_extracted_text_vector();

-- Vector embeddings (pgvector)
CREATE TABLE embeddings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    artifact_id UUID NOT NULL REFERENCES artifacts(id) ON DELETE CASCADE,
    
    -- Embedding vector
    vector vector(1536) NOT NULL,  -- Default OpenAI embedding dimension
    
    -- Embedding metadata
    model_id VARCHAR(128) NOT NULL,  -- e.g., "nomic-embed-text"
    model_version VARCHAR(32),
    
    -- Text reference (if applicable)
    extracted_text_id UUID REFERENCES extracted_text(id) ON DELETE SET NULL,
    text_snippet TEXT,  -- Small preview, not the full text
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    
    INDEX idx_embeddings_artifact ON embeddings(artifact_id),
    INDEX idx_embeddings_model ON embeddings(model_id)
);

-- ============================================================================
-- RECEIPTS AND AUDIT TRAIL
-- ============================================================================

CREATE TABLE processing_receipts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    artifact_id UUID NOT NULL REFERENCES artifacts(id) ON DELETE CASCADE,
    job_id UUID REFERENCES refinement_jobs(id) ON DELETE SET NULL,
    
    -- Processing evidence
    pass refinement_pass NOT NULL,
    pipeline_version VARCHAR(32) NOT NULL,
    
    -- Input validation
    source_hash VARCHAR(64) NOT NULL,      -- Artifact's content_hash at processing time
    input_size_bytes BIGINT NOT NULL,
    
    -- Output tracking
    output_summary JSONB NOT NULL,         -- Key metrics: text_lines, embedding_count, etc.
    output_size_bytes BIGINT NOT NULL,
    
    -- Execution metadata
    started_at TIMESTAMP WITH TIME ZONE NOT NULL,
    completed_at TIMESTAMP WITH TIME ZONE NOT NULL,
    wall_time_ms INT NOT NULL,
    cpu_time_ms INT,
    
    -- Result status
    success BOOLEAN NOT NULL DEFAULT true,
    error_code VARCHAR(32),
    
    -- Audit trail
    executor_id VARCHAR(128),  -- Worker or service that processed
    policy_decision_id UUID,   -- Reference to governance decision
    
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    
    INDEX idx_receipts_artifact ON processing_receipts(artifact_id),
    INDEX idx_receipts_job ON processing_receipts(job_id),
    INDEX idx_receipts_pass ON processing_receipts(pass, created_at DESC),
    INDEX idx_receipts_pipeline ON processing_receipts(pipeline_version, created_at DESC)
);

-- ============================================================================
-- AUDIT AND LOGGING
-- ============================================================================

CREATE TABLE audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Action details
    action VARCHAR(64) NOT NULL,  -- e.g., 'job_claimed', 'payload_evicted', 'pressure_state_change'
    actor VARCHAR(128),           -- Worker, service, or process that triggered the action
    
    -- Related entities
    artifact_id UUID REFERENCES artifacts(id) ON DELETE SET NULL,
    job_id UUID REFERENCES refinement_jobs(id) ON DELETE SET NULL,
    budget_id UUID REFERENCES memory_budgets(id) ON DELETE SET NULL,
    
    -- Audit details
    details JSONB,
    
    -- Compliance
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    
    INDEX idx_audit_action ON audit_log(action, created_at DESC),
    INDEX idx_audit_artifact ON audit_log(artifact_id, created_at DESC)
);

-- ============================================================================
-- PERFORMANCE TUNING
-- ============================================================================

-- Vacuum strategy for time-series tables
ALTER TABLE memory_usage_snapshots SET (fillfactor = 70);
ALTER TABLE processing_receipts SET (fillfactor = 90);

-- ============================================================================
-- END OF SCHEMA
-- ============================================================================
