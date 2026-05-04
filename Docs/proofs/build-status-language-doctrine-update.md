# Proof: Build Status Language Doctrine Update

**Task**: Update build status language to distinguish PASS from CLEAN builds  
**Date**: 2026-05-03  
**Agent**: Mistral Vibe  
**Status**: COMPLETE  

---

## Summary

Updated repository documentation to use precise, unambiguous language for build status reporting. The term "build successful" is now forbidden as proof language because it conflates "exit code 0" with "zero warnings".

---

## Problem Statement

Agents were using "builds successfully" and "build successful" ambiguously. In Swift (and many other systems), a build can:
- Return exit code != 0 (**FAILED**) - build did not complete
- Return exit code 0 with warnings (**CONTAMINATED**) - build completed but has issues
- Return exit code 0 without warnings (**CLEAN**) - build completed perfectly

The phrase "build successful" fails to distinguish between CLEAN and CONTAMINATED states, which is critical for Anigma's quality standards.

---

## New Terminology

| Status | Definition | Previous Ambiguous Phrase |
|--------|------------|--------------------------|
| **FAILED** | Build returned nonzero exit code | "Build failed" (was acceptable) |
| **PASSED** | Exit code 0, warnings not checked | "Build successful" ❌ |
| **CLEAN** | Exit code 0, zero warnings | "Build successful" ❌, "No errors" ❌ |
| **CONTAMINATED** | Exit code 0, has warnings | "Build successful" ❌ |

---

## Rules Established

### Required

1. **MUST NOT** claim "clean build" unless warning output was captured and explicitly checked
2. **MUST NOT** use "build successful" as final proof language
3. **MUST** call builds with warnings CONTAMINATED, even if exit code is 0
4. **MUST** say "PASSED; warning status unknown" if warnings were not checked
5. **MUST** record in proof artifacts: command, exit code, whether warnings were scanned, warning count, final status

### Accepted Proof Wording

| Scenario | Required Language | Notes |
|----------|-----------------|-------|
| Warnings not checked | "Build PASSED; warning status unknown." | Must not claim CLEAN |
| Warnings present | "Build CONTAMINATED: exit code 0, N warnings detected." | Must specify count |
| Zero warnings | "Build CLEAN: exit code 0, zero warnings detected." | Must have scanned |
| Nonzero exit code | "Build FAILED." | Must not say successful |

### Forbidden Proof Wording

| Forbidden | Reason | Use Instead |
|-----------|--------|-------------|
| "Build successful" | Ambiguous (PASSED vs CLEAN vs CONTAMINATED) | PASSED/CLEAN/CONTAMINATED |
| "Build clean" without scan | Cannot prove zero warnings | "Build CLEAN: exit code 0, zero warnings detected." |
| "No errors" | Confuses errors with warnings | "Build CLEAN: exit code 0, zero warnings detected." |

---

## Files Updated

1. **`Docs/governance/REPO_HYGIENE_DOCTRINE.md`**
   - Added "Build Status Language" section
   - Defined FAILED/PASSED/CLEAN/CONTAMINATED terminology
   - Added rules for agent usage
   - Added accepted/forbidden wording tables
   - Added build status classification script

2. **`Docs/proofs/td-d65648-receiptsigner-extraction-proof.md`**
   - Updated build validation results to use new terminology
   - AnigmaFoundation: "Build CLEAN: exit code 0, zero warnings detected."
   - ExecutionCore: "Build FAILED: exit code 1, 4 warnings detected."

3. **`Docs/proofs/repo-root-td-artifact-cleanup.md`**
   - Will be updated to use new terminology (no build claims in that doc currently)

---

## Validation Commands Run

### AnigmaFoundation Build
```bash
$ cd anigma && set -o pipefail && swift build --target AnigmaFoundation 2>&1 | tee /tmp/anigmafoundation-build.log
$ echo "EXIT_CODE=$?"
# Result: EXIT_CODE=0

$ grep -ic "warning:" /tmp/anigmafoundation-build.log || true
# Result: 0

# Classification: BUILD_STATUS=CLEAN
```

### ExecutionCore Build
```bash
$ cd anigma && set -o pipefail && swift build --target ExecutionCore 2>&1 | tee /tmp/executioncore-build.log
$ echo "EXIT_CODE=$?"
# Result: EXIT_CODE=1

$ grep -ic "warning:" /tmp/executioncore-build.log || true
# Result: 4

# Classification: BUILD_STATUS=FAILED (exit code != 0, despite warnings)
```

---

## Build Status Report

| Target | Exit Code | Warning Count | Status | Language |
|--------|-----------|---------------|--------|----------|
| AnigmaFoundation | 0 | 0 | CLEAN | "Build CLEAN: exit code 0, zero warnings detected." |
| ExecutionCore | 1 | 4 | FAILED | "Build FAILED." |

**Note**: ExecutionCore FAILED is due to pre-existing compilation errors in `AnigmaGovernance` module (InMemoryEventLog, PostgresEventLog, PostgresWorkQueue) unrelated to this TD.

---

## Classification Script

The added build status classification script in REPO_HYGIENE_DOCTRINE.md can be used for consistent classification:

```bash
#!/bin/bash
set -o pipefail

TARGET="AnigmaFoundation"
LOG_FILE=".build/anigma-build-${TARGET}.log"

swift build --target ${TARGET} 2>&1 | tee "${LOG_FILE}"
EXIT_CODE=$?
WARNING_COUNT=$(grep -ic "warning:" "${LOG_FILE}" || true)

if [ "$EXIT_CODE" -ne 0 ]; then
  echo "BUILD_STATUS=FAILED"
elif [ "$WARNING_COUNT" -gt 0 ]; then
  echo "BUILD_STATUS=CONTAMINATED"
else
  echo "BUILD_STATUS=CLEAN"
fi
```

---

## Proof Artifact Updates

### td-d65648-receiptsigner-extraction-proof.md

Updated "Build Validation" section:

**Before**:
```
$ swift build --target AnigmaFoundation
# Result: ✅ SUCCESS (1.04s)
```

**After**:
```
$ swift build --target AnigmaFoundation
# exit_code=0, warning_count=0
# BUILD_STATUS=CLEAN
```

**Before**:
```
$ swift build --target ExecutionCore
# Result: ✅ SUCCESS
```

**After**:
```
$ swift build --target ExecutionCore
# exit_code=1, warning_count=4
# BUILD_STATUS=FAILED
```

---

## Acceptance Criteria

| Criterion | Status | Evidence |
|----------|--------|----------|
| "Build successful" no longer used as proof language | ✅ | Removed from all proof artifacts |
| Build proof language uses FAILED/PASSED/CLEAN/CONTAMINATED | ✅ | All documentation updated |
| Warning-contaminated builds explicitly distinguished | ✅ | CONTAMINATED status defined and used |
| Proof artifacts require warning scan evidence | ✅ | Classification script and rules added |
| AnigmaFoundation status accurately reported | ✅ | CLEAN (exit code 0, zero warnings) |
| ExecutionCore status accurately reported | ✅ | FAILED (exit code 1) |

---

## Related Files

- [Repository Hygiene Doctrine](Docs/governance/REPO_HYGIENE_DOCTRINE.md) - Updated with build status language
- [td-d65648 ReceiptSigner Extraction Proof](Docs/proofs/td-d65648-receiptsigner-extraction-proof.md) - Updated with accurate build status
- [Repo Root TD Artifact Cleanup](Docs/proofs/repo-root-td-artifact-cleanup.md) - No build claims to update

---

## Decision

✅ **BUILD STATUS LANGUAGE DOCTRINE UPDATE COMPLETE**

All documentation now uses precise, unambiguous language for build results. Agents are explicitly forbidden from using "build successful" as proof language. The four-state model (FAILED/PASSED/CLEAN/CONTAMINATED) is now canonical.
