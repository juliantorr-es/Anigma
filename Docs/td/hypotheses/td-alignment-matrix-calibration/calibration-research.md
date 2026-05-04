# Alignment Diagnostic Matrix Calibration Research

**Task ID**: td-alignment-matrix-calibration  
**Status**: In Progress  
**Date**: 2025-01-XX  
**Priority**: P1

---

## Executive Summary

The alignment diagnostic matrix workflow is operational but noisy. Baseline counts show P0=5 (all real), P1=213 (mostly false positives from meta-discussion), P2=0. The primary noise source is the zero-copy claim scanner flagging **doctrine, research, and proof documents** that define, limit, or criticize "zero-copy" claims rather than asserting them.

---

## Baseline Counts

| Severity | Count | Status |
|---|---|---|
| P0 | 5 | All verified as real findings |
| P1 | 213 | Contains significant noise |
| P2 | 0 | None |
| Informational | 0 | None |

---

## P0 Findings (All Real)

All 5 P0 findings are **sidecar readiness gaps** for executable products:

| ID | Subject | Type | Misalignment | Owner TD |
|---|---|---|---|---|
| ADM-0001 | AnigmaSidecar | executable_product | Product build/readiness is not equivalent to governed sidecar health. | N/A (infrastructure) |
| ADM-0002 | SidecarOfficeService | executable_product | Product build/readiness is not equivalent to governed sidecar health. | N/A (infrastructure) |
| ADM-0003 | SidecarPDFService | executable_product | Product build/readiness is not equivalent to governed sidecar health. | N/A (infrastructure) |
| ADM-0004 | SidecarTranslateService | executable_product | Product build/readiness is not equivalent to governed sidecar health. | N/A (infrastructure) |
| ADM-0006 | PDFSidecarExecutable | executable_product | Product build/readiness is not equivalent to governed sidecar health. | N/A (infrastructure) |

**Note**: These are infrastructure-level findings that require sidecar readiness receipt implementation. They are **not** false positives and must remain visible.

---

## P1 Clusters by Diagnostic Class

### 1. Sidecar Readiness Gaps: 0 (in P1)
- All sidecar findings are correctly P0

### 2. Native Leakage Graph Paths: 1 finding
- **ADM-0007**: `ExecutionCore` target reaches native dependency `'HardwareAuthority'`
- **Type**: Graph-backed, real finding
- **Status**: True positive, must be preserved

### 3. Zero-Copy Overclaims: 212 findings
- **Pattern**: All flagged by `zero-copy|zero copy|no-copy` regex in `claim_audit_patterns`
- **Breakdown by file type**:
  - Documentation/Doctrine/Research: ~180+ findings (FALSE POSITIVES)
  - Production Swift code: ~32 findings (mixed - need review)

#### P1 Zero-Copy Findings by Subject Type

| Subject Type | Count |
|---|---|
| file | 212 |
| target | 1 |

#### P1 Zero-Copy Findings by Subject Category

**Doctrine/Research/Proof Files** (FALSE POSITIVES - meta-discussion):
- `Docs/governance/CHUNK_STORAGE_RECEIPT_DOCTRINE.md`: 6
- `Docs/governance/HETEROGENEOUS_SATURATED_ARCHITECTURE_DOCTRINE.md`: 5
- `Docs/governance/alignment-diagnostic-rules.yaml`: 5
- `Docs/proofs/chunk-storage-receipt-schema.md`: 3
- `Docs/proofs/architecture-map-and-file-role-index.md`: 1
- `Docs/proofs/alignment-diagnostic-matrix-workflow.md`: 2
- `Docs/proofs/backend-normalization-heterogeneous-overlap-research.md`: 1
- `Docs/proofs/heterogeneous-saturated-architecture-research.md`: 5
- `Docs/proofs/likec4-architecture-model-adoption.md`: 3
- `Docs/research/backend-normalization-heterogeneous-overlap/assumption-map.md`: 2
- `Docs/research/backend-normalization-heterogeneous-overlap/followup-td-plan.md`: 0 (not in list)
- `Docs/research/backend-normalization-heterogeneous-overlap/materialization-and-copy-claims.md`: 7
- `Docs/research/backend-normalization-heterogeneous-overlap/misalignment-findings.md`: 2
- `Docs/research/heterogeneous-saturated-architecture/README.md`: 3
- `Docs/research/heterogeneous-saturated-architecture/anigma-doctrine-gap-analysis.md`: 9
- `Docs/research/heterogeneous-saturated-architecture/apple-silicon-metal.md`: 4
- `Docs/research/heterogeneous-saturated-architecture/cuda-unified-memory.md`: 2
- `Docs/research/heterogeneous-saturated-architecture/ecs-data-oriented-zero-copy.md`: 3
- `Docs/research/heterogeneous-saturated-architecture/example-receipts.md`: 3
- `Docs/td/TD_*`: ~20+
- `Docs/td/td-task-registry.yaml`: 14
- `Docs/schemas/*`: ~5
- `Docs/diagrams/likec4/README.md`: 2
- `Docs/architecture/maps/*`: ~10

**Total Doctrine/Research/Proof**: ~130+ files with 212-32 = **~180+ false positives**

**Production Code Files** (need manual review for true positives):
- `anigma/Packages/ContractsCore/Sources/EvidenceContracts/EvidenceContracts.swift`: 3
- `anigma/Packages/ContractsCore/Sources/EvidenceContracts/NativeWire.swift`: (not in list above, need to check)
- `anigma/Packages/ContractsCore/Sources/FoundationContracts/MediaContracts.swift`: 3
- `anigma/Packages/GlyphAtlasCapsule/Sources/GlyphAtlasCapsule/GlyphAtlasCapsule.swift`: 3
- `anigma/Packages/MediaFingerprintCapsule/Sources/MediaFingerprintCapsule/AccelerateMediaProcessor.swift`: 2
- `anigma/Packages/SaturatedModelRegistry/Sources/SaturatedModelRegistry/ModelRegistry.swift`: 3
- `anigma/Packages/SaturationInferenceCore/Sources/SaturationInferenceCore/UnifiedMemoryPool.swift`: 2
- `anigma/Packages/SaturationInferenceCore/Sources/SaturationInferenceCore/UnifiedTensor.swift`: 3
- `anigma/Packages/SaturationKit/Sources/SaturationKit/BinaryAtlasStandard.swift`: 3
- `anigma/Packages/SaturationKit/Sources/SaturationKit/DSLMemoryBridge.swift`: 3
- `anigma/Packages/SaturationKit/Sources/SaturationKit/TextProjection.swift`: 2
- `anigma/Packages/SubprocessPooling/Sources/MLWorker.swift`: 2
- `anigma/Packages/TurboQuantKVCache/Sources/TurboQuantKVCache/GPUCacheTier.swift`: (need to check)
- `anigma/Packages/VectorIndexCapsule/Sources/VectorIndexCapsule/VectorIndexCapsuleWrapper.swift`: 2
- `anigma/Packages/AnigmaSidecar/SharedMemoryAuthority.swift`: (need to check)
- `anigma/Packages/AnigmaPipeline/Pipeline/MediaFabricComponent.swift`: (need to check)
- `ExecutionCore`: (the target from ADM-0007)

**Total Production Code**: ~32 files with multiple findings each = **~50-60 findings**

---

## False-Positive Classes Identified

### Class A: Doctrine Definition Files
Files that **define** zero-copy rules and cannot be flagged for violating them:
- `Docs/governance/CHUNK_STORAGE_RECEIPT_DOCTRINE.md`
- `Docs/governance/HETEROGENEOUS_SATURATED_ARCHITECTURE_DOCTRINE.md`
- `Docs/governance/alignment-diagnostic-rules.yaml` (the rules file itself)

**Pattern**: These files use "zero-copy" to establish the rule that it must not be claimed without proof.

### Class B: Research Analysis Files  
Files that **analyze or criticize** zero-copy claims:
- `Docs/research/backend-normalization-heterogeneous-overlap/materialization-and-copy-claims.md`
- `Docs/research/backend-normalization-heterogeneous-overlap/misalignment-findings.md`
- `Docs/research/heterogeneous-saturated-architecture/*` (all files)
- `Docs/research/backend-normalization-heterogeneous-overlap/*` (all files)

**Pattern**: These files discuss what zero-copy means, where it's overclaimed, and what proof would be needed.

### Class C: Proof Schema Files
Files that **define receipt schemas** for proving zero-copy claims:
- `Docs/proofs/chunk-storage-receipt-schema.md`
- `Docs/schemas/chunk-storage-receipt.schema.json`
- `Docs/schemas/file-role-index.schema.json`
- `Docs/schemas/module-role-index.schema.json`

**Pattern**: These files define the mechanism for proving zero-copy, so they inherently mention "zero-copy".

### Class D: TD Registry and Task Files
Files that **track work** related to zero-copy calibration:
- `Docs/td/td-task-registry.yaml`
- `Docs/td/TD_*.md`
- `Docs/td/ready/p1-*/task.md`
- `Docs/td/ready/p1-*/task.yaml`
- etc.

**Pattern**: These files describe tasks to fix zero-copy overclaims - they are meta-discussion.

### Class E: Architecture Maps and Diagrams
Files that **document the architecture**:
- `Docs/architecture/maps/*`
- `Docs/diagrams/likec4/README.md`
- `Docs/proofs/alignment-diagnostic-matrix-workflow.md`
- `Docs/proofs/architecture-map-and-file-role-index.md`
- `Docs/proofs/likec4-architecture-model-adoption.md`
- `Docs/proofs/backend-normalization-heterogeneous-overlap-research.md`
- `Docs/proofs/heterogeneous-saturated-architecture-research.md`

**Pattern**: Architecture documentation that references zero-copy as a design principle.

---

## True-Positive Classes to Preserve

### Class 1: Contract Files with Zero-Copy Claims
- `anigma/Packages/ContractsCore/Sources/EvidenceContracts/*`
- `anigma/Packages/ContractsCore/Sources/FoundationContracts/*`

**Status**: If these contain "zero-copy" without corresponding receipt requirements, they ARE overclaims and should remain flagged.

### Class 2: Capsule Implementations
- `anigma/Packages/GlyphAtlasCapsule/*`
- `anigma/Packages/MediaFingerprintCapsule/*`
- `anigma/Packages/SaturatedModelRegistry/*`
- `anigma/Packages/SaturationInferenceCore/*`
- `anigma/Packages/SaturationKit/*`
- `anigma/Packages/TurboQuantKVCache/*`
- `anigma/Packages/VectorIndexCapsule/*`
- `anigma/Packages/GeometryCapsule/*`
- `anigma/Packages/AnigmaSidecar/*`
- `anigma/Packages/AnigmaPipeline/*`
- `anigma/Packages/SubprocessPooling/*`
- `anigma/Packages/AnigmaCore/*`

**Status**: Capsules that claim zero-copy without proof should remain flagged.

### Class 3: Native Leakage Path
- `ExecutionCore` -> `HardwareAuthority` (ADM-0007)

**Status**: Real graph-backed finding, must be preserved.

---

## Proposed Rule Changes

### Change 1: Add Documentation Meta-Discussion Exclusions

**File**: `Docs/governance/alignment-diagnostic-rules.yaml`

Add a new section `claim_scan_exclusions` that defines paths where claim patterns should be ignored:

```yaml
# Paths where claim patterns are meta-discussion, not actual claims
claim_scan_exclusions:
  path_patterns:
    - "Docs/governance/*.md"
    - "Docs/governance/*.yaml"
    - "Docs/research/**/*"
    - "Docs/proofs/*.md"
    - "Docs/schemas/*.json"
    - "Docs/schemas/*.yaml"
    - "Docs/td/**/*"
    - "Docs/diagrams/**/*"
    - "Docs/architecture/**/*"
  except:
    # If we want to scan specific proof files for claims (unlikely)
    - "Docs/anigma-proven-zero-copy-receipts.md"
```

### Change 2: Add Claim Context Filters

Add context-aware scanning that distinguishes:
- **Definition/Discussion**: Patterns like "do not claim zero-copy without", "zero-copy requires proof", "define zero-copy as"
- **Actual claims**: Patterns like "This is zero-copy", "achieves zero-copy", "zero-copy path"

```yaml
claim_context_filters:
  # Ignore if the line contains these exclusion phrases
  exclude_phrases:
    - "do not claim zero-copy"
    - "zero-copy requires"
    - "zero-copy must"
    - "forbids zero-copy"
    - "cannot claim zero-copy"
    - "definition of zero-copy"
    - "zero-copy means"
    - "distinguishes zero-copy"
    - "copy-minimized vs zero-copy"
    - "overclaim"
    - "overclaims"
  # Only flag if the line contains these inclusion phrases (positive claims)
  require_phrases:
    - "is zero-copy"
    - "achieves zero-copy"
    - "zero-copy path"
    - "zero-copy flow"
    - "zero-copy execution"
    - "claim zero-copy"
```

### Change 3: Distinguish Graph-Backed vs Name-Only Findings

The native leakage finding (ADM-0007) is **graph-backed** - it comes from actual dependency analysis. This is a true positive.

The zero-copy findings are **name-only** - they come from text scanning. We need to:
1. Separate the scanning logic from graph analysis
2. Only flag text-based claims in **production code files** (`.swift` files in `Sources/`)
3. Exclude text-based claims in **documentation files**

### Change 4: Add Deduplication Keys

Many findings are duplicates because the same file is scanned multiple times or the same pattern matches multiple times in one file.

Add deduplication based on:
- `(subject_file, pattern_id)` - one finding per pattern per file
- Or `(subject_file, line_number, pattern_id)` - one finding per line per pattern

### Change 5: Refine Severity Mapping

Current mapping:
- zero-copy: P1
- hardware-resident: P1  
- copy-minimized: informational
- materialization-gate: informational

Proposed mapping for text-based findings:
- zero-copy in production Swift code: P1
- hardware-resident in production Swift code: P1
- zero-copy in documentation: **exclude entirely** (not a finding)
- hardware-resident in documentation: **exclude entirely**

### Change 6: Add Accepted Exception Paths

Add to the `exceptions` list:
```yaml
exceptions:
  # Existing
  - id: "ADM-0005"
    reason: "AnigmaFoundation currently depends on HardwareAuthority for legacy bootstrap."
  # New: zero-copy claims in documentation are meta-discussion
  - id: "ADM-0008-ADM-0100"  # Range for doctrine/research zeros
    reason: "Doctrine and research files discuss zero-copy rules; not actual claims."
```

But a range-based exception is fragile. Better to use path-based exclusions.

---

## Proposed Accepted Exceptions

| Exception ID/Pattern | Reason | Scope |
|---|---|---|
| All `Docs/**` files | Meta-discussion of zero-copy | Documentation |
| `alignment-diagnostic-rules.yaml` scanning itself | Self-reference | This file |
| `*schema*.json`, `*schema*.md` | Define proof mechanisms | Schema definitions |

---

## Deduplication Strategy

### Strategy 1: File-and-Pattern Deduplication
Each unique combination of `(file_path, pattern_id)` produces at most **one** diagnostic, regardless of how many matches exist in the file.

**Implementation**: In `scan_for_patterns()`, group results by `(file, pattern_id)` and emit only one finding per group.

### Strategy 2: Line-Level Deduplication
Each unique combination of `(file_path, line_number, pattern_id)` produces at most one diagnostic.

**Implementation**: Already unique in current implementation (one match = one line), but multiple patterns can match the same line.

### Strategy 3: Diagnostic ID Ranges for Document Categories
Instead of individual exceptions, assign **exception ranges** based on subject type and path:
- ADM-0008 to ADM-0200: All Docs/ files with zero-copy pattern → **Excepted**
- ADM-0201+: Production code with zero-copy pattern → **Preserved**

But this is fragile if ordering changes.

**Recommended**: Use path-based filtering in the scanner itself, not post-hoc exception lists.

---

## Implementation Plan

### Phase 1: Update alignment-diagnostic-rules.yaml
1. Add `claim_scan_exclusions.path_patterns` with Docs/ paths
2. Add `claim_context_filters` for phrase-based exclusion
3. Keep existing `exceptions` for specific known false positives

### Phase 2: Update Scan Logic in audit.py
1. Modify `scan_for_patterns()` to accept exclusion patterns
2. Filter findings based on `claim_scan_exclusions` from rules
3. Apply context filters to exclude lines with definition/discussion patterns
4. Add deduplication by `(file_path, pattern_id)` 

### Phase 3: Separate Graph vs Text Findings
1. Graph findings (from target dependency analysis) → keep existing logic
2. Text findings (from pattern scanning) → apply exclusion filters

### Phase 4: Validate
1. Rerun matrix
2. Verify P0 count remains 5
3. Verify P1 count drops significantly (target: < 50)
4. Verify native leakage finding (ADM-0007) is preserved
5. Verify production Swift files with zero-copy claims still flagged

---

## Success Criteria

| Metric | Before | After | Status |
|---|---|---|---|
| P0 Count | 5 | 5 | Preserved |
| P1 Count | 213 | < 50 | Reduced |
| False Positives (Docs) | ~180+ | 0 | Eliminated |
| True Positives (Production) | ~33 | ~33 | Preserved |
| Native Leakage (ADM-0007) | 1 | 1 | Preserved |
| Duplicate Findings | Many | Minimal | Reduced |

---

## Next Actions

1. ✅ **Done**: Generate baseline
2. ✅ **Done**: Run current matrix  
3. ✅ **Done**: Analyze P0 and P1 clusters
4. 🔄 **In Progress**: Create this research artifact
5. ⏳ **Next**: Update `alignment-diagnostic-rules.yaml` with exclusions
6. ⏳ **Next**: Modify `scan_for_patterns()` in audit.py
7. ⏳ **Next**: Rerun and validate
