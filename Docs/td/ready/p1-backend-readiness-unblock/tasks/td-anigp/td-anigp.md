# td-anigp: Resolve AnigmaPipeline compilation errors blocking BackendReadiness

**TD ID:** td-anigp
**Parent:** td-358315
**Priority:** P0
**Status:** RESEARCH
**Phase:** P1 (Backend Readiness Unblock)
**Created:** 2026-05-03

---

## Problem

After td-d65648, td-ebd744, td-7c0153 Phase 1, and td-anigov, BackendReadiness still fails due to **pre-existing compilation errors in AnigmaPipeline** that are unrelated to the previously resolved modules.

### Current Build Status

| Target | Exit Code | Classification | Notes |
|--------|-----------|----------------|-------|
| AnigmaGovernance | 0 | CLEAN | Resolved by td-anigov |
| AnigmaPipeline | 1 | FAILED | Pre-existing errors (this TD) |
| BackendReadinessContractTests | 1 | FAILED | Blocked by AnigmaPipeline |

### Known Errors (from BackendReadinessContractTests build)

1. **MetopticonRunner.swift:47** - Missing argument for parameter 'database' in call to `ModulePipelineFactory.createRunner`
2. **PipelineContractRegistry.swift:23** - Cannot find 'PDFLayoutExtractContract' in scope

---

## Goal

Classify and fix the AnigmaPipeline compilation errors **narrowly** so BackendReadiness can proceed to direct test execution or direct test failures.

---

## Non-Goals

- Do NOT touch PDF sidecar lane (`Scripts/test_pdf_sidecar_readiness.sh`)
- Do NOT revisit ReceiptSigner unless directly referenced by current errors
- Do NOT revisit RendererBackend unless directly referenced by current errors
- Do NOT revisit AnigmaGovernance unless directly referenced by current errors
- Do NOT remove `--skip PDFSidecarExecutable` from `test_backend_readiness.sh`
- Do NOT introduce fake stubs
- Do NOT add `@_exported` imports
- Do NOT broaden umbrella imports
- Do NOT change package graph edges without pre/post graph evidence

---

## Required Research Phase

### Step 1: Graph Snapshot (Pre-Change)
```bash
cd /Users/user/Developer/GitHub/Anigma_clean
python3 Scripts/anigma_package_graph_audit.py \
  --output-dir .build/anigma-graph/td-anigp-pre snapshot
```

### Step 2: Capture Exact Errors
```bash
cd /Users/user/Developer/GitHub/Anigma_clean/anigma
set -o pipefail
swift build --target AnigmaPipeline 2>&1 | tee .build/td-anigp-anigmapipeline.log
status=$?
warnings=$(grep -ic "warning:" .build/td-anigp-anigmapipeline.log || true)
echo "AnigmaPipeline exit_code=$status warning_count=$warnings"
```

### Step 3: Extract and Classify Each Error
```bash
rg -n "error:|warning:" .build/td-anigp-anigmapipeline.log
```

**For each error, classify into one of:**
- `missing import`
- `stale API reference`
- `wrong initializer`
- `duplicate symbol/name collision`
- `target dependency issue`
- `package graph/tier violation`
- `contract/runtime leakage`
- `implementation gap`
- `test-only mismatch`

### Step 4: Write Graph Hypothesis
Create: `Docs/td/hypotheses/td-anigp/td-anigp-error-classification.md`

**Required sections:**
- Build Status (pre-fix)
- Exact Errors table with classification
- Error Detail for each error
- Graph Evidence (pre snapshot, relevant targets, proposed dependency changes, cycle/tier risk)
- Hypothesis (smallest likely fix before patching)
- Non-goals
- SwiftPM Graph Evidence Note
- Strict Build-Status Language
- Next Steps
- Files

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
6. **Document all escape hatches** - Every `@unchecked Sendable`, `@preconcurrency`, or `nonisolated` must have explicit justification

---

## Validation Commands

Run all validation commands before claiming done:

```bash
# Direct target build
swift build --target AnigmaPipeline

# Transitively check AnigmaCore
swift build --target AnigmaCore

# Run BackendReadiness test
Scripts/test_backend_readiness.sh BackendReadinessContractTests

# Validate tiers
python3 tools/governance/scripts/validate_tiers.py

# Validate no cycles
python3 Scripts/validate_no_cycles.py .build/anigma-package.json

# Post-change graph snapshot
python3 Scripts/anigma_package_graph_audit.py snapshot \
  --output-dir .build/anigma-graph/td-anigp-post

# Manual graph diff (until diff command implemented)
ls .build/anigma-graph/td-anigp-pre/anigma-target-graph.json
ls .build/anigma-graph/td-anigp-post/anigma-target-graph.json
```

---

## Proof Artifact

Create: `Docs/proofs/td-anigp-anigmapipeline-backend-readiness-unblock.md`

**Required sections:**
- Pre-change snapshot reference
- Exact errors extracted
- Classification of each error
- Why each fix is safe
- Every @unchecked Sendable / @preconcurrency / nonisolated use, if any
- Whether each such use is permanent, temporary, or requires follow-up
- Build status classifications using FAILED/PASSED/CLEAN/CONTAMINATED
- Graph diff summary (or manual comparison if diff command not available)
- Remaining BackendReadiness blockers, if any

---

## Acceptance Criteria

| Criterion | Status | Evidence |
|----------|--------|----------|
| AnigmaPipeline compile errors are fixed or precisely classified | ⏭️ | Classification in hypothesis document |
| AnigmaPipeine builds CLEAN | ⏭️ | Exit code 0 from swift build --target AnigmaPipeline |
| Generic BackendReadiness advances past AnigmaPipeline compilation errors | ⏭️ | Exit code 0 from test_backend_readiness.sh BackendReadinessContractTests |
| No fake stubs | ⏭️ | Code review of changes |
| No new dependency cycles | ⏭️ | validate_no_cycles.py passes |
| No new tier violations | ⏭️ | validate_tiers.py passes |
| No silent concurrency escape hatches | ⏭️ | Every escape hatch documented with invariant |
| Graph diff is documented | ⏭️ | Graph diff in proof artifact |
| td-358315 blocker list is updated based on actual validation | ⏭️ | Updated blocker list in td-358315 |

---

## Next Actions

1. Run Step 1-3 from Research Phase
2. Create `Docs/td/hypotheses/td-anigp/td-anigp-error-classification.md`
3. Apply fixes per classification and safety rules
4. Run all validation commands
5. Capture post-change snapshot
6. Create proof artifact
7. Update td-358315 blocker list
8. Re-run BackendReadiness to confirm unblocked

---

## Related TDs

| TD | Status | Relation |
|----|--------|----------|
| td-358315 | blocked | Parent - BackendReadiness Test Triage |
| td-d65648 | DONE | Unblocked ReceiptSigner |
| td-ebd744 | DONE | Unblocked RendererBackend |
| td-7c0153 | NOT DONE | Phase 1 accepted for merge; Phase 2 pending |
| td-anigov | DONE | Unblocked AnigmaGovernance |
| td-anigp | RESEARCH | This TD - Unblock BackendReadiness from AnigmaPipeline errors |

---

## Files

| Path | Purpose |
|------|---------|
| `Docs/td/ready/p1-backend-readiness-unblock/tasks/td-anigp/td-anigp.md` | This TD |
| `Docs/td/hypotheses/td-anigp/td-anigp-error-classification.md` | Error classification (to be created) |
| `Docs/proofs/td-anigp-anigmapipeline-backend-readiness-unblock.md` | Proof artifact (to be created) |
| `.build/anigma-graph/td-anigp-pre/` | Pre-change graph snapshots (to be created) |
| `.build/anigma-graph/td-anigp-post/` | Post-change graph snapshots (to be created) |
| `.build/td-anigp-anigmapipeline.log` | Build output (to be created) |

---

## Current Correct State

- td-d65648: **DONE**
- td-ebd744: **DONE**
- td-7c0153: **NOT DONE** (Phase 1 accepted for merge; Phase 2 native-shim isolation pending unless split)
- td-anigov: **DONE**
- td-anigp: **RESEARCH** (this TD)
- td-358315: **BLOCKED** (active blocker: td-anigp - AnigmaPipeline compilation errors)

---

## Do Not Proceed Without

1. **Evidence collection** - Graph snapshot and error extraction first
2. **Classification** - Every error classified before patching
3. **Hypothesis** - Written hypothesis explaining smallest likely fix
4. **Justification** - Every escape hatch must have explicit safety invariant

**The immediate next move is AnigmaPipeline error extraction and classification, not PDF.**
