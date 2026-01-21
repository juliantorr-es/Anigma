# Database Architecture & Governance Guide

## Overview

Anigma's database architecture implements a three-tier system with built-in governance retention, designed for court-safe evidence storage and efficient, bounded growth management.

## Architecture Components

### Core Governance Layer (Production-Hardened)

#### AnigmaCore
- ECS primitives for entity modeling
- Component system for structural composition
- Job/workflow model for concurrency
- Scheduler for managed execution

#### DatabaseCore
- Content-addressed artifact store with hash-based deduplication
- Master ledger with segmented time-bounded storage
- WAL management and VACUUM scheduling
- Semantic search with full audit trail

#### ContractsCore
- Policy definitions and versioned schemas
- Contract artifact tracking for public surfaces
- Validation rules for cross-module boundaries

### Capability Layer (Feature-Rich)

#### HarmoniaModule
- Inference and policy enforcement
- Court-safe evidence bundling
- CLI governance and audit trail

#### DiaplasionModule, OutlineumModule, AccessumModule, etc.
- Domain-specific workflows with content-addressed storage
- Media processing and access management
- Content generation and outline creation

## Database Implementation Details

### Content-Addressed Storage

The content-addressed artifact store ensures deduplication and efficient storage:

```sql
CREATE TABLE content_addressed_artifacts (
    content_hash TEXT PRIMARY KEY,
    payload_data BLOB,
    payload_size INTEGER,
    hash_algorithm TEXT,
    is_compressed BOOLEAN DEFAULT FALSE,
    first_seen_at REAL,
    reference_count INTEGER DEFAULT 0,
    indexed_at REAL DEFAULT (julianday('now'))
);
```

- **Deduplication**: Payloads with identical SHA256 hashes share storage
- **Reference Counting**: Safe deletion with reference integrity checks
- **Compression**: Optional compression for large payloads
- **Indexing**: Optimized for hash-based lookups

### Master Ledger Segmentation

Time-based segmentation prevents unbounded ledger growth:

- **Segments**: Hourly time windows (e.g., `seg-2025-12-29-15`)
- **Rotation**: Automatic segment creation when thresholds exceeded
- **Retention**: Archival policy for old segments (30-90 days default)
- **Queries**: Cross-segment query interface with transparent access

### Search Infrastructure

Semantic search with complete evidence recording:

- **Search Index**: Vector embeddings for text content
- **Query Audit**: Every search logged with user attribution
- **Result Tracking**: Full result audit with relevance scores and rankings
- **History Management**: Configurable retention periods for search logs

## Governance and Retention

### Retention Policy Structure

```swift
public struct RetentionPolicy {
    public let policyType: RetentionPolicyType
    public let sessionDb: SessionRetentionPolicy
    public let artifacts: ArtifactRetentionPolicy
    public let gc: GCPolicy
}
```

- **Policy Types**: Production, testing, development
- **Session DB TTL**: Configurable lifetime for temporary databases
- **Artifact TTL**: Type-specific retention with byte limits
- **GC Settings**: Batch sizes, minimum age, and max storage limits

### Governance Invariants

The system enforces critical invariants to maintain court-safe operation:

1. **Content Integrity**: No orphaned references or missing artifacts
2. **Policy Compliance**: All retention policies properly enforced
3. **Segmentation Consistency**: Master ledger segments properly maintained
4. **Audit Trail**: Search operations fully recorded and traceable
5. **Maintenance Tracking**: All housekeeping operations documented

### Automated Enforcement

- **GC Operations**: Invariant checks before/after deletions
- **Maintenance**: WAL checkpointing and VACUUM with compliance verification
- **Retention Validation**: Automatic deletion within policy boundaries

## Operational Procedures

### Daily Operations

#### 1. Automatic Housekeeping

```bash
./Scripts/helpers/harmonia-receipts.sh start daily-housekeeping
./Scripts/helpers/gated-ci.sh gates
```

#### 2. Garbage Collection

```bash
harmonia gc --dry-run  # Preview deletions
harmonia gc                # Execute with policy enforcement
```

#### 3. Database Maintenance

```bash
./Scripts/helpers/maintain.sh --analyze-only
./Scripts/helpers/maintain.sh --vacuum --aggressive
```

### Weekly Operations

```bash
./Scripts/helpers/segment --archive-older-than 30  # Archive segments older than 30 days
./Scripts/helpers/search --stats                       # Check search index health
./Scripts/helpers/gated-ci.sh full-acceptance               # Full compliance check
```

### Migration Procedures

#### Policy Updates

1. Create new policy file (`policy-v2.toml`)
2. Validate with `harmonia policy validate`
3. Apply with `harmonia policy update --file policy-v2.toml`
4. Verify with invariant check report

#### Schema Migrations

1. Create migration script in `Tools/migrations/`
2. Test in development with `./Tools/run_governed_tests.sh`
3. Apply in production with `./Scripts/helpers/gated-ci.sh apply`

### Auditing and Compliance

#### Evidence Bundle Generation

```bash
harmonia evidence-bundle --days 7 --out bundle.json
```

#### Invariant Verification

```bash
./Scripts/helpers/validate-system.sh full  # Complete system validation
./Scripts/helpers/gated-ci.sh invariants        # Check all invariants
```

#### Search Audit Trail

```bash
harmonia search --history --user admin                # Search audit
harmonia search --stats                     # Index statistics
```

## System Requirements

### Minimum Recommendations

- **Storage**: 10GB minimum for production workloads
- **Memory**: 4GB RAM for efficient WAL and cache operations
- **CPU**: 2+ cores for concurrent operations

### Performance Tuning

- **WAL Checkpointing**: Based on size (10-50MB) and time intervals
- **VACUUM**: In response to fragmentation (≥20%) or scheduled daily/weekly
- **Segment Rotation**: Default hourly segments; configurable to daily/weekly
- **Search Indexing**: Batch updates for new content; re-index on schema changes

## Failure Recovery

### Backup and Restore

```bash
# Create evidence bundle before major operations
harmonia evidence-bundle --full --pre-migration

# Restore from evidence bundle if needed
harmonia system-recover --from bundle.json
```

### Emergency Procedures

- **Lockdown Mode**: `./Scripts/helpers/daemon-manager.sh lock` for critical systems
- **Manual GC**: `harmonia gc --policy-file emergency-policy.toml` for urgent cleanup
- **Manual Segment Restore**: Search-specific segments for affected data

## Contact Support

- **Policy Questions**: Consult `Docs/governance/contract-artifacts/README.md`
- **Architectural Guidance**: Review `Docs/architecture/` directory
- **Implementation Rules**: See `Docs/ImplementationRules.md` for constraints

## Production Deployment

### Security Controls

- **File Permissions**: Restrict access to SQLite and ledger files
- **Network Controls**: No external network dependencies for core governance
- **Access Logging**: All operations are logged with full audit trail
- **Encrypted Storage**: Optional database encryption for sensitive environments

### Monitoring

- **Health Checks**: Automated invariant verification with alerts
- **Disk Usage**: Monitoring with alerts when nearing capacity bounds
- **Performance Metrics**: Query execution time and WAL growth tracking
- **Retention Audit**: Policy compliance verification and breach detection

This architecture provides court-safe evidence preservation while maintaining efficient storage usage through automated governance enforcement.