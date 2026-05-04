# Proof: Alignment Matrix Sidecar Rule Refinement

**Task ID**: td-alignment-matrix-sidecar-rule-refinement  
**Date**: 2025-01-XX  
**Status**: VALIDATED  
**Author**: Anigma Diagnostic Harness

---

## Diagnostic Execution

### Command
```bash
python3 Scripts/anigma_package_graph_audit.py alignment-matrix
```

### Output
```
Alignment matrix generated in .build/anigma-graph/current/
Summary: P0=4, P1=24, P2=0, Info=0
```

---

## Proof Results

### P0 Diagnostics (4 total)
All expected missing sidecar readiness lanes are preserved as P0:

| Diagnostic ID | Subject | Status | Follow-up TD |
|---|---|---|---|
| ADM-0001 | AnigmaSidecar | open | td-sidecar-anigma-readiness |
| ADM-0002 | SidecarOfficeService | open | td-sidecar-office-readiness |
| ADM-0003 | SidecarPDFService | open | td-sidecar-pdf-service-readiness |
| ADM-0004 | SidecarTranslateService | open | td-sidecar-translate-readiness |

### Resolved Products (0 active P0)
**PDFSidecarExecutable** is correctly suppressed from active P0 diagnostics:
- Resolved by: td-7c0153-01 (DONE)
- Evidence: `Scripts/test_pdf_sidecar_readiness.sh` exists
- Mechanism: Added to `resolved_sidecar_products` in alignment-diagnostic-rules.yaml

### Exception Handling
**anigma-mcp** is correctly handled via exception:
- Exception ID: ADM-0005
- Reason: "anigma-mcp: Governed sidecar with dedicated readiness lane - exception from P0 until explicit gap proven"
- Status: Suppressed from active P0 (exception applied)
- Note: Exception reason was corrected from copy-paste error ("AnigmaFoundation depends on HardwareAuthority")

---

## Root Cause Analysis

### Root Cause: Global Readiness Detection Bug
The regression was caused by global readiness detection. `BackendReadinessContractTests` satisfied the detector for every sidecar product, suppressing all P0 sidecar readiness findings.

```python
# BUGGY CODE (before fix)
has_readiness = False
for target in target_graph.get("targets", []):
    if "Readiness" in target["name"]:
        has_readiness = True  # ← Always True due to BackendReadinessContractTests
        break
```

Bad logic: "Any target with Readiness in the repo exists, therefore every sidecar has readiness."  
Correct logic: "Each sidecar/product must have its own product-specific readiness lane or documented exception."

### Fix Applied
Changed logic to check for **product-specific** readiness scripts only:

```python
# FIXED CODE
has_readiness_script = check_for_readiness_script(product["name"], repo_root)

if not has_readiness_script:
    # Flag as P0
```

The `check_for_readiness_script()` function scans for `test_*{product}_readiness.sh` scripts and checks script content for product mentions.

**Key principle**: Each sidecar/product must have its own product-specific readiness lane or documented exception, not a global check for the word "Readiness".

---

## Validation

### Before Fix
- P0 count: 0 (all sidecar findings incorrectly suppressed)

### After Fix
- P0 count: 4 (exactly the 4 real missing readiness lanes)
- All resolved/suppressed cases handled correctly

### Verification Script
```python
import json
from collections import Counter

data = json.load(open(".build/anigma-graph/current/anigma-alignment-diagnostic-matrix.json"))
diags = data.get("diagnostics", [])
print("Counts:", Counter(d.get("severity") for d in diags))

p0 = [d for d in diags if d.get("severity") == "P0"]
p0_subjects = [d.get("subject") for d in p0]
print("P0 subjects:", p0_subjects)

required = {"AnigmaSidecar", "SidecarOfficeService", "SidecarPDFService", "SidecarTranslateService"}
actual = set(p0_subjects)

# Verify all required P0 subjects are present
assert required - actual == set(), f"Missing P0 subjects: {required - actual}"

# Verify resolved products are not flagged
assert "PDFSidecarExecutable" not in actual, "PDFSidecarExecutable should not be active P0"
assert "anigma-mcp" not in actual, "anigma-mcp should be handled by exception"

print("✅ PASSED: All P0 sidecar diagnostics preserved correctly")
```

Result: `✅ PASSED: All P0 sidecar diagnostics preserved correctly`

---

## Files Modified

1. **Scripts/anigma_package_graph_audit.py** (lines 1273-1282)
   - Removed global `has_readiness` target name check
   - Now only checks product-specific readiness scripts
   - Fix: Changed `if not has_readiness and not has_readiness_script:` to `if not has_readiness_script:`

2. **Docs/governance/alignment-diagnostic-rules.yaml**
   - Added `resolved_sidecar_products` with PDFSidecarExecutable
   - Fixed ADM-0005 exception reason

---

## Requirements Satisfied

✅ Initial rule refinement over-suppressed P0 findings - **FIXED**  
✅ Regression fixed - **YES**  
✅ Resolved PDFSidecarExecutable is no longer active P0 - **VERIFIED**  
✅ anigma-mcp corrected/reclassified - **VERIFIED** (corrected exception reason)  
✅ Four real sidecar readiness gaps remain P0 - **VERIFIED** (P0=4)  
✅ No production Swift code changes - **CONFIRMED**  
✅ No Package.swift architecture changes - **CONFIRMED**  

---

## Decision Record

The regression was caused by a flawed global readiness check that matched `BackendReadinessContractTests` and other test targets with "Readiness" in their names. This caused all sidecar products to appear as having readiness coverage, suppressing legitimate P0 findings.

The fix switches to product-specific readiness detection, which correctly identifies:
- Products without readiness scripts → P0
- Products with readiness scripts → Not flagged
- Products in resolved list → Not flagged
- Products with exceptions → Not flagged

This preserves the signal-to-noise ratio while maintaining accurate gap detection.
