> Historical status snapshot. This file reflects the state observed on 2026-04-21 and is not the source of truth for current status.
>
> Source of truth:
> - `td`
> - `anigma/current_build_status.txt`
> - `anigma/build_phase3_logs/`


# Contextum Phase 3 Complete: Analytics as Provable Facts

## Summary
Phase 3 implements analytics as **governed aggregates with receipts**, not dashboard vibes. Every metric is reproducible from the event stream, every anomaly is backed by explicit evidence references, and every computation produces its own receipt.

## Core Principle
**If you can't regenerate an aggregate from the event stream plus a declared parameter set, it's not an analytic—it's a rumor.**

## What Was Implemented

### 1. Analytics Rollup System ✅
Governed job that consumes telemetry events and produces immutable aggregate reports.

**Job Kind**: `context.analytics.rollup`

**Inputs**:
- Time window (start, end)
- Grouping keys (agent ID, taxonomy, repo size band)
- Rollup spec with version hash

**Outputs**:
- `AnalyticsReport` artifact with:
  - Agent metrics (latency distributions p50/p95/p99, success/failure counts, failure code distributions)
  - Index health (artifact counts, embedding coverage, index lag percentiles, pending job counts)
  - Search quality (total searches, empty results, avg result count, chunk reference rate)
- Receipt ID referencing the rollup execution
- Event range references (first/last event IDs consumed)

**Provenance**:
- `rollupSpecHash`: Deterministic hash of computation parameters
- `groupKeyHash`: Hash of grouping criteria
- `eventRangeStart/End`: Exact input event boundaries
- `reportArtifactHash`: SHA256 of serialized report
- `receiptID`: Links to governance execution

**Database Table**: `contextum_analytics_rollups`
```sql
CREATE TABLE contextum_analytics_rollups (
    id TEXT PRIMARY KEY,
    window_start INTEGER NOT NULL,
    window_end INTEGER NOT NULL,
    group_key_hash TEXT NOT NULL,
    rollup_spec_hash TEXT NOT NULL,
    event_range_start INTEGER NOT NULL,
    event_range_end INTEGER NOT NULL,
    event_count INTEGER NOT NULL,
    report_artifact_hash TEXT NOT NULL,
    receipt_id TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    UNIQUE(window_start, window_end, group_key_hash, rollup_spec_hash)
);
```

**Key Features**:
- Percentile computation uses sorted latency arrays (no estimation)
- Failure codes aggregated into distributions per agent+taxonomy+repoSizeBand
- Index lag computed from artifact commit time → embedding available time
- Search quality tracks result counts and whether chunks were actually referenced

### 2. Anomaly Detection System ✅
Governed scan that consumes rollup artifacts and produces anomaly reports with explicit evidence.

**Job Kind**: `context.analytics.anomalyScan`

**Inputs**:
- List of rollup IDs to scan
- Anomaly spec with detection rules and thresholds

**Outputs**:
- `AnomalyReport` artifacts with:
  - Detector ID (e.g., "latency_spike", "failure_rate_increase", "index_lag")
  - Subject key (which agent/taxonomy/band triggered it)
  - Severity (info/warning/critical)
  - Evidence dictionary with exact metrics that triggered detection
  - Links to source rollup IDs

**Detection Rules** (Phase 3):
1. **Latency Spike**: p95 > threshold (configurable, default 5000ms)
2. **Failure Rate Increase**: failure_count / total > threshold (default 30%)
3. **Index Lag**: p95 lag > threshold (default 300s)

**Database Table**: `contextum_anomalies`
```sql
CREATE TABLE contextum_anomalies (
    id TEXT PRIMARY KEY,
    detector_id TEXT NOT NULL,
    window_start INTEGER NOT NULL,
    window_end INTEGER NOT NULL,
    group_key_hash TEXT NOT NULL,
    anomaly_spec_hash TEXT NOT NULL,
    subject_key TEXT NOT NULL,
    severity TEXT NOT NULL,
    evidence_rollup_ids TEXT NOT NULL,
    report_artifact_hash TEXT NOT NULL,
    receipt_id TEXT NOT NULL,
    detected_at INTEGER NOT NULL
);
```

**Provenance**:
- `anomalySpecHash`: Hash of detection rules/thresholds used
- `evidenceRollupIDs`: Links to exact rollups that triggered detection
- `reportArtifactHash`: SHA256 of anomaly report
- `receiptID`: Governance execution reference

### 3. Workflow Integration ✅
Both analytics and anomaly detection run as governed workflows with telemetry.

**AnalyticsRollupWorkflow**:
- Executes rollup via `AnalyticsRollupSystem`
- Records duration
- Returns report artifact

**AnomalyScanWorkflow**:
- Executes scan via `AnomalyScanSystem`
- Counts critical vs warning anomalies
- Records duration
- Returns anomaly list

### 4. Database Integration ✅
All analytics operations use `ContextumDatabase` (backed by `DatabaseActor`).

**New Methods**:
- `insertAnalyticsRollup()` - Stores rollup with provenance
- `insertAnomaly()` - Stores anomaly with evidence links
- `queryTelemetryEvents()` - Fetches events for time window
- `queryAnalyticsRollups()` - Fetches rollups by ID
- `queryIndexHealthStats()` - Computes index health metrics

**Idempotency**: Rollup table has `UNIQUE(window_start, window_end, group_key_hash, rollup_spec_hash)` constraint to prevent duplicates.

## What Makes This Court-Safe

1. **Reproducibility**: Given the same event stream and rollup spec, you get the same report hash.
2. **Provenance**: Every aggregate points to its input event range and computation spec.
3. **Immutability**: Reports are artifacts with hashes, not mutable dashboard rows.
4. **Evidence Chain**: Anomalies reference rollups, rollups reference events, events reference jobs/receipts.
5. **No Hidden State**: All computation parameters are hashed and stored.

## What This Unlocks

### Explainable Decisions
- "Why did we route this task to agent X?" → Query rollup for agent X's success rate on this taxonomy.
- "Why was this flagged as an anomaly?" → Fetch anomaly report, inspect evidence dictionary.

### Regression Detection
- Compare rollup reports across time windows with same spec hash.
- If agent latency p95 increases by >50% across windows, it's measurable and traceable.

### Forensics Foundation
- Phase 4 can build failure reports by querying rollups + anomalies + events.
- All references are stable IDs, not "log lines we hope are still around."

## What's Still Missing (Phase 4+)

### Phase 4: Forensics as Artifacts
- `FailureReport` as a first-class artifact
- Root cause hypothesis generation backed by rollup evidence
- Replay workflows that reconstruct context → plan → execution

### Phase 5: Feedback Loops
- User feedback events (good/bad ratings on agent executions)
- Recommendation jobs that produce scored agent maps with explanations
- Drift detection comparing embeddings/retrieval across model versions

### Phase 6: Production Hardening
- Retention policies as governed sweep jobs
- Redaction with content replacement + hash retention
- Compaction with Merkle chains for tamper evidence
- Trust tier enforcement on analytics queries

## Integration Status

| Component | Status | Notes |
|-----------|--------|-------|
| Analytics Rollup System | ✅ Complete | Percentile computation, failure codes, index health |
| Anomaly Detection System | ✅ Complete | 3 detectors with severity levels |
| Rollup Workflows | ✅ Complete | Governed execution with receipts |
| Database Schema | ✅ Complete | Rollups + anomalies tables with provenance |
| Telemetry Event Queries | ✅ Complete | Time-windowed event fetching |
| Idempotency | ✅ Complete | UNIQUE constraint on rollup key |
| Reproducibility | ✅ Complete | Spec hashes + event range references |

## Test Criteria (Phase 3 "Done")

1. ✅ **Regeneration Test**: Run rollup twice on same event set → same report hash
2. ✅ **Provenance Test**: Every rollup row has receipt ID + event range + spec hash
3. ✅ **Anomaly Evidence Test**: Every anomaly references rollup IDs that contain the metrics
4. ⏳ **Load Test**: Rollup 10k events → completes without timeout (pending integration test)

## Next Steps

**Immediate** (to complete Phase 3 integration):
1. Wire rollup + anomaly workflows into `LocalLLMOrchestrator` as background analysis jobs
2. Add UI to display anomalies with drill-down to rollup evidence
3. Add scheduled rollup jobs (daily/hourly windows)

**Phase 4 Prep**:
1. Define `FailureReport` artifact schema
2. Implement `context.forensics.failureReport` workflow
3. Wire failure reports into orchestrator postflight on agent execution failure

---

**Implemented**: 2026-01-07  
**Status**: Phase 3 Complete — Analytics as provable facts with receipts
