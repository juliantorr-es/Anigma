--
-- GovernedPersistence_RLS.sql
-- Migration to enable Multi-Tenant Row-Level Security (RLS) and Audit Chaining.
--

-- 1. Identity & Projects
CREATE TABLE IF NOT EXISTS projects (
    project_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    configuration JSONB DEFAULT '{}'
);

CREATE TABLE IF NOT EXISTS principals (
    principal_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES projects(project_id) ON DELETE CASCADE,
    display_name TEXT NOT NULL,
    trust_tier INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Audit & Evidence with Chaining
CREATE TABLE IF NOT EXISTS audit_logs (
    receipt_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES projects(project_id) ON DELETE CASCADE,
    principal_id UUID NOT NULL REFERENCES principals(principal_id),
    operation_type TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    payload JSONB NOT NULL,
    previous_receipt_hash TEXT, -- Cryptographic link to previous record
    receipt_hash TEXT NOT NULL,  -- BLAKE3/SHA256 of this record + previous_receipt_hash
    signature TEXT,              -- Digital signature of receipt_hash
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. Content-Addressed Storage (CAS)
CREATE TABLE IF NOT EXISTS blobs (
    blob_hash TEXT PRIMARY KEY, -- BLAKE3
    sha256_hash TEXT NOT NULL UNIQUE,
    size_bytes BIGINT NOT NULL,
    storage_path TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS artifacts (
    artifact_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES projects(project_id) ON DELETE CASCADE,
    blob_hash TEXT NOT NULL REFERENCES blobs(blob_hash),
    filename_hint TEXT,
    media_type TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. Knowledge Graph (Semantic Surface)
CREATE TABLE IF NOT EXISTS entities (
    entity_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES projects(project_id) ON DELETE CASCADE,
    receipt_id UUID NOT NULL REFERENCES audit_logs(receipt_id),
    name TEXT NOT NULL,
    kind TEXT NOT NULL, -- Person, Org, Policy, Symbol
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS relationships (
    rel_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES projects(project_id) ON DELETE CASCADE,
    receipt_id UUID NOT NULL REFERENCES audit_logs(receipt_id),
    source_id UUID NOT NULL REFERENCES entities(entity_id) ON DELETE CASCADE,
    target_id UUID NOT NULL REFERENCES entities(entity_id) ON DELETE CASCADE,
    kind TEXT NOT NULL, -- GovernedBy, Accessed, etc.
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 5. Row-Level Security (RLS) Policies

-- Enable RLS on all project-specific tables
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE principals ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE artifacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE entities ENABLE ROW LEVEL SECURITY;
ALTER TABLE relationships ENABLE ROW LEVEL SECURITY;

ALTER TABLE projects FORCE ROW LEVEL SECURITY;
ALTER TABLE principals FORCE ROW LEVEL SECURITY;
ALTER TABLE audit_logs FORCE ROW LEVEL SECURITY;
ALTER TABLE artifacts FORCE ROW LEVEL SECURITY;
ALTER TABLE entities FORCE ROW LEVEL SECURITY;
ALTER TABLE relationships FORCE ROW LEVEL SECURITY;

-- Define Project Isolation Policy
-- Note: 'anigma.current_project_id' must be set in the session by DatabaseAuthority.
CREATE POLICY project_isolation_policy ON projects USING (project_id = current_setting('anigma.current_project_id', true)::uuid) WITH CHECK (project_id = current_setting('anigma.current_project_id', true)::uuid);
CREATE POLICY project_isolation_policy ON principals USING (project_id = current_setting('anigma.current_project_id', true)::uuid) WITH CHECK (project_id = current_setting('anigma.current_project_id', true)::uuid);
CREATE POLICY project_isolation_policy ON audit_logs USING (project_id = current_setting('anigma.current_project_id', true)::uuid) WITH CHECK (project_id = current_setting('anigma.current_project_id', true)::uuid);
CREATE POLICY project_isolation_policy ON artifacts USING (project_id = current_setting('anigma.current_project_id', true)::uuid) WITH CHECK (project_id = current_setting('anigma.current_project_id', true)::uuid);
CREATE POLICY project_isolation_policy ON entities USING (project_id = current_setting('anigma.current_project_id', true)::uuid) WITH CHECK (project_id = current_setting('anigma.current_project_id', true)::uuid);
CREATE POLICY project_isolation_policy ON relationships USING (project_id = current_setting('anigma.current_project_id', true)::uuid) WITH CHECK (project_id = current_setting('anigma.current_project_id', true)::uuid);

-- 6. Indices for Performance
CREATE INDEX idx_audit_logs_project ON audit_logs(project_id);
CREATE INDEX idx_audit_logs_chain ON audit_logs(project_id, created_at DESC);
CREATE INDEX idx_artifacts_project ON artifacts(project_id);
CREATE INDEX idx_entities_project ON entities(project_id);
CREATE INDEX idx_relationships_project ON relationships(project_id);
