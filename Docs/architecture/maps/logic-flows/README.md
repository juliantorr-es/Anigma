# Logic Flows

**Doc ID:** LOGIC_FLOWS  
**Status:** ACTIVE  
**Owner:** Architecture Team  
**Last Updated:** 2026-05-02  
**Parent:** [Architecture Maps](../README.md)  

---

## Overview

Logic flow diagrams illustrate the **major process flows** in Anigma using Mermaid syntax. These are **not code-level call graphs** but rather **conceptual flows** showing:

1. **Authorities and Gates**: Which governance points control the flow
2. **Proof Points**: Where evidence/receipts are emitted
3. **Failure Paths**: Important error/rollback scenarios
4. **Start/End**: Clear entry and exit points

---

## Directory Structure

```
Docs/architecture/maps/logic-flows/
├── README.md                              # This file
├── media-materialization-flow.mmd        # MediaCore zero-copy flow
├── td-bootstrap-flow.mmd                  # TD descriptor generation
├── public-history-excision-flow.mmd      # Git history filtering
└── subprocess-pooling-planned-flow.mmd   # anigmad worker pooling
```

---

## Diagram Index

### 1. [media-materialization-flow.mmd](./media-materialization-flow.mmd)

**Domain:** MediaCore  
**Purpose:** Media surface materialization with zero-copy enforcement  
**Key Concepts:**
- SurfaceAuthority: Single authority per surface type
- MaterializationGate: Gate pattern for controlled materialization
- ZeroCopyProof: Proof emitted for every materialization decision
- Hot-path vs Cold-path: Performance-critical vs optional paths

**Flow Stages:**
```
Surface Request
    ↓
Authority Lookup (SurfaceAuthority)
    ↓
Gate Check (MaterializationGate.canMaterialize)
    ↓ [Hot-path: zero-copy available]
Zero-Copy Surface Return
    ↓
Proof Emission (ZeroCopyProof)
    ↓
Success
    
OR [Cold-path: materialization required]
    ↓
Gate Approval (MaterializationGate.performMaterialization)
    ↓
Materialized Surface Return
    ↓
Proof Emission (MaterializationProof)
    ↓
Success
```

**Authorities/Gates:**
- SurfaceAuthority: Validates surface type and capabilities
- MaterializationGate: Controls when materialization is allowed

**Proof/Evidence:**
- ZeroCopyProof: Emitted when zero-copy path taken
- MaterializationProof: Emitted when materialization performed

**Failure Paths:**
- Authority rejection: Invalid surface type or unauthorized access
- Gate rejection: Materialization denied (e.g., hot-path only mode)
- Resource exhaustion: Not enough memory/GPU resources

---

### 2. [td-bootstrap-flow.mmd](./td-bootstrap-flow.mmd)

**Domain:** TD System  
**Purpose:** Generate TD descriptors from existing documentation  
**Key Concepts:**
- Source of Truth: Docs/ is authoritative
- Descriptor Generation: YAML descriptors from markdown/docs
- Command Emission: Commands used are recorded for reproducibility

**Flow Stages:**
```
Start (Agent/CLI triggers bootstrap)
    ↓
Scan Docs/ directory
    ↓
Identify TD-relevant documents (tasks, epics, proofs)
    ↓
Extract metadata (id, title, priority, lane, etc.)
    ↓
Generate descriptor YAML
    ↓
Validate against td-epic.schema.json / td-task.schema.json
    ↓
Emit Bootstrap Commands (--emit-commands)
    ↓
Create/Update descriptors in Docs/td/<status>/<id>/
    ↓
Validate with validate_td_folder_system.py
    ↓
Verify with validate_td_docs_sync.py
    ↓
Success (Descriptors in sync with Docs/)
```

**Authorities/Gates:**
- Schema Validation: td-epic.schema.json, td-task.schema.json
- Structure Validation: validate_td_folder_system.py
- Sync Validation: validate_td_docs_sync.py

**Proof/Evidence:**
- Bootstrap commands: Recorded in output for reproducibility
- Validation results: Exit codes and logs from validators
- Descriptor files: Generated YAML files

**Failure Paths:**
- Schema violation: Descriptor doesn't match schema
- Structure violation: Wrong folder structure or file placement
- Sync violation: Descriptors don't match source_docs

---

### 3. [public-history-excision-flow.mmd](./public-history-excision-flow.mmd)

**Domain:** History Management  
**Purpose:** Prepare public history by filtering sensitive/private content  
**Key Concepts:**
- History Excision: Remove or rewrite git history
- Filter Criteria: What to remove, what to keep
- Safety: Dry-run before apply, backup before rewrite

**Flow Stages:**
```
Start (History excision task preparation)
    ↓
Define Filter Criteria (paths, message patterns, file patterns)
    ↓
Identify Sensitive Commits
    ↓
Create Backup (git clone --mirror, git bundle)
    ↓
Dry Run (git filter-repo --dry-run)
    ↓
Review Changes (git log, git diff)
    ↓
[If approved]
    ↓
Apply Filter (git filter-repo --force)
    ↓
Push to New Remote (git push --force)
    ↓
Validate (git fsck, build verification)
    ↓
Create Excision Proof
    ↓
Success (Public history ready)
    
[If not approved]
    ↓
Restore from Backup
    ↓
Abort
```

**Authorities/Gates:**
- Filter Definition: What constitutes sensitive content
- Dry-Run Gate: Must pass dry-run before apply
- Safety Gate: Backup must exist before rewrite

**Proof/Evidence:**
- Filter criteria: Documented in task descriptor
- Dry-run output: Saved for review
- Backup verification: Proof backup was created
- Excision proof: Proof artifact documenting what was removed

**Failure Paths:**
- Filter too broad: Removes too much (caught in dry-run review)
- Backup failure: Cannot create backup
- Apply failure: Filter-repo fails mid-rewrite
- Validation failure: Rewritten history doesn't build

---

### 4. [subprocess-pooling-planned-flow.mmd](./subprocess-pooling-planned-flow.mmd)

**Domain:** anigmad / SubprocessPooling  
**Purpose:** Warm pool management for parallel execution  
**Key Concepts:**
- ProcessPool<W>: Generic pool with type parameter W
- Worker Lifecycle: Checkout, use, checkin, recycle
- Crash Detection: Monitor and recover from worker crashes
- Deterministic Shutdown: Clean shutdown on daemon exit

**Flow Stages - Pool Initialization:**
```
Start (anigmad startup)
    ↓
Load Pool Configuration (size, worker type, timeout)
    ↓
Create PoolMetrics (observability)
    ↓
Initialize WorkerState Tracking
    ↓
Pre-warm Workers (create initial pool)
    ↓
Register with RuntimeOrchestrator
    ↓
Success (Pool ready for tasks)
```

**Flow Stages - Worker Lifecycle:**
```
Start (Task submission)
    ↓
Checkout Worker from Pool
    ↓
Validate Worker Health
    → [If unhealthy]
    |   ↓
    |   Recycle Worker (kill, create new)
    |   ↓
    |   Retry Checkout
    ↓ [If healthy]
Assign Task to Worker
    ↓
Start Heartbeat Monitoring
    ↓
Worker Executes Task
    ↓
Return Results
    ↓
Checkin Worker to Pool
    ↓
Update PoolMetrics
    ↓
Success
```

**Authorities/Gates:**
- SubprocessManager: Manages pool lifecycle (ProcessPool<W>)
- WorkerState: Tracks worker health and lifecycle
- PoolMetrics: Collects observability data
- PoolConfiguration: Defines pool sizing and behavior

**Proof/Evidence:**
- PoolMetrics: Performance and usage statistics
- WorkerState logs: Worker lifecycle events
- Crash reports: When workers crash and are recycled

**Failure Paths:**
- Worker crash: Detected by heartbeat, worker recycled
- Pool exhaustion: All workers busy, task queued
- Startup failure: Cannot create initial workers
- Resource exhaustion: System cannot allocate more workers

---

## Usage

### For Agents

1. **Understanding flows**: When working on a module, consult its logic flow diagram
2. **Proof points**: Know where evidence should be emitted
3. **Gate locations**: Understand where validation happens
4. **Failure modes**: Prepare for and handle expected failures

### For Humans

1. **Documentation**: Use diagrams to understand system behavior
2. **Onboarding**: Study flows to learn how Anigma works
3. **Troubleshooting**: Follow flows to diagnose issues

---

## Validation

### Mermaid Validation

If `mmdc` (Mermaid CLI) is installed:

```bash
# Validate all Mermaid diagrams
mmdc -i *.mmd -o /tmp/mermaid-test/ --width 1200 --height 800

# Validate specific diagram
mmdc -i media-materialization-flow.mmd -o /tmp/test.png
```

### Manual Validation

1. **Syntax Check**: Ensure valid Mermaid flow chart syntax
2. **Link Check**: All referenced authorities/gates exist
3. **Proof Check**: Proof points match actual proof artifacts
4. **Gate Check**: Gates match governance validators

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-05-02 | Initial 4 logic flows: media-materialization, td-bootstrap, public-history-excision, subprocess-pooling |
