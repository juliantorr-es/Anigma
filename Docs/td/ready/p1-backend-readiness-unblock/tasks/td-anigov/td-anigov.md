# td-anigov: Resolve AnigmaGovernance compilation errors blocking BackendReadiness

**TD ID:** td-anigov
**Parent:** td-358315
**Priority:** P0
**Status:** RESEARCH
**Phase:** P1 (Backend Readiness Unblock)
**Created:** 2026-05-03

---

## Problem

After td-d65648, td-ebd744, and td-7c0153 Phase 1, generic BackendReadiness no longer appears blocked by:
- ReceiptSigner extraction (td-d65648 - DONE)
- RendererBackendContracts extraction (td-ebd744 - DONE)
- PDFSidecarExecutable reachability (td-7c0153 Phase 1 - ACCEPTED FOR MERGE)

It now **fails due to pre-existing AnigmaGovernance compilation errors** that are unrelated to the above.

## Current Validation

| Component | Exit Code | Warning Count | Classification | Notes |
|-----------|-----------|---------------|----------------|-------|
| PDFSidecarReadiness | 0 | 1 | CONTAMINATED | Binary not found - target compiled, product not exposed |
| Generic BackendReadiness | 1 | 4 | FAILED | Due to pre-existing AnigmaGovernance errors |

**Key Finding:** No directed reachability exists between BackendReadinessContractTests and PDFSidecarExecutable. PDFium linkage is proven in PDFNative, not AnigmaNativeShims. AnigmaNativeShims is a contamination risk because it carries vendorLinkerSettings.

---

## Goal

Classify and fix the AnigmaGovernance compilation errors **narrowly** so BackendReadiness can proceed to direct test execution or direct test failures.

---

## Non-Goals

- Do NOT revisit ReceiptSigner extraction unless current errors directly reference it
- Do NOT revisit RendererBackendContracts unless current errors directly reference it
- Do NOT remove PDFSidecarExecutable --skip yet
- Do NOT touch PDFSidecarReadiness except to preserve current behavior
- Do NOT introduce fake stubs
- Do NOT add @_exported imports
- Do NOT broaden umbrella imports
- Do NOT change package graph edges without pre/post graph evidence

## Critical Note

**Do NOT mark td-358315 unblocked merely because td-7c0153 Phase 1 is accepted.** BackendReadiness must be re-run after AnigmaGovernance errors are fixed, and results must be classified using FAILED/PASSED/CLEAN/CONTAMINATED. The immediate next move is not PDF anymore. It is AnigmaGovernance error extraction and classification.

**PDFSidecarReadiness classification:** CONTAMINATED (exit_code=0, warning_count=1) - This is acceptable for Phase 1 merge with documented warning, but should NOT be used as "clean" proof.

---

## Required Research Phase

### Step 1: Graph Snapshot (Pre-Change)
```bash
python3 Scripts/anigma_package_graph_audit.py snapshot \
  --output-dir .build/anigma-graph/td-anigov-pre \
  --task-id td-anigov \
  --label pre
```

### Step 2: Run Failing Command
```bash
set -o pipefail
Scripts/test_backend_readiness.sh BackendReadinessContractTests 2>&1 | tee .build/td-anigov-backend-readiness.log
status=$?
warnings=$(grep -ic "warning:" .build/td-anigov-backend-readiness.log || true)
echo "BackendReadiness exit_code=$status warning_count=$warnings"
```

### Step 3: Extract Exact AnigmaGovernance Errors
```bash
rg -n "error:|warning:" .build/td-anigov-backend-readiness.log
```

### Step 4: Classify Every Error

For each error, classify into one of:
- `missing import`
- `stale API reference`
- `wrong initializer`
- `duplicate symbol/name collision`
- `target dependency issue`
- `package graph/tier violation`
- `contract/runtime leakage`
- `implementation gap`
- `test-only mismatch`

**Expected Errors (from validation):**
- PostgresEventLog conformance isolation
- PostgresWorkQueue initializer
- InMemoryEventLog Sendable conformance

### Step 5: Write Graph Hypothesis
Create: `Docs/td/hypotheses/td-anigov/td-anigov-graph-hypothesis.md`

Format:
```markdown
# TD-Anigov Graph Hypothesis

## Errors Found
| Line | Error | Classification | Target | File |
|------|-------|----------------|--------|------|
| N | error: ... | missing import | AnigmaGovernance | File.swift:N |

## Dependency Analysis
- Error 1: affects target A via path X -> Y -> Z
- Error 2: affects target B via path X -> Y -> Z

## Proposed Fixes
- Fix 1: Add import X to File.swift (no dependency edge change)
- Fix 2: Update stale API reference (no dependency edge change)
- Fix 3: Implement missing initializer (no dependency edge change)

## Edge Change Simulations
For any proposed fix that changes dependencies:
1. Simulate: what edge would this add?
2. Check: would this create a cycle?
3. Check: would this create a tier violation?
4. If yes to either: stop, create contract extraction TD instead
```

---

## Implementation Rules

1. **Smallest safe patch only** - Apply minimal changes to resolve errors
2. **Prefer fixing stale API references** over adding new dependencies
3. **Simulate edge changes first** - If a fix would add a dependency edge:
   - Simulate or reason from graph evidence first
   - Check for cycles using `python3 Scripts/validate_no_cycles.py`
   - Check for tier violations using `python3 tools/governance/scripts/validate_tiers.py`
4. **Stop on violations** - If adding an edge creates a cycle or tier violation, stop and create a contract extraction TD instead
5. **Strict build-status language** - Use only: FAILED, PASSED, CLEAN, CONTAMINATED

---

## Validation Commands

Run all validation commands before claiming done:

```bash
# Build AnigmaGovernance target
swift build --target AnigmaGovernance

# Build AnigmaFoundation target  
swift build --target AnigmaFoundation

# Run BackendReadiness test
Scripts/test_backend_readiness.sh BackendReadinessContractTests

# Validate tiers
python3 tools/governance/scripts/validate_tiers.py

# Validate no cycles
python3 Scripts/validate_no_cycles.py .build/anigma-package.json

# Post-change graph snapshot
python3 Scripts/anigma_package_graph_audit.py snapshot \
  --output-dir .build/anigma-graph/td-anigov-post \
  --task-id td-anigov \
  --label post

# Generate graph diff
python3 Scripts/anigma_package_graph_audit.py diff \
  --from .build/anigma-graph/td-anigov-pre \
  --to .build/anigma-graph/td-anigov-post
```

---

## Proof Artifact

Create: `Docs/proofs/td-anigov-anigma-governance-backend-readiness-unblock.md`

Required sections:
- Pre-change snapshot reference
- Exact errors extracted
- Classification of each error
- Changes made (if any)
- Post-change snapshot reference
- Validation results
- Graph diff summary
- Acceptance criteria status

---

## Acceptance Criteria

| Criterion | Status | Evidence |
|----------|--------|----------|
| AnigmaGovernance errors are fixed or precisely classified | ⏭️ | Classification in hypothesis document |
| Generic BackendReadiness advances past AnigmaGovernance compilation errors | ⏭️ | Exit code 0 from test_backend_readiness.sh |
| No new cycles | ⏭️ | validate_no_cycles.py passes |
| No new tier violations | ⏭️ | validate_tiers.py passes |
| No fake stubs | ⏭️ | Code review of changes |
| No broad umbrella imports | ⏭️ | Code review of changes |
| Graph diff is documented | ⏭️ | Graph diff in proof artifact |
| td-358315 blocker list is updated based on actual validation | ⏭️ | Updated blocker list |

---

## Next Actions

1. Run Step 1-4 from Research Phase
2. Create `Docs/td/hypotheses/td-anigov/td-anigov-graph-hypothesis.md`
3. Implement fixes per classification
4. Run all validation commands
5. Create proof artifact
6. Update td-358315 blocker list

---

## Related TDs

| TD | Status | Relation |
|----|--------|----------|
| td-358315 | blocked | Parent - BackendReadiness Test Triage |
| td-d65648 | DONE | Unblocked ReceiptSigner |
| td-ebd744 | DONE | Unblocked RendererBackend |
| td-7c0153 | NOT DONE | Phase 1 accepted for merge; Phase 2 pending |
| td-anigov | RESEARCH | This TD - Unblock BackendReadiness from AnigmaGovernance errors |

---

## Files

| Path | Purpose |
|------|---------|
| `Docs/td/ready/p1-backend-readiness-unblock/tasks/td-anigov/td-anigov.md` | This TD |
| `Docs/td/hypotheses/td-anigov/td-anigov-graph-hypothesis.md` | Graph hypothesis (to be created) |
| `Docs/proofs/td-anigov-anigma-governance-backend-readiness-unblock.md` | Proof artifact (to be created) |
| `.build/anigma-graph/td-anigov-pre/` | Pre-change snapshots (to be created) |
| `.build/anigma-graph/td-anigov-post/` | Post-change snapshots (to be created) |
| `.build/td-anigov-backend-readiness.log` | Failing command output (to be created) |
