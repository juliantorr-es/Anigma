# Research: Zero-Copy and Hardware-Resident Claim Audit

**Task ID**: td-zero-copy-hardware-resident-claim-audit  
**Severity**: P1 (23 zero-copy + 1 hardware-resident findings)  
**Status**: RESEARCH IN PROGRESS  
**Date**: 2025-01-17  

---

## Executive Summary

24 P1 findings remain after ExecutionCore → HardwareAuthority resolution:
- **23 zero-copy claims** across 19 files
- **1 hardware-resident claim** in MediaGovernance.swift

These fall into distinct categories requiring different remediation strategies.

---

## 1. Findong Classification Table

| ID | File | Line | Claim Type | Classification | Rationale | Action |
|---|---|---|---|---|---|---|
| ADM-0002 | SharedMemoryAuthority.swift | 5 | zero-copy | **DOCTRINE** | Describes POSIX shm_open/mmap intent | Keep - accurate description |
| ADM-0003 | VectorIndexCapsuleWrapper.swift | 119 | Zero-copy | **INTENTION** | "for GPU processing" - intention without proof | standardize to "GPU-accessible" |
| ADM-0004 | MetalGeometryAccelerator.swift | 6 | zero-copy | **ASPIRATIONAL** | Implementing with MetalBuffer | Keep with qualification |
| ADM-0006 | MediaFabricComponent.swift | 6 | zero-copy | **ASPIRATIONAL** | "Saturated Fabric" design goal | Keep with qualification |
| ADM-0007 | EvidenceContracts.swift | 495+ | zero-copy | **DOCTRINE** | Defines MediaCopyProof schema | Keep - contract requirement |
| ADM-0008 | NativeWire.swift | 92 | zero-copy | **DOCTRINE** | Describes contract behavior | Keep - contract requirement |
| ADM-0009 | MediaContracts.swift | 5 | zero-copy | **DOCTRINE** | Contract requirement requirement | Keep - contract requirement |
| ADM-0010 | SurfaceContracts.swift | 61 | zero-copy | **DOCTRINE** | Proof record description | Keep - contract requirement |
| ADM-0011 | MediaExecutorContracts.swift | 5 | zero-copy | **DOCTRINE** | Contract requirement | Keep - contract requirement |
| ADM-0012 | AudioBufferContracts.swift | 37 | zero-copy | **DOCTRINE** | Proof requirement | Keep - contract requirement |
| ADM-0013 | MediaPrimitives.swift | 14 | zero-copy | **Doctrine/Type** | Type definition | keepTYPE |
| ADM-0014 | MediaGovernance.swift | 11 | hardware-resident | **DOCTRINE** | Describes MaterializationReason purpose | Keep - accurate |
| ADM-0015 | AccelerateMediaProcessor.swift | 6 | Zero-copy | **INTENTION** | CVPixelBuffer processing claim | standardize to "direct buffer" |
| ADM-0016 | AccelerateMediaProcessor.swift | 16 | zero-copy | **INTENTION** | CVPixelBuffer claim | standardize to "direct buffer" |
| ADM-0017 | GPUCacheTier.swift | 72 | zero-copy | **TECHNICAL FACT** | MTLHeap .storageModeShared | Keep - accurate Metal fact |
| ADM-0018 | GlyphAtlasCapsule.swift | 43, 51, 122 | zero-copy | **INTENTION** | MTLBuffer via DSLMemoryBridge | Replace with "mapped GPU buffer" |
| ADM-0019 | CapsuleBuffer.swift | 4 | zero-copy | **DOCTRINE** | Contract type descriptor | Keep - contract requirement |
| ADM-0020 | DSLMemoryBridge.swift | 32, 35, 45 | zero-copy | **TECHNICAL FACT** | MTLBuffer noCopy usage | Keep - accurate |
| ADM-0021 | TextProjection.swift | 8, 26 | zero-copy | **TECHNICAL FACT** | DSLMemoryBridge mapped | Keep - references fact |
| ADM-0022 | BinaryAtlasStandard.swift | 12, 19, 123 | zero-copy | **TECHNICAL FACT** | mmap memory mapping | Keep - accurate |
| ADM-0023 | UnifiedTensor.swift | 5, 20, 26 | zero-copy | **INTENTION** | CPU/GPU access via MTLBuffer | Replace with "unified memory" |
| ADM-0024 | UnifiedMemoryPool.swift | 5, 20 | zero-copy | **INTENTION** | CPU/GPU tensor allocations | Replace with "unified memory" |

---

## 2. Classification Definitions

### DOCTRINE (Keep) - N=7
Claims in **contract modules** (ContractsCore) that define **requirements** and **proof schemas**.  
These are aspirations/standards, not claims about current implementation.  
**Examples**:
- "must produce a MediaCopyProof indicating whether zero-copy"
- "A contract for decoding... into a zero-copy frame handle"
- "proof of zero-copy continuity"

**Action**: NO CHANGE. These are legitimate contract specifications.

### TECHNICAL FACT (Keep) - N=4
Claims that reference **concrete, verifiable mechanisms** with zero-copy semantics:
- `.storageModeShared` in Metal = CPU can access GPU memory without copy
- MTLBuffer with `noCopy:` flag = buffer sharing
- mmap with MAP_SHARED = shared memory mapping

**Action**: NO CHANGE. These are accurate technical descriptions.

### INTENTION (Standardize) - N=8
Claims about **intent or design goal** without proof/receipt instrumentation:
- "for GPU processing"
- "GPU-accessible"
- "via DSLMemoryBridge"

**Action**: Replace with **accurate but non-overclaiming** terminology:
| Original | Replacement | Rationale |
|---|---|---|
| "zero-copy" | "copy-minimized" | Broad standard direction, implies intent not guarantee |
| "zero-copy" | "direct buffer" / "mapped buffer" | Specific mechanism without false guarantee |
| "zero-copy" | "unified memory" | MTLBuffer .storageModeShared semantics |
| "zero-copy" | "GPU-accessible" | Describes capability not guarantee |

### ASPIRATIONAL (Qualify) - N=2
Design goals that should be marked as such:
- "Implements ... with Zero-copy MetalBuffer geometry"
- "Managed within the Saturated Fabric for zero-copy continuity"

**Action**: Add qualifying language:
- "Zero-copy design goal" or "Intended for zero-copy operation"

---

## 3. Research Questions

### Q1: What defines a "zero-copy" overclaim?
**A**: A claim that data movement happens without copying **without**: 
- Receipt/instrumentation proving it
- Verifiable mechanism (mmap MAP_SHARED, MTLBuffer noCopy, .storageModeShared)
- Being in contract/doctrine context

### Q2: Which files are in contract vs implementation layers?
**A**:
- **Contract layer**: ContractsCore/* (FoundationContracts, EvidenceContracts, etc.)
- **Implementation layer**: All other Packages/ (SaturationKit, GlyphAtlasCapsule, etc.)

### Q3: What terminology should replace overbroad "zero-copy"?
**A**: Hierarchy of precision:
1. "copy-minimized" - General intent, no strong guarantee
2. "direct buffer access" - Specific mechanism
3. "mapped memory" - mmap/MTLBuffer mapping
4. "unified memory" - .storageModeShared semantics
5. "zero-copy (where possible)" - Explicit qualification

### Q4: What about "hardware-resident" claims?
**A**: Line 11 of MediaGovernance.swift:
```swift
/// Reasons for requesting a materialization (copy) of hardware-resident media.
```
This is **DOCTRINE** - it defines what the governance system handles. The term is accurate: materialization IS for hardware-resident media. **KEEP**.

### Q5: What constitutes proof/instrumentation?
**A**:
- Explicit receipt emission (MediaCopyProof, etc.)
- Measured copy count = 0
- Verified mechanism with known zero-copy semantics (mmap MAP_SHARED, MTLBuffer noCopy)
- Runtime instrumentation tracking copy operations

### Q6: Which claims have actual proof mechanisms?
**A**: Contracts that define proof schemas (EvidenceContracts) are themselves proof mechanisms. Claims WITHIN those contracts are doctrine, not overclaims.

### Q7: Should contract modules ever be flagged for zero-copy claims?
**A**: NO in general. Contracts define **requirements and schemas**, not **implementations**. The alignment rules should consider this.

**Recommendation**: Add exclusion for contract modules in claim audit rules, OR allow doctrine/aspirational usage in contracts.

---

## 4. Proposed Actions by Category

### Category A: DOCTRINE - No Change (7+1 hardware-resident)
Files (DO NOT MODIFY):
- ContractsCore/Sources/EvidenceContracts/EvidenceContracts.swift (ADM-0007)
- ContractsCore/Sources/EvidenceContracts/NativeWire.swift (ADM-0008)
- ContractsCore/Sources/FoundationContracts/MediaContracts.swift (ADM-0009)
- ContractsCore/Sources/FoundationContracts/SurfaceContracts.swift (ADM-0010)
- ContractsCore/Sources/FoundationContracts/MediaExecutorContracts.swift (ADM-0011)
- ContractsCore/Sources/FoundationContracts/AudioBufferContracts.swift (ADM-0012)
- ContractsCore/Sources/FoundationContracts/MediaSubstrate/MediaPrimitives.swift (ADM-0013)
- ContractsCore/Sources/EvidenceContracts/Governance/MediaGovernance.swift (ADM-0014)
- CapsuleCore/Sources/CapsuleCore/CapsuleBuffer.swift (ADM-0019)

**Rationale**: Contracts define what SHOULD happen and what proof looks like. These are not implementation overclaims.

### Category B: TECHNICAL FACT - No Change (5)
Files (DO NOT MODIFY):
- AnigmaSidecar/SharedMemoryAuthority.swift (ADM-0002) - shm_open/mmap
- TurboQuantKVCache/Sources/TurboQuantKVCache/GPUCacheTier.swift (ADM-0017) - MTLHeap .storageModeShared
- SaturationKit/Sources/SaturationKit/DSLMemoryBridge.swift (ADM-0020) - MTLBuffer noCopy
- SaturationKit/Sources/SaturationKit/TextProjection.swift (ADM-0021) - DSLMemoryBridge mapped
- SaturationKit/Sources/SaturationKit/BinaryAtlasStandard.swift (ADM-0022) - mmap

**Rationale**: These reference concrete mechanisms with provable zero-copy semantics.

### Category C: INTENTION - Standardize (8)
Files (MODIFY):
- VectorIndexCapsule/Sources/VectorIndexCapsule/VectorIndexCapsuleWrapper.swift:119 (ADM-0003)
  - "Zero-copy bulk vector retrieval" → "Bulk vector retrieval for GPU processing"
  
- MediaFingerprintCapsule/Sources/MediaFingerprintCapsule/AccelerateMediaProcessor.swift:6,16 (ADM-0015)
  - "Zero-copy frame extraction" → "Direct frame extraction"
  - "zero-copy CVPixelBuffer" → "direct CVPixelBuffer access"
  
- GlyphAtlasCapsule/Sources/GlyphAtlasCapsule/GlyphAtlasCapsule.swift:43,51,122 (ADM-0018)
  - "zero-copy GPU access" → "mapped GPU buffer access"
  - "zero-copy" in comments → "mapped"
  
- SaturationInferenceCore/Sources/SaturationInferenceCore/UnifiedTensor.swift:5,20,26 (ADM-0023)
  - "zero-copy CPU/GPU access" → "unified CPU/GPU memory"
  
- SaturationInferenceCore/Sources/SaturationInferenceCore/UnifiedMemoryPool.swift:5,20 (ADM-0024)
  - "zero-copy CPU/GPU memory" → "unified CPU/GPU memory"

### Category D: ASPIRATIONAL - Qualify (2)
Files (MODIFY):
- GeometryCapsule/Sources/GeometryCapsule/MetalGeometryAccelerator.swift:6 (ADM-0004)
  - "Zero-copy MetalBuffer geometry" → "MetalBuffer geometry (zero-copy design goal)"
  
- AnigmaCore/Sources/AnigmaPipeline/Pipeline/MediaFabricComponent.swift:6 (ADM-0006)
  - "zero-copy continuity" → "copy-minimized continuity (zero-copy design goal)"

---

## 5. Remediation Strategy

### Phase 1: Contract Module Exclusion (RECOMMENDED FIRST)
The alignment-diagnostic-rules.yaml currently flags ALL zero-copy text in production Swift files. Contracts defining proof schemas should NOT be flagged.

**Proposed rule update**:
```yaml
# In claim_scan_exclusions:
  path_patterns:
    # ADD: Contract modules defining proof schemas
    - "ContractsCore/**/*"
    - "*Contracts/**/*"
    - "AnigmaPrimitives/**/*"
```

This would eliminate ~7 false positives (ADM-0007 through ADM-0013, ADM-0019) immediately.

### Phase 2: Technical Fact Recognition
Mechanisms with provable zero-copy semantics should be exempt:
- mmap with MAP_SHARED
- MTLBuffer with .storageModeShared
- MTLBuffer with noCopy initialization

### Phase 3: Replace Overbroad Claims
For remaining true overclaims, replace with precise terminology.

---

## 6. Next Steps

1. **Immediate**: Update claim_scan_exclusions to exclude contract modules (reduces P1 by ~7)
2. **Immediate**: Document technical fact exceptions (reduces P1 by ~5)
3. **This task**: Fix remaining ~11 overbroad claims with precise terminology
4. **Follow-up**: For implementations with actual zero-copy mechanisms, add receipt emission

---

## 7. Decision Options

### Option A: All Fixes in This Task
Fix all 23 zero-copy + 1 hardware-resident claims now.
- **Pros**: Cleans all P1 findings
- **Cons**: May include changes to contract doctrine text; requires careful review

### Option B: Contract Exclusion First
1. Update rules to exclude contract modules from claim scanning
2. Document technical fact exceptions
3. Fix remaining implementation overclaims
- **Pros**: Architecturally sound; contract vs implementation distinction
- **Cons**: Requires rule change

### Option C: Conservative Fixes Only
Only fix clear overclaims in implementation files.
Leave contract doctrine and technical facts unchanged.
- **Pros**: Minimal risk; no doctrine changes
- **Cons**: P1 count only reduces partially

**RECOMMENDED**: Option B (Contract Exclusion First) + Option C (Conservative Fixes)

---

## 8. Risk Assessment

### Low Risk Changes
- Replacing "zero-copy" with "copy-minimized" in implementation comments
- Replacing "zero-copy" with specific mechanisms ("mapped", "unified memory")
- Adding qualifying language ("design goal", "where possible")

### Medium Risk Changes
- Modifying contract module comments (risk of changing doctrine intent)
- Updating alignment-diagnostic-rules.yaml (impacts all future scans)

### High Risk Changes
- Adding @_exported or other prohibited constructs
- Moving code between tiers
- Creating fake receipts/proofs

**Strategy**: Only low-risk changes in this task.

---

*Research conducted by: Mistral Vibe*  
*Task: td-zero-copy-hardware-resident-claim-audit*