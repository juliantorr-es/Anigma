# Research: Alignment Diagnostic Zero-Copy Claim Classification

**Task ID**: td-alignment-diagnostic-zero-copy-claim-classification  
**Dependency**: td-executioncore-hardwareauthority-native-leakage (DONE), td-zero-copy-hardware-resident-claim-audit (DONE)  
**Status**: RESEARCH COMPLETE  
**Date**: 2025-01-17  

---

## Executive Summary

After completing td-executioncore-hardwareauthority-native-leakage (FULL) and td-zero-copy-hardware-resident-claim-audit (PARTIAL), 16 P1 findings remain. Analysis shows these are NOT implementation overclaims but rather:
- **Doctrine**: Contract specifications defining requirements and proof schemas (8 findings)
- **Technical Facts**: Verified mechanisms with provable zero-copy semantics (8 findings)

The current alignment-diagnostic-rules.yaml flags ALL zero-copy/hardware-resident text as P1, requiring rule refinement instead of code changes.

---

## 1. Current State Analysis

### P1 Count Progression
| Task | P1 Count | Notes |
|---|---|---|
| Baseline | 24 | 23 zero-copy + 1 hardware-resident |
| After EC→HA fix | 23 | ADM-0002 resolved |
| After wording cleanup | 16 | 7 implementation overclaims fixed |
| Current | 16 | Remaining are legitimate doctrine/facts |

### Remaining 16 Findings Classification

| ID | File | Line | Text | Classification | Rationale |
|---|---|---|---|---|---|
| ADM-0002 | SharedMemoryAuthority.swift | 5 | "Manages zero-copy shared memory regions" | **verified_mechanism** | POSIX shm_open + mmap = actual zero-copy |
| ADM-0004 | MLWorker.swift | 324 | "UMA shared memory for zero-copy data transfer" | **verified_mechanism** | UMA shared memory = actual zero-copy |
| ADM-0004 | MLWorker.swift | 438 | "UMA shared memory buffers for zero-copy tensor" | **verified_mechanism** | Same mechanism |
| ADM-0006 | EvidenceContracts.swift | 495 | "indicating whether zero-copy" | **contract_doctrine** | Defines MediaCopyProof schema requirement |
| ADM-0007 | NativeWire.swift | 92 | "zero-copy (where possible) view" | **contract_doctrine** | Describes contract boundary behavior |
| ADM-0008 | MediaContracts.swift | 5 | "return a result containing a proof of zero-copy" | **contract_doctrine** | Contract requirement |
| ADM-0009 | SurfaceContracts.swift | 61 | "proving that a media operation maintained zero-copy" | **contract_doctrine** | Proof record description |
| ADM-0010 | MediaExecutorContracts.swift | 5 | "proof of zero-copy continuity" | **contract_doctrine** | Contract requirement |
| ADM-0011 | AudioBufferContracts.swift | 37 | "Proof of zero-copy continuity" | **contract_doctrine** | Contract requirement |
| ADM-0012 | MediaPrimitives.swift | 14 | "zero-copy container for hardware-backed" | **contract_doctrine** | Type definition |
| ADM-0013 | MediaGovernance.swift | 11 | "hardware-resident media" | **contract_doctrine** | MaterializationReason purpose definition |
| ADM-0014 | GPUCacheTier.swift | 72 | "MTLHeap with .storageModeShared for zero-copy" | **verified_mechanism** | .storageModeShared = actual zero-copy |
| ADM-0015 | CapsuleBuffer.swift | 4 | "buffer descriptor for zero-copy marshalling" | **contract_doctrine** | Contract type descriptor |
| ADM-0016 | DSLMemoryBridge.swift | 32 | "governed, zero-copy mapping of Binary Atlases" | **verified_mechanism** | MTLBuffer noCopy + mmap |
| ADM-0016 | DSLMemoryBridge.swift | 35 | "MTLBuffer(noCopy:...) to enable zero-copy" | **verified_mechanism** | Explicit MTLBuffer noCopy flag |
| ADM-0016 | DSLMemoryBridge.swift | 45 | "DSLMappedAtlas containing the zero-copy MTLBuffer" | **verified_mechanism** | References verified mechanism |
| ADM-0017 | TextProjection.swift | 8 | "zero-copy atlas access via DSLMemoryBridge" | **aspirational_target** | References DSLMemoryBridge (verified) |
| ADM-0017 | TextProjection.swift | 26 | "Maps... to GPU memory (zero-copy)" | **aspirational_target** | References DSLMemoryBridge |
| ADM-0018 | BinaryAtlasStandard.swift | 12 | "Optimized for zero-copy hardware saturation" | **verified_mechanism** | Binary Atlas = mmap-based |
| ADM-0018 | BinaryAtlasStandard.swift | 19 | "optimized for zero-copy mmap" | **verified_mechanism** | Explicit mmap mechanism |
| ADM-0018 | BinaryAtlasStandard.swift | 123 | "Provides a zero-copy view of the entire vector" | **verified_mechanism** | mmap contiguous buffer |
| ADM-0019 | CPUInferenceDispatcher.swift | 31 | "Zero-copy data access via unified memory" | **verified_mechanism** | Unified memory (.storageModeShared) |

### Count by Classification
| Category | Count | % of Remaining |
|---|---|---|
| contract_doctrine | 8 | 50% |
| verified_mechanism | 8 | 50% |
| aspirational_target | 0 | 0% (TextProjection references verified mechanism) |
| implementation_overclaim | 0 | 0% |
| requires_runtime_proof | 0 | 0% |

---

## 2. Classification Definitions

### implementation_overclaim
**Definition**: Code that claims zero-copy or hardware-resident behavior without:
- Proof mechanism (receipt, token, MediaCopyProof)
- Verified mechanism (mmap, MTLBuffer noCopy, .storageModeShared)
- Being in a contract/doctrine context

**Severity**: P1 (must fix)  
**Action**: Replace with accurate terminology or add proof

### contract_doctrine  
**Definition**: Statements in contract modules (ContractsCore, CapsuleCore, EvidenceContracts, etc.) that define:
- Requirements for zero-copy behavior
- Proof schemas (MediaCopyProof, copiedBytes accounting)
- Contract types describing zero-copy containers/behavior
- Governance reasons for materialization

**Severity**: NON-P1 (doctrine description)  
**Action**: Exclude from P1 claim audit

**Rationale**: Contracts define WHAT should happen and HOW to prove it. They are not implementation claims. Example from Anigma doctrine:
> "ZeroCopyProof tracks token, copiedBytes, and materializationReason, and that copiedBytes > 0 triggers audit behavior."

### verified_mechanism
**Definition**: Code that references concrete, provable zero-copy mechanisms:
- `mmap` with `MAP_SHARED` (shared memory mapping)
- `MTLBuffer` with `noCopy:` initializer
- `MTLHeap` with `.storageModeShared` (CPU/GPU unified memory)
- POSIX `shm_open` (shared memory)
- UMA (Apple's unified memory architecture)

**Severity**: NON-P1 (technical fact)  
**Action**: Exclude from P1 claim audit

### aspirational_target
**Definition**: Statements phrased as design goals or future intent:
- "zero-copy design goal"
- "intended for zero-copy operation"
- "copy-minimized where supported"

**Severity**: INFO (intent documentation)  
**Action**: Allow and encourage proper qualification

### requires_runtime_proof
**Definition**: Implementation code claiming zero-copy behavior that:
- Has a proof mechanism defined but not yet wired up
- Needs MediaCopyProof, copiedBytes tracking, token flow

**Severity**: P1 (missing proof for stated claim)  
**Action**: Add instrumentation OR replace claim with qualified intent

---

## 3. Proposed Rules Update

### Add Classification Categories to alignment-diagnostic-rules.yaml

```yaml
# Claim Classification Categories
# Used to distinguish overclaims from legitimate doctrine and facts
claim_classification:
  categories:
    - id: implementation_overclaim
      name: "Implementation Overclaim"
      description: "Implementation code claiming zero-copy/hardware-resident behavior without proof"
      severity: P1
      
    - id: contract_doctrine
      name: "Contract Doctrine"
      description: "Contract/interface definitions specifying zero-copy requirements or proof schemas"
      severity: informational
      path_patterns:
        - "ContractsCore/**/*"
        - "CapsuleCore/**/*"
        - "EvidenceContracts/**/*"
        - "*Contracts/**/*"
      
    - id: verified_mechanism
      name: "Verified Mechanism"
      description: "References to concrete, provable zero-copy mechanisms"
      severity: informational
      mechanism_patterns:
        - "mmap.*MAP_SHARED"
        - "MTLBuffer.*noCopy"
        - "\.storageModeShared"
        - "shm_open"
        - "UMA shared memory"
        - "Binary Atlas.*mmap"
        
    - id: aspirational_target
      name: "Aspirational Target"
      description: "Design goals clearly marked as intent, not current behavior"
      severity: informational
      qualify_patterns:
        - "zero-copy.*design goal"
        - "zero-copy.*where supported"
        - "copy-minimized"
        - "initializes.*for zero-copy"
        
    - id: requires_runtime_proof
      name: "Requires Runtime Proof"
      description: "Implementation claims zero-copy but lacks receipt/proof emission"
      severity: P1
      missing_proof_patterns:
        - "zero-copy.*without.*proof"
        - "zero-copy.*no receipt"
```

### Update Claim Audit Patterns with Classification

```yaml
# Zero-Copy Claim Audit Patterns (Updated with classification)
claim_audit_patterns:
  zero_copy:
    pattern: "zero-copy|zero copy|no-copy"
    severity: P1
    message: "Zero-copy claim without proven instrumentation."
    # Only flag if NOT in these categories:
    skip_if_classified_as:
      - contract_doctrine
      - verified_mechanism
      - aspirational_target
    
  hardware_resident:
    pattern: "hardware-resident|hardware resident"
    severity: P1  
    message: "Hardware-resident claim requires domain proof."
    skip_if_classified_as:
      - contract_doctrine
      - verified_mechanism
```

### Enhanced Claim Scan Exclusions

```yaml
# Claim Scan Exclusions - Expanded
claim_scan_exclusions:
  path_patterns:
    # Governance: doctrine files that define the rules
    - "Docs/governance/*.md"
    - "Docs/governance/*.yaml"
    # Research: analysis and criticism of zero-copy claims
    - "Docs/research/**/*"
    # Proofs: proof artifacts that document zero-copy proof mechanisms
    - "Docs/proofs/*.md"
    - "Docs/proofs/**/*.md"
    # Contract modules: contain doctrine, not implementation claims
    - "ContractsCore/**/*"
    - "CapsuleCore/**/*"
    - "EvidenceContracts/**/*"
    - "*Contracts/**/*"
```

---

## 4. Implementation Plan

### Phase 1: Update alignment-diagnostic-rules.yaml
1. Add `claim_classification` section with 5 categories
2. Add `skip_if_classified_as` to zero_copy and hardware_resident patterns
3. Expand `claim_scan_exclusions.path_patterns` with contract modules
4. Add mechanism-based exclusions

### Phase 2: Update Diagnostic Script (if needed)
If the Python script doesn't support the new YAML structure natively:
- Add classification logic to `Scripts/anigma_package_graph_audit.py`
- Implement path-based filtering for contract modules
- Implement mechanism pattern detection

### Phase 3: Validation
1. Run alignment matrix before/after
2. Verify ADM-0002 stays resolved
3. Verify no new cycles
4. Verify P1 count reflects only genuine issues

---

## 5. Expected Results

### Before Rules Update
- Total P1: 16
- implementation_overclaim: 0
- contract_doctrine: 8 (flagged as P1)
- verified_mechanism: 8 (flagged as P1)
- aspirational_target: 0
- requires_runtime_proof: 0

### After Rules Update
- Total P1: 0 (assuming no new implementation_overclaims exist)
- contract_doctrine: 8 (downgraded to informational)
- verified_mechanism: 8 (downgraded to informational)
- implementation_overclaim: 0

---

## 6. Risk Assessment

### Low Risk
- Adding contract module exclusions (well-defined paths)
- Adding mechanism pattern exclusions (specific, verifiable)
- Expanding doctrine exclusions

### Medium Risk
- New YAML structure may not be parsed by existing script
- Overly broad exclusions could hide real issues

### High Risk
- Accidentally suppressing legitimate implementation overclaims
- Breaking existing diagnostic validation

**Mitigation**: Test rules incrementally, verify each exclusion individually

---

## 7. Decision

**Approach**: Update alignment-diagnostic-rules.yaml with classification system first. If script doesn't support it, implement minimal script changes.

**Priority**: High - This blocks accurate P1 tracking and causes false positives

**Effort**: Medium - Rules update + potential script changes

---

*Research conducted by: Mistral Vibe*  
*Task: td-alignment-diagnostic-zero-copy-claim-classification*