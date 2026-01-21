# Contextum Phases 3-4 Complete

## Status: Analytics + Forensics Implementation ✅

Successfully implemented Phase 3 (Analytics as Provable Facts) and Phase 4 (Forensics as First-Class Artifacts) for the Contextum governance and context substrate.

---

## Phase 3: Analytics as Derived Facts with Receipts ✅

### Core Principle
**Analytics are governed aggregates that can be reproduced from event streams, not dashboard vibes.**

### Implementation

#### 1. Analytics Rollup System
- **Job Kind**: `context.analytics.rollup`
- **Input**: Time window + grouping keys + rollup spec hash
- **Output**: `AnalyticsReport` artifact with receipt
- **Database**: `contextum_analytics_rollups` table with:
  - Window bounds (start/end timestamps)
  - Group key hash for deterministic grouping
  - Rollup spec hash (defines exact computation)
  - Event range references (which events were consumed)
  - Receipt ID and report artifact hash

#### 2. Anomaly Detection System
- **Job Kind**: `context.analytics.anomalyScan`
- **Input**: Rollup IDs + anomaly spec hash (detection method + thresholds)
- **Output**: `AnomalyReport` artifacts with severity classification
- **Database**: `contextum_anomalies` table with:
  - Detector ID and anomaly spec hash
  - Subject key (what triggered the anomaly)
  - Evidence rollup IDs (which aggregates support this finding)
  - Severity tier (high/medium/low)
  - Receipt ID and report artifact hash

#### 3. Minimum Viable Metrics
All metrics are **factual aggregates**, not interpretations:

- **Latency distributions** by (agentID, taxonomy, repoSizeBand)
  - p50, p95, p99 durations
- **Failure code distributions** by same grouping
  - Counts per error code, not "guesses"
- **Index lag** defined as: `artifactCommitReceiptTime → embeddingAvailableTime`
  - p50/p95 lag in seconds
- **Search quality proxies**:
  - "Search returned results" (yes/no)
  - "Agent output referenced returned chunk IDs" (if tracked)

#### 4. Reproducibility Contract
- Every rollup references **exact input event ranges** (start/end event IDs or offsets)
- Every anomaly references **exact rollup IDs** used as evidence
- Rollup spec hash ensures **same input + same spec = same output**
- Anomaly spec hash ensures **deterministic detection rules**

### What This Unlocks
- "Why did p95 latency increase?" becomes a query against rollup artifacts with receipts, not memory
- Anomalies are **provable findings** backed by explicit event ranges and detection rules
- Agent performance tracking becomes **learning signal** instead of vibes

---

## Phase 4: Forensics as First-Class Artifacts ✅

### Core Principle
**Failure investigation produces immutable artifacts with explicit evidence chains, not log spelunking.**

### Implementation

#### 1. Forensics Report Generation
- **Job Kind**: `context.forensics.failureReport`
- **Input**: 
  - Subject receipt ID (the run being investigated)
  - Optional comparison criteria (same taxonomy, same repo size, last N successful)
- **Output**: `ForensicsReport` artifact containing:
  - Timeline of events (preflight → plan → execution → postflight)
  - Evidence references (not copies) to:
    - Preflight search telemetry event ID
    - Returned chunk hashes
    - Plan artifact hash
    - Execution receipts for each step
    - Postflight outcome event ID
    - Environment correlation values
    - Index state snapshot IDs

#### 2. Root Cause Hypotheses (Evidence-Backed)
Every hypothesis includes:
- **Hypothesis type**: missingContext, lowQualityContext, modelDrift, environmentMismatch, resourceExhaustion, policyViolation, corruptedInput
- **Rule ID + spec hash**: Which detection rule fired (reproducible)
- **Evidence references**: Explicit pointers to forensic evidence entries
- **Confidence tier**: high/medium/low
- **Explanation**: Structured text backed by the referenced evidence

Example hypothesis:
```
Type: missingContext
Rule: "preflight_returned_few_chunks_v1"
Rule Spec Hash: sha256:abc123...
Evidence: [preflightSearchEvent:uuid-123, comparisonRun:uuid-456]
Confidence: high
Explanation: "Preflight returned 2 chunks after filters, while similar successful runs returned avg 15 chunks."
```

#### 3. Replay with Context Reconstruction
- **Job Kind**: `context.forensics.replay`
- **Input**: Original run ID + receipt ID + optional agent override + policy authorization
- **Process**:
  1. Look up original run's preflight search event
  2. Reconstruct context set by chunk hashes (from artifact store)
  3. Verify policy allows replay
  4. Submit orchestrator job with reconstructed context
  5. Record `ReplayLinkageComponent` with:
     - Original run ID
     - Replay run ID + receipt ID
     - Reconstruction method ("artifact_store_hash_lookup")
     - Corpus snapshot hash (if available)
     - Context set hash (hash of chunk hashes returned)
- **Output**: New receipt chain linked to original, NOT rewriting history

#### 4. Database Schema

**forensics_reports**:
```sql
reportID (PK)
subjectReceiptID (indexed)
subjectRunID, subjectWorkflowID (optional)
investigationType (failureReport | performanceAnomaly | contextDriftAnalysis | replayComparison)
reportArtifactHash (indexed)
created (timestamp)
```

**forensic_evidence**:
```sql
reportID (FK → forensics_reports)
evidenceType (preflightSearchEvent | postflightOutcomeEvent | executionReceipt | planArtifact | contextChunk | environmentSnapshot | indexStateSnapshot | comparisonRunReceipt)
referenceID (event ID, receipt ID, chunk hash, etc)
evidenceHash (optional)
description (optional)
```

**root_cause_hypotheses**:
```sql
reportID (FK → forensics_reports)
hypothesisID (PK)
hypothesisType
ruleID, ruleSpecHash (reproducible detection)
evidenceReferences (JSON array of evidence IDs)
confidence (high | medium | low)
explanation (text)
```

**replay_linkage**:
```sql
originalRunID (indexed)
replayRunID (PK)
replayReceiptID (indexed)
reconstructionMethod
corpusSnapshotHash (optional)
contextSetHash (hash of chunk hashes)
created (timestamp)
```

### What This Unlocks
- **No more log archaeology**: `generateFailureReport(receiptID)` produces a single artifact
- **Traceable causality**: Context → Plan → Execution → Output with hashes
- **Reproducible replay**: Reconstruct exact context set, run again, compare outcomes
- **Court-safe explanations**: Every hypothesis backed by explicit, immutable evidence

---

## Integration Status

| Component | Status | Notes |
|-----------|--------|-------|
| Analytics Rollup System | ✅ Complete | Governed aggregates with receipts |
| Anomaly Detection System | ✅ Complete | Spec-hashed detectors with evidence |
| Minimum Metrics Set | ✅ Complete | Latency, failures, index lag, search quality |
| Forensics Report Generation | ✅ Complete | Job-based artifact production |
| Root Cause Hypotheses | ✅ Complete | Evidence-backed, rule-based hypotheses |
| Replay with Reconstruction | ✅ Complete | Context reconstruction from chunk hashes |
| Database Schema (Phase 3) | ✅ Complete | Rollups + anomalies tables |
| Database Schema (Phase 4) | ✅ Complete | Forensics + evidence + hypotheses + replay |
| ContextumModule API | ✅ Complete | executeAnalyticsRollup, executeAnomalyScan, generateFailureReport, replayRun |

---

## What's Next: Phase 5-6

### Phase 5: Controlled Feedback Loops
- **Feedback records**: Immutable vote/rating events referencing run IDs
- **Agent recommendations**: Governed job producing scored map + explainable features
  - Sample size, success rates, failure code penalties, latency p95, recency weighting
  - Every number corresponds to a rollup row or event query
- **Embedding drift detection**: Compare retrieval behavior across model versions
  - Input: (modelFromHash, modelToHash, corpusSnapshotHash, querySetHash, driftSpecHash)
  - Output: Drift events with declared comparison sets

### Phase 6: Production Hardening
- **Retention**: Governed sweep job with deletion manifests
- **Redaction**: Replacement with irreversible redacted form + retained hash
- **Compaction**: VACUUM/optimize with Merkle-ish chain of segment hashes
- **Trust tiers**: Enforce tier gates on search results and forensic access

---

## Architecture Principles Maintained

✅ **Job-shaped, not dashboard-shaped**: All operations are governed workflows  
✅ **Receipts for everything**: Every artifact has provenance  
✅ **Reproducibility**: Same input + same spec = same output  
✅ **Evidence over interpretation**: Facts with references, not stories  
✅ **No rewriting history**: Append new branches, don't mutate  
✅ **Court-safe by design**: Model hash + input hash + output hash + signed provenance  

*Implemented: 2026-01-07*  
*Status: Phases 0-4 complete. Contextum is now a governed forensics substrate, not "search with vibes."*
