# Database Housekeeping and Retention

## Overview

Harmonia implements bounded storage with auditable retention to prevent infinite log growth while preserving legal defensibility. The system uses a content-addressed artifact store with deduplication and append-only evidence chains.

## Architecture

### Append-Only Master Ledger
- **Evidence chain events are never deleted** - provides immutable audit trail
- All tool calls, successes, failures, and policy decisions are recorded forever
- Retention events record what cleanup occurred without destroying provenance

### Content-Addressed Artifact Store
- Large payloads stored by SHA-256 hash with automatic deduplication
- Artifacts can be compressed and expired while preserving hash references
- Evidence references artifacts by hash, not inline data

### Retention Events
- Append-only log of all cleanup operations
- Records policy hash, timestamps, deletion counts, and affected artifact hashes
- Provides forensic trail of what was cleaned up and why

## Retention Policy

The retention policy is a machine-readable TOML file that governs:

### Session Database Lifecycle
```toml
[session_db]
ttl_days = 7                    # Delete session DBs after 7 days
max_size_mb = 100               # Max size per session DB
cleanup_interval_hours = 24       # Check for cleanup every 24 hours
```

### Artifact Payload Retention
```toml
[artifacts]
default_ttl_days = 90            # Default retention for most artifacts
large_payload_threshold_mb = 10   # Payloads larger than this get shorter TTL
large_payload_ttl_days = 30       # Shorter retention for large payloads
max_total_storage_gb = 50         # Maximum total artifact storage
compression_enabled = true          # Enable compression for large artifacts
```

### Artifact-Specific Rules
```toml
[[artifacts.rules]]
pattern = "tool_result_*"
ttl_days = 30
description = "Tool output results (often large, less critical long-term)"

[[artifacts.rules]]
pattern = "diff_*"
ttl_days = 365
description = "Diffs (keep longer for change tracking)"
```

### Garbage Collection Settings
```toml
[gc]
dry_run_default = true           # Safety: default to dry-run
max_delete_per_run = 10000     # Limit deletions per run
min_age_hours = 1              # Don't delete artifacts newer than this
require_policy_hash_match = true  # Only run if policy hash matches stored state
vacuum_threshold_mb = 100        # Run VACUUM when this much space can be reclaimed
```

## Storage Model

### Artifact Storage
```sql
CREATE TABLE artifacts (
    artifact_hash TEXT PRIMARY KEY,     -- Content-addressed storage
    algorithm TEXT NOT NULL DEFAULT 'sha256',
    version INTEGER NOT NULL DEFAULT 1,
    byte_length INTEGER NOT NULL,       -- Original size
    compression_type TEXT,               -- none, lz4, etc.
    compressed_length INTEGER,            -- Compressed size if applicable
    stored_at INTEGER NOT NULL,         -- When stored
    last_referenced_at INTEGER,         -- Last time referenced
    reference_count INTEGER DEFAULT 0,   -- Active references
    payload BLOB                        -- Actual data (compressed or not)
);
```

### Evidence to Artifact Links
```sql
CREATE TABLE evidence_artifacts (
    evidence_id TEXT NOT NULL,
    artifact_hash TEXT NOT NULL,
    reference_type TEXT NOT NULL,          -- 'result', 'parameter', 'diff'
    created_at INTEGER NOT NULL,
    PRIMARY KEY (evidence_id, artifact_hash),
    FOREIGN KEY (evidence_id) REFERENCES evidence_chain(evidence_id),
    FOREIGN KEY (artifact_hash) REFERENCES artifacts(artifact_hash)
);
```

### Retention Events
```sql
CREATE TABLE retention_events (
    event_id TEXT PRIMARY KEY,
    policy_hash TEXT NOT NULL,           -- Stable hash of policy contents
    policy_version TEXT NOT NULL,
    event_type TEXT NOT NULL,            -- 'gc_run', 'session_cleanup'
    started_at INTEGER NOT NULL,
    completed_at INTEGER NOT NULL,
    artifacts_deleted INTEGER DEFAULT 0,
    artifacts_freed_bytes INTEGER DEFAULT 0,
    sessions_deleted INTEGER DEFAULT 0,
    affected_artifact_hashes TEXT,          -- JSON array of deleted hashes
    retention_summary TEXT,                  -- JSON summary of cleanup
    created_by TEXT NOT NULL DEFAULT 'harmonia-gc'
);
```

## Garbage Collection Process

### 1. Policy Validation
- Compute stable hash of retention policy contents
- Compare against last stored policy hash (if required)
- Reject run if policy has changed without manual acknowledgment

### 2. Session Database Cleanup
- Identify expired session databases based on TTL
- Delete session DB files that are past retention period
- Record cleanup statistics in retention event

### 3. Artifact Cleanup
- Find artifacts eligible for deletion based on:
  - Age (older than TTL)
  - Reference count (no active references)
  - Storage limits (total size caps)
  - Pattern-specific rules
- Delete payload bytes while preserving hash records
- Update reference counts and timestamps

### 4. Database Maintenance
- Run VACUUM on artifact store when enough space can be reclaimed
- Perform WAL checkpointing to manage write-ahead log size
- Avoid aggressive VACUUM on append-only master ledger

## Safety Guarantees

### Court-Safe Evidence
- **Master ledger events are never deleted** - complete audit trail preserved
- **Retention events provide forensic trail** of what was cleaned up
- **Artifact hashes remain even when payloads are deleted**
- **Policy hash validation prevents silent policy changes**

### Bounded Storage
- **Automatic cleanup of temporary session databases**
- **Configurable TTL for different artifact types**
- **Storage limits prevent infinite growth**
- **Compression reduces storage footprint**

### Deterministic Behavior
- **Dry-run mode shows exactly what would be deleted**
- **Policy-driven decisions are reproducible**
- **Batch processing with configurable limits**
- **Stable hashing of policy contents**

## CLI Usage

### Run Garbage Collection
```bash
# Dry run (default safe mode)
harmonia gc

# Show what would be deleted
harmonia gc --dry-run

# Apply cleanup with custom policy
harmonia gc --apply --policy-file custom-policy.toml

# Override limits
harmonia gc --apply --max-delete 5000 --min-age-hours 2
```

### Retention Policy Management
- Default policy: `Sources/HarmoniaModule/Config/RetentionPolicy.toml`
- Custom policy: `--policy-file path/to/policy.toml`
- Policy validation ensures stable, auditable configuration

## Integration with Evidence Chain

The garbage collector integrates seamlessly with the existing evidence recording system:

1. **EvidenceRecorder** stores large results as artifacts by hash
2. **ArtifactStore** provides deduplication and compression
3. **GarbageCollector** enforces retention policy
4. **Retention events** provide audit trail of cleanup

This maintains the core governance principle: **"policy decides, writes are gated, everything is logged"** while adding sustainable storage management.