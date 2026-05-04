# Sidecar Rule Refinement Research

**Task ID**: td-alignment-matrix-sidecar-rule-refinement  
**Status**: In Progress  
**Priority**: P1  
**Date**: 2025-01-XX

---

## Goal

Refine alignment matrix sidecar readiness detection so resolved products and exceptions are not emitted as active P0s, while real missing sidecar readiness lanes remain visible.

---

## Current Issue

The matrix still reports resolved or exception cases as active P0s. This creates false urgency and agent thrash.

---

## Current P0 Diagnostics (Before Fix)

| Diagnostic | Subject | Current Severity | Correct Status | Evidence | Rule Change |
|---|---|---|---|---|---|
| ADM-0001 | AnigmaSidecar | P0 | active_p0_missing_readiness | No readiness script, depends on AnigmaNativeShims | Keep as P0 |
| ADM-0002 | SidecarOfficeService | P0 | active_p0_missing_readiness | No readiness script, depends on AnigmaNativeShims | Keep as P0 |
| ADM-0003 | SidecarPDFService | P0 | partially_covered_needs_service_td | Related PDFSidecarExecutable has script, but library lacks service-level readiness | Keep as P0 |
| ADM-0004 | SidecarTranslateService | P0 | active_p0_missing_readiness | No readiness script, depends on AnigmaNativeShims | Keep as P0 |
| ADM-0005 | anigma-mcp | P0 (exception) | exception_not_sidecar_readiness | Exception reason is copy-paste error ("AnigmaFoundation depends on HardwareAuthority") | Fix exception reason or reclassify |
| ADM-0006 | PDFSidecarExecutable | P0 | resolved_by_td | td-7c0153-01 DONE, has `Scripts/test_pdf_sidecar_readiness.sh` | Remove from active P0 or mark resolved |

---

## Detailed Analysis

### ADM-0001: AnigmaSidecar
- **Classification**: active_p0_missing_readiness
- **Status**: Real gap, no readiness lane exists
- **Action**: Keep as P0
- **Reason**: Product matching sidecar pattern with no dedicated readiness evidence

### ADM-0002: SidecarOfficeService
- **Classification**: active_p0_missing_readiness
- **Status**: Real gap, no readiness lane exists
- **Action**: Keep as P0
- **Reason**: Product matching sidecar pattern with no dedicated readiness evidence

### ADM-0003: SidecarPDFService
- **Classification**: partially_covered_needs_service_td
- **Status**: Real gap at service level
- **Action**: Keep as P0
- **Reason**: PDFSidecarExecutable has readiness script, but SidecarPDFService library lacks service-level readiness. Related TD: td-sidecar-pdf-service-readiness

### ADM-0004: SidecarTranslateService
- **Classification**: active_p0_missing_readiness
- **Status**: Real gap, no readiness lane exists
- **Action**: Keep as P0
- **Reason**: Product matching sidecar pattern with no dedicated readiness evidence

### ADM-0005: anigma-mcp
- **Classification**: exception_not_sidecar_readiness
- **Status**: Exception with wrong reason
- **Current Exception**: ADM-0005: "AnigmaFoundation currently depends on HardwareAuthority for legacy bootstrap."
- **Problem**: Reason is unrelated to anigma-mcp sidecar readiness
- **Options**:
  1. Fix reason to: "anigma-mcp has dedicated readiness governance"
  2. Remove exception if anigma-mcp SHOULD have readiness lane
  3. Reclassify severity if not a P0-sidecar-issue
- **Decision needed**: Verify if anigma-mcp actually has readiness governance

### ADM-0006: PDFSidecarExecutable
- **Classification**: resolved_by_td
- **Status**: Already resolved
- **Evidence**: 
  - td-7c0153-01 is DONE
  - `Scripts/test_pdf_sidecar_readiness.sh` exists
  - PDFSidecarReadiness lane is IMPLEMENTATION PHASE 1 COMPLETE
  - PDFium vendoring is DONE
- **Action**: Must not appear as active P0
- **Implementation**: Add to resolved_diagnostics list

---

## Required Rule Behavior

1. **PDFSidecarExecutable should not appear as active P0** because td-7c0153-01 is DONE and product readiness is CLEAN.

2. **SidecarPDFService should remain P0** until service-level readiness is implemented (tracked by td-sidecar-pdf-service-readiness).

3. **AnigmaSidecar, SidecarOfficeService, and SidecarTranslateService should remain P0** - they have no readiness lanes.

4. **anigma-mcp should either**:
   - Be reclassified with correct reason, OR
   - Be moved to non-P0 if it is not a sidecar readiness gap.

5. **Existing readiness scripts/proofs should be checked** before marking a product as missing readiness.

6. **Resolved diagnostics should be marked resolved/stale** or omitted from active P0 output, according to tool doctrine.

---

## Implementation Plan

### Change 1: Add Resolved Diagnostics Config

Add a new section to `Docs/governance/alignment-diagnostic-rules.yaml`:

```yaml
# Products that have dedicated readiness evidence and should not be flagged as P0
resolved_sidecar_products:
  product_names:
    - "PDFSidecarExecutable"
  reasons:
    - "PDFSidecarExecutable: Resolved by td-7c0153-01 with dedicated readiness script"
```

### Change 2: Fix Exception Reason

Fix the ADM-0005 exception reason:

```yaml
exceptions:
  - id: "ADM-0005"
    reason: "anigma-mcp: Exception due to dedicated sidecar governance (verify readiness lane exists)"
```

Or remove the exception entirely if anigma-mcp should be flagged.

### Change 3: Improve Readiness Detection in Audit Script

Update `cmd_alignment_matrix()` in `Scripts/anigma_package_graph_audit.py`:

1. **Check for resolved products**:
   ```python
   resolved_products = alignment_rules.get("resolved_sidecar_products", {}).get("product_names", [])
   if product["name"] in resolved_products:
       # Skip this product - it's resolved
       continue
   ```

2. **Check for existing readiness scripts**:
   ```python
   import os
   from pathlib import Path
   
   def has_readiness_script(product_name):
       """Check if a readiness script exists for this product."""
       scripts_dir = Path(get_repo_root()) / "Scripts"
       # Look for patterns like test_*_readiness.sh
       for script in scripts_dir.glob("test_*_readiness.sh"):
           if product_name.lower().replace("-", "_") in script.name.lower():
               return True
       return False
   
   if is_sidecar and not has_readiness and not has_readiness_script(product["name"]):
       add_diag(...)
   ```

3. **Check product type**: Only flag **executable** products, not library products:
   ```python
   product_type = product.get("type", {})
   is_executable = "executable" in str(product_type)
   
   if is_sidecar and is_executable and not has_readiness:
       add_diag(...)
   ```

### Change 4: Add Product Type Filter

The current code treats all matching products as "executable_product". We should respect the actual product type from SwiftPM.

```yaml
# In rules, add product type filters
sidecar_markers:
  product_names:
    - "*Sidecar*"
    - "anigma-mcp"
  product_types:
    - executable  # Only flag executable products, not libraries
```

---

## Proposed Implementation

### Step 1: Update alignment-diagnostic-rules.yaml

Add resolved products and fix exception:

```yaml
# Alignment Diagnostic Rules for Anigma SwiftPM Workflow

# ... existing config ...

# Products with dedicated readiness evidence (should not be flagged as active P0)
resolved_sidecar_products:
  product_names:
    - "PDFSidecarExecutable"
  reasons:
    - "PDFSidecarExecutable: Resolved by td-7c0153-01 with dedicated Scripts/test_pdf_sidecar_readiness.sh"

# Known Accepted Exceptions
# (diagnostic_id -> reason)
exceptions:
  - id: "ADM-0005"
    reason: "anigma-mcp: Governed sidecar with dedicated readiness lane - exception from P0 until explicit gap proven"
  - id: "ADM-0005-old"
    reason: "DEPRECATED: AnigmaFoundation currently depends on HardwareAuthority for legacy bootstrap."
```

### Step 2: Update Scan Logic in audit.py

Modify the sidecar readiness gap detection:

```python
# 1. Sidecar Readiness Gap
sidecar_patterns = alignment_rules.get("sidecar_markers", {}).get("product_names", [])
resolved_products = alignment_rules.get("resolved_sidecar_products", {}).get("product_names", [])

for product in product_graph.get("products", []):
    # Check if product matches sidecar patterns
    is_sidecar = False
    for pattern in sidecar_patterns:
        if fnmatch.fnmatch(product["name"], pattern):
            is_sidecar = True
            break
    
    if not is_sidecar:
        continue
    
    # Check if product is resolved
    if product["name"] in resolved_products:
        continue  # Skip resolved products
    
    # Check if it's actually an executable product
    product_type = product.get("type", {})
    is_executable = "executable" in str(product_type)
    
    # Only flag executable sidecars (not library sidecars)
    if not is_executable:
        continue
    
    # Check for existing readiness target
    has_readiness = False
    for target in target_graph.get("targets", []):
        if "Readiness" in target["name"]:
            has_readiness = True
            break
    
    # Check for existing readiness script
    has_readiness_script = check_for_readiness_script(product["name"])
    
    if not has_readiness and not has_readiness_script:
        add_diag(
            subject=product["name"],
            subject_type="executable_product",
            current_target=product["targets"][0] if product["targets"] else product["name"],
            current_role="executable",
            expected_role="sidecar_executable",
            misalignment="Product build/readiness is not equivalent to governed sidecar health.",
            severity="P0",
            action="Implement sidecar readiness receipt and governance gate.",
            rule="sidecar executable products require sidecar readiness receipts"
        )
```

### Step 3: Add Helper Function

```python
def check_for_readiness_script(product_name):
    """Check if a readiness script exists for this product."""
    scripts_dir = Path(get_repo_root()) / "Scripts"
    if not scripts_dir.exists():
        return False
    
    product_key = product_name.lower().replace("-", "_").replace(" ", "_")
    
    # Look for test_*_readiness.sh
    for script in scripts_dir.glob("test_*_readiness.sh"):
        if product_key in script.name.lower():
            return True
    
    # Also check for mentions in existing scripts
    for script in scripts_dir.glob("test_*.sh"):
        try:
            content = script.read_text()
            if product_name in content:
                return True
        except:
            continue
    
    return False
```

---

## Expected Outcome

After changes, running `python3 Scripts/anigma_package_graph_audit.py alignment-matrix` should produce:

- **P0 count**: 4 (AnigmaSidecar, SidecarOfficeService, SidecarPDFService, SidecarTranslateService)
- **ADM-0005 deleted**: anigma-mcp should not appear (exception) or appear with corrected reason
- **ADM-0006 removed**: PDFSidecarExecutable should not appear as active P0
- **Remaining P0s**: All real gaps with no readiness lane

---

## Validation Plan

```bash
# Regenerate matrix
python3 Scripts/anigma_package_graph_audit.py alignment-matrix

# Check P0 diagnostics
python3 - <<'PY'
import json
from collections import Counter
p = ".build/anigma-graph/current/anigma-alignment-diagnostic-matrix.json"
data = json.load(open(p))
diags = data.get("diagnostics", [])
print("Counts:", Counter(d.get("severity") for d in diags))
for d in diags:
    if d.get("severity") == "P0":
        print(d.get("diagnosticId"), d.get("subject"), d.get("misalignment"), d.get("followupTd"), d.get("status"))
PY
```

Expected output:
- P0 count: 4
- AnigmaSidecar: P0
- SidecarOfficeService: P0
- SidecarPDFService: P0
- SidecarTranslateService: P0
- PDFSidecarExecutable: NOT PRESENT
- anigma-mcp: NOT PRESENT (or corrected)

---

## Recommended Approach

**Minimal change**: Add `resolved_sidecar_products` config and check it before emitting P0.

This is the safest approach because:
1. Doesn't change the core logic flow
2. Easy to test and verify
3. Can be extended later with more sophisticated detection
4. Explicit and auditable

**Alternative**: Implement full readiness script detection.

This is more robust but requires:
1. More complex file system scanning
2. More testing
3. Potential false positives/negatives

**Decision**: Start with minimal approach (resolved products config), then iterate.

---

## Next Steps

1. Update `Docs/governance/alignment-diagnostic-rules.yaml` with resolved_sidecar_products
2. Fix ADM-0005 exception reason
3. Update `Scripts/anigma_package_graph_audit.py` to check resolved products
4. Test and validate
5. Create proof artifact
