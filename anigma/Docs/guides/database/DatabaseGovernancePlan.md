# Database Governance & Retention Implementation Plan

> **"Annoyingly sane, which is exactly why it works"**
> 
> Implementation plan for semantic search placement, master/session DBs, and "please don't let my logs become a geological layer"

---

## Scope and Non-Negotiables

You're building a **governed system**, not a scrapbook. The master DB remains **append-only source of truth** for decisions and provenance. Session DBs stay **disposable per-agent scratch**. Heavy payloads (full tool outputs, big diffs, blobs) get **tiered and expired** under an explicit retention policy. When anything is deleted, **deletion itself is logged** as an auditable retention event so the chain stays intact.

---

## Phase A: Define Data Model in DatabaseCore

**DatabaseCore becomes home for schemas, migrations, and deterministic queries** that make storage bounded without making evidence untrustworthy.

### Content-Addressed Artifact Store
- **Key**: Strong hash (plus algorithm/version)  
- **Value**: Blob payload plus metadata (byte length, compression flag, first-seen timestamp)
- **Deduplication**: Tool outputs, large diffs, and "snapshots" point to artifacts by hash instead of inlining bytes everywhere
- **Result**: Stop paying 400 times for the same log spam

### Master Ledger "Thinning"
- **Tool call events**: Record tool name, inputs (or hash of inputs if large), precondition hash, file hash, result status, error signature
- **Artifact references**: Pointers to artifacts by hash reference instead of embedding bytes
- **Long-term storage**: Master ledger is what you keep indefinitely
- **Payload DB**: What you prune and compact

### Session DB Boundaries
- **Temporary storage**: Short-lived indexes, intermediate retrieval candidates, working state
- **Never pollutes master**: Session DBs should never contain master-only tables
- **Enforceable separation**: Architecture already exists, housekeeping makes it policy

---

## Phase B: Retention Policy as First-Class Contract

**Add a machine-readable retention policy** that lives with the repo, versioned, and loaded by Harmonia. Put it near the existing policy pack so it's governed the same way as permissions and tool rate limits.

### Policy Structure
```yaml
retention_policy:
  version: "1.0"
  policy_hash: "sha256:..."
  
  classes:
    session_db:
      ttl_hours: 24
      max_size_mb: 100
      
    verbose_payload:
      ttl_days: 7
      max_total_gb: 10
      
    artifacts:
      by_type:
        embeddings: { ttl_days: 365, keep_forever: false }
        tool_outputs: { ttl_days: 30, keep_forever: false }
        build_artifacts: { ttl_days: 90, keep_forever: false }
        
    master_ledger:
      keep_events_forever: true
      allow_payload_expiration: true
      
  segments:
    max_size_mb: 500
    rotation_interval_days: 30
    
  hot_runs:
    max_kept: 100
    cooldown_days: 7
```

### Deletion Definitions
- **Hard delete**: Payload bytes physically removed
- **Tombstone**: References marked as deleted but hash preserved  
- **Retention event**: Always recorded in ledger when anything is deleted
- **Policy enforcement**: Not a manual cleanup script, but enforcement of explicit rules with receipts

---

## Phase C: Implement Garbage Collector Command in Harmonia

**Add a single entry-point command** that enforces retention in a deterministic, testable way. This should behave like a sysadmin tool, not a "maybe it cleans stuff" vibe.

### GC Flow
1. **Load retention policy** from repo (versioned, hash-verified)
2. **Enumerate eligible deletions** based on policy rules
3. **Delete payloads and artifacts** that are provably safe to delete
4. **Record retention events** in master ledger (what was deleted, why, when)
5. **Run compaction** on databases that are allowed to shrink

### Eligibility Proof
**"Safe to delete" means**:
- Artifact is unreferenced by any retained ledger events, OR
- Referenced only by events whose policy class allows payload expiration while keeping hashes and metadata

**In other words**: You can delete bytes, but you don't delete the fact that bytes existed.

### Dry-Run Mode
- **Deterministic report**: Counts, bytes to be freed, which policy rule triggered each deletion class
- **Truth enforcement**: Humans love lying to themselves about disk usage; a dry-run report forces truth
- **CI integration**: Run in CI to report projected cleanup without deleting anything

---

## Phase D: SQLite Housekeeping That Won't Sabotage Performance

**If you're going to log constantly, you need to treat SQLite like a database, not a magical notebook.**

### WAL Mode Management
- **Use WAL appropriately** for concurrent access
- **Regular checkpointing**: Prevent ever-growing WAL files (infinite pile of logs in a different hat)
- **Monitor WAL size**: Alert if WAL grows beyond expected bounds

### Scheduled VACUUM Operations
- **Payload DBs and segments**: Run VACUUM after major deletions to reclaim disk space
- **Master ledger**: Casual VACUUM every five minutes is unnecessary
- **Incremental vacuum**: Consider for large DBs, but don't overcomplicate until you measure

### Query Optimization
- **Run ANALYZE** after major churn so queries don't degrade over time
- **Critical for FTS**: Full-text search and retrieval queries need accurate statistics
- **Performance monitoring**: Track query plans and execution times

---

## Phase E: Segmentation So "Master DB Forever" Doesn't Mean "Master DB Enormous"

**Keep the append-only ledger concept, but implement it as segments** when it grows beyond a threshold. Think "log segments" with a stable index, not one immortal SQLite file that eventually becomes your personal tragedy.

### Segment Architecture
- **Master index DB**: Run summaries and canonical event index
- **Time-sliced segments**: Detailed event rows in time-bounded files
- **Independent rotation**: Segments can be rotated and compacted independently
- **Evidence pointer scheme**: Hashes + IDs make cross-segment references workable

### Rotation Strategy
- **Size-based**: Rotate when segment exceeds threshold (e.g., 500MB)
- **Time-based**: Rotate on schedule (e.g., monthly) regardless of size
- **Hot/cold separation**: Recent segments stay "hot" for fast access, older segments can be compressed

### Referential Integrity
- **Cross-segment references**: Evidence pointers work across segment boundaries
- **Segment index**: Master index knows which segment contains which event ranges
- **Atomic rotation**: New segments become active only when fully initialized

---

## Phase F: Semantic Search Storage Lives in DatabaseCore, Inference Stays Outside

**DatabaseCore should store indexed representations** and expose deterministic "hybrid retrieve" queries. Model inference belongs in the MLX/Orchestrum layer.

### Storage Separation
- **DatabaseCore**: Indexed representations, FTS indexes, embedding tables with hash references
- **MLX/Orchestrum**: Embedding generation, reranking, query rewriting
- **Harmonia**: Orchestrates steps under policy, EvidenceRecorder logs everything

### Hybrid Retrieval Queries
```sql
-- Lexical candidates via SQLite FTS
SELECT document_id, bm25_score FROM document_units_fts 
WHERE document_units_fts MATCH ? 
LIMIT 50;

-- Vector candidates via embedding table  
SELECT document_id, similarity FROM embeddings 
WHERE embedding_recipe_id = ? 
AND cosine_similarity(vector, ?) > 0.7
LIMIT 50;

-- Merge and rank in application layer
```

### Retrieval Evidence
- **Query hash**: Deterministic hash of query text and parameters
- **Candidate IDs**: All considered document units with scores
- **Selected chunks**: Final results with content hashes
- **Execution trace**: Timing, model versions, policy decisions
- **Audit trail**: Every search operation becomes tamper-evident

---

## Phase G: Evidence for Housekeeping, Not Just Tool Calls

**Add a retention event type to the ledger**. Every GC run records complete context so cleanup itself is tamper-evident.

### Retention Event Schema
```json
{
  "event_type": "retention_operation",
  "policy_version_hash": "sha256:...",
  "start_timestamp": 1702531200,
  "end_timestamp": 1702534800,
  "deletions_performed": {
    "artifacts_deleted": 1247,
    "payload_bytes_freed": 2147483648,
    "sessions_expired": 15,
    "segments_compacted": 3
  },
  "deletion_categories": {
    "verbose_tool_outputs": 856,
    "build_artifacts": 234,
    "orphaned_embeddings": 157
  },
  "tombstoned_hashes": [
    "sha256:abc123...",
    "sha256:def456..."
  ],
  "refusals": [
    {
      "artifact_hash": "sha256:still_used",
      "reason": "referenced_by_retained_ledger_events"
    }
  ]
}
```

### Refusal Logging
- **Record when GC refuses deletion** because artifacts are still referenced by retained evidence
- **Debugging value**: Essential when wondering "why is my disk still full?"
- **Policy feedback**: Helps tune retention policies based on actual usage patterns

---

## Phase H: Testing and Invariants So This Doesn't Become Another Broken Subsystem

**You need tests that prove you don't accidentally destroy auditability.**

### Deduplication Tests
```swift
func testArtifactDeduplication() async throws {
    // Generate identical artifacts multiple times
    let artifact1 = try await generateToolOutput("same content")
    let artifact2 = try await generateToolOutput("same content") 
    let artifact3 = try await generateToolOutput("different content")
    
    // Assert: one artifact row for identical content, multiple references
    let artifacts = try await getArtifacts()
    XCTAssertEqual(artifacts.count, 2) // same + different
    XCTAssertEqual(artifacts[0].referenceCount, 2)
}
```

### Policy Expiration Tests
```swift
func testPolicyExpiration() async throws {
    // Create events with expirable payloads
    let eventId = try await createToolEvent(payload: "verbose log")
    
    // Advance time beyond policy TTL
    timeTravel(days: 8)
    
    // Run GC
    let gcResult = try await runGarbageCollector()
    
    // Assert: ledger event still exists, payload bytes are gone
    let ledgerEvent = try await getLedgerEvent(eventId)
    XCTAssertNotNil(ledgerEvent)
    XCTAssertNil(ledgerEvent.payloadBytes) // Deleted
    
    // Assert: retention event was recorded
    let retentionEvents = try await getRetentionEvents()
    XCTAssertTrue(retentionEvents.contains { $0.deletedPayloads.contains(eventId) })
}
```

### Session DB TTL Tests
```swift
func testSessionDBTTL() async throws {
    // Create session DB with temporary data
    let sessionId = try await createSessionDB()
    try await storeTemporaryData(sessionId, "short_lived")
    
    // Advance time beyond session TTL
    timeTravel(hours: 25)
    
    // Run session cleanup
    try await cleanupExpiredSessions()
    
    // Assert: session DB deleted, master unaffected
    XCTAssertFalse(sessionDBExists(sessionId))
    let masterEvents = try await getMasterLedgerEvents()
    XCTAssertTrue(masterEvents.count > 0) // Unaffected
}
```

### Governance Gate Invariants
- **"Payload deletion must always write a retention event"**
- **"No orphan artifact references in retained ledger"**  
- **"Master ledger never hard-deletes events"**
- **"Session DBs must not contain master-only tables"**
- **"All deletions must be traceable to specific policy rules"**

---

## Phase I: Rollout Path That Doesn't Break Your Current Dev Loop

**Start with the highest-impact, lowest-risk changes, then gradually increase scope.**

### Phase 1: Artifact Store + Hash References (Immediate Impact)
- **Add artifact store schema** to DatabaseCore
- **Switch noisiest payload fields** to hash references (tool outputs, build logs)
- **Result**: Immediate dramatic reduction in storage growth
- **Risk**: Low - just adds indirection, doesn't delete anything yet

### Phase 2: GC Command in Dry-Run Mode (Safe Validation)
- **Implement GC command** with full dry-run reporting
- **Run in CI** to produce regular cleanup projections
- **Review reports**: Ensure policies make sense before real deletion
- **Risk**: Zero - only reports, no changes to data

### Phase 3: Enable Real Deletion (Controlled Rollout)
- **Start with local development**: Enable real deletion on dev machines
- **Monitor closely**: Watch for unexpected data loss or performance issues
- **Gradual expansion**: Roll out to automated schedules after validation
- **Risk**: Medium - actual data deletion, but with extensive logging

### Phase 4: Segmentation (Scale-Driven)
- **Monitor growth patterns**: Wait until you see real segmentation benefits
- **Don't premature-segment**: If current DB is still small, wait
- **Implement when needed**: Base decision on actual measurements, not hypotheticals
- **Risk**: Low - can be deferred until clearly beneficial

---

## End State You're Aiming For

**You keep an infinite audit story without keeping infinite bytes.**

- **Always answer "what happened"** from the master ledger
- **Prove content involvement** via cryptographic hashes  
- **Keep heavy payloads** only as long as policy justifies their space cost
- **Never wake up** to find your laptop quietly became a log museum

**The system remains governed, auditable, and predictable - exactly what institutions need and what lets you sleep at night.**

---

## Integration with Existing Architecture

This plan builds on Anigma's existing strengths:

- **Evidence system**: Already has tamper-evidence chains and bundle export
- **Document units**: Already implement stable identity with provenance  
- **ML worker**: Already produces governed artifacts with hash references
- **Policy system**: Already has permission and rate limit governance

The database governance plan extends these patterns to solve the storage growth problem while maintaining the court-safe provenance that makes Anigma unique.

**Result**: A system that scales to enterprise usage without becoming a liability.